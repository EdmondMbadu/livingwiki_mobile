import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'auth.dart';
import 'boards.dart';
import 'community.dart';
import 'gems.dart';
import 'library.dart';
import 'chat.dart';
import 'collections.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  Future<void> protected(BuildContext context, Widget screen) async {
    if (await requireSignIn(context) && context.mounted) {
      openScreen(context, screen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageBody(
      children: [
        const Eyebrow('Your corner of the world'),
        const SizedBox(height: 14),
        Text(
          state.user == null
              ? 'Make room\nfor wonder.'
              : 'Hello, ${state.name}.\nStay curious.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        Surface(
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: Palette.moss,
                backgroundImage: state.user?.photoURL == null
                    ? null
                    : NetworkImage(state.user!.photoURL!),
                child: state.user?.photoURL != null
                    ? null
                    : Text(
                        state.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Newsreader',
                          fontSize: 30,
                          color: Palette.forest,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.user?.displayName ?? 'The curious are welcome here',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.user?.email ?? 'A world of stories is waiting.',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: state.user == null ? 'Sign in' : 'Edit profile',
                onPressed: () => state.user == null
                    ? openScreen(context, const AuthScreen())
                    : openScreen(context, const ProfileScreen()),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ],
          ),
        ),
        if (state.user == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FilledButton(
              onPressed: () => openScreen(context, const AuthScreen()),
              child: const Text('Sign in or create an account'),
            ),
          ),
        if (state.user != null && !state.user!.emailVerified)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Surface(
              color: Palette.gold.withValues(alpha: .25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'One last thing: verify your email.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open the link in your inbox to finish setting up your account.',
                    style: TextStyle(fontSize: 12),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () async {
                          try {
                            await state.repository.call(
                              'sendAccountVerificationEmail',
                              {'redirectTo': '/home'},
                            );
                            if (context.mounted) {
                              toast(context, 'Verification email sent.');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, friendlyError(e));
                            }
                          }
                        },
                        child: const Text('Resend email'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await state.user?.reload();
                        },
                        child: const Text('I’ve verified'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SectionHeading('The things you’re collecting'),
        Surface(
          child: Column(
            children: [
              MenuRow(
                icon: Icons.bookmark_border_rounded,
                title: 'Saved discoveries',
                subtitle:
                    '${state.saved.length} boards kept close on this device',
                onTap: () => openScreen(
                  context,
                  const BoardsScreen(initialFilter: 'Saved'),
                ),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.dashboard_outlined,
                title: 'My boards',
                subtitle: 'Stories, ideas, and collections you’ve made',
                onTap: () => protected(
                  context,
                  const BoardsScreen(initialFilter: 'Mine'),
                ),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.auto_stories_outlined,
                title: 'My wikis',
                subtitle: 'Your personal living knowledge',
                onTap: () => protected(context, const MyWikisScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.collections_bookmark_outlined,
                title: 'Collections',
                subtitle: 'Bring your boards together',
                onTap: () => protected(context, const CollectionsScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.travel_explore_rounded,
                title: 'Trips',
                subtitle: 'A story around every corner',
                onTap: () => openScreen(
                  context,
                  const BoardsScreen(initialFilter: 'Trips'),
                ),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.music_note_outlined,
                title: 'Songs',
                subtitle: 'The soundtrack to your discoveries',
                onTap: () => openScreen(
                  context,
                  const BoardsScreen(initialFilter: 'Songs'),
                ),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.movie_outlined,
                title: 'My videos',
                onTap: () => protected(context, const MyVideosScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.location_on_outlined,
                title: 'Off Grids',
                subtitle: 'Little places. Lasting impressions.',
                onTap: () => openScreen(context, const GemsScreen()),
              ),
            ],
          ),
        ),
        const SectionHeading('A little more connected'),
        Surface(
          child: Column(
            children: [
              MenuRow(
                icon: Icons.people_outline,
                title: 'My teams',
                onTap: () => protected(context, const TeamsScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.diversity_1_outlined,
                title: 'Friends',
                onTap: () => protected(context, const FriendsScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.chat_bubble_outline,
                title: 'Conversations',
                onTap: () => protected(context, const ChatHistoryScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.notifications_none_rounded,
                title: 'Updates & invitations',
                onTap: () => protected(context, const NotificationsScreen()),
              ),
            ],
          ),
        ),
        const SectionHeading('Make yourself at home'),
        Surface(
          child: Column(
            children: [
              MenuRow(
                icon: Icons.person_outline_rounded,
                title: 'Profile & account',
                onTap: () => protected(context, const ProfileScreen()),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.dark_mode_outlined,
                title: 'Evening mode',
                trailing: Switch.adaptive(
                  value: state.dark,
                  onChanged: state.setDark,
                ),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.workspace_premium_outlined,
                title: 'Your membership',
                subtitle: stringValue(
                  state.profile['pricingPlan'],
                  'Explore the LivingWiki plans',
                ),
                onTap: () =>
                    openUrl(context, 'https://livingwiki.com/membership'),
              ),
              const Divider(),
              MenuRow(
                icon: Icons.public,
                title: 'Play in the Trove',
                subtitle: 'Open Starfold City on LivingWiki',
                onTap: () => openUrl(context, 'https://livingwiki.com/trove'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          children: [
            TextButton(
              onPressed: () =>
                  openUrl(context, 'https://livingwiki.com/privacy'),
              child: const Text('Privacy', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => openUrl(context, 'https://livingwiki.com/terms'),
              child: const Text('Terms', style: TextStyle(fontSize: 11)),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'LivingWiki',
                applicationVersion: '1.0.0',
                applicationLegalese: 'A world worth knowing.',
              ),
              child: const Text(
                'About & licenses',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        if (state.user != null)
          TextButton(
            onPressed: () async {
              await state.repository.auth.signOut();
            },
            child: const Text('Sign out'),
          ),
        const SizedBox(height: 18),
        const Center(child: Eyebrow('Made for a life of discovery')),
        const SizedBox(height: 30),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController();
  bool busy = false, initialized = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      name.text = AppScope.of(context).user?.displayName ?? '';
    }
  }

  Future<void> run(Future<void> Function() action, String message) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) toast(context, message);
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> avatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null || file.size > 5 * 1024 * 1024) {
      toast(context, 'Choose a photo under 5 MB.');
      return;
    }
    final state = AppScope.of(context);
    await run(() async {
      final ext = file.extension ?? 'jpg';
      final ref = FirebaseStorage.instance.ref(
        'users/${state.user!.uid}/profile/avatar-${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await ref.putData(
        file.bytes!,
        SettableMetadata(
          contentType: ext == 'jpg' || ext == 'jpeg'
              ? 'image/jpeg'
              : 'image/$ext',
        ),
      );
      final url = await ref.getDownloadURL();
      await state.user!.updatePhotoURL(url);
      await state.repository.db.collection('users').doc(state.user!.uid).update(
        {'photoURL': url, 'profilePictureType': 'image'},
      );
    }, 'Your photo is updated.');
  }

  Future<void> delete() async {
    final state = AppScope.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your sign-in account. Your published content may remain under the existing LivingWiki retention policy. You may be asked to sign in again first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await run(() async {
      await state.user!.delete();
      if (mounted) Navigator.pop(context);
    }, 'Your account has been deleted.');
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('A little about you')),
      body: PageBody(
        children: [
          const Eyebrow('Your LivingWiki identity'),
          const SizedBox(height: 16),
          Text(
            'Come as you are.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 45,
              backgroundColor: Palette.moss,
              backgroundImage: state.user?.photoURL == null
                  ? null
                  : NetworkImage(state.user!.photoURL!),
              child: state.user?.photoURL == null
                  ? const Icon(
                      Icons.person_outline,
                      size: 40,
                      color: Palette.forest,
                    )
                  : null,
            ),
          ),
          TextButton(
            onPressed: busy ? null : avatar,
            child: const Text('Choose a profile photo'),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 14),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Email address'),
            child: Text(state.user?.email ?? ''),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 24),
          BusyButton(
            busy: busy,
            label: 'Save profile',
            onPressed: () {
              if (name.text.trim().isEmpty) {
                setState(() => error = 'Enter your name.');
                return;
              }
              run(
                () => state.repository.updateProfile(name.text),
                'Your profile is updated.',
              );
            },
          ),
          const SizedBox(height: 28),
          MenuRow(
            icon: Icons.lock_reset_rounded,
            title: 'Reset your password',
            onTap: busy
                ? null
                : () => run(
                    () => state.repository.call(
                      'sendAccountPasswordResetEmail',
                      {'email': state.user?.email},
                    ),
                    'A password reset link is on its way.',
                  ),
          ),
          MenuRow(
            icon: Icons.manage_accounts_outlined,
            title: 'Manage your membership',
            subtitle: 'Continue securely on LivingWiki',
            onTap: () => openUrl(context, 'https://livingwiki.com/profile'),
          ),
          const SizedBox(height: 36),
          TextButton(
            onPressed: busy ? null : delete,
            child: Text(
              'Delete my account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class MyVideosScreen extends StatelessWidget {
  const MyVideosScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your moving stories')),
    body: PageBody(
      children: [
        const Eyebrow('My videos'),
        const SizedBox(height: 16),
        Text(
          'Some stories\nneed to move.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        AccountStream(
          collection: 'videos',
          emptyTitle: 'Your films will live here',
          emptyMessage:
              'Videos you create on LivingWiki appear in this library.',
          builder: (items) => Column(
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: InkWell(
                    onTap: () => openScreen(
                      context,
                      VideoScreen(
                        url: stringValue(item['video_url']),
                        title: stringValue(item['source_title']),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: 1.6,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Photo(url: stringValue(item['poster_url'])),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_filled,
                                    color: Colors.white,
                                    size: 54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          stringValue(item['source_title']),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${stringValue(item['video_kind'])} · ${intValue(item['duration_seconds'])} seconds',
                          style: const TextStyle(
                            color: Palette.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
