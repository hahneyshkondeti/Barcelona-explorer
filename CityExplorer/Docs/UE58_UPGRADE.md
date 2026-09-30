# Unreal 5.8.3 upgrade

Existing project upgraded in place on unreal-migration. Engine: 5.8.3, CL 58210709. Host: Apple M2 Pro, arm64; Xcode 27.0, build 27A266a; macOS SDK 27.0.

- EngineAssociation changed from 5.5 to 5.8.
- Both targets now use BuildSettingsVersion.V7 and Unreal5_8 include order.
- Build helper defaults to the existing UE_5.8 installation.
- Xcode workspace regenerated successfully after resolving shared-engine warning-setting conflicts with V7 defaults.
- Mac VALID, without changing engine SDK bounds.
- CityExplorerEditor Mac Development -architecture=arm64 succeeded. Resulting project dylib is Mach-O arm64.
- Editor launch initially discovered the missing optional Xcode Metal Toolchain. Downloaded through xcodebuild -downloadComponent MetalToolchain; xcrun metal --version now succeeds.
- Existing project opened successfully in Unreal Editor with Metal SM6 on Apple M2 Pro. Gameplay migration continues separately; a C++ module build does not establish feature parity or a packaged game.
- Engine project generation warns about a missing MetalShaderConverter third-party include directory. It did not prevent the editor module build.

No Godot source, branch, save or installed application was changed. Original Unreal commit history is retained. Generated project files are not committed.
