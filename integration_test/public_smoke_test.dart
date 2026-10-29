import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livingwiki_mobile/main.dart' as app;
import 'package:livingwiki_mobile/core/app_state.dart';
import 'package:livingwiki_mobile/main.dart';
import 'package:livingwiki_mobile/features/explore.dart';
import 'package:livingwiki_mobile/features/nearby_gems.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native public discovery, directory, boards and account', (
    tester,
  ) async {
    app.main();
    for (var i = 0; i < 80 && find.byType(AppShell).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('The world has\nstories. Find yours.'), findsOneWidget);
    final state = AppScope.of(tester.element(find.byType(AppShell)));
    await tester.runAsync(() async {
      if (state.atlases.isEmpty) await state.loadAtlases();
    });
    await tester.pump(const Duration(seconds: 1));
    expect(state.catalogError, isNull);
    expect(state.atlases, isNotEmpty);
    await tester.ensureVisible(find.text('Find gems near me'));
    await tester.tap(find.text('Find gems near me'));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyGemsScreen), findsOneWidget);
    expect(find.text('There’s wonder\nright around you.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cities').first);
    await tester.tap(find.text('Cities').first);
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryScreen), findsOneWidget);
    expect(find.text('Find your next chapter'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boards').last);
    await tester.pumpAndSettle();
    expect(find.text('Stories to get\nlost in.'), findsOneWidget);
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    expect(find.text('Your corner of the world'.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
