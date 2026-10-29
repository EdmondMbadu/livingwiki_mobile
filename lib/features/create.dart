import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'board_editor.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});
  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final form = GlobalKey<FormState>();
  final prompt = TextEditingController();
  String mode = 'describe';
  int count = 8;
  bool busy = false;
  String? error;
  Future<void> generate() async {
    if (!form.currentState!.validate() || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await AppScope.of(context).repository.call(
        'generateBoardWizardBatch',
        {
          'mode': mode,
          'prompt': prompt.text.trim(),
          'pastedList': mode == 'paste' ? prompt.text.trim() : '',
          'url': mode == 'url' ? prompt.text.trim() : '',
          'count': count,
          'countMode': 'fixed',
          'vibe': 'curator',
          'defaultType': 'place',
          'mediaMode': 'images',
          'narrationStyle': 'standard',
          'narrationSecondsPerCard': 30,
          'targetBoardId': '',
          'existingCards': [],
          'listingIntent': 'auto',
          if (mode == 'walking-tour' || mode == 'driving-tour')
            'tourOptions': {
              'voiceStyle': 'local',
              'paceOrRouteStyle': 'Standard',
              'extras': ['Photo stops', 'Accessibility notes'],
            },
        },
      );
      if (maps(result['cards']).isEmpty) {
        throw StateError(
          'No cards came back. Please try a more specific idea.',
        );
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => BoardEditor(seed: result)),
      );
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Follow an idea')),
    body: PageBody(
      children: [
        const Eyebrow('The LivingWiki wizard'),
        const SizedBox(height: 16),
        Text(
          'A spark.\nA whole new story.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 14),
        const Text(
          'Start with an idea, a web page, or a list. We’ll help you shape it into a board you can make your own.',
          style: TextStyle(color: Palette.muted),
        ),
        const SizedBox(height: 26),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Where shall we begin?'),
          items: const [
            DropdownMenuItem(
              value: 'describe',
              child: Text('An idea or a question'),
            ),
            DropdownMenuItem(value: 'url', child: Text('A web page')),
            DropdownMenuItem(
              value: 'paste',
              child: Text('A list or a piece of writing'),
            ),
            DropdownMenuItem(
              value: 'walking-tour',
              child: Text('A walking tour'),
            ),
            DropdownMenuItem(
              value: 'driving-tour',
              child: Text('A driving tour'),
            ),
          ],
          onChanged: busy ? null : (v) => setState(() => mode = v!),
        ),
        const SizedBox(height: 18),
        Form(
          key: form,
          child: TextFormField(
            controller: prompt,
            maxLength: 20000,
            minLines: 5,
            maxLines: 14,
            decoration: InputDecoration(
              labelText: mode == 'url'
                  ? 'Web page URL'
                  : mode.contains('tour')
                  ? 'City, route, and places to visit'
                  : 'Tell us what you have in mind',
              alignLabelWithHint: true,
              hintText: mode == 'url'
                  ? 'https://…'
                  : 'A slow afternoon discovering the hidden gardens of Philadelphia…',
            ),
            validator: (v) {
              if (v == null || v.trim().length < 5) {
                return 'Give your curiosity a little more detail.';
              }
              if (mode == 'url' && Uri.tryParse(v.trim())?.scheme != 'https') {
                return 'Use a public HTTPS web page.';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(child: Text('Cards in your story')),
            DropdownButton<int>(
              value: count,
              items: [4, 6, 8, 10, 12, 16]
                  .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => count = v!),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        BusyButton(
          busy: busy,
          label: 'Bring the idea to life',
          onPressed: generate,
          icon: Icons.auto_awesome_outlined,
        ),
        const SizedBox(height: 12),
        Text(
          busy
              ? 'Good stories take a little time. You can review every card before saving.'
              : 'Review and edit before saving. Generation uses your existing LivingWiki allowance.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Palette.muted),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: busy
              ? null
              : () => openScreen(context, const BoardEditor()),
          child: const Text('Start with a blank board instead'),
        ),
      ],
    ),
  );
}
