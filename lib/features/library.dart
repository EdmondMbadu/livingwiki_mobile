import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'atlas.dart';
import 'auth.dart';

class MyWikisScreen extends StatefulWidget {
  const MyWikisScreen({super.key});
  @override
  State<MyWikisScreen> createState() => _MyWikisScreenState();
}

class _MyWikisScreenState extends State<MyWikisScreen> {
  int revision = 0;
  Future<void> create() async {
    if (!await requireSignIn(context) || !mounted) return;
    final name = TextEditingController(), description = TextEditingController();
    final value = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A wiki of your own'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'What’s it called?'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'What’s it about?'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe later'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(ctx, (name.text.trim(), description.text.trim()));
              }
            },
            child: const Text('Create wiki'),
          ),
        ],
      ),
    );
    // Dialog animations finish before their controllers are released.
    Future.delayed(const Duration(milliseconds: 350), () {
      name.dispose();
      description.dispose();
    });
    if (value == null || !mounted) return;
    try {
      final atlas = await AppScope.of(
        context,
      ).repository.createWiki(value.$1, value.$2);
      if (mounted) {
        setState(() => revision++);
        openScreen(context, AtlasScreen(atlas: atlas));
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My wikis'),
      actions: [
        IconButton(
          tooltip: 'Create wiki',
          onPressed: create,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: PageBody(
      children: [
        const Eyebrow('Your own corner of knowledge'),
        const SizedBox(height: 14),
        Text(
          'Something worth\nknowing.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 16),
        const Text(
          'Build a living library from your documents, links, and ideas.',
          style: TextStyle(color: Palette.muted),
        ),
        const SizedBox(height: 24),
        AsyncContent<List<Atlas>>(
          key: ValueKey(revision),
          load: () => AppScope.of(context).repository.myAtlases(),
          builder: (items) => items.isEmpty
              ? EmptyState(
                  title: 'Make space for your ideas',
                  message:
                      'A personal wiki turns your sources into something you can explore and ask questions about. Creation follows your existing membership.',
                  action: 'Create a wiki',
                  onAction: create,
                )
              : Column(
                  children: [
                    for (final a in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Surface(
                          child: MenuRow(
                            icon: Icons.auto_stories_outlined,
                            title: a.name,
                            subtitle: a.description,
                            onTap: () =>
                                openScreen(context, AtlasScreen(atlas: a)),
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

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.atlas});
  final Atlas atlas;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int revision = 0;
  bool busy = false;
  double progress = 0;
  String? error;
  bool get own =>
      widget.atlas.data['user_id'] == AppScope.of(context).user?.uid;
  Future<void> upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'md', 'docx', 'csv'],
      withData: true,
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    if (file.bytes == null || file.size > 25 * 1024 * 1024) {
      toast(context, 'Choose a document smaller than 25 MB.');
      return;
    }
    final mime = switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'csv' => 'text/csv',
      'md' => 'text/markdown',
      _ => 'text/plain',
    };
    setState(() {
      busy = true;
      progress = 0;
      error = null;
    });
    try {
      await AppScope.of(context).repository.uploadDocument(
        widget.atlas,
        file.name,
        mime,
        file.bytes!,
        (v) {
          if (mounted) setState(() => progress = v);
        },
      );
      if (mounted) {
        setState(() => revision++);
        toast(context, 'Uploaded. Your wiki is processing the source.');
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addLink() async {
    final input = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bring a source into your wiki'),
        content: TextField(
          controller: input,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://…',
            labelText: 'Web page URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (Uri.tryParse(input.text.trim())?.scheme == 'https') {
                Navigator.pop(ctx, input.text.trim());
              }
            },
            child: const Text('Add source'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), input.dispose);
    if (url == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AppScope.of(context).repository.call('submitUrlDocument', {
        'url': url,
        'atlasId': widget.atlas.id,
      });
      if (mounted) {
        setState(() => revision++);
        toast(context, 'The source is being added to your wiki.');
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('The source library'),
      actions: [
        IconButton(
          tooltip: 'Refresh sources',
          onPressed: () => setState(() => revision++),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: PageBody(
      children: [
        Eyebrow(widget.atlas.name),
        const SizedBox(height: 14),
        Text(
          'Knowledge with\nroots.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 14),
        const Text(
          'The documents and references behind this wiki.',
          style: TextStyle(color: Palette.muted),
        ),
        const SizedBox(height: 24),
        if (own)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : upload,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload a document'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : addLink,
                icon: const Icon(Icons.link),
                label: const Text('Add a web page'),
              ),
            ],
          ),
        if (busy)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: LinearProgressIndicator(
              value: progress > 0 && progress < 1 ? progress : null,
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
        const SizedBox(height: 20),
        AsyncContent<List<Json>>(
          key: ValueKey(revision),
          load: () => AppScope.of(context).repository.documents(widget.atlas),
          builder: (docs) => docs.isEmpty
              ? const EmptyState(
                  title: 'A fresh page',
                  message:
                      'Documents will appear here once they are added to this wiki.',
                )
              : Column(
                  children: [
                    for (final d in docs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Surface(
                          child: MenuRow(
                            icon: Icons.description_outlined,
                            title: stringValue(
                              d['filename'],
                              stringValue(d['title'], 'Source'),
                            ),
                            subtitle:
                                '${stringValue(d['status'], 'Available')} · ${intValue(d['page_count'])} pages${stringValue(d['error_message']).isNotEmpty ? '\n${d['error_message']}' : ''}',
                            onTap: () async {
                              try {
                                final result = await AppScope.of(context)
                                    .repository
                                    .call('getWikiSourceDocumentLink', {
                                      'documentId': d['id'],
                                      'atlasId': widget.atlas.id,
                                      'filename': d['filename'],
                                    });
                                if (context.mounted) {
                                  openUrl(context, stringValue(result['url']));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  toast(context, friendlyError(e));
                                }
                              }
                            },
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
