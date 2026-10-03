# Installed Mac playability check — 2026-10-03

Scope: packaged `/Applications/City Explorer Unreal.app`, UE 5.8.3, Xcode 27, Apple Silicon arm64. Visual upgrades remain paused. Godot checkout and `/Applications/City Explorer.app` were not modified.

## Repairs

The recorded database was available. Remaining usability defects were in result presentation and keyboard focus: the combo had no explicit readable row renderer; Enter could clear query focus; the combo restored its own focus after selection, overriding immediate focus changes. Search now retains field focus on commit, focuses populated results, renders readable rows, and uses a one-shot Slate active timer to focus enabled Next after the popup reply completes. Slate timers run while gameplay is paused.

Settings sound previously saved a boolean without applying it. It now applies transient primary audio volume, including on startup. Sound and frame-limit buttons show feedback. Appearance rebuild restores button focus. Development diagnostics record navigation focus and window/pointer geometry without consuming input or logging typed street text.

## Actual installed GUI checks

All passes below used keyboard input and screenshots in the installed Metal application, outside Editor/PIE. Enter activates the real UMG button callbacks.

| Feature/button | Result |
|---|---|
| Explore and Barcelona selection | Pass |
| City Back | Pass: returns Home |
| Query typing and Enter search | Pass: `Carrer de Mallorca 494` returns 3 matches |
| Search button | Pass: `Carrer de Balmes 10` returns 5 matches |
| Result selection | Pass: Mallorca 493–495 and Balmes 10 are readable and selectable |
| Next | Pass: becomes enabled only after selection; opens car screen |
| Selected point and world startup | Pass: safe spawn stored and world started; car rendered at both chosen roads |
| Start exploring | Pass |
| Vehicle Back and location Back | Pass: returns address screen and city screen respectively |
| Short/no-match search | Pass: minimum-two-character and no-recorded-matches feedback; Next disabled |
| Driving | Pass for short keyboard throttle movement; visible car/world movement and speed HUD |
| HUD Pause, P and Escape | Pass |
| Pause Continue | Pass: restores exploration input |
| Recover to safe road | Pass: returns car to road with speed reset |
| Choose new location | Pass: returns focused address field |
| Settings and Settings Continue | Pass |
| Toggle sound | Pass for status/preference; audible-content coverage remains pending |
| Toggle 30/60 FPS | Pass for feedback and applied cap |
| Change appearance | Pass both directions; keyboard navigation retained |
| Pause Home | Pass: returns Home |

Menu/pause uses UIOnly with explicit focus. Driving uses GameAndUI with viewport focus so gameplay keys work and the Pause button remains reachable. Cursor is visible; mouse capture/lock is disabled.

## Installed executable physics regression

The actual installed executable ran with `-nullrhi -unattended -nosound -CityExplorerPhysicsProbe -stdout`. It reported `CITY_EXPLORER_PHYSICS_SUCCESS`:

- Four cooked steering mappings: D/Right +1, A/Left −1.
- Four ground contacts and 1300 kg vehicle mass.
- Throttle produced 368.6 cm/s and 547.9 cm travel over the measured interval.
- Braking, pause stability and safe recovery passed.
- Front-wheel angles were +6.2 degrees for right and −6.5 degrees for left.

This regression exercises cooked input modifiers and Chaos simulation; it is separate from physical key-hold steering acceptance.

## Build and remaining coverage

Native game compile, cook, stage and signing passed. Final Editor compile passed; platform validation reports Mac VALID. Installed deep strict signature verification passed. Updated bundle came from the verified staged app and replaced only the Unreal installation; previous candidates were retained in temporary backups.

Automated mouse coordinates did not reliably target the app on this multi-display Mac. Slate showed the window at desktop Y=2159 while generated pointer events targeted another display; coordinate actions also reported window-not-found. Therefore mouse click coverage is UNVERIFIED, not a pass or proof of an application mouse defect. The user previously independently confirmed mouse Explore and reached driving. Physical mouse search/result/Next acceptance remains required before resuming visual work.

Broad driving/collision/camera testing, live Google APIs, additional cities, audible content and performance profiling remain pending. Offline recorded-address search does not require a Google key. This is a functional development milestone, not production-quality acceptance.
