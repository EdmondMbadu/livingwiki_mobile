import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livingwiki_mobile/core/app_state.dart';
import 'package:livingwiki_mobile/core/nearby_location.dart';
import 'package:livingwiki_mobile/core/theme.dart';
import 'package:livingwiki_mobile/data/models.dart';
import 'package:livingwiki_mobile/data/nearby_gems.dart';
import 'package:livingwiki_mobile/data/repository.dart';
import 'package:livingwiki_mobile/features/nearby_gems.dart';

Json response(String id) => {
  'board': {
    'title': 'Gems near Philadelphia',
    'description': 'Two lovely places',
    'kind': 'nearby-gems',
    'nearbyGems': {
      'locationLabel': 'Philadelphia, PA',
      'range': 'walk',
      'travelMode': 'walking',
      'defaultSort': 'travel-time',
      'generatedAt': '2026-10-29T00:00:00.000Z',
      'originStored': false,
      'generationGrantId': id,
    },
  },
  'cards': [
    {
      'title': 'A little garden',
      'notes': 'An unexpectedly peaceful corner.',
      'type': 'place',
      'scope': 'place',
      'status': 'saved',
      'tags': ['nearby gem'],
      'locationLat': 39.94,
      'locationLng': -75.16,
      'nearby': {
        'durationSeconds': 600,
        'distanceMeters': 700,
        'measurement': 'route',
        'category': 'Outdoors',
      },
    },
    {
      'title': 'The old bookshop',
      'notes': 'A place to get lost in a story.',
      'type': 'shop',
      'scope': 'place',
      'status': 'saved',
      'tags': ['nearby gem'],
      'locationLat': 39.95,
      'locationLng': -75.17,
      'nearby': {
        'durationSeconds': 300,
        'distanceMeters': 900,
        'measurement': 'estimated',
        'category': 'Curious corner',
      },
    },
  ],
};

class NearbyRepository extends LivingRepository {
  NearbyRepository({
    required FakeFirebaseFirestore database,
    required MockFirebaseAuth auth,
  }) : super(database: database, auth: auth);
  Json? arguments;
  int searches = 0;
  FirebaseFunctionsException? failure;
  Completer<Json>? pending;
  @override
  Future<Json> call(String name, [Json arguments = const {}]) async {
    if (name != 'discoverNearbyGems') return {};
    searches++;
    if (failure != null) throw failure!;
    this.arguments = arguments;
    return pending == null
        ? response(arguments['boardId'] as String)
        : pending!.future;
  }
}

class UnavailableLocation extends NearbyLocation {
  @override
  Future<Position> current() async => throw const NearbyLocationFailure(
    'Location access was not allowed. Enter a starting place instead.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late NearbyRepository repo;
  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'test-user', displayName: 'Test Explorer'),
      signedIn: true,
    );
    repo = NearbyRepository(database: db, auth: auth);
  });
  test(
    'callable contract, UUID grant, private save, and lossless cards',
    () async {
      final draft = await repo.discoverNearbyGems(
        range: NearbyRange.walk,
        count: 8,
        details: ' Gardens ',
        manualLocation: ' Philadelphia ',
      );
      expect(repo.arguments!['boardId'], matches(RegExp(r'^[a-f0-9-]{36}$')));
      expect(repo.arguments!['manualLocation'], 'Philadelphia');
      expect(repo.arguments!['range'], 'walk');
      expect(repo.arguments!['details'], 'Gardens');
      expect(repo.arguments!.containsKey('latitude'), false);
      expect(draft.cards.first.id, isNotEmpty);
      await repo.saveBoard(
        null,
        title: 'My nearby gems',
        description: 'Keep the best',
        image: '',
        visibility: 'private',
        kind: 'nearby-gems',
        cards: draft.cards.take(1).toList(),
        nearbyDraft: draft,
      );
      final stored = (await db.collection('boards').doc(draft.id).get())
          .data()!;
      expect(stored['nearbyGems'], draft.metadata);
      expect(stored['cards'].length, 1);
      expect(stored['cards'][0]['nearby']['durationSeconds'], 600);
      expect(stored['visibility'], 'private');
      expect(stored.containsKey('latitude'), false);
      expect(stored['nearbyGems']['originStored'], false);
      const fixture = String.fromEnvironment('EXPORT_NEARBY_FIXTURE');
      if (fixture.isNotEmpty) {
        File(fixture).writeAsStringSync(
          jsonEncode(
            stored,
            toEncodable: (v) =>
                v is Timestamp ? v.toDate().toIso8601String() : null,
          ),
        );
      }
    },
  );
  test(
    'no matches, quota and service failures give actionable feedback',
    () async {
      for (final item in {
        'not-found': 'wider travel range',
        'resource-exhausted': 'search limit',
        'failed-precondition': 'temporarily unavailable',
        'deadline-exceeded': 'too long',
      }.entries) {
        repo.failure = FirebaseFunctionsException(
          code: item.key,
          message: 'server detail',
        );
        await expectLater(
          repo.discoverNearbyGems(
            range: NearbyRange.walk,
            count: 8,
            manualLocation: 'Philadelphia',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(item.value),
            ),
          ),
        );
      }
    },
  );
  test(
    'coordinates, count bounds, stale responses and account changes are guarded',
    () async {
      await repo.discoverNearbyGems(
        range: NearbyRange.adventure,
        count: 50,
        latitude: 39.95,
        longitude: -75.16,
      );
      expect(repo.arguments!['range'], 'adventure');
      expect(repo.arguments!['count'], 16);
      expect(repo.arguments!['latitude'], 39.95);
      expect(repo.arguments!.containsKey('manualLocation'), false);
      expect(
        () => repo.discoverNearbyGems(
          range: NearbyRange.walk,
          count: 8,
          latitude: double.nan,
          longitude: 0,
        ),
        throwsStateError,
      );
      expect(
        () =>
            NearbyGemsDraft.fromResponse('wrong', 'test-user', response('old')),
        throwsStateError,
      );
      repo.pending = Completer<Json>();
      final work = repo.discoverNearbyGems(
        range: NearbyRange.walk,
        count: 8,
        manualLocation: 'Philadelphia',
      );
      await auth.signOut();
      repo.pending!.complete(response(repo.arguments!['boardId'] as String));
      await expectLater(work, throwsStateError);
    },
  );
  test(
    'specialized board cannot be saved by a different owner or without a grant',
    () async {
      final draft = await repo.discoverNearbyGems(
        range: NearbyRange.walk,
        count: 8,
        manualLocation: 'Philadelphia',
      );
      Future<void> save(NearbyGemsDraft? d) => repo.saveBoard(
        null,
        title: 'Gems',
        description: '',
        image: '',
        visibility: 'private',
        kind: 'nearby-gems',
        cards: draft.cards,
        nearbyDraft: d,
      );
      await expectLater(save(null), throwsStateError);
      await expectLater(
        save(
          NearbyGemsDraft(
            id: draft.id,
            ownerId: 'another-user',
            board: draft.board,
            cards: draft.cards,
          ),
        ),
        throwsStateError,
      );
      expect((await db.collection('boards').get()).docs, isEmpty);
    },
  );
  test('sort, estimated travel labels, pins and directions retain meaning', () {
    final draft = NearbyGemsDraft.fromResponse(
      'id',
      'test-user',
      response('id'),
    );
    expect(
      sortNearbyCards(draft.cards, 'travel-time').first.title,
      'The old bookshop',
    );
    expect(
      sortNearbyCards(draft.cards, 'distance').first.title,
      'A little garden',
    );
    expect(
      nearbyTravelLabel(draft.cards.last, walking: true),
      'Est. · 5 min walk · 0.6 mi',
    );
    expect(
      nearbyPoint(const WikiCard({'locationLat': 100, 'locationLng': 0})),
      isNull,
    );
    expect(
      Uri.parse(
        nearbyDirections(draft.cards.first, true),
      ).queryParameters['travelmode'],
      'walking',
    );
  });

  Future<AppState> pump(
    WidgetTester tester, {
    NearbyLocation? location,
    double scale = 1,
    bool dark = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(repo, await SharedPreferences.getInstance());
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(320, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: livingTheme(dark: dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: NearbyGemsScreen(location: location),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'manual search reviews selections and saves to the specialized board',
    (tester) async {
      await pump(tester);
      await scrollTo(tester, find.text('Enter a place'));
      await tester.tap(find.text('Enter a place'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.widgetWithText(TextField, 'Starting place'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Starting place'),
        'Philadelphia',
      );
      await scrollTo(tester, find.text('Find my gems'));
      await tester.tap(find.text('Find my gems'));
      await tester.pumpAndSettle();
      expect(repo.searches, 1);
      await scrollTo(tester, find.text('A little garden'));
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Keep 1 gem · private board'), findsOneWidget);
      await tester.tap(find.text('Keep 1 gem · private board'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('boards').get()).docs.single
            .data()['cards']
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'permission failure offers manual fallback with no discovery call',
    (tester) async {
      await pump(
        tester,
        location: UnavailableLocation(),
        scale: 1.3,
        dark: true,
      );
      await scrollTo(tester, find.text('Find my gems'));
      await tester.tap(find.text('Find my gems'));
      await tester.pumpAndSettle();
      expect(repo.searches, 0);
      await scrollTo(tester, find.widgetWithText(TextField, 'Starting place'));
      expect(find.widgetWithText(TextField, 'Starting place'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('cancelled discoveries cannot replace the active screen', (
    tester,
  ) async {
    await pump(tester);
    await scrollTo(tester, find.text('Enter a place'));
    await tester.tap(find.text('Enter a place'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.widgetWithText(TextField, 'Starting place'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Starting place'),
      'Philadelphia',
    );
    repo.pending = Completer<Json>();
    await scrollTo(tester, find.text('Find my gems'));
    await tester.tap(find.text('Find my gems'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Cancel search'));
    await tester.pumpAndSettle();
    repo.pending!.complete(response(repo.arguments!['boardId'] as String));
    await tester.pumpAndSettle();
    expect(find.text('Your next\nlittle adventure.'), findsNothing);
    expect((await db.collection('boards').get()).docs, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('guest sign-in preserves the chosen starting place', (
    tester,
  ) async {
    await auth.signOut();
    await pump(tester, location: UnavailableLocation());
    await scrollTo(tester, find.text('Enter a place'));
    await tester.tap(find.text('Enter a place'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.widgetWithText(TextField, 'Starting place'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Starting place'),
      'Philadelphia',
    );
    await scrollTo(tester, find.text('Find my gems'));
    await tester.tap(find.text('Find my gems'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back,\ncurious soul.'), findsOneWidget);
    expect(repo.searches, 0);
    await auth.signInWithEmailAndPassword(
      email: 'test@example.test',
      password: 'test-password',
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repo.arguments!['manualLocation'], 'Philadelphia');
    expect(find.text('Keep 2 gems · private board'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
