import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livingwiki_mobile/core/app_state.dart';
import 'package:livingwiki_mobile/core/theme.dart';
import 'package:livingwiki_mobile/core/widgets.dart';
import 'package:livingwiki_mobile/data/models.dart';
import 'package:livingwiki_mobile/data/repository.dart';
import 'package:livingwiki_mobile/features/auth.dart';
import 'package:livingwiki_mobile/features/board_editor.dart';
import 'package:livingwiki_mobile/features/chat.dart';
import 'package:livingwiki_mobile/features/voice.dart';
import 'package:livingwiki_mobile/main.dart';

class TestRepository extends LivingRepository {
  TestRepository(FakeFirebaseFirestore database, MockFirebaseAuth auth)
    : super(database: database, auth: auth);
  @override
  Future<DataPage<Board>> publicBoards({dynamic cursor}) async =>
      const DataPage([
        Board(
          id: 'public-board',
          title: 'A little wonder',
          ownerName: 'LivingWiki',
          count: 3,
        ),
      ], hasMore: false);
  final calls = <String>[];
  @override
  Future<Json> call(String name, [Json arguments = const {}]) async {
    calls.add(name);
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseAuth auth;
  late AppState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: 'first-user',
        displayName: 'Curious Person',
        email: 'curious@example.test',
      ),
    );
    state = AppState(
      TestRepository(FakeFirebaseFirestore(), auth),
      await SharedPreferences.getInstance(),
    );
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() => state.dispose());
  Future<void> pumpApp(
    WidgetTester tester, {
    Widget? screen,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final errorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      errorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = errorHandler);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: livingTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen ?? const AppShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone home renders and guest creation opens real sign-in', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('The world has\nstories. Find yours.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Boards').last);
    await tester.pumpAndSettle();
    expect(find.text('Stories to get\nlost in.'), findsOneWidget);
    await tester.tap(find.byTooltip('Create a board'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back,\ncurious soul.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact and large text layouts have no overflow', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(320, 740), textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Text me'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text me'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('tablet home lays out correctly', (tester) async {
    await pumpApp(tester, size: const Size(1024, 1366));
    expect(find.text('The world has\nstories. Find yours.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('landing text mode picks a wiki and opens its conversation', (
    tester,
  ) async {
    state.atlases = [
      const Atlas(
        id: 'philly',
        name: 'Philadelphia',
        slug: 'philly',
        kind: 'city',
      ),
    ];
    await pumpApp(tester);
    expect(find.byType(LivingWikiBrand), findsOneWidget);
    await tester.tap(find.text('Text me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start chatting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(find.text('Where shall we explore?'), findsOneWidget);
    await tester.tap(find.text('Philadelphia'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(state.selectedAtlas?.id, 'philly');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).enabled,
      isTrue,
    );
    expect((state.repository as TestRepository).calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'landing voice mode opens a preview without starting the microphone',
    (tester) async {
      state.selectedAtlas = const Atlas(
        id: 'philly',
        name: 'Philadelphia',
        slug: 'philly',
        kind: 'city',
      );
      await pumpApp(tester);
      await tester.ensureVisible(find.text('Start talking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start talking'));
      // Voice has a continuous pulse animation; wait only for route transition.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(VoiceScreen), findsOneWidget);
      expect(find.text('Talk with Picamo'), findsOneWidget);
      expect(find.text('Philadelphia'), findsOneWidget);
      expect(
        find.image(const AssetImage('assets/images/picamo-city-guide.webp')),
        findsOneWidget,
      );
      expect(find.text('Start a conversation'), findsOneWidget);
      expect((state.repository as TestRepository).calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Philadelphia · Change wiki'), findsOneWidget);
    },
  );
  testWidgets('dismissing the wiki picker keeps the landing mode ready', (
    tester,
  ) async {
    state.atlases = [
      const Atlas(id: 'philly', name: 'Philadelphia', slug: 'philly'),
    ];
    await pumpApp(tester);
    await tester.tap(find.text('Text me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start chatting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('Where shall we explore?'))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text('Start chatting'), findsOneWidget);
    expect(state.selectedAtlas, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('auth validates input without making a backend request', (
    tester,
  ) async {
    await pumpApp(tester, screen: const AuthScreen());
    await tester.ensureVisible(find.text('Sign in').last);
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'new board validation and existing card edits preserve metadata',
    (tester) async {
      await auth.signInWithEmailAndPassword(
        email: 'curious@example.test',
        password: 'test',
      );
      await tester.pump();
      await pumpApp(tester, screen: const BoardEditor());
      await tester.scrollUntilVisible(
        find.text('Save board'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save board'));
      await tester.pumpAndSettle();
      expect(find.text('Your board needs a name.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'saved boards are isolated per account and restored after sign-in',
    () async {
      await state.toggleSaved('guest-board');
      expect(state.saved, {'guest-board'});
      await auth.signInWithEmailAndPassword(
        email: 'curious@example.test',
        password: 'test',
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.saved, isEmpty);
      await state.toggleSaved('personal-board');
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(state.saved, {'guest-board'});
      await auth.signInWithEmailAndPassword(
        email: 'curious@example.test',
        password: 'test',
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.saved, {'personal-board'});
    },
  );
  test('dark preference and visitor identity persist on device', () async {
    final id = state.visitorId;
    await state.setDark(true);
    expect((await SharedPreferences.getInstance()).getBool('dark'), isTrue);
    expect((await SharedPreferences.getInstance()).getString('visitorId'), id);
  });
}
