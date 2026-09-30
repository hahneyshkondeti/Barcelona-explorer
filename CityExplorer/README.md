# CityExplorer — Unreal migration

This is the initial Unreal 5.5.4 C++ project scaffold. It is not yet a playable migration. No levels, widgets, input assets or migrated gameplay classes exist yet. Compilation, editor launch and packaging are blocked by the incompatible Xcode 27.0 toolchain. Do not substitute this for the working Godot application.

The preserved Godot source remains at this checkout's root and on `codex/mac-first` at commit `53fb555`. The original checkout remains on that branch. This checkout is on `unreal-migration`.

Read `Docs/MIGRATION.md` for the architecture mapping, validation checklist and next steps. `Docs/SOURCE_INVENTORY.json` records source hashes, script interfaces and asset types. Offline geographic data and compatible source textures remain at the repository root; they have not been imported or staged into Unreal yet.

Once full compatible Xcode is installed and selected, build the editor target using the installed Unreal engine's Mac Build.sh with `CityExplorerEditor Mac Development -Project=<absolute path>/CityExplorer.uproject`. Only proceed with asset generation and gameplay migration after successful compilation.
