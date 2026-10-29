import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'boards.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Together is a good place')),
    body: PageBody(
      children: [
        const Eyebrow('Your teams'),
        const SizedBox(height: 14),
        Text(
          'Shared stories.\nShared purpose.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        AccountStream(
          collection: 'team_memberships',
          emptyTitle: 'Good things happen together',
          emptyMessage:
              'Your teams will appear here when you accept an invitation.',
          builder: (items) => Column(
            children: [
              for (final team in items.where((t) => t['status'] == 'active'))
                MenuRow(
                  icon: Icons.people_outline,
                  title: stringValue(team['name']),
                  subtitle: 'Team workspace',
                  onTap: () => openScreen(
                    context,
                    TeamScreen(
                      teamId: stringValue(
                        team['teamId'],
                        stringValue(team['id']),
                      ),
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

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key, required this.teamId});
  final String teamId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Team workspace')),
    body: AsyncContent<Json>(
      load: () => AppScope.of(context).repository.call('teamCommand', {
        'action': 'dashboard',
        'teamId': teamId,
      }),
      builder: (data) {
        final team = mapValue(data['team']);
        return PageBody(
          children: [
            const Eyebrow('Built together'),
            const SizedBox(height: 14),
            Text(
              stringValue(team['name']),
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 12),
            Text(
              stringValue(team['description']),
              style: const TextStyle(color: Palette.muted),
            ),
            const SectionHeading('The team’s TalkThrus'),
            for (final listing in maps(data['listings']))
              MenuRow(
                icon: Icons.home_work_outlined,
                title: stringValue(listing['title']),
                subtitle: stringValue(listing['status']),
                onTap: () {
                  if (listing['status'] == 'published') {
                    openScreen(
                      context,
                      BoardScreen(boardId: stringValue(listing['id'])),
                    );
                  } else {
                    openUrl(
                      context,
                      'https://livingwiki.com/teams/$teamId?listing=${listing['id']}',
                    );
                  }
                },
              ),
            const SectionHeading('The people behind it'),
            for (final member in maps(data['members']))
              MenuRow(
                icon: Icons.person_outline,
                title: stringValue(member['name']),
                subtitle: stringValue(member['title']),
                trailing: const SizedBox.shrink(),
              ),
          ],
        );
      },
    ),
  );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool busy = false;
  int revision = 0;
  Future<void> respond(Json invitation, bool accept) async {
    setState(() => busy = true);
    try {
      await AppScope.of(context).repository.call('teamCommand', {
        'action': 'respondInvitation',
        'inviteId': invitation['id'],
        'accept': accept,
      });
      if (mounted) {
        setState(() => revision++);
        toast(
          context,
          accept ? 'Welcome to the team.' : 'Invitation declined.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your updates')),
    body: PageBody(
      children: [
        const Eyebrow('A little connection'),
        const SizedBox(height: 14),
        Text(
          'You’re in the loop.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SectionHeading('Invitations'),
        AsyncContent<Json>(
          key: ValueKey(revision),
          load: () => AppScope.of(
            context,
          ).repository.call('teamCommand', {'action': 'inbox'}),
          builder: (d) {
            final items = maps(d['invitations']);
            return items.isEmpty
                ? const Text(
                    'No pending invitations.',
                    style: TextStyle(color: Palette.muted),
                  )
                : Column(
                    children: [
                      for (final i in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Surface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stringValue(i['teamName']),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${stringValue(i['inviterName'], 'A teammate')} invited you to join.',
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    FilledButton(
                                      onPressed: busy
                                          ? null
                                          : () => respond(i, true),
                                      child: const Text('Join team'),
                                    ),
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => respond(i, false),
                                      child: const Text('Decline'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
          },
        ),
        const SectionHeading('What’s new'),
        AccountStream(
          collection: 'team_notifications',
          emptyTitle: 'All quiet for now',
          emptyMessage: 'Updates from your teams will appear here.',
          builder: (items) {
            final updates =
                items.where((i) => i['type'] != 'team_invitation').toList()
                  ..sort(
                    (a, b) => stringValue(
                      b['createdAt'],
                    ).compareTo(stringValue(a['createdAt'])),
                  );
            return Column(
              children: [
                if (updates.any((i) => i['read'] != true))
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              setState(() => busy = true);
                              try {
                                final repo = AppScope.of(context).repository;
                                for (final i in updates.where(
                                  (i) => i['read'] != true,
                                )) {
                                  await repo.markRead(i['id']);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  toast(context, friendlyError(e));
                                }
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child: const Text('Mark all as read'),
                    ),
                  ),
                for (final item in updates)
                  MenuRow(
                    icon: item['read'] == true
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_outlined,
                    title: stringValue(item['message'], 'A team update'),
                    subtitle: stringValue(item['createdAt']).split('T').first,
                    onTap: () async {
                      try {
                        await AppScope.of(
                          context,
                        ).repository.markRead(item['id']);
                        if (context.mounted) {
                          openScreen(
                            context,
                            TeamScreen(teamId: stringValue(item['teamId'])),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) toast(context, friendlyError(e));
                      }
                    },
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class AccountStream extends StatefulWidget {
  const AccountStream({
    super.key,
    required this.collection,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.builder,
  });
  final String collection, emptyTitle, emptyMessage;
  final Widget Function(List<Json>) builder;
  @override
  State<AccountStream> createState() => _AccountStreamState();
}

class _AccountStreamState extends State<AccountStream> {
  Stream<List<Json>>? stream;
  String? uid;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (uid != state.user?.uid || stream == null) {
      uid = state.user?.uid;
      stream = uid == null
          ? const Stream.empty()
          : state.repository.accountCollection(widget.collection);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Json>>(
    stream: stream,
    builder: (_, snapshot) {
      if (snapshot.hasError) {
        return EmptyState(
          title: 'Couldn’t load updates',
          message: friendlyError(snapshot.error!),
          action: 'Try again',
          onAction: () => setState(
            () => stream = AppScope.of(
              context,
            ).repository.accountCollection(widget.collection),
          ),
        );
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final items = snapshot.data ?? [];
      if (items.isEmpty) {
        return EmptyState(
          title: widget.emptyTitle,
          message: widget.emptyMessage,
        );
      }
      return widget.builder(items);
    },
  );
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int revision = 0;
  bool busy = false;
  Future<void> invite() async {
    final email = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Explore with a friend'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Their email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (email.text.contains('@')) {
                Navigator.pop(ctx, email.text.trim());
              }
            },
            child: const Text('Send invitation'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), email.dispose);
    if (value == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AppScope.of(
        context,
      ).repository.call('inviteBoardFriend', {'email': value});
      if (mounted) {
        setState(() => revision++);
        toast(context, 'Friend invitation sent.');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Friends'),
      actions: [
        IconButton(
          tooltip: 'Invite a friend',
          onPressed: busy ? null : invite,
          icon: const Icon(Icons.person_add_alt_outlined),
        ),
      ],
    ),
    body: PageBody(
      children: [
        const Eyebrow('Better with good company'),
        const SizedBox(height: 14),
        Text(
          'Your kind of\ncurious people.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 22),
        AsyncContent<Json>(
          key: ValueKey(revision),
          load: () => AppScope.of(context).repository.call('listBoardFriends'),
          builder: (d) => Column(
            children: [
              if (maps(d['friends']).isEmpty)
                EmptyState(
                  title: 'Make a little connection',
                  message:
                      'Invite friends to share discoveries and contribute to your gems.',
                  action: 'Invite a friend',
                  onAction: busy ? null : invite,
                ),
              for (final f in maps(d['friends']))
                MenuRow(
                  icon: Icons.person_outline,
                  title: stringValue(
                    f['displayName'],
                    stringValue(f['name'], stringValue(f['email'])),
                  ),
                  subtitle: stringValue(f['email']),
                  trailing: const SizedBox.shrink(),
                ),
              for (final r in maps(d['incoming']))
                Surface(
                  child: Column(
                    children: [
                      Text(
                        stringValue(
                          r['senderEmail'],
                          stringValue(r['fromEmail'], 'A friend request'),
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    try {
                                      await AppScope.of(context).repository
                                          .call('respondBoardFriendRequest', {
                                            'requestId': r['id'],
                                            'action': 'accept',
                                          });
                                      if (mounted) setState(() => revision++);
                                    } catch (e) {
                                      if (context.mounted) {
                                        toast(context, friendlyError(e));
                                      }
                                    }
                                  },
                            child: const Text('Accept'),
                          ),
                          TextButton(
                            onPressed: () async {
                              try {
                                await AppScope.of(context).repository.call(
                                  'respondBoardFriendRequest',
                                  {'requestId': r['id'], 'action': 'decline'},
                                );
                                if (mounted) setState(() => revision++);
                              } catch (e) {
                                if (context.mounted) {
                                  toast(context, friendlyError(e));
                                }
                              }
                            },
                            child: const Text('Decline'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
