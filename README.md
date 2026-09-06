# UnityToolkit

UnityToolkit gives SPT client modders a shared set of libraries for asynchronous work, native collections, dependency injection, LINQ, and string building. It was created by [Arys](https://github.com/ArysWasTaken/UnityToolkit); this fork is maintained by Tylevo.

**2.0.2 is a release candidate for SPT 4.1.5.** Both projects build successfully and all four isolated prepatcher tests pass. In-game testing of the corrected prepatcher is still pending. The release is being held as a draft, so its download is not publicly available yet.

## What changed in 2.0.2

The plugin is rebuilt against SPT 4.1.5 references. The old 2.0.1 plugin referenced SPT 4.0.1, which caused SPT 4.1's startup version check to reject it.

This version also fixes the prepatcher's companion lookup. It previously treated its own DLL filename as a directory and could silently skip loading `System.Runtime.CompilerServices.Unsafe.dll`. It now finds that library beside the prepatcher DLL, including when the game is started from a different working directory.

The public API and plugin GUID are unchanged. The companion libraries have not been upgraded. See the [changelog](CHANGELOG.md) for the complete changes and [release notes](docs/releases/v2.0.2.md) for the candidate's validation status.

## Installing

Use the installable ZIP from [Releases](https://github.com/Tylevo/UnityToolkit-New/releases) once 2.0.2 is published. GitHub's source-code archives are for development and do not contain a complete installation.

1. Close SPT and the launcher.
2. Extract the complete ZIP into your SPT 4.1.5 folder and replace the existing UnityToolkit files when prompted.
3. Keep one UnityToolkit installation in these locations:

   ```text
   BepInEx/plugins/UnityToolkit/
   BepInEx/patchers/UnityToolkit/
   ```

Install both folders, including their companion DLLs and notices. UnityToolkit is a standalone dependency shared by the mods that use it; it does not require any particular consuming mod. Compatibility with every dependent mod has not been verified.

## Included libraries

| Library | Used for |
| --- | --- |
| [UniTask](https://github.com/Cysharp/UniTask) | Async/await and coroutine alternatives suited to Unity. |
| [Unity.Collections](https://docs.unity3d.com/Packages/com.unity.collections@2.6/manual/collections-overview.html) | Native container types for Unity code and jobs. Follow the library's allocation and job-safety rules. |
| [VContainer](https://vcontainer.hadashikick.jp) | Dependency injection for C# classes and Unity components. |
| [ZLinq](https://github.com/Cysharp/ZLinq) | LINQ operations through value enumerables. |
| [ZString](https://github.com/Cysharp/ZString) | String building with reduced allocations. |

The package also includes UnityToolkit's prepatcher and its Unsafe companion library. The linked documentation describes the libraries; APIs available to your mod depend on the versions included in the package.

## Using UnityToolkit in a mod

Copy the assemblies from the release into your project's reference folder, then add references to UnityToolkit and the companion libraries your mod uses. Declare the dependency on your BepInEx plugin class:

```csharp
[BepInDependency("com.arys.unitytoolkit", "2.0.2")]
```

Use the `BepInEx` namespace for this attribute. Players must install the complete UnityToolkit package alongside your mod. The dependency GUID remains `com.arys.unitytoolkit`.

For source builds and local reference setup, see [BUILDING.md](BUILDING.md). The [prepatcher test guide](tests/README.md) explains how to run the isolated regression tests.

## Credits and license

UnityToolkit is by Arys and retains its original [MIT license](LICENSE). Tylevo maintains this SPT 4.1.5 update. The companion libraries retain their authorship and licenses, with full notices included in both installation folders.

[Upstream source](https://github.com/ArysWasTaken/UnityToolkit) · [Existing Forge page](https://forge.sp-tarkov.com/mod/1426/unitytoolkit)
