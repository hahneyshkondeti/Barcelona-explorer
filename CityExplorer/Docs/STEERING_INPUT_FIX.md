# Steering input repair — 2026-10-01

The user reported that both arrow directions steered right in the installed game.
Unreal inspection confirmed IMC_Driving had no modifiers on either Left or A:
both generated the same positive axis value as Right/D. The vehicle passes the
axis directly to Chaos steering.

Repaired the existing input asset: Left and A negate the X axis; Right and D
remain positive. The asset bootstrap now converts reflected key names to
strings and writes each modified mapping struct back into the mappings array.
Without the array write-back, Python edits to the struct were discarded.
Tools/repair_steering_input.py is an idempotent, targeted repair with assertions.

Validation: repair assertions passed with Left/A=-1 and Right/D=+1. A separate
Unreal process reloaded the saved asset and confirmed the two negative modifiers
persisted. The native Apple Silicon package is rebuilt with this asset. No
vehicle physics, visual systems, or Godot source changes are involved.
