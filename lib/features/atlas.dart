import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'auth.dart';
import 'boards.dart';
import 'chat.dart';
import 'library.dart';
import 'voice.dart';

class AtlasScreen extends StatefulWidget {
  const AtlasScreen({super.key, required this.atlas});
  final Atlas atlas;
  @override
  State<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends State<AtlasScreen> {
  String tab = 'Overview';
  @override
  Widget build(BuildContext context) {
    final a = widget.atlas;
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(a.name, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'Share wiki',
            onPressed: () => shareLink(
              context,
              a.name,
              'https://livingwiki.com/atlas/${a.slug}',
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 275,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Photo(url: a.image, asset: a.localImage),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xD9102D20)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 23,
                        right: 23,
                        bottom: 24,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Pill(
                              '${a.kind.toUpperCase()} WIKI',
                              light: true,
                              icon: Icons.public,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              a.name,
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                            if (a.location.isNotEmpty)
                              Text(
                                a.location,
                                style: const TextStyle(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        state.selectAtlas(a);
                        openScreen(context, ChatScreen(atlas: a));
                      },
                      icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                      label: const Text('Ask this wiki'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () =>
                        openScreen(context, LibraryScreen(atlas: a)),
                    child: const Icon(Icons.library_books_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final t in ['Overview', 'Stories', 'Knowledge'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: tab == t,
                          label: Text(t),
                          onSelected: (_) => setState(() => tab = t),
                        ),
                      ),
                  ],
                ),
              ),
              if (tab == 'Overview') ...[
                MenuRow(
                  icon: Icons.mic_none_rounded,
                  title: 'Have a conversation',
                  subtitle: 'Get to know this wiki by voice',
                  onTap: () => openScreen(
                    context,
                    VoiceScreen(title: a.name, image: a.image, atlasId: a.id),
                  ),
                ),
                SectionHeading('Every place has a soul.'),
                Text(
                  a.description.isEmpty
                      ? 'Explore the stories, sources, and local knowledge that bring ${a.name} to life.'
                      : a.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Start with a question'),
                      const SizedBox(height: 12),
                      for (final question in [
                        'What makes ${a.name} special?',
                        'What should I know before I visit?',
                        'Tell me something unexpected.',
                      ])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            question,
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: const Icon(
                            Icons.north_east_rounded,
                            size: 16,
                          ),
                          onTap: () => openScreen(
                            context,
                            ChatScreen(atlas: a, initialQuestion: question),
                          ),
                        ),
                    ],
                  ),
                ),
                if (a.latitude != null && a.longitude != null)
                  MenuRow(
                    icon: Icons.map_outlined,
                    title: 'Find it on the map',
                    subtitle: 'Get directions and explore nearby',
                    onTap: () => openUrl(
                      context,
                      'https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}',
                    ),
                  ),
                MenuRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Stay in the loop',
                  subtitle: 'Subscribe to this wiki’s updates',
                  onTap: () async {
                    if (!await requireSignIn(context)) return;
                    try {
                      await state.repository.call('subscribeToAtlasUpdates', {
                        'atlasId': a.id,
                        'email': state.user!.email,
                      });
                      if (context.mounted) {
                        toast(context, 'You’re subscribed to ${a.name}.');
                      }
                    } catch (e) {
                      if (context.mounted) toast(context, friendlyError(e));
                    }
                  },
                ),
              ],
              if (tab == 'Stories') ...[
                const SectionHeading('Stories worth your time'),
                AsyncContent<List<Board>>(
                  load: () => state.repository.cityBoards(a.id),
                  builder: (boards) => boards.isEmpty
                      ? const EmptyState(
                          title: 'The next chapter is coming',
                          message:
                              'Published collections will appear here. In the meantime, ask this wiki a question.',
                        )
                      : BoardGrid(
                          boards: boards,
                          onTap: (b) =>
                              openScreen(context, BoardScreen(boardId: b.id)),
                        ),
                ),
              ],
              if (tab == 'Knowledge') ...[
                const SectionHeading('Go a little deeper'),
                WikiContent(atlas: a),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class WikiContent extends StatelessWidget {
  const WikiContent({super.key, required this.atlas});
  final Atlas atlas;
  @override
  Widget build(BuildContext context) => AsyncContent<Json>(
    load: () => AppScope.of(context).repository.wiki(atlas),
    builder: (data) {
      final articles = maps(data['articles']), topics = maps(data['topics']);
      if (articles.isEmpty && topics.isEmpty) {
        return const EmptyState(
          title: 'Knowledge is growing here',
          message: 'Articles and sources will appear as this wiki grows.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final article in articles)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Surface(
                child: InkWell(
                  onTap: () =>
                      openScreen(context, ArticleScreen(article: article)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('From the wiki'),
                      const SizedBox(height: 10),
                      Text(
                        stringValue(article['title']),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        stringValue(article['summary']),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Palette.muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Text(
                            'Read the story',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 15),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (topics.isNotEmpty) ...[
            const SectionHeading('Explore by topic'),
            for (final topic in topics)
              MenuRow(
                icon: Icons.subject_rounded,
                title: stringValue(topic['name']),
                subtitle: stringValue(topic['summary']),
                onTap: () => openScreen(
                  context,
                  TopicScreen(topic: topic, atlas: atlas),
                ),
              ),
          ],
        ],
      );
    },
  );
}

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Json article;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        IconButton(
          tooltip: 'Share article',
          onPressed: () => shareLink(
            context,
            stringValue(article['title']),
            'https://livingwiki.com/wiki',
          ),
          icon: const Icon(Icons.ios_share_outlined),
        ),
      ],
    ),
    body: PageBody(
      children: [
        const Eyebrow('Living knowledge'),
        const SizedBox(height: 18),
        SelectableText(
          stringValue(article['title']),
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 16),
        if (stringValue(article['summary']).isNotEmpty)
          Text(
            stringValue(article['summary']),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Palette.muted),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Divider(),
        ),
        MarkdownBody(
          data: stringValue(article['content']),
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: Theme.of(context).textTheme.bodyLarge,
            h1: Theme.of(context).textTheme.headlineLarge,
            h2: Theme.of(context).textTheme.headlineMedium,
          ),
          onTapLink: (_, url, _) {
            if (url != null) openUrl(context, url);
          },
        ),
        if (maps(article['source_documents']).isNotEmpty) ...[
          const SectionHeading('Sources'),
          for (final source in maps(article['source_documents']))
            MenuRow(
              icon: Icons.description_outlined,
              title: stringValue(source['filename']),
              onTap: () async {
                try {
                  final link = await AppScope.of(context).repository
                      .call('getWikiSourceDocumentLink', {
                        'documentId': source['document_id'],
                        'atlasId': article['atlas_id'],
                        'filename': source['filename'],
                      });
                  if (context.mounted) {
                    await openUrl(context, stringValue(link['url']));
                  }
                } catch (e) {
                  if (context.mounted) toast(context, friendlyError(e));
                }
              },
            ),
        ],
        const SizedBox(height: 40),
      ],
    ),
  );
}

class TopicScreen extends StatelessWidget {
  const TopicScreen({super.key, required this.topic, required this.atlas});
  final Json topic;
  final Atlas atlas;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(stringValue(topic['name']))),
    body: PageBody(
      children: [
        Text(
          stringValue(topic['summary']),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        AsyncContent<Json>(
          load: () => AppScope.of(context).repository.call(
            atlas.data['is_public'] == true
                ? 'getPublicWikiTopicDetails'
                : 'getWikiTopicDetails',
            {'topicId': topic['id']},
          ),
          builder: (d) => Column(
            children: [
              for (final entry in maps(d['entries']))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Surface(
                    child: SelectableText(stringValue(entry['claim'])),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
