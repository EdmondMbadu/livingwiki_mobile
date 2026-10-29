import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'boards.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});
  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  int revision = 0;
  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).repository;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your collections'),
        actions: [
          IconButton(
            tooltip: 'Create collection',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CollectionEditor(),
                ),
              );
              if (mounted) setState(() => revision++);
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: PageBody(
        children: [
          const Eyebrow('Bring good things together'),
          const SizedBox(height: 16),
          Text(
            'A world within\nyour world.',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 24),
          AsyncContent<List<Json>>(
            key: ValueKey(revision),
            load: () async {
              final result = await repo.db
                  .collection('board_collections')
                  .where('owner_user_id', isEqualTo: repo.requireUser())
                  .where('visibility', isEqualTo: 'public')
                  .limit(100)
                  .get();
              return result.docs.map((d) => {'id': d.id, ...d.data()}).toList();
            },
            builder: (items) => items.isEmpty
                ? const EmptyState(
                    title: 'A collection is a point of view',
                    message:
                        'Use the + button to bring your public boards together into a shareable collection.',
                  )
                : Column(
                    children: [
                      for (final c in items)
                        MenuRow(
                          icon: Icons.collections_bookmark_outlined,
                          title: stringValue(c['title']),
                          subtitle:
                              '${strings(c['board_ids']).length} boards · ${stringValue(c['description'])}',
                          onTap: () => openScreen(
                            context,
                            CollectionScreen(collection: c),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.collection});
  final Json collection;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('A curated little world'),
      actions: [
        IconButton(
          tooltip: 'Share collection',
          onPressed: () => shareLink(
            context,
            stringValue(collection['title']),
            'https://livingwiki.com/boards/u/${Uri.encodeComponent('${collection['owner_public_slug']}~${collection['owner_user_id']}')}/collections/${collection['slug']}',
          ),
          icon: const Icon(Icons.ios_share_outlined),
        ),
      ],
    ),
    body: PageBody(
      children: [
        const Eyebrow('A collection'),
        const SizedBox(height: 16),
        Text(
          stringValue(collection['title']),
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 14),
        Text(
          stringValue(collection['description']),
          style: const TextStyle(color: Palette.muted),
        ),
        const SizedBox(height: 24),
        AsyncContent<List<Board>>(
          load: () => AppScope.of(
            context,
          ).repository.savedBoards(strings(collection['board_ids']).toSet()),
          builder: (items) => BoardGrid(
            boards: items,
            onTap: (b) => openScreen(context, BoardScreen(boardId: b.id)),
          ),
        ),
      ],
    ),
  );
}

class CollectionEditor extends StatefulWidget {
  const CollectionEditor({super.key});
  @override
  State<CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<CollectionEditor> {
  final name = TextEditingController(), description = TextEditingController();
  final selected = <String>{};
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (name.text.trim().isEmpty || selected.isEmpty) {
      setState(
        () => error = 'Add a name and choose at least one public board.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final state = AppScope.of(context),
        now = DateTime.now().toUtc().toIso8601String();
    try {
      final repo = state.repository;
      final uid = repo.requireUser();
      final ref = repo.db.collection('board_collections').doc();
      final base = slugify(name.text.trim());
      final slug =
          '${base.isEmpty ? 'collection' : base.substring(0, base.length.clamp(0, 65))}-${ref.id.substring(0, 6).toLowerCase()}';
      await ref.set({
        'id': ref.id,
        'slug': slug,
        'owner_user_id': uid,
        'owner_public_slug':
            '${slugify(state.user?.displayName ?? 'explorer')}-${uid.substring(0, 6).toLowerCase()}',
        'owner_display_name': state.user?.displayName ?? 'LivingWiki curator',
        'owner_photo_url': state.user?.photoURL ?? '',
        'owner_profile_icon': '',
        'owner_profile_picture_type': state.user?.photoURL == null
            ? null
            : 'image',
        'visibility': 'public',
        'title': name.text.trim(),
        'description': description.text.trim(),
        'board_ids': selected.toList(),
        'created_at_iso': now,
        'updated_at_iso': now,
        'server_updated_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        toast(context, 'Your collection is ready to share.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create a collection')),
    body: PageBody(
      children: [
        TextField(
          controller: name,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'A name for this little world',
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: description,
          maxLength: 280,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'What brings it together?',
          ),
        ),
        const SectionHeading('Choose your public boards'),
        const Text(
          'Collections are public and can contain up to 50 of your public boards.',
          style: TextStyle(color: Palette.muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        AsyncContent<List<Board>>(
          load: () => AppScope.of(context).repository.myBoards(),
          builder: (items) {
            final boards = items
                .where((b) => b.visibility == 'public')
                .toList();
            return boards.isEmpty
                ? const EmptyState(
                    title: 'Publish your first board',
                    message:
                        'Public boards you own will appear here to add to a collection.',
                  )
                : Column(
                    children: [
                      for (final b in boards)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected.contains(b.id),
                          title: Text(b.title),
                          subtitle: Text('${b.count} cards'),
                          onChanged: busy
                              ? null
                              : (v) => setState(() {
                                  if (v == true && selected.length < 50) {
                                    selected.add(b.id);
                                  } else {
                                    selected.remove(b.id);
                                  }
                                }),
                        ),
                    ],
                  );
          },
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 24),
        BusyButton(busy: busy, label: 'Create collection', onPressed: save),
      ],
    ),
  );
}
