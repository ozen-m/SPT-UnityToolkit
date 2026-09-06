# Prepatcher regression tests

These tests invoke the compiled `UnityToolkit.Prepatcher.Patcher.TargetDLLs`, `Initialize()`, and `Patch(ref AssemblyDefinition)` methods in a separate Windows PowerShell 5.1 / .NET Framework process for each case. They load real BepInEx and Mono.Cecil libraries, rather than stubbing the product or repeating its path-resolution code.

You need a built prepatcher, its original `System.Runtime.CompilerServices.Unsafe.dll` companion, an incoming Unsafe assembly, and a directory containing the BepInEx and Mono.Cecil versions used by your target SPT installation. None of these binaries are included here.

## Run

All input paths and the output directory must be supplied explicitly. Choose an output folder outside both the repository and your game installation. The wrapper rejects output within the repository or any input assembly directory. It copies test fixtures into a fresh run folder and never changes the input assemblies.

From the repository root, replace the example paths with your own:

```powershell
$testArguments = @{
    PatcherPath = 'C:\ToolkitBuild\UnityToolkit-Prepatcher.dll'
    ReferencesDirectory = 'C:\SptReferences\410x'
    CompanionPath = 'C:\ToolkitCompanion\System.Runtime.CompilerServices.Unsafe.dll'
    IncomingAssemblyPath = 'C:\SptManaged\System.Runtime.CompilerServices.Unsafe.dll'
    OutputDirectory = 'C:\ToolkitTestResults'
    RunName = 'fixed-build-01'
}
& .\tests\Test-Prepatcher.ps1 @testArguments
```

Use Windows PowerShell 5.1. If script execution is disabled, a shell started with `powershell.exe -NoProfile -ExecutionPolicy Bypass` permits these scripts for that process without changing the system policy.

Use a fresh `RunName` for each run. Existing run folders are never overwritten. JSON evidence and process logs are written to `<OutputDirectory>/<RunName>/`. The wrapper exits nonzero if any expected result fails.

## What is checked

- An adjacent companion is loaded from the prepatcher's directory, including directory names containing spaces.
- An unrelated process working directory does not change which companion is selected.
- The replacement is a different assembly object and matches the companion's full identity, MVID, and enumerated public/protected API.
- Missing and malformed companions leave the incoming object, identity, MVID, and API unchanged.
- `TargetDLLs` names exactly `System.Runtime.CompilerServices.Unsafe.dll`.

The input assembly may already have the same version as the companion. The positive cases also check object replacement and the module's actual source path, so equal version numbers cannot produce a false pass. Each case runs in its own process to isolate the prepatcher's static cache.

To reproduce the original companion-path bug, supply a prepatcher built before the fix and add `-ExpectOriginalFailure`. In that mode, both adjacent-companion cases must fail specifically because no replacement was loaded, while the missing/malformed cases must pass:

```powershell
$testArguments.PatcherPath = 'C:\ToolkitBaseline\UnityToolkit-Prepatcher.dll'
$testArguments.RunName = 'original-path-bug-01'
& .\tests\Test-Prepatcher.ps1 @testArguments -ExpectOriginalFailure
```

These are isolated prepatcher regression tests. They do not launch SPT, verify BepInEx startup order, or establish runtime compatibility with every consuming mod. Keep generated fixtures, logs, and binary inputs out of commits and release archives.
