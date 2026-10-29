# Verification record — October 29, 2026

The native implementation uses the supplied web repository as its backend contract. The original web checkout was not edited.

| Check | Result |
| --- | --- |
| Flutter static analysis | No issues |
| Unit and widget tests | 24 tests covering schema/privacy, translation, stale edits, account-scoped saves, forms, navigation and responsive layouts |
| Actual Firestore rules in a demo-project emulator | 5 checks passed: regular-user create, focused edit, ownership rejection, membership restriction and unlisted link access |
| Production public SDK/API smoke | 4 checks passed: wiki directory, full boards/cards, knowledge response, Off Grids directory |
| iPhone 17 Pro / iOS 26.2 simulator integration | Passed: app initialization, real public directory data, city navigation, boards and account screens |
| Android debug package | Built successfully |
| iOS simulator app | Built successfully |
| Compiled web preview | Built successfully |
| Phone browser visual inspection | Explore, Philadelphia wiki and public story gallery checked at 390 × 844 |

## Outputs

- Android: `build/app/outputs/flutter-apk/app-debug.apk`
- iPhone simulator: `build/ios/iphonesimulator/Runner.app`
- Web preview: `build/web/`

The debug APK is installable on Android devices allowing development installation. The iOS artifact is for simulators and is not a signed App Store archive. Build outputs are ignored by source control and can be regenerated using the README commands.

## Boundaries

These results do not certify store readiness or authenticated production writes. No live test users were created, no production stories were published, and no invitations or account emails were sent during verification. Physical-device sign-in, voice calls, media/document ingestion and subscription acceptance are listed in `RELEASE.md`. Backend rules, functions, billing and existing users were left unchanged; only the two mobile Firebase client registrations and the development Android certificate were added.
