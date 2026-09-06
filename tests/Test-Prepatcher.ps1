param(
    [Parameter(Mandatory = $true)][string]$PatcherPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$RunName,
    [Parameter(Mandatory = $true)][string]$ReferencesDirectory,
    [Parameter(Mandatory = $true)][string]$CompanionPath,
    [Parameter(Mandatory = $true)][string]$IncomingAssemblyPath,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [switch]$ExpectOriginalFailure
)

$ErrorActionPreference = 'Stop'
$PatcherPath = (Resolve-Path -LiteralPath $PatcherPath).Path
$ReferencesDirectory = (Resolve-Path -LiteralPath $ReferencesDirectory).Path
$CompanionPath = (Resolve-Path -LiteralPath $CompanionPath).Path
$IncomingAssemblyPath = (Resolve-Path -LiteralPath $IncomingAssemblyPath).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$protectedDirectories = @($sourceRoot, $ReferencesDirectory,
    [IO.Path]::GetDirectoryName($PatcherPath), [IO.Path]::GetDirectoryName($CompanionPath),
    [IO.Path]::GetDirectoryName($IncomingAssemblyPath))
foreach ($protectedDirectory in $protectedDirectories) {
    $protectedRoot = $protectedDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ($OutputDirectory -ieq $protectedRoot -or
        $OutputDirectory.StartsWith($protectedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputDirectory must be outside the repository and all input assembly directories.'
    }
}
$runRoot = Join-Path $OutputDirectory $RunName
if (Test-Path -LiteralPath $runRoot) { throw "Run directory already exists; choose a fresh RunName: $runRoot" }
New-Item -ItemType Directory -Path $runRoot | Out-Null
$childPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$summaries = [Collections.Generic.List[object]]::new()
$cases = @(
    @{Name = 'adjacent-same-directory'; Scenario = 'Adjacent'; SeparateWorkingDirectory = $false},
    @{Name = 'adjacent-with-spaces-and-other-working-directory'; Scenario = 'Adjacent'; SeparateWorkingDirectory = $true},
    @{Name = 'missing-companion'; Scenario = 'Missing'; SeparateWorkingDirectory = $true},
    @{Name = 'malformed-companion'; Scenario = 'Malformed'; SeparateWorkingDirectory = $true}
)
foreach ($case in $cases) {
    $caseRoot = Join-Path $runRoot $case.Name
    $caseDirectory = Join-Path $caseRoot 'Toolkit install with spaces'
    New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
    Copy-Item -LiteralPath $PatcherPath -Destination (Join-Path $caseDirectory 'UnityToolkit-Prepatcher.dll')
    if ($case.Scenario -eq 'Adjacent') {
        Copy-Item -LiteralPath $CompanionPath -Destination (Join-Path $caseDirectory 'System.Runtime.CompilerServices.Unsafe.dll')
    }
    elseif ($case.Scenario -eq 'Malformed') {
        [IO.File]::WriteAllBytes((Join-Path $caseDirectory 'System.Runtime.CompilerServices.Unsafe.dll'), [Text.Encoding]::UTF8.GetBytes('This is deliberately not a managed assembly.'))
    }
    $workingDirectory = $caseDirectory
    if ($case.SeparateWorkingDirectory) {
        $workingDirectory = Join-Path $caseRoot 'unrelated working directory'
        New-Item -ItemType Directory -Path $workingDirectory | Out-Null
    }
    $resultPath = Join-Path $caseRoot 'result.json'
    $logPath = Join-Path $caseRoot 'process.log'
    & $childPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-PrepatcherCase.ps1') -CaseDirectory $caseDirectory -WorkingDirectory $workingDirectory -ReferencesDirectory $ReferencesDirectory -IncomingAssemblyPath $IncomingAssemblyPath -ExpectedCompanionPath $CompanionPath -Scenario $case.Scenario -ResultPath $resultPath *> $logPath
    $childExit = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $resultPath)) { throw "Child process produced no result: $logPath" }
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $expectedFailure = $ExpectOriginalFailure -and $case.Scenario -eq 'Adjacent'
    $matchedExpectation = if ($expectedFailure) {
        -not $result.passed -and $childExit -eq 1 -and $result.error -like '*adjacent companion was not loaded*'
    } else { $result.passed -and $childExit -eq 0 }
    $summaries.Add([pscustomobject]@{
        name = $case.Name; scenario = $case.Scenario; childProcessId = $result.processId
        passed = $result.passed; expectedOriginalFailure = $expectedFailure
        matchedExpectation = $matchedExpectation; exitCode = $childExit; evidence = $resultPath
        incomingIdentity = $result.incomingIdentity; actualIdentity = $result.actualIdentity
        expectedIdentity = $result.expectedIdentity; error = $result.error
    })
}
$summary = [ordered]@{
    patcherPath = $PatcherPath
    patcherSha256 = (Get-FileHash -LiteralPath $PatcherPath -Algorithm SHA256).Hash
    runName = $RunName
    outputDirectory = $OutputDirectory
    actualCompiledMethods = @('TargetDLLs', 'Initialize', 'Patch')
    isolatedProcessPerCase = $true
    allExpectationsMet = @($summaries | Where-Object { -not $_.matchedExpectation }).Count -eq 0
    cases = @($summaries)
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding UTF8
$summaries | Select-Object name, passed, expectedOriginalFailure, matchedExpectation, exitCode | Format-Table -AutoSize
Write-Output ('Evidence: ' + (Join-Path $runRoot 'summary.json'))
if (-not $summary.allExpectationsMet) { exit 1 }
