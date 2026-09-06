# Building UnityToolkit 2.0.2

The SPT 4.1.5 release builds the plugin for .NET Standard 2.1 and the prepatcher for .NET Framework 4.8. The instructions below compile locally with automatic deployment and archive creation disabled.

## Prerequisites

- Windows, Git, .NET SDK **9.0.314**, and the **.NET Framework 4.8 targeting pack**. `global.json` selects the SDK used for this release.
- SPT **4.1.5** compilation references, stored outside the repository.
- The companion libraries from Arys's [UnityToolkit 2.0.1 release](https://github.com/ArysWasTaken/UnityToolkit/releases/tag/v2.0.1). Use the installable archive, `UnityToolkit-v2.0.1.7z`, rather than a source-code download.

Clone this fork and run the commands from its root:

```powershell
git clone https://github.com/Tylevo/UnityToolkit-New.git
Set-Location -LiteralPath './UnityToolkit-New'
```

## Prepare the references

Create a local reference directory such as `C:/Path/To/SPT-References/410x/`. Place the following matching SPT 4.1.5 references in it:

```text
0Harmony.dll
Assembly-CSharp.dll
BepInEx.dll
Mono.Cecil.dll
Mono.Cecil.Mdb.dll
Mono.Cecil.Pdb.dll
Mono.Cecil.Rocks.dll
MonoMod.RuntimeDetour.dll
MonoMod.Utils.dll
Newtonsoft.Json.dll
spt-reflection.dll
System.Memory.dll
UnityEngine.dll
UnityEngine.CoreModule.dll
```

Use the matching publicized/hollowed game reference assembly for `Assembly-CSharp.dll`, as used by SPT client mod development. These files are compiler inputs from your local SPT development setup. Keep them out of commits and release archives, and do not replace live game assemblies with development references.

Extract the upstream 2.0.1 archive into a separate working folder. Copy its 11 plugin companion DLLs into `project/UnityToolkit/References/`, excluding `UnityToolkit.dll`:

```text
UniTask.Addressables.dll
UniTask.dll
UniTask.DOTween.dll
UniTask.Linq.dll
UniTask.TextMeshPro.dll
Unity.Collections.dll
VContainer.dll
ZLinq.dll
ZLinq.Unity.dll
ZLinq.Unity.UnityCollectoins.dll
ZString.dll
```

Keep the spelling `UnityCollectoins` in the upstream filename: the project references that exact file. Retain the upstream archive's patcher companion, `System.Runtime.CompilerServices.Unsafe.dll`, for packaging and tests.

## Compile

Set the paths below to your local directories. `$toolkitReferences` points to the directory **containing** `410x`; both directory values must end with a slash.

```powershell
$toolkitReferences = 'C:/Path/To/SPT-References/'
$toolkitInstall = 'C:/Path/To/SPT/'
$toolkitBuild = @(
    '--configuration', 'SPT-4.1 Release'
    '-p:Platform=AnyCPU'
    '-p:SptVersion=410x'
    '-p:SkipDeploy=true'
    "-p:SptSharedAssembliesDir=$toolkitReferences"
    "-p:SptDir=$toolkitInstall"
    '--disable-build-servers'
)

dotnet build project/UnityToolkit/UnityToolkit.csproj @toolkitBuild
if ($LASTEXITCODE -ne 0) { throw 'UnityToolkit build failed.' }

dotnet build project/UnityToolkit.Prepatcher/UnityToolkit.Prepatcher.csproj @toolkitBuild
if ($LASTEXITCODE -ne 0) { throw 'UnityToolkit prepatcher build failed.' }
```

`SkipDeploy=true` skips both projects' installation-copy and release-archive targets. Keep it set when compiling or testing without an intended installation. The commands explicitly override the inherited local path defaults in `Directory.Build.props`.

The resulting Toolkit DLLs are:

```text
project/UnityToolkit/Build/SPT-4.1/netstandard2.1/UnityToolkit.dll
project/UnityToolkit.Prepatcher/Build/SPT-4.1/UnityToolkit-Prepatcher.dll
```

Both DLLs should report assembly/file version `2.0.2.0`. The plugin's BepInEx version is `2.0.2`, and its SPT reflection reference is `4.1.5.0`.

## Validate and package

Run the compiled prepatcher tests using the explicit local inputs described in [tests/README.md](tests/README.md). The corrected build passed all four cases: adjacent companion, path with spaces and an unrelated working directory, missing companion, and malformed companion. The earlier prepatcher reproduced the original failure in both adjacent-companion cases.

For a standalone package, start from the upstream 15-file installation layout in a separate staging directory. Replace the two Toolkit DLLs with your build, retain the 13 unchanged companion/configuration files, and include the complete third-party notices in both Toolkit folders. The 2.0.2 ZIP has 17 files.

Do not copy a build output directory wholesale into a release: it can contain game and SPT references copied for compilation. Package only the reviewed Toolkit installation layout, with `BepInEx/` at the archive root.

Both builds completed with zero warnings and errors. SPT 4.1.5 startup verified the corrected companion lookup and UnityToolkit 2.0.2 loading; the tester reported no issues. This startup check does not establish complete raid, multiplayer, or every-mod compatibility.
