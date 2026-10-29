import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/repository.dart';
import 'features/account.dart';
import 'features/atlas.dart';
import 'features/auth.dart';
import 'features/boards.dart';
import 'features/chat.dart';
import 'features/community.dart';
import 'features/explore.dart';
import 'features/gems.dart';
import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Palette.paper,
    ),
  );
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppState> startup;
  Future<AppState> initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 25));
    }
    final preferences = await SharedPreferences.getInstance();
    return AppState(LivingRepository(), preferences);
  }

  @override
  void initState() {
    super.initState();
    startup = initialize();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppState>(
    future: startup,
    builder: (_, snapshot) {
      if (snapshot.hasData) return LivingWikiApp(state: snapshot.data!);
      if (snapshot.hasError) {
        debugPrint('LivingWiki startup: ${snapshot.error}');
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: livingTheme(),
        home: Scaffold(
          body: snapshot.hasError
              ? EmptyState(
                  title: 'Let’s reconnect.',
                  message:
                      'LivingWiki couldn’t connect. Check your connection and try again.',
                  action: 'Try again',
                  onAction: () => setState(() => startup = initialize()),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/brand.png',
                        width: 64,
                        height: 64,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'LivingWiki',
                        style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 36,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'A world worth knowing.',
                        style: TextStyle(color: Palette.muted),
                      ),
                      const SizedBox(height: 36),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}

class LivingWikiApp extends StatefulWidget {
  const LivingWikiApp({super.key, required this.state});
  final AppState state;
  @override
  State<LivingWikiApp> createState() => _LivingWikiAppState();
}

class _LivingWikiAppState extends State<LivingWikiApp> {
  final navigator = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? links;
  String? previousUid;
  void sessionChanged() {
    final next = widget.state.user?.uid;
    if (previousUid != null && previousUid != next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          navigator.currentState?.pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const AppShell()),
            (_) => false,
          );
        }
      });
    }
    previousUid = next;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.loadAtlases();
    });
    previousUid = widget.state.user?.uid;
    widget.state.addListener(sessionChanged);
    links = AppLinks().uriLinkStream.listen((uri) {
      unawaited(handleLink(uri));
    }, onError: (_) {});
  }

  Future<void> handleLink(Uri uri) async {
    if (!['livingwiki.com', 'www.livingwiki.com'].contains(uri.host) &&
        uri.scheme != 'livingwiki') {
      return;
    }
    final parts = uri.scheme == 'livingwiki' && uri.host.isNotEmpty
        ? [uri.host, ...uri.pathSegments]
        : uri.pathSegments;
    if (parts.length < 2) return;
    final nav = navigator.currentState;
    if (nav == null) return;
    Widget? screen;
    if (parts[0] == 'boards') screen = BoardScreen(boardId: parts[1]);
    if (parts[0] == 'off-grids') screen = GemScreen(gemId: parts[1]);
    if (['atlas', 'wiki', 'chat'].contains(parts[0])) {
      try {
        final atlas = await widget.state.repository.atlasBySlug(parts[1]);
        if (atlas != null) {
          screen = parts[0] == 'chat'
              ? ChatScreen(atlas: atlas)
              : AtlasScreen(atlas: atlas);
        }
      } catch (_) {
        return;
      }
    }
    if (screen != null && mounted) {
      nav.push(MaterialPageRoute<void>(builder: (_) => screen!));
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(sessionChanged);
    links?.cancel();
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: widget.state,
    child: ListenableBuilder(
      listenable: widget.state,
      builder: (_, _) => MaterialApp(
        navigatorKey: navigator,
        title: 'LivingWiki',
        debugShowCheckedModeBanner: false,
        theme: livingTheme(),
        darkTheme: livingTheme(dark: true),
        themeMode: widget.state.dark ? ThemeMode.dark : ThemeMode.light,
        home: const AppShell(),
      ),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  final visited = <int>{0};
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final destinations = [
      const ExploreScreen(),
      const BoardsScreen(),
      ChatScreen(key: ValueKey('chat:${state.user?.uid}')),
      const AccountScreen(),
    ];
    return Scaffold(
      appBar: index == 0 || index == 3
          ? AppBar(
              titleSpacing: 24,
              toolbarHeight: 70,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/brand.png', width: 30, height: 30),
                  const SizedBox(width: 9),
                  const Flexible(
                    child: Text(
                      'LivingWiki',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Newsreader',
                        fontSize: 28,
                        letterSpacing: -.8,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Your updates',
                  onPressed: () async {
                    if (await requireSignIn(context) && context.mounted) {
                      openScreen(context, const NotificationsScreen());
                    }
                  },
                  icon: const Icon(Icons.notifications_none_rounded, size: 22),
                ),
                const SizedBox(width: 10),
              ],
            )
          : null,
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < destinations.length; i++)
            visited.contains(i) ? destinations[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
        ),
        child: NavigationBar(
          height: 72,
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: .65),
          selectedIndex: index,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            setState(() {
              index = i;
              visited.add(i);
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Boards',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Ask',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'You',
            ),
          ],
        ),
      ),
    );
  }
}
