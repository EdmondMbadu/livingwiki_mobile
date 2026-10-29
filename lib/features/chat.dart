import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import '../data/city_guide.dart';
import 'city_guide.dart';
import 'auth.dart';
import 'explore.dart';
import 'voice.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.atlas,
    this.initialQuestion,
    this.draftQuestion,
    this.threadId,
    this.initialMessages = const [],
  });
  final Atlas? atlas;
  final String? initialQuestion, draftQuestion, threadId;
  final List<Json> initialMessages;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController(), scroll = ScrollController();
  final List<Json> messages = [];
  Atlas? atlas;
  String? threadId, error, failedQuestion;
  String mode = 'wiki';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    atlas = widget.atlas;
    input.text = widget.draftQuestion ?? '';
    threadId = widget.threadId;
    messages.addAll(widget.initialMessages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      atlas ??= AppScope.of(context).selectedAtlas;
      if (widget.initialQuestion != null) send(widget.initialQuestion!);
    });
  }

  void scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  Future<void> send([String? question]) async {
    final text = (question ?? input.text).trim();
    if (text.isEmpty || busy || atlas == null) return;
    final state = AppScope.of(context);
    input.clear();
    setState(() {
      messages.add({'role': 'user', 'text': text});
      busy = true;
      error = null;
      failedQuestion = null;
    });
    scrollDown();
    try {
      final result = await state.repository.ask(
        atlas!,
        text,
        threadId: threadId,
        mode: mode,
        visitorId: state.visitorId,
      );
      if (!mounted) return;
      if (result['blocked'] == true ||
          result['requiresSignIn'] == true &&
              stringValue(result['answer']).isEmpty) {
        throw StateError('Sign in to keep this conversation going.');
      }
      final answer = stringValue(result['answer']);
      if (answer.isEmpty) {
        throw StateError('No answer came back. Please try again.');
      }
      setState(() {
        threadId = result['threadId'] as String?;
        messages.add({
          'role': 'assistant',
          'text': answer,
          'citations': result['citedPassages'],
          'locations': result['mappableLocations'],
          'travelGuide': result['travelGuide'],
          'knowledgeGap': result['knowledgeGap'],
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          failedQuestion = text;
          messages.removeLast();
          input.text = text;
        });
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        scrollDown();
      }
    }
  }

  Future<void> chooseAtlas() async {
    final state = AppScope.of(context);
    final chosen = await showModalBottomSheet<Atlas>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .75,
        child: _WikiPicker(atlases: state.atlases),
      ),
    );
    if (chosen == null || !mounted) return;
    state.selectAtlas(chosen);
    setState(() {
      atlas = chosen;
      input.clear();
      threadId = null;
      messages.clear();
      error = null;
    });
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    atlas ??= widget.atlas ?? state.selectedAtlas;
    final picamoCity = atlas != null && usesPicamoCityGuide(atlas!);
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: busy ? null : chooseAtlas,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  atlas?.name ?? 'Ask Picamo',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
        actions: [
          if (atlas != null)
            IconButton(
              tooltip: 'Talk to this wiki',
              onPressed: busy
                  ? null
                  : () => openScreen(
                      context,
                      VoiceScreen(
                        title: atlas!.name,
                        image: atlas!.image,
                        atlasId: atlas!.id,
                      ),
                    ),
              icon: const Icon(Icons.mic_none_rounded),
            ),
          IconButton(
            tooltip: 'Chat history',
            onPressed: () async {
              if (await requireSignIn(context) && context.mounted) {
                openScreen(context, const ChatHistoryScreen());
              }
            },
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'New conversation',
            onPressed: busy
                ? null
                : () => setState(() {
                    threadId = null;
                    messages.clear();
                    error = null;
                    input.clear();
                  }),
            icon: const Icon(Icons.edit_square, size: 21),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text(
                        'Wiki knowledge',
                        style: TextStyle(fontSize: 11),
                      ),
                      selected: mode == 'wiki',
                      onSelected: busy
                          ? null
                          : (_) => setState(() => mode = 'wiki'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text(
                        'Internet',
                        style: TextStyle(fontSize: 11),
                      ),
                      selected: mode == 'internet',
                      onSelected: busy
                          ? null
                          : (_) => setState(() => mode = 'internet'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: messages.isEmpty && !busy
                    ? ListView(
                        padding: const EdgeInsets.all(28),
                        children: [
                          if (picamoCity) ...[
                            PicamoCityHero(atlas: atlas!),
                            const SizedBox(height: 20),
                            PicamoCityStarters(
                              atlas: atlas!,
                              onSelected: (starter) {
                                setState(() => input.text = starter.question);
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 30),
                            Center(
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/picamo.webp',
                                  semanticLabel:
                                      'Picamo, your curiosity companion',
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Center(child: Eyebrow('Explore with Picamo')),
                            const SizedBox(height: 16),
                            Text(
                              'Good questions.\nUnexpected places.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              atlas == null
                                  ? 'Meet Picamo, your curiosity companion.\nChoose a wiki, then follow your curiosity.'
                                  : 'Explore ${atlas!.name} with Picamo.\nAsk about the people, places, and stories within.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Palette.muted),
                            ),
                            const SizedBox(height: 26),
                            if (atlas == null)
                              FilledButton.icon(
                                onPressed: chooseAtlas,
                                icon: const Icon(Icons.public),
                                label: const Text('Choose a wiki'),
                              )
                            else ...[
                              for (final q in [
                                'What should I discover first?',
                                'Tell me a story most people don’t know.',
                                'Help me plan an afternoon.',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: OutlinedButton(
                                    onPressed: () => send(q),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            q,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.north_east, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ],
                          if (state.atlases.isEmpty)
                            TextButton(
                              onPressed: () =>
                                  openScreen(context, const DirectoryScreen()),
                              child: const Text('Explore the wiki directory'),
                            ),
                        ],
                      )
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.all(24),
                        itemCount: messages.length + (busy ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Text(
                                    'Following the story…',
                                    style: TextStyle(color: Palette.muted),
                                  ),
                                ],
                              ),
                            );
                          }
                          final m = messages[i], own = m['role'] == 'user';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: Column(
                              crossAxisAlignment: own
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!own) ...[
                                  Eyebrow(atlas?.name ?? 'LivingWiki'),
                                  const SizedBox(height: 10),
                                ],
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: own
                                        ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: .6)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: MarkdownBody(
                                    data: stringValue(m['text']),
                                    selectable: true,
                                    onTapLink: (_, href, _) {
                                      if (href != null) openUrl(context, href);
                                    },
                                  ),
                                ),
                                if (!own && m['knowledgeGap'] == true)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'The wiki has limited sources for this answer.',
                                      style: TextStyle(
                                        color: Palette.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                if (!own &&
                                    maps(
                                      m['citations'] ?? m['cited_passages'],
                                    ).isNotEmpty)
                                  ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    title: Text(
                                      '${maps(m['citations'] ?? m['cited_passages']).length} sources',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    children: [
                                      for (final citation in maps(
                                        m['citations'] ?? m['cited_passages'],
                                      ))
                                        ListTile(
                                          title: Text(
                                            stringValue(citation['filename']),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${stringValue(citation['text'])}\nPage ${citation['page'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                for (final place in maps(
                                  m['locations'] ?? m['mappable_locations'],
                                ))
                                  TextButton.icon(
                                    onPressed: () => openUrl(
                                      context,
                                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(stringValue(place['search_query'], stringValue(place['name'])))}',
                                    ),
                                    icon: const Icon(
                                      Icons.place_outlined,
                                      size: 16,
                                    ),
                                    label: Text(stringValue(place['name'])),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (state.user == null)
                        TextButton(
                          onPressed: () => requireSignIn(context),
                          child: const Text('Sign in'),
                        ),
                    ],
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 15),
                  child: Column(
                    children: [
                      TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 5,
                        enabled: !busy && atlas != null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => send(),
                        decoration: InputDecoration(
                          hintText: atlas == null
                              ? 'Choose a wiki to begin'
                              : 'Ask something wonderful…',
                          suffixIcon: IconButton(
                            tooltip: 'Send question',
                            onPressed: busy || atlas == null
                                ? null
                                : () => send(),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Stay curious. Check important details with the sources.',
                        style: TextStyle(color: Palette.muted, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WikiPicker extends StatefulWidget {
  const _WikiPicker({required this.atlases});
  final List<Atlas> atlases;
  @override
  State<_WikiPicker> createState() => _WikiPickerState();
}

class _WikiPickerState extends State<_WikiPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.atlases
        .where((a) => a.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Find a wiki',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (state.selectedAtlas != null &&
                  !items.any((a) => a.id == state.selectedAtlas!.id))
                ListTile(
                  title: Text(state.selectedAtlas!.name),
                  onTap: () => Navigator.pop(context, state.selectedAtlas),
                ),
              for (final a in items)
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(a.name),
                  subtitle: Text(a.kind),
                  onTap: () => Navigator.pop(context, a),
                ),
              if (state.moreAtlases)
                TextButton(
                  onPressed: () => state.loadAtlases(),
                  child: const Text('Load more wikis'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Conversations')),
    body: PageBody(
      children: [
        AsyncContent<List<Json>>(
          load: () => AppScope.of(context).repository.history(),
          builder: (items) => items.isEmpty
              ? const EmptyState(
                  title: 'Every conversation starts somewhere',
                  message:
                      'Your conversations will be kept here when you ask a wiki a question.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      MenuRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: stringValue(
                          item['title'],
                          'A curious conversation',
                        ),
                        subtitle: stringValue(item['last_question']),
                        onTap: () async {
                          final repo = AppScope.of(context).repository;
                          try {
                            final a = await repo.atlas(
                              stringValue(item['atlas_id']),
                            );
                            final messages = await repo.messages(
                              stringValue(item['id']),
                            );
                            if (context.mounted && a != null) {
                              openScreen(
                                context,
                                ChatScreen(
                                  atlas: a,
                                  threadId: stringValue(item['id']),
                                  initialMessages: messages,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, friendlyError(e));
                            }
                          }
                        },
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
