import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livingwiki_mobile/core/app_state.dart';
import 'package:livingwiki_mobile/core/theme.dart';
import 'package:livingwiki_mobile/data/city_guide.dart';
import 'package:livingwiki_mobile/data/models.dart';
import 'package:livingwiki_mobile/data/repository.dart';
import 'package:livingwiki_mobile/features/atlas.dart';
import 'package:livingwiki_mobile/features/chat.dart';
import 'package:livingwiki_mobile/features/city_guide.dart';

const philly = Atlas(
  id: 'philly',
  name: 'Philadelphia',
  slug: 'philly',
  kind: 'city',
);
const vegas = Atlas(
  id: 'vegas',
  name: 'Las Vegas',
  slug: 'las-vegas',
  kind: 'city',
);

class CityTestRepository extends LivingRepository {
  CityTestRepository()
    : super(database: FakeFirebaseFirestore(), auth: MockFirebaseAuth());
  final asked = <String>[];
  int shelfLoads = 0;
  @override
  Future<List<Board>> cityBoards(String atlasId) async {
    shelfLoads++;
    return [
      Board(
        id: 'story-$atlasId',
        title: 'A real $atlasId story',
        description: 'A published city collection.',
        count: 4,
      ),
    ];
  }

  @override
  Future<Json> ask(
    Atlas atlas,
    String question, {
    String? threadId,
    String mode = 'wiki',
    required String visitorId,
  }) async {
    asked.add('${atlas.id}:$question');
    return {'answer': 'An answer', 'threadId': 'thread'};
  }
}

void main() {
  test(
    'city guide follows web identity rules, including overrides and legacy cities',
    () {
      expect(usesPicamoCityGuide(philly), isTrue);
      expect(
        usesPicamoCityGuide(
          const Atlas(
            id: 'custom',
            name: 'A city',
            slug: 'custom',
            data: {
              'wiki_type': 'city',
              'chat_guide': {
                'city_persona_override': true,
                'name': 'Local guide',
              },
            },
          ),
        ),
        isFalse,
      );
      expect(
        usesPicamoCityGuide(
          const Atlas(
            id: 'uni',
            name: 'College',
            slug: 'college',
            kind: 'university',
          ),
        ),
        isFalse,
      );
      expect(
        usesPicamoCityGuide(
          const Atlas(
            id: 'legacy',
            name: 'Legacy city',
            slug: 'legacy',
            kind: 'topic',
            data: {
              'wiki_type': 'topic',
              'city_config': {'enabled': true},
            },
          ),
        ),
        isTrue,
      );
      expect(
        usesPicamoCityGuide(
          const Atlas(
            id: 'uni',
            name: 'College',
            slug: 'college',
            data: {
              'wiki_type': 'city',
              'university_config': {'enabled': true},
            },
          ),
        ),
        isFalse,
      );
      expect(
        usesPicamoCityGuide(Atlas.fromJson('topic', {'name': 'An old topic'})),
        isFalse,
      );
    },
  );
  testWidgets('Picamo city hero handles a compact phone and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: livingTheme(dark: true),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: PicamoCityHero(
                  atlas: Atlas(
                    id: 'long',
                    name: 'San Cristóbal de las Casas',
                    slug: 'long',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Picamo Knows'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'city prompts prepare the right question, and changing cities clears it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = CityTestRepository();
      final appState = AppState(repo, await SharedPreferences.getInstance())
        ..atlases = [philly, vegas];
      addTearDown(appState.dispose);
      await tester.pumpWidget(
        AppScope(
          state: appState,
          child: MaterialApp(
            theme: livingTheme(),
            home: const AtlasScreen(atlas: philly),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Picamo Knows'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('A local dinner spot'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('A local dinner spot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A local dinner spot'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      final composer = find.byType(TextField).last;
      expect(
        tester.widget<TextField>(composer).controller!.text,
        contains('Philadelphia'),
      );
      expect(repo.asked, isEmpty);
      await tester.tap(find.text('Philadelphia').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Las Vegas'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      expect(find.text('Beyond the Strip'), findsOneWidget);
      expect(repo.asked, isEmpty);
    },
  );
  testWidgets('Picamo Picks opens only that city’s published board shelf', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = CityTestRepository();
    final state = AppState(repo, await SharedPreferences.getInstance());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: livingTheme(),
          home: const AtlasScreen(atlas: vegas),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Explore Las Vegas with Picamo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('A real vegas story'), findsWidgets);
    expect(find.text('A real philly story'), findsNothing);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(repo.shelfLoads, 1);
    expect(find.text('A real vegas story'), findsWidgets);
  });
}
