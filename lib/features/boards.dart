import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:video_player/video_player.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'auth.dart';
import 'board_editor.dart';
import 'chat.dart';
import 'create.dart';
import 'voice.dart';
import 'nearby_gems.dart';

class BoardsScreen extends StatefulWidget {
  const BoardsScreen({super.key, this.initialFilter = 'Discover'});
  final String initialFilter;
  @override
  State<BoardsScreen> createState() => _BoardsScreenState();
}

class _BoardsScreenState extends State<BoardsScreen> {
  late String filter;
  final search = TextEditingController();
  List<Board> boards = [];
  bool busy = true, more = true;
  dynamic cursor;
  String? error;
  int generation = 0;
  String? accountId;
  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) => load(reset: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = AppScope.of(context).user?.uid ?? '';
    if (accountId != null && id != accountId) {
      boards = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load(reset: true);
      });
    }
    accountId = id;
  }

  Future<void> load({bool reset = false}) async {
    final run = ++generation;
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        boards = [];
        cursor = null;
      }
    });
    try {
      if (filter == 'Mine') {
        if (state.user == null) {
          setState(() {
            boards = [];
            more = false;
            busy = false;
          });
          return;
        }
        final items = await state.repository.myBoards();
        if (mounted && run == generation) {
          setState(() {
            boards = items;
            more = false;
          });
        }
      } else if (filter == 'Saved') {
        final items = await state.repository.savedBoards(state.saved);
        if (mounted && run == generation) {
          setState(() {
            boards = items;
            more = false;
          });
        }
      } else {
        final page = await state.repository.publicBoards(
          cursor: reset ? null : cursor,
        );
        final items = filter == 'Songs'
            ? await Future.wait(
                page.items.map((b) => state.repository.board(b.id)),
              )
            : page.items;
        if (mounted && run == generation) {
          setState(() {
            boards = reset ? items : [...boards, ...items];
            cursor = page.cursor;
            more = page.hasMore;
          });
        }
      }
    } catch (e) {
      if (mounted && run == generation) {
        setState(() => error = friendlyError(e));
      }
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final visible = boards.where((b) {
      final d = '${b.title} ${b.description}'.toLowerCase();
      final q = search.text.toLowerCase();
      if (!d.contains(q)) return false;
      if (filter == 'Saved' && !state.saved.contains(b.id)) return false;
      return switch (filter) {
        'Trips' =>
          ['trip', 'tour', 'walking-tour', 'driving-tour'].contains(b.kind) ||
              d.contains('walking tour'),
        'Songs' => b.isMusic,
        'Properties' =>
          b.data['is_property'] == true ||
              ['property', 'real-estate', 'listing'].contains(b.kind),
        _ => true,
      };
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your next rabbit hole'),
        actions: [
          IconButton(
            tooltip: 'Create a board',
            onPressed: () async {
              if (await requireSignIn(context) && context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const CreateScreen()),
                );
                if (mounted) load(reset: true);
              }
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: RefreshIndicator(
            onRefresh: () => load(reset: true),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              children: [
                const Eyebrow('Collect what moves you'),
                const SizedBox(height: 12),
                Text(
                  filter == 'Mine'
                      ? 'A little world,\nmade by you.'
                      : filter == 'Saved'
                      ? 'Keep a little\nwonder close.'
                      : 'Stories to get\nlost in.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Find a story, place, or collection',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in [
                        'Discover',
                        'Mine',
                        'Saved',
                        'Trips',
                        'Songs',
                        'Properties',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              f,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: filter == f,
                            onSelected: busy
                                ? null
                                : (_) {
                                    setState(() => filter = f);
                                    load(reset: true);
                                  },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (filter == 'Saved')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Saved on this device, separately for each account.',
                      style: TextStyle(color: Palette.muted, fontSize: 11),
                    ),
                  ),
                if (error != null)
                  EmptyState(
                    title: 'The stories are still here',
                    message: error!,
                    action: 'Try again',
                    onAction: () => load(reset: true),
                  ),
                if (visible.isEmpty && !busy && error == null)
                  EmptyState(
                    title: filter == 'Mine'
                        ? 'Your first story starts here'
                        : filter == 'Saved'
                        ? 'A place for your favorites'
                        : 'Keep exploring',
                    message: filter == 'Mine'
                        ? 'Bring together the places, ideas, and stories you love.'
                        : filter == 'Saved'
                        ? 'Tap the bookmark on a board to keep it close.'
                        : 'Try another search, or load more discoveries below.',
                    action: filter == 'Mine'
                        ? (state.user == null ? 'Sign in' : 'Create a board')
                        : null,
                    onAction: () async {
                      if (await requireSignIn(context) && context.mounted) {
                        openScreen(context, const CreateScreen());
                      }
                    },
                  ),
                BoardGrid(
                  boards: visible,
                  onTap: (b) => openScreen(context, BoardScreen(boardId: b.id)),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (more && !busy)
                  Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: OutlinedButton(
                      onPressed: load,
                      child: const Text('More to discover'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.boardId});
  final String boardId;
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  int revision = 0;
  bool likeBusy = false;
  bool? liked;
  int? likes;
  Future<void> like(Board board) async {
    setState(() => likeBusy = true);
    try {
      final state = AppScope.of(context);
      final result = await state.repository.call('toggleBoardLike', {
        'boardId': board.id,
        'visitorId': state.visitorId,
      });
      if (mounted) {
        setState(() {
          liked = result['liked'] == true;
          likes = intValue(result['likeCount']);
        });
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => likeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('The story board', style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'Share board',
            onPressed: () => shareLink(
              context,
              'A LivingWiki story',
              'https://livingwiki.com/boards/${widget.boardId}',
            ),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: AsyncContent<Board>(
        key: ValueKey('${widget.boardId}:$revision:${state.user?.uid}'),
        load: () => state.repository.board(widget.boardId),
        builder: (b) {
          final cards = b.cards
              .where(
                (c) =>
                    c.data['authorOnly'] != true ||
                    b.ownerId == state.user?.uid,
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => revision++);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 1.45,
                        child: Photo(url: b.image),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Pill(b.label, icon: Icons.auto_stories_outlined),
                        const SizedBox(width: 8),
                        Pill('${cards.length} cards'),
                        if (b.visibility != 'public') ...[
                          const SizedBox(width: 8),
                          Pill(b.visibility, icon: Icons.lock_outline),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      b.title,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      b.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Palette.muted),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Curated by ${b.ownerName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed: cards.isEmpty
                              ? null
                              : () => openScreen(
                                  context,
                                  StoryPlayer(board: b, cards: cards),
                                ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play the story'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await state.toggleSaved(b.id);
                            } catch (e) {
                              if (context.mounted) {
                                toast(context, friendlyError(e));
                              }
                            }
                          },
                          icon: Icon(
                            state.saved.contains(b.id)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          label: Text(
                            state.saved.contains(b.id) ? 'Saved' : 'Save',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: likeBusy ? null : () => like(b),
                          icon: Icon(
                            liked == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 19,
                          ),
                          label: Text(
                            '${likes ?? intValue(b.data['like_count'])}',
                          ),
                        ),
                      ],
                    ),
                    if (b.ownerId == state.user?.uid)
                      MenuRow(
                        icon: Icons.edit_outlined,
                        title: 'Edit your board',
                        subtitle:
                            'Add cards, shape the story, choose an audience',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => BoardEditor(board: b),
                            ),
                          );
                          if (mounted) setState(() => revision++);
                        },
                      ),
                    if (stringValue(b.data['socialVideoUrl']).isNotEmpty)
                      MenuRow(
                        icon: Icons.movie_outlined,
                        title: 'Watch the film',
                        onTap: () => openScreen(
                          context,
                          VideoScreen(
                            url: stringValue(b.data['socialVideoUrl']),
                            title: b.title,
                          ),
                        ),
                      ),
                    if (b.atlasId.isNotEmpty)
                      MenuRow(
                        icon: Icons.auto_awesome_outlined,
                        title: 'Ask about this world',
                        onTap: () async {
                          try {
                            final a = await state.repository.atlas(b.atlasId);
                            if (context.mounted && a != null) {
                              openScreen(context, ChatScreen(atlas: a));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, friendlyError(e));
                            }
                          }
                        },
                      ),
                    if (b.kind == 'nearby-gems')
                      NearbyGemsCollection(
                        cards: cards,
                        walking:
                            mapValue(b.data['nearbyGems'])['travelMode'] ==
                            'walking',
                        onOpen: (card) => openScreen(
                          context,
                          CardScreen(board: b, card: card),
                        ),
                      ),
                    if (b.kind != 'nearby-gems')
                      SectionHeading(
                        'One card. Another discovery.',
                        subtitle:
                            'Take your time. There’s a story in every one.',
                      ),
                    if (cards.isEmpty)
                      const EmptyState(
                        title: 'A story in the making',
                        message: 'Cards will appear here as this board grows.',
                      ),
                    for (
                      var i = 0;
                      b.kind != 'nearby-gems' && i < cards.length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _StoryCard(
                          card: cards[i],
                          number: i + 1,
                          onTap: () => openScreen(
                            context,
                            CardScreen(board: b, card: cards[i]),
                          ),
                        ),
                      ),
                    if (mapValue(b.data['learningQuiz']).isNotEmpty)
                      MenuRow(
                        icon: Icons.quiz_outlined,
                        title: 'Test your discoveries',
                        subtitle: 'Take the board’s quiz',
                        onTap: () =>
                            openScreen(context, BoardQuizScreen(board: b)),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.card,
    required this.number,
    required this.onTap,
  });
  final WikiCard card;
  final int number;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Surface(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (card.image.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: AspectRatio(
                aspectRatio: 1.8,
                child: Photo(url: card.image),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('${number.toString().padLeft(2, '0')} / ${card.type}'),
                const SizedBox(height: 10),
                Text(
                  card.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (card.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    card.subtitle,
                    style: const TextStyle(color: Palette.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  card.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward, size: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CardScreen extends StatelessWidget {
  const CardScreen({super.key, required this.board, required this.card});
  final Board board;
  final WikiCard card;
  @override
  Widget build(BuildContext context) {
    final contact = mapValue(card.data['contactDetails']);
    return Scaffold(
      appBar: AppBar(
        title: const Text('A closer look', style: TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'Share card',
            onPressed: () => shareLink(
              context,
              card.title,
              'https://livingwiki.com/boards/${board.id}?card=${card.id}',
            ),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: PageBody(
        children: [
          if (card.image.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 1.3,
                child: Photo(url: card.image),
              ),
            ),
          const SizedBox(height: 24),
          Eyebrow(card.type),
          const SizedBox(height: 12),
          Text(card.title, style: Theme.of(context).textTheme.displayMedium),
          if (card.subtitle.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              card.subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Palette.muted),
            ),
          ],
          const SizedBox(height: 22),
          MarkdownBody(
            data: card.notes,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: Theme.of(context).textTheme.bodyLarge,
            ),
            onTapLink: (_, url, _) {
              if (url != null) openUrl(context, url);
            },
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: card.tags.map((t) => Pill(t)).toList(),
          ),
          const SizedBox(height: 18),
          if (card.mapUrl.isNotEmpty || card.data['locationLat'] != null)
            MenuRow(
              icon: Icons.directions_outlined,
              title: 'Go there',
              subtitle: 'Open directions',
              onTap: () => openUrl(
                context,
                card.mapUrl.isNotEmpty
                    ? card.mapUrl
                    : 'https://www.google.com/maps/dir/?api=1&destination=${card.data['locationLat']},${card.data['locationLng']}',
              ),
            ),
          if (card.source.isNotEmpty)
            MenuRow(
              icon: Icons.open_in_new_rounded,
              title: 'Explore the source',
              onTap: () => openUrl(context, card.source),
            ),
          if (stringValue(
            mapValue(card.data['conversation'])['atlasId'],
          ).isNotEmpty)
            MenuRow(
              icon: Icons.mic_none_rounded,
              title: 'Talk with this story',
              subtitle: 'Ask a question. Hear another side.',
              onTap: () => openScreen(
                context,
                VoiceScreen(
                  title: card.title,
                  image: card.image,
                  atlasId: stringValue(
                    mapValue(card.data['conversation'])['atlasId'],
                    board.atlasId,
                  ),
                  boardId: board.id,
                  cardId: card.id,
                ),
              ),
            ),
          if (stringValue(card.data['productUrl']).isNotEmpty)
            MenuRow(
              icon: Icons.shopping_bag_outlined,
              title: 'View product',
              subtitle: stringValue(card.data['price']),
              onTap: () =>
                  openUrl(context, stringValue(card.data['productUrl'])),
            ),
          if (stringValue(card.data['spotifyTrackUrl']).isNotEmpty)
            MenuRow(
              icon: Icons.music_note_outlined,
              title: 'Listen on Spotify',
              subtitle: stringValue(card.data['spotifyArtistName']),
              onTap: () =>
                  openUrl(context, stringValue(card.data['spotifyTrackUrl'])),
            ),
          if (stringValue(card.data['youtubeVideoId']).isNotEmpty)
            MenuRow(
              icon: Icons.smart_display_outlined,
              title: 'Watch on YouTube',
              onTap: () => openUrl(
                context,
                'https://www.youtube.com/watch?v=${card.data['youtubeVideoId']}',
              ),
            ),
          if (stringValue(mapValue(card.data['talkDrop'])['url']).isNotEmpty)
            MenuRow(
              icon: Icons.play_circle_outline,
              title: 'Watch the Talk Drop',
              onTap: () => openScreen(
                context,
                VideoScreen(
                  url: stringValue(mapValue(card.data['talkDrop'])['url']),
                  title: card.title,
                ),
              ),
            ),
          if (stringValue(card.data['childBoardId']).isNotEmpty)
            MenuRow(
              icon: Icons.layers_outlined,
              title: 'Step inside this collection',
              onTap: () => openScreen(
                context,
                BoardScreen(boardId: stringValue(card.data['childBoardId'])),
              ),
            ),
          if (contact.isNotEmpty) ...[
            const SectionHeading('Let’s connect'),
            for (final entry in contact.entries.where(
              (e) => e.value is String && (e.value as String).isNotEmpty,
            ))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: SelectableText('${entry.key}: ${entry.value}'),
              ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                openScreen(context, StoryPlayer(board: board, cards: [card])),
            icon: const Icon(Icons.headphones_outlined),
            label: const Text('Listen to this story'),
          ),
        ],
      ),
    );
  }
}

class StoryPlayer extends StatefulWidget {
  const StoryPlayer({super.key, required this.board, required this.cards});
  final Board board;
  final List<WikiCard> cards;
  @override
  State<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<StoryPlayer> {
  final audio = AudioPlayer();
  final page = PageController();
  final Map<String, Source> cache = {};
  StreamSubscription? audioSubscription;
  int index = 0, request = 0;
  bool playing = false, loading = false;
  String language = 'en';
  String? error;
  List<WikiCard>? translated;
  List<WikiCard> get cards => translated ?? widget.cards;
  @override
  void initState() {
    super.initState();
    audioSubscription = audio.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => playing = s == PlayerState.playing);
    });
  }

  Future<void> play() async {
    if (loading) return;
    if (playing) {
      await audio.pause();
      return;
    }
    if (audio.state == PlayerState.paused) {
      await audio.resume();
      return;
    }
    final run = ++request, current = cards[index];
    final state = AppScope.of(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final key = '${current.id}:$language';
      Source? source = cache[key];
      if (source == null) {
        if (current.audio.isNotEmpty && language == 'en') {
          source = UrlSource(current.audio);
        } else {
          final text = current.narration.isEmpty
              ? '${current.title}. ${current.subtitle}'
              : current.narration;
          final result = await state.repository
              .call('synthesizeChatAnswerSpeech', {
                'text': text.substring(0, text.length.clamp(0, 4000)),
                'question': 'Read this LivingWiki story aloud.',
                'anonymousVisitorId': state.visitorId,
                'mode': 'tour',
                'boardId': widget.board.id,
                'cardId': current.id,
                'contentLanguage': language,
              });
          if (stringValue(result['audioUrl']).isNotEmpty) {
            source = UrlSource(stringValue(result['audioUrl']));
          } else if (stringValue(result['audioBase64']).isNotEmpty) {
            source = BytesSource(
              base64Decode(result['audioBase64']),
              mimeType: stringValue(result['contentType'], 'audio/mpeg'),
            );
          } else {
            throw StateError('Narration is not available for this card yet.');
          }
        }
        cache[key] = source;
      }
      if (mounted && request == run) await audio.play(source);
    } catch (e) {
      if (mounted && request == run) setState(() => error = friendlyError(e));
    } finally {
      if (mounted && request == run) setState(() => loading = false);
    }
  }

  Future<void> changeLanguage(String next) async {
    if (next == language || loading) return;
    request++;
    await audio.stop();
    if (!mounted) return;
    if (next == 'en') {
      setState(() {
        language = next;
        translated = null;
      });
      return;
    }
    final state = AppScope.of(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await state.repository.call('translateBoard', {
        'boardId': widget.board.id,
        'targetLanguage': next,
      });
      if (result['boardId'] != widget.board.id ||
          result['targetLanguage'] != next) {
        throw StateError('The translation did not match this story.');
      }
      final translatedCards = translateCards(widget.cards, result);
      if (!mounted) return;
      setState(() {
        translated = translatedCards;
        language = next;
      });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    request++;
    audioSubscription?.cancel();
    audio.dispose();
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF142C22),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 14, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Close story',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    widget.board.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                DropdownButton<String>(
                  value: language,
                  dropdownColor: Palette.ink,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  underline: const SizedBox.shrink(),
                  icon: const Icon(
                    Icons.language,
                    color: Colors.white70,
                    size: 20,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'ja', child: Text('日本語')),
                    DropdownMenuItem(value: 'pt', child: Text('Português')),
                    DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                  ],
                  onChanged: loading ? null : (v) => changeLanguage(v!),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= index ? Palette.gold : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: page,
              itemCount: cards.length,
              onPageChanged: (i) async {
                request++;
                await audio.stop();
                if (mounted) {
                  setState(() {
                    index = i;
                    loading = false;
                    error = null;
                  });
                }
              },
              itemBuilder: (_, i) {
                final c = cards[i];
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 1.1,
                        child: Photo(
                          url: c.image.isNotEmpty
                              ? c.image
                              : widget.board.image,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    Eyebrow(
                      '${(i + 1).toString().padLeft(2, '0')} / ${cards.length.toString().padLeft(2, '0')}',
                      color: Palette.gold,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      c.title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      c.narration.isEmpty ? c.subtitle : c.narration,
                      style: const TextStyle(
                        color: Color(0xFFD0DCCD),
                        fontSize: 16,
                        height: 1.75,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error!,
                style: const TextStyle(color: Palette.gold, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous card',
                  onPressed: index == 0
                      ? null
                      : () => page.previousPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                  icon: Icon(
                    Icons.skip_previous_rounded,
                    color: index == 0 ? Colors.white24 : Colors.white,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.gold,
                    foregroundColor: Palette.ink,
                  ),
                  onPressed: loading ? null : play,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  label: Text(
                    loading
                        ? 'Preparing…'
                        : playing
                        ? 'Pause story'
                        : 'Listen',
                  ),
                ),
                IconButton(
                  tooltip: 'Next card',
                  onPressed: index == cards.length - 1
                      ? null
                      : () => page.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: index == cards.length - 1
                        ? Colors.white24
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.url, required this.title});
  final String url, title;
  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final VideoPlayerController player;
  late final Future<void> ready;
  @override
  void initState() {
    super.initState();
    player = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    ready = player.initialize();
    player.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    player.removeListener(_changed);
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(widget.title),
    ),
    body: FutureBuilder<void>(
      future: ready,
      builder: (_, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            title: 'Video unavailable',
            message: 'Try opening the video directly.',
            action: 'Open video',
            onAction: () => openUrl(context, widget.url),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: player.value.aspectRatio,
                child: VideoPlayer(player),
              ),
              VideoProgressIndicator(
                player,
                allowScrubbing: true,
                padding: const EdgeInsets.all(16),
              ),
              IconButton(
                tooltip: player.value.isPlaying ? 'Pause video' : 'Play video',
                onPressed: () =>
                    player.value.isPlaying ? player.pause() : player.play(),
                icon: Icon(
                  player.value.isPlaying
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class BoardQuizScreen extends StatefulWidget {
  const BoardQuizScreen({super.key, required this.board});
  final Board board;
  @override
  State<BoardQuizScreen> createState() => _BoardQuizScreenState();
}

class _BoardQuizScreenState extends State<BoardQuizScreen> {
  int index = 0;
  final Map<String, String> answers = {};
  final started = DateTime.now();
  Json? grade;
  bool busy = false;
  String? notice;
  List<Json> get questions =>
      maps(mapValue(widget.board.data['learningQuiz'])['questions']);
  Future<void> finish() async {
    final results = questions
        .map(
          (q) => <String, dynamic>{
            'questionId': q['id'],
            'selectedOptionId': answers[q['id']],
            'correctOptionId': q['correctOptionId'],
            'correct': answers[q['id']] == q['correctOptionId'],
            'explanation': q['explanation'],
          },
        )
        .toList();
    final score = results.where((r) => r['correct'] == true).length;
    setState(() {
      grade = {
        'score': score,
        'total': questions.length,
        'percent': (100 * score / questions.length).round(),
        'results': results,
      };
    });
    final state = AppScope.of(context);
    if (state.user == null) {
      setState(
        () => notice =
            'Your result is here for this session. Sign in next time to save scores.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      final result = await state.repository.call('submitBoardQuizAttempt', {
        'boardId': widget.board.id,
        'quizId': mapValue(widget.board.data['learningQuiz'])['id'],
        'answers': answers.entries
            .map((e) => {'questionId': e.key, 'optionId': e.value})
            .toList(),
        'elapsedMs': DateTime.now().difference(started).inMilliseconds,
      });
      if (mounted) {
        setState(() {
          if (mapValue(result['grade']).isNotEmpty) {
            grade = mapValue(result['grade']);
          }
          notice = result['leaderboardSaved'] == true
              ? 'Your score is on the leaderboard.'
              : 'Your score has been saved.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => notice = 'Your result is ready, but it could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty ||
        mapValue(widget.board.data['learningQuiz'])['published'] != true) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          title: 'A quiz in the making',
          message: 'Come back when the author publishes this quiz.',
        ),
      );
    }
    final q = questions[index], options = maps(questions[index]['options']);
    return Scaffold(
      appBar: AppBar(title: const Text('A little knowledge check')),
      body: PageBody(
        children: [
          Eyebrow(
            grade == null
                ? '${index + 1} of ${questions.length}'
                : 'The discoveries add up',
          ),
          const SizedBox(height: 20),
          Text(
            grade == null
                ? stringValue(q['prompt'])
                : 'Curiosity looks good on you.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 25),
          if (grade == null) ...[
            LinearProgressIndicator(value: (index + 1) / questions.length),
            const SizedBox(height: 24),
            for (final option in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: answers[q['id']] == option['id']
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed: () => setState(
                    () => answers[stringValue(q['id'])] = stringValue(
                      option['id'],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(stringValue(option['text'])),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: answers[q['id']] == null
                  ? null
                  : () {
                      if (index < questions.length - 1) {
                        setState(() => index++);
                      } else {
                        finish();
                      }
                    },
              child: Text(
                index == questions.length - 1
                    ? 'See how you did'
                    : 'Next question',
              ),
            ),
          ] else ...[
            Text(
              '${grade!['score']} / ${grade!['total']}',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: 12),
            if (notice != null)
              Text(notice!, style: const TextStyle(color: Palette.muted)),
            if (busy) const LinearProgressIndicator(),
            const SectionHeading('A little reflection'),
            for (final result in maps(grade!['results']))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            result['correct'] == true
                                ? Icons.check_circle_outline
                                : Icons.lightbulb_outline,
                            color: result['correct'] == true
                                ? Palette.forest
                                : Palette.coral,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stringValue(
                                questions
                                    .where(
                                      (q) => q['id'] == result['questionId'],
                                    )
                                    .firstOrNull?['prompt'],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(stringValue(result['explanation'])),
                    ],
                  ),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to the story'),
            ),
          ],
        ],
      ),
    );
  }
}
