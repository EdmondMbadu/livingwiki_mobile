# LivingWiki mobile

A native Flutter companion to LivingWiki for regular users. Built around Explore, Boards, Ask, and You, with a warm editorial design, bundled Newsreader typography, existing LivingWiki imagery, native Firebase connections, and no admin interface.

## Run

Requires Flutter 3.41 / Dart 3.11 or later, Xcode with iOS 15+ support, or an Android SDK for API 24+. The package lock is committed as the reproducible dependency baseline.

```sh
flutter pub get
flutter run
```

For a browser preview:

```sh
flutter run -d chrome --web-port 5174
```

The registered app identifier is `com.livingwiki.mobile` on both mobile platforms. Public client configurations are in `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`, and `android/app/google-services.json`. They target the same `living-atlas-7622a` project as the web app, the standard `(default)` Firestore database, and Cloud Functions in `us-central1`. These files contain public client identifiers, never service-account credentials or AI keys.

## Product coverage

See [the feature and backend map](docs/FEATURE_MAP.md) for each journey and its web counterpart, and [release preparation](docs/RELEASE.md) for device testing and distribution requirements.

Native flows include public discovery and maps; city, university, and personal wikis; articles and source references; chat and conversation history; voice and talking cards; public and personal boards; board/card creation, editing, reordering and drafts; AI board generation; story playback and content translation; saved boards, likes, collections, trips, music and videos; Off Grids and PinTalks; source uploads; team membership and invitations; profiles and authentication.

Membership/billing, advanced media production and avatar configuration, team draft authoring, and the Trove game continue on the existing website. In-app team updates are supported; OS push notifications require additional backend and platform provisioning. The UI is English; story content can be translated into seven supported languages. This is a substantial native implementation, not an assertion of full parity with every web Studio tool.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
flutter build web
flutter test integration_test/public_smoke_test.dart -d <simulator-id>
```

The public smoke script makes no authenticated or content writes:

```sh
node scripts/public-smoke.mjs
```

The rule compatibility test uses an isolated local **demo** project and the exact serializer payload emitted by Dart. It reads the existing web rules without deploying them or changing production. It requires Java 21+, Firebase CLI, and the sibling web app's installed Node dependencies:

```sh
flutter test --dart-define=EXPORT_BOARD_FIXTURE=/tmp/livingwiki-mobile-board.json test/repository_test.dart
node scripts/check-firestore-rules.mjs
```

Set `LIVINGWIKI_WEB_ROOT` when the web repository is not at `../living-wiki`.

## Implementation notes

- Firebase is initialized explicitly per platform. Email/password and Google authentication use existing accounts; Apple authentication is implemented and requires its provider to be enabled before release.
- Firestore rules remain the authority for permissions and paid entitlements. The app never writes roles or subscription fields.
- Existing board edits preserve unknown fields and use an optimistic version check to reject stale edits from another device.
- Device bookmarks and drafts are scoped by account. Signing out clears private navigation, chat selection, and profile state. Bookmark behavior follows the web app's device-local design.
- Voice uses temporary backend-issued ElevenLabs WebRTC tokens. No provider API keys enter the app. A conversation starts only when the user taps its button, and ends when the screen closes or the app moves to the background.
- Documents use `prepareDocumentUpload`; Off Grids uses server-issued upload tickets; PinTalks upload in 8 MB resumable chunks. Existing server approval, visibility, and quota checks remain in force.
- Authenticated workflows need an actual member account for final device acceptance. Tests use isolated mocks/emulators; they do not create production users, send invitations, or publish test content.
# livingwiki_mobile
