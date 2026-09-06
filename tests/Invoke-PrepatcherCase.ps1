param(
    [Parameter(Mandatory = $true)][string]$CaseDirectory,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$ReferencesDirectory,
    [Parameter(Mandatory = $true)][string]$IncomingAssemblyPath,
    [Parameter(Mandatory = $true)][string]$ExpectedCompanionPath,
    [Parameter(Mandatory = $true)][ValidateSet('Adjacent', 'Missing', 'Malformed')][string]$Scenario,
    [Parameter(Mandatory = $true)][string]$ResultPath
)

$ErrorActionPreference = 'Stop'
$result = [ordered]@{
    scenario = $Scenario
    processId = $PID
    runtime = [Environment]::Version.ToString()
    caseDirectory = $CaseDirectory
    workingDirectory = $WorkingDirectory
    passed = $false
    error = $null
}
$incoming = $null
$expected = $null
$patched = $null

function Get-PublicApi([Mono.Cecil.AssemblyDefinition]$Assembly) {
    $api = [Collections.Generic.List[string]]::new()
    foreach ($type in $Assembly.MainModule.GetTypes()) {
        if (-not ($type.IsPublic -or $type.IsNestedPublic -or $type.IsNestedFamily -or $type.IsNestedFamilyOrAssembly)) { continue }
        $api.Add(('TYPE {0}|{1}|{2}' -f $type.FullName, $type.Attributes, $type.BaseType.FullName))
        foreach ($interface in $type.Interfaces) { $api.Add('INTERFACE ' + $type.FullName + '|' + $interface.InterfaceType.FullName) }
        foreach ($field in $type.Fields) {
            if ($field.IsPublic -or $field.IsFamily -or $field.IsFamilyOrAssembly) {
                $api.Add(('FIELD {0}|{1}|{2}' -f $field.FullName, $field.Attributes, $field.Constant))
            }
        }
        foreach ($method in $type.Methods) {
            if ($method.IsPublic -or $method.IsFamily -or $method.IsFamilyOrAssembly) {
                $api.Add(('METHOD {0}|{1}' -f $method.FullName, $method.Attributes))
                foreach ($parameter in $method.Parameters) {
                    $api.Add(('PARAMETER {0}|{1}|{2}|{3}' -f $method.FullName, $parameter.Index, $parameter.Attributes, $parameter.Constant))
                }
                foreach ($generic in $method.GenericParameters) {
                    $api.Add(('GENERIC {0}|{1}|{2}|{3}' -f $method.FullName, $generic.Name, $generic.Attributes, (($generic.Constraints | ForEach-Object { $_.ConstraintType.FullName }) -join ',')))
                }
            }
        }
        foreach ($property in $type.Properties) {
            if (($property.GetMethod -and $property.GetMethod.IsPublic) -or ($property.SetMethod -and $property.SetMethod.IsPublic)) {
                $api.Add('PROPERTY ' + $property.FullName)
            }
        }
        foreach ($event in $type.Events) {
            if ($event.AddMethod -and $event.AddMethod.IsPublic) { $api.Add('EVENT ' + $event.FullName) }
        }
    }
    return @($api | Sort-Object)
}

try {
    Set-Location -LiteralPath $WorkingDirectory
    [Environment]::CurrentDirectory = $WorkingDirectory
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $ReferencesDirectory 'Mono.Cecil.dll'))
    $null = [Reflection.Assembly]::LoadFrom((Join-Path $ReferencesDirectory 'BepInEx.dll'))
    $patcherPath = Join-Path $CaseDirectory 'UnityToolkit-Prepatcher.dll'
    $patcherAssembly = [Reflection.Assembly]::LoadFrom($patcherPath)
    $patcher = $patcherAssembly.GetType('UnityToolkit.Prepatcher.Patcher', $true)
    $result.patcherLocation = $patcherAssembly.Location
    $result.patcherSha256 = (Get-FileHash -LiteralPath $patcherPath -Algorithm SHA256).Hash
    $targets = @($patcher.GetProperty('TargetDLLs').GetValue($null, $null))
    $result.targetDlls = $targets
    if ($targets.Count -ne 1 -or $targets[0] -cne 'System.Runtime.CompilerServices.Unsafe.dll') {
        throw 'TargetDLLs changed or no longer names exactly the Unsafe companion.'
    }

    $incoming = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($IncomingAssemblyPath)
    $expected = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($ExpectedCompanionPath)
    $result.incomingIdentity = $incoming.Name.FullName
    $result.incomingMvid = $incoming.MainModule.Mvid.ToString()
    $result.incomingPublicApi = @(Get-PublicApi $incoming)
    $result.expectedIdentity = $expected.Name.FullName
    $result.expectedMvid = $expected.MainModule.Mvid.ToString()
    $result.expectedPublicApi = @(Get-PublicApi $expected)
    $result.expectedCompanionSha256 = (Get-FileHash -LiteralPath $ExpectedCompanionPath -Algorithm SHA256).Hash

    # These invoke the actual product methods and their static cache in a fresh process.
    $null = $patcher.GetMethod('Initialize').Invoke($null, $null)
    [object[]]$patchArguments = @($incoming)
    $null = $patcher.GetMethod('Patch').Invoke($null, $patchArguments)
    $patched = [Mono.Cecil.AssemblyDefinition]$patchArguments[0]
    $result.sameIncomingObject = [object]::ReferenceEquals($incoming, $patched)
    $result.actualIdentity = $patched.Name.FullName
    $result.actualMvid = $patched.MainModule.Mvid.ToString()
    $result.actualPublicApi = @(Get-PublicApi $patched)
    $result.actualModulePath = $patched.MainModule.FileName

    if ($Scenario -eq 'Adjacent') {
        if ($result.sameIncomingObject) { throw 'The adjacent companion was not loaded; Patch retained the incoming assembly.' }
        if ($result.actualIdentity -cne $result.expectedIdentity) { throw 'Replacement assembly identity differs from the companion.' }
        if ($result.actualMvid -cne $result.expectedMvid) { throw 'Replacement assembly module identity differs from the companion.' }
        if (@(Compare-Object $result.expectedPublicApi $result.actualPublicApi -CaseSensitive).Count -ne 0) {
            throw 'Replacement assembly public API differs from the complete companion API.'
        }
        if ([IO.Path]::GetFullPath($result.actualModulePath) -ine [IO.Path]::GetFullPath((Join-Path $CaseDirectory 'System.Runtime.CompilerServices.Unsafe.dll'))) {
            throw 'The replacement was not loaded from the adjacent companion file.'
        }
    }
    else {
        if (-not $result.sameIncomingObject -or $result.actualIdentity -cne $result.incomingIdentity -or
            $result.actualMvid -cne $result.incomingMvid -or
            @(Compare-Object $result.incomingPublicApi $result.actualPublicApi -CaseSensitive).Count -ne 0) {
            throw 'A missing or malformed companion must leave the incoming assembly object and metadata unchanged.'
        }
    }
    $result.passed = $true
}
catch {
    $result.error = $_.Exception.ToString()
}
finally {
    if ($patched -and -not [object]::ReferenceEquals($patched, $incoming)) { $patched.Dispose() }
    if ($incoming) { $incoming.Dispose() }
    if ($expected) { $expected.Dispose() }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
}
if ($result.passed) { exit 0 }
exit 1
