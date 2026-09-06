# Changelog

## 2.0.2 — SPT 4.1.5 release candidate

Prepared for release; the download is held as a draft while in-game testing of the corrected prepatcher is pending. This is a compatibility update and bug fix. It keeps UnityToolkit's existing public API and companion library versions.

- **SPT 4.1.5 build:** rebuilt the plugin against the matching SPT references, including `spt-reflection` 4.1.5.0. Added the `SPT-4.1 Release` solution/project configuration and its .NET Standard 2.1 plugin target. The upstream plugin's 4.0.1 reflection reference caused SPT 4.1's startup version check to reject it.
- **Prepatcher build:** moved the prepatcher target to .NET Framework 4.8 and used the matching local SPT/BepInEx/Mono.Cecil references instead of the old package paths.
- **Companion lookup fix:** resolve `System.Runtime.CompilerServices.Unsafe.dll` from the prepatcher's containing directory. The old path appended the companion filename to the prepatcher DLL filename and could silently skip the replacement.
- **Player-loop lookup:** use the literal `"Injection"` reflection name so the patch compiles against the selected references while targeting the same method.
- **Version metadata:** set the plugin to 2.0.2 and both DLLs to assembly/file version 2.0.2.0. Include the prepatcher's existing AssemblyInfo source and retain Arys's authorship and the original plugin GUID.
- **Build controls:** add optional `SkipDeploy=true` guards for installation and archive targets, deterministic release settings, and the documented .NET SDK 9.0.314 build setup.
- **Standalone packaging:** preserve the original 15-file installation layout and its 13 unchanged companion/configuration files. Include two complete license-notice files, for 17 files total, retaining the original MIT license and companion credits.
- **Regression coverage:** add four isolated tests of the compiled prepatcher, covering adjacent, spaced/unrelated-working-directory, missing, and malformed companion cases. All four pass; the original bug reproduces in both adjacent cases. API and method comparisons confirm unchanged public API and plugin method bodies, with only the prepatcher's static constructor changing behavior.

The build and test results establish the checks above. They do not establish in-game behavior or compatibility with every mod using UnityToolkit. See the [release notes](docs/releases/v2.0.2.md) and [build/test instructions](BUILDING.md).

## 2.0.1 — upstream baseline

This update is based on Arys's UnityToolkit 2.0.1, source commit `3c27a9798dc4396ca0b3dc765448a4221ff3007b`. Earlier history remains available in the [upstream repository](https://github.com/ArysWasTaken/UnityToolkit).
