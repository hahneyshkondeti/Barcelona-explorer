# iOS delivery from GitHub

App Store account setup and public submission are parked. The repository includes an iOS build workflow, unsigned compile validation, and an explicitly selected signing/upload path. An unsigned build cannot be installed on an iPhone. Signed builds still need device QA and Apple processing/review.

## Configuration

- Working name: Brisa — Barcelona. Store name availability is not verified.
- Bundle ID: `com.hahneyshkondeti.brisa`; Apple team: `SZ65B2964T`.
- iPhone only, arm64, landscape, minimum iOS 16. Baseline target: iPhone 11/A13 at 30 FPS, optional 60 FPS. City-scale device performance is not yet verified.
- Godot 4.5 stable, official binaries and templates pinned by SHA-512.
- GitHub `macos-26` runner, checks iOS SDK >=26. Apple requires Xcode 26/iOS 26 SDK for current uploads; this does not change the app's iOS 16 deployment minimum.
- Build number comes from the GitHub workflow run number. Start a new workflow run for another upload; do not re-upload an already accepted build number. If moving an existing app to this workflow, ensure the run number exceeds its current build number first.

## Available now: build without credentials

1. Open repository Actions → **iOS build** → Run workflow → `unsigned`.
2. CI imports assets, validates city data, runs handling/gameplay/city/model/streaming tests, exports a fresh Xcode project, compiles for a generic physical iPhone, and checks the app's identity, orientation, data bundle, privacy manifest and icon.
3. Download the `Brisa-Xcode-<run>` artifact (retained 7 days). Unzip, open `ios/Brisa.xcodeproj`, choose your Apple team/signing and physical iPhone, then Run. The artifact includes the offline city. Use full Xcode 26+, not only Command Line Tools.

CI also runs automatically for code pushes and pull requests. Pull requests never use Apple secrets. The signed job only runs manually from `main` after validation passes. Workflow artifacts are build outputs, not an App Store release.

## Later: signed archive or upload

The GitHub `app-store` environment is already created and restricted to the `main` branch; no Apple credentials have been added.

Create/register the matching App ID and App Store Connect app record in your Apple account. Make an Apple Distribution certificate (export as password-protected `.p12` with its private key) and an App Store provisioning profile for that exact ID and certificate. Store these as GitHub **app-store environment secrets** (repository secrets are also accepted):

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 of the distribution `.p12` |
| `P12_PASSWORD` | Password protecting the `.p12` |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 of the App Store `.mobileprovision` |
| `ASC_KEY_BASE64` | Base64 of an App Store Connect API `.p8` key, upload mode only |
| `ASC_KEY_ID` | API key ID, upload mode only |
| `ASC_ISSUER_ID` | API issuer ID, upload mode only |

Do not commit these files or paste values into chat. On macOS, `base64 -i /path/to/file | pbcopy` copies a file's encoded content for the GitHub secret field. The API key must have access to upload this app. The environment allows `main` deployments; you can optionally require your review before signing.

Run Actions → iOS build → `archive` to obtain a signed IPA. Choose `upload` only when ready to send the build to App Store Connect/TestFlight. The signing script validates profile identity, expiry and distribution type, creates a temporary keychain, archives/exports with manual signing, and removes signing files afterward. It does not create certificates or accept account agreements.

The workflow does not submit App Review, enable public sales, add testers, or automatically release the app. After Apple processes the upload, test it on the baseline phone; then complete the store record and submit through App Store Connect.

## Store materials and final device gate

Draft description: “Explore Barcelona by car at your own pace. Follow mapped streets, discover Sagrada Família and browse offline places and addresses across the city's ten districts. Streets, footprints and tree locations use dated open data; terrain, façades and landmark models are simplified interpretations.” Do not advertise photographic reconstruction, live shops, surveyed terrain or measured device FPS.

The repository's original icon is `assets/icon.svg`. Capture App Store screenshots on actual supported iPhone builds; the current desktop development screenshots are not submission screenshots. Confirm store name, category, age-rating answers, pricing/territories, support contact/URL and privacy-policy URL in the account. A privacy statement draft is in `PRIVACY.md`; publish it at a stable public URL and add the owner's contact before submission.

Required device checks: first launch in airplane mode, a 15-minute drive through dense Eixample and a tile boundary, district jumps, memory/thermal behavior, 30/60 FPS frame-time capture, touch safe areas, collision/recovery, audio interruptions, background/resume, saving across relaunch and fresh installation. Current city data and navigation graph have substantial memory cost; raise the minimum device or reduce the dataset resident in memory if profiling shows pressure. Do not mark the release ready solely because CI compiles.

No accounts, analytics, advertisements, runtime network calls, GPS or external SDKs are used by game scripts. Local saves contain virtual car position, discoveries and settings. The export declares no tracking/collected data; engine required-reason API declarations cover app-container file metadata, on-device time measurement and local file writing. Reassess privacy declarations when adding SDKs or network services.

Sources: [Godot iOS export](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_ios.html), [GitHub Xcode signing](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications), [Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/), [Apple upload workflow](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

## Verified build

The unsigned iPhone compile and exported-app checks passed in [GitHub run 35929020609](https://github.com/hahneyshkondeti/Barcelona-explorer/actions/runs/35929020609), using source commit `b5ac516`. Download **Brisa-Xcode-2** from that run's Artifacts section (about 160 MB compressed; expires after 7 days). This contains the exported project for local signing. No signing or App Store upload was performed.
