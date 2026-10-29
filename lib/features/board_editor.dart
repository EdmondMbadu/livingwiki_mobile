import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';

class BoardEditor extends StatefulWidget {
  const BoardEditor({super.key, this.board, this.seed});
  final Board? board;
  final Json? seed;
  @override
  State<BoardEditor> createState() => _BoardEditorState();
}

class _BoardEditorState extends State<BoardEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      image = TextEditingController();
  List<WikiCard> cards = [];
  String visibility = 'unlisted', kind = 'standard';
  String? error;
  bool busy = false, dirty = false, saved = false, uploading = false;
  String get draftKey =>
      'board-draft:${AppScope.of(context).user?.uid}:${widget.board?.id ?? 'new'}';
  @override
  void initState() {
    super.initState();
    final b = widget.board;
    if (b != null) {
      title.text = b.title;
      description.text = b.description;
      image.text = b.image;
      cards = [...b.cards];
      visibility = b.visibility;
      kind = b.kind;
    }
    if (widget.seed != null) {
      final generated = mapValue(widget.seed!['board']);
      title.text = stringValue(generated['title']);
      description.text = stringValue(generated['description']);
      kind = stringValue(generated['kind'], 'standard');
      final now = DateTime.now().toUtc().toIso8601String();
      cards = maps(widget.seed!['cards']).indexed
          .map(
            (entry) => WikiCard({
              ...entry.$2,
              'id': 'card-${DateTime.now().microsecondsSinceEpoch}-${entry.$1}',
              'type': stringValue(entry.$2['type'], 'note'),
              'scope': stringValue(entry.$2['scope'], 'place'),
              'status': stringValue(entry.$2['status'], 'saved'),
              'rating': intValue(entry.$2['rating']),
              'imageUrl': stringValue(entry.$2['imageUrl']),
              'imageUrls': strings(entry.$2['imageUrls']),
              'mediaKind': stringValue(entry.$2['media_kind']),
              'entityName': stringValue(entry.$2['entity_name']),
              'entityType': stringValue(entry.$2['entity_type']),
              'shortSummary': stringValue(entry.$2['short_summary']),
              'createdAt': now,
              'updatedAt': now,
            }),
          )
          .toList();
      image.text =
          cards.where((c) => c.image.isNotEmpty).firstOrNull?.image ?? '';
      dirty = true;
    }
    for (final c in [title, description, image]) {
      c.addListener(() {
        if (!dirty && mounted) setState(() => dirty = true);
      });
    }
  }

  Future<void> saveDraft() async {
    final state = AppScope.of(context);
    await state.preferences.setString(
      draftKey,
      jsonEncode({
        'title': title.text,
        'description': description.text,
        'image': image.text,
        'visibility': visibility,
        'kind': kind,
        'cards': cards.map((c) => c.data).toList(),
      }),
    );
    if (mounted) toast(context, 'Draft saved on this device.');
  }

  Future<void> restoreDraft() async {
    final raw = AppScope.of(context).preferences.getString(draftKey);
    if (raw == null) {
      toast(context, 'No draft saved on this device yet.');
      return;
    }
    try {
      final d = mapValue(jsonDecode(raw));
      setState(() {
        title.text = stringValue(d['title']);
        description.text = stringValue(d['description']);
        image.text = stringValue(d['image']);
        visibility = stringValue(d['visibility'], 'unlisted');
        kind = stringValue(d['kind'], 'standard');
        cards = maps(d['cards']).map(WikiCard.new).toList();
        dirty = true;
      });
    } catch (_) {
      toast(context, 'This draft could not be restored.');
    }
  }

  Future<void> uploadImage() async {
    final state = AppScope.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.size >= 10 * 1024 * 1024 || file.bytes == null) {
      toast(context, 'Choose an image smaller than 10 MB.');
      return;
    }
    setState(() => uploading = true);
    try {
      final ext = file.extension?.toLowerCase() ?? 'jpg';
      final ref = FirebaseStorage.instance.ref(
        'users/${state.repository.requireUser()}/boards/mobile/${DateTime.now().microsecondsSinceEpoch}.$ext',
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
      if (mounted) setState(() => image.text = url);
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await state.repository.saveBoard(
        widget.board,
        title: title.text.trim(),
        description: description.text.trim(),
        image: image.text.trim(),
        visibility: visibility,
        kind: kind,
        cards: cards,
        tourMeta: mapValue(widget.seed?['board'])['tourMeta'],
      );
      await state.preferences.remove(draftKey);
      if (mounted) {
        setState(() {
          saved = true;
          dirty = false;
        });
        Navigator.pop(context);
        toast(context, 'Your board is saved.');
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep this story?'),
        content: const Text(
          'Save a draft on this device so you can come back to it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard changes'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save draft'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel' || !mounted) return;
    if (choice == 'save') await saveDraft();
    if (mounted) {
      setState(() {
        saved = true;
        dirty = false;
      });
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppScope.of(context).profile;
    final canPrivate =
        [
              'personal_plus',
              'creator',
              'explorer',
              'lifetime',
            ].contains(stringValue(profile['pricingPlan']).toLowerCase()) &&
            ['active', 'trialing', 'paid'].contains(
              stringValue(profile['subscriptionStatus']).toLowerCase(),
            ) ||
        widget.board?.visibility == 'private';
    return PopScope(
      canPop: saved || !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: busy ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            widget.board == null ? 'Make something yours' : 'Shape your story',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Draft options',
              onSelected: (v) => v == 'save' ? saveDraft() : restoreDraft(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'save',
                  child: Text('Save draft on device'),
                ),
                PopupMenuItem(
                  value: 'restore',
                  child: Text('Restore device draft'),
                ),
              ],
            ),
          ],
        ),
        body: PageBody(
          children: [
            const Eyebrow('A collection with a point of view'),
            const SizedBox(height: 14),
            Text(
              'What’s your story?',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'A favorite neighborhood. A trip to remember.\nSomething you can’t stop thinking about.',
              style: TextStyle(color: Palette.muted),
            ),
            const SizedBox(height: 28),
            Form(
              key: form,
              child: Column(
                children: [
                  TextFormField(
                    controller: title,
                    maxLength: 240,
                    decoration: const InputDecoration(
                      labelText: 'Give it a name',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Your board needs a name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 5000,
                    decoration: const InputDecoration(
                      labelText: 'Set the scene',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: image,
                    decoration: const InputDecoration(
                      labelText: 'Cover image URL',
                      hintText: 'https://…',
                    ),
                    validator: (v) =>
                        v == null ||
                            v.isEmpty ||
                            Uri.tryParse(v)?.scheme == 'https'
                        ? null
                        : 'Use an HTTPS image link.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: uploading ? null : uploadImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        uploading ? 'Uploading photo…' : 'Choose a cover photo',
                      ),
                    ),
                  ),
                  if (image.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: AspectRatio(
                          aspectRatio: 1.8,
                          child: Photo(url: image.text),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: visibility,
                    decoration: const InputDecoration(
                      labelText: 'Who can see it?',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'unlisted',
                        child: Text('Anyone with the link'),
                      ),
                      const DropdownMenuItem(
                        value: 'public',
                        child: Text('Everyone · public discovery'),
                      ),
                      if (canPrivate)
                        const DropdownMenuItem(
                          value: 'private',
                          child: Text('Only me'),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      visibility = v!;
                      dirty = true;
                    }),
                  ),
                  if (!canPrivate)
                    const Padding(
                      padding: EdgeInsets.only(top: 9),
                      child: Text(
                        'Private boards are included with a personal wiki membership.',
                        style: TextStyle(fontSize: 11, color: Palette.muted),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (widget.board == null)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: kind,
                      decoration: const InputDecoration(
                        labelText: 'Kind of collection',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'standard',
                          child: Text('Stories & ideas'),
                        ),
                        DropdownMenuItem(
                          value: 'walking-tour',
                          child: Text('A trip or walking tour'),
                        ),
                        DropdownMenuItem(
                          value: 'driving-tour',
                          child: Text('A driving tour'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        kind = v!;
                        dirty = true;
                      }),
                    ),
                ],
              ),
            ),
            SectionHeading(
              'The story, card by card',
              action: 'Add card',
              onAction: busy || cards.length >= 200
                  ? null
                  : () async {
                      final c = await Navigator.push<WikiCard>(
                        context,
                        MaterialPageRoute(builder: (_) => const CardEditor()),
                      );
                      if (c != null && mounted) {
                        setState(() {
                          cards.add(c);
                          dirty = true;
                        });
                      }
                    },
            ),
            if (cards.isEmpty)
              const EmptyState(
                title: 'Start with one good thing',
                message:
                    'Add a card for a place, an idea, a song, or a memory.',
              ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              onReorder: (old, next) {
                if (busy) return;
                setState(() {
                  if (next > old) next--;
                  final card = cards.removeAt(old);
                  cards.insert(next, card);
                  dirty = true;
                });
              },
              itemBuilder: (_, i) => ListTile(
                key: ValueKey(cards[i].id),
                contentPadding: EdgeInsets.zero,
                leading: SizedBox(
                  width: 50,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Photo(url: cards[i].image),
                  ),
                ),
                title: Text(
                  cards[i].title,
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  cards[i].status,
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () async {
                  final c = await Navigator.push<WikiCard>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CardEditor(card: cards[i]),
                    ),
                  );
                  if (c != null && mounted) {
                    setState(() {
                      cards[i] = c;
                      dirty = true;
                    });
                  }
                },
                trailing: Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: IconButton(
                    tooltip: 'Remove card',
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            cards.removeAt(i);
                            dirty = true;
                          }),
                    icon: const Icon(Icons.remove_circle_outline, size: 19),
                  ),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            BusyButton(
              busy: busy || uploading,
              label: 'Save board',
              onPressed: save,
              icon: Icons.check_rounded,
            ),
            const SizedBox(height: 18),
            if (widget.board != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this board?'),
                            content: const Text(
                              'This removes the board and its cards permanently.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep board'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete board'),
                              ),
                            ],
                          ),
                        );
                        if (confirm != true || !context.mounted) return;
                        try {
                          await AppScope.of(
                            context,
                          ).repository.deleteBoard(widget.board!);
                          if (context.mounted) {
                            setState(() {
                              dirty = false;
                              saved = true;
                            });
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          if (context.mounted) toast(context, friendlyError(e));
                        }
                      },
                child: Text(
                  'Delete board',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CardEditor extends StatefulWidget {
  const CardEditor({super.key, this.card});
  final WikiCard? card;
  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title,
      subtitle,
      notes,
      image,
      source,
      map,
      tags,
      spotify;
  String status = 'saved', type = 'note';
  @override
  void initState() {
    super.initState();
    final c = widget.card;
    title = TextEditingController(text: c?.title);
    subtitle = TextEditingController(text: c?.subtitle);
    notes = TextEditingController(text: c?.notes);
    image = TextEditingController(text: c?.image);
    source = TextEditingController(text: c?.source);
    map = TextEditingController(text: c?.mapUrl);
    tags = TextEditingController(text: c?.tags.join(', '));
    spotify = TextEditingController(
      text: stringValue(c?.data['spotifyTrackUrl']),
    );
    status = c?.status ?? 'saved';
    type = c?.type ?? 'note';
  }

  @override
  void dispose() {
    for (final c in [
      title,
      subtitle,
      notes,
      image,
      source,
      map,
      tags,
      spotify,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    final now = DateTime.now().toUtc().toIso8601String();
    Navigator.pop(
      context,
      WikiCard({
        ...?widget.card?.data,
        'id':
            widget.card?.id ?? 'card-${DateTime.now().microsecondsSinceEpoch}',
        'title': title.text.trim(),
        'subtitle': subtitle.text.trim(),
        'notes': notes.text.trim(),
        'type': type,
        'scope': widget.card?.data['scope'] ?? 'place',
        'status': status,
        'rating': widget.card?.data['rating'] ?? 0,
        'imageUrl': image.text.trim(),
        'imageUrls': image.text.trim().isEmpty ? [] : [image.text.trim()],
        'audioPreviewUrl': widget.card?.audio ?? '',
        'spotifyTrackId': widget.card?.data['spotifyTrackId'] ?? '',
        'spotifyTrackUrl': spotify.text.trim(),
        'spotifyUri': widget.card?.data['spotifyUri'] ?? '',
        'spotifyArtistName': widget.card?.data['spotifyArtistName'] ?? '',
        'spotifyAlbumName': widget.card?.data['spotifyAlbumName'] ?? '',
        'spotifyArtworkUrl': widget.card?.data['spotifyArtworkUrl'] ?? '',
        'placeId': widget.card?.data['placeId'] ?? '',
        'googleMapsUrl': map.text.trim(),
        'sourceUrl': source.text.trim(),
        'tags': tags.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .take(12)
            .toList(),
        'stickers': widget.card?.data['stickers'] ?? [],
        'tour': widget.card?.data['tour'],
        'createdAt': widget.card?.data['createdAt'] ?? now,
        'updatedAt': now,
      }),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.card == null ? 'One good discovery' : 'Edit card'),
    ),
    body: PageBody(
      children: [
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: title,
                maxLength: 240,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Give this card a title.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: subtitle,
                decoration: const InputDecoration(
                  labelText: 'A little context',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notes,
                minLines: 5,
                maxLines: 15,
                decoration: const InputDecoration(
                  labelText: 'Tell the story',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: image,
                decoration: const InputDecoration(labelText: 'Image URL'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: source,
                decoration: const InputDecoration(
                  labelText: 'Source or website URL',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: map,
                decoration: const InputDecoration(
                  labelText: 'Google Maps link',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: spotify,
                decoration: const InputDecoration(
                  labelText: 'Spotify track link',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Architecture, history, coffee',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Your relationship with this discovery',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'planned',
                    child: Text('Planning to explore'),
                  ),
                  DropdownMenuItem(value: 'saved', child: Text('Saved')),
                  DropdownMenuItem(value: 'visited', child: Text('Been there')),
                  DropdownMenuItem(
                    value: 'favorite',
                    child: Text('An all-time favorite'),
                  ),
                ],
                onChanged: (v) => setState(() => status = v!),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: save,
                  child: const Text('Keep this card'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
