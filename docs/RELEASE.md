# Device acceptance and distribution

## Registered connections

- Firebase project: `living-atlas-7622a`
- Firestore: `(default)` / Standard / `nam5`
- Cloud Functions: `us-central1`
- iOS app: `1:661893013313:ios:3ad658c88e3f1a71614bc0`
- Android app: `1:661893013313:android:a9ee8844e1004ad6614bc0`
- Bundle/package: `com.livingwiki.mobile`
- Local Android debug SHA-1 registered for Google sign-in. Release/Play signing certificates must be registered separately.

No production rules or functions were deployed by this mobile implementation.

## Before store distribution

1. Select the Apple Developer team in Xcode and configure distribution signing. Enable Sign in with Apple in the Apple project and Firebase Authentication if that provider is to ship. The client implementation is present; the service must be enabled and exercised with an actual account.
2. Replace Android's starter debug signing for release with the intended upload key. Register the Play App Signing SHA certificates in Firebase. Keep signing credentials outside source control.
3. Exercise Google sign-in on physical iOS and Android devices, then verify email sign-in, signup, verification, password recovery, sign-out and account deletion. No real credentials or production test accounts are embedded here.
4. Accept the microphone prompt on a physical device and test a wiki call and a talking-card call, mute/unmute, interruption, leaving the screen and backgrounding. Confirm the existing ElevenLabs agent allows the backend-requested configuration and WebRTC token flow. The client needs no ElevenLabs key.
5. Use a regular account with and without a paid membership to test private boards and personal wiki creation. Verify backend-denied writes are explained correctly. Membership management currently continues on the website; evaluate store purchase rules before distribution.
6. Test a real document upload and URL ingestion in an owned wiki; wait for indexing and check the resulting articles/chat. Test Off Grids photos and resumable PinTalk uploads against an owned gem, and a friend contribution requiring approval.
7. Test an existing team member's listings, real invitations, and unread updates. Native team administration is intentionally absent. Do not confuse in-app updates with OS push notifications; APNs/FCM token registration and delivery are not implemented.
8. For HTTPS universal/app links, publish Apple and Android association documents on `livingwiki.com` and add the release signing identities and Apple application identifier. Custom `livingwiki://` links are already wired. Hosted route changes are outside this repository.
9. Finish store metadata, privacy disclosures and human acceptance of the complete journeys. The interface is English; content translation is available for English, French, Spanish, Portuguese, Japanese, German and Chinese. Full interface localization remains separate work.

## Verification boundaries

Automated tests exercise schema mapping, public filtering, edit ownership, stale-write protection, translation paths, sign-in form validation, navigation, account bookmark isolation, device settings, small/large text and tablet layouts. Local emulator checks apply the existing web project's actual Firestore rules to a payload serialized by the Dart repository.

The production smoke script is read-only and does not sign in, generate content, start voice calls, send messages or publish anything. Authenticated provider, payment, camera/gallery, microphone and real account write journeys require device acceptance. A passing analyzer or simulator build is not a claim that those external service workflows were exercised.

Assets are reused from the supplied web repository. Newsreader licensing is bundled in `assets/fonts/newsreader-OFL.txt`; public-wiki asset attribution is bundled in `assets/images/ATTRIBUTIONS.md`. Maps credit OpenStreetMap contributors.

## Nearby Gems device acceptance

- On a physical iPhone and Android device, allow foreground location, deny it, and deny permanently; confirm a typed city/address remains available.
- Turn location services off and confirm the app offers settings and manual search. No background location permission is requested.
- With an existing signed-in account, search each travel range, adjust the 4–16 card target, review map/list results and estimated travel times, keep a subset, then reopen and edit the private board in My Boards.
- Confirm directions use the selected walking/driving mode. The board retains place coordinates, never the user's search origin.
- The callable/grant/save contract is covered by mocked discovery tests and the real Firestore rules in an isolated demo emulator. Production authenticated discovery was not exercised with a live account during implementation.
