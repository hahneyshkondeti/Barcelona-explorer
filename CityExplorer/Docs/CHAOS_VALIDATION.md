# Chaos vehicle milestone

The prototype transform-driven pawn is replaced by AWheeledVehiclePawn with ChaosWheeledVehicleMovementComponent. The existing touring-car geometry is preserved, exported as a five-bone rig, and imported with its original materials. A single chassis box provides collision; wheels use the standard Chaos suspension, tire, drivetrain, ABS and traction-control simulation. The native vehicle animation graph uses Unreal's WheelController for suspension, rotation and steering.

## Automated runtime evidence (UE 5.8.3, arm64, Xcode 27)

2026-10-01: opt-in `-CityExplorerPhysicsProbe` executed the actual Barcelona map and vehicle using NullRHI. Four wheel contacts; chassis mass 1300 kg; settled roll approximately zero. With 0.65 throttle for three seconds the car travelled 5.48 m and reached 3.69 m/s. Service braking, front-wheel steering, pause immobility and recovery velocity reset passed. Completion marker: `CITY_EXPLORER_PHYSICS_SUCCESS`. Process exit status alone does not establish success on macOS.

The core offline-map, terrain, directed-route and historical handling tests also passed. The historical handling test validates reference math, not Chaos performance.

## Remaining validation

Visible wheel animation, mouse and keyboard menu flow, sustained driving, curb/building collision, camera clearance, frame timing and packaged launch still require checks. A locked Mac prevented the latest visible inspection. Passing this short simulation is not proof of production driving quality. Roads, world materials and lighting remain at the migration baseline and need the subsequent quality phases.

## Rebuilding the imported vehicle

`Tools/export_rigged_touring_car.gd` exports the preserved Godot touring-car geometry without altering the original Godot checkout. `Tools/import_touring_car.py` imports the rig. After an import, run `Tools/configure_vehicle_physics.py` in Unreal's Python commandlet to replace automatically generated multi-body collision with the intended chassis body. Import and configure scripts save the assets; runtime does not rewrite collision assets.
