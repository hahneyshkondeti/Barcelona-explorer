# CityExplorer — Unreal migration

The existing project now targets Unreal Engine 5.8.3. Xcode 27 is accepted by Unreal platform validation; the arm64 editor module builds successfully. Project files were regenerated after adopting the engine's V7 build settings and Unreal5_8 include order. Apple's Metal Toolchain 27A266a was installed for shader compilation.

This remains an in-progress migration, not a replacement for the working Godot application. Read `Docs/MIGRATION.md` and `Docs/UE58_UPGRADE.md` for status and validation.

Build the editor with `python3 Tools/build_editor.py`. The default engine is `/Users/Shared/Epic Games/UE_5.8`; override `UE_ROOT` or `DEVELOPER_DIR` when needed. Generated Xcode workspace, Binaries, Intermediate, Saved and shader caches are local build products.

Godot remains on `codex/mac-first` at `53fb555`, and its installed app is untouched. Unreal development remains on `unreal-migration` with upstream `origin/unreal-migration`.
