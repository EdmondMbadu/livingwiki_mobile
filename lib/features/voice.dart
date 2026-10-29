import 'dart:async';
import 'package:elevenlabs_agents/elevenlabs_agents.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({
    super.key,
    required this.title,
    this.atlasId,
    this.boardId,
    this.cardId,
    this.image = '',
  });
  final String title, image;
  final String? atlasId, boardId, cardId;
  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final ConversationClient client;
  late final AnimationController pulse;
  final List<Json> transcript = [];
  bool busy = false, active = false;
  int epoch = 0;
  String? error;
  String language = 'en';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    client = ConversationClient(
      callbacks: ConversationCallbacks(
        onMessage: ({required message, required source}) {
          if (mounted) {
            setState(
              () => transcript.add({
                'role': source == Role.user ? 'You' : widget.title,
                'text': message,
              }),
            );
          }
        },
        onError: (message, [details]) {
          if (mounted) {
            setState(() {
              error = 'The voice connection was interrupted. Please try again.';
              busy = false;
              active = false;
            });
          }
        },
        onDisconnect: (_) {
          if (mounted) {
            setState(() {
              active = false;
              busy = false;
            });
          }
        },
      ),
    );
    client.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  Future<void> start() async {
    if (busy || active) return;
    final request = ++epoch;
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await state.repository
          .call('createElevenLabsVoiceSession', {
            'connectionType': 'webrtc',
            'atlasId': widget.atlasId,
            'atlasName': widget.title,
            'anonymousVisitorId': state.visitorId,
            'analyticsVisitorId': state.visitorId,
            'participantName': state.user?.displayName,
            'voiceLanguageCode': language,
            if (widget.cardId != null) 'experience': 'talking-card',
            if (widget.boardId != null) 'boardId': widget.boardId,
            if (widget.cardId != null) 'cardId': widget.cardId,
          });
      if (!mounted || epoch != request) return;
      final token = stringValue(session['conversationToken']);
      if (token.isEmpty) {
        throw StateError('Voice is not available for this story yet.');
      }
      await client.startSession(
        conversationToken: token,
        userId: stringValue(session['userId'], state.visitorId),
        dynamicVariables: mapValue(session['dynamicVariables']),
        overrides: ConversationOverrides(
          tts:
              session['voiceOverrideEnabled'] == true &&
                  stringValue(session['voiceId']).isNotEmpty
              ? TtsOverrides(voiceId: session['voiceId'])
              : null,
        ),
      );
      if (!mounted || epoch != request) {
        await client.endSession();
        return;
      }
      setState(() => active = true);
    } catch (e) {
      if (mounted && epoch == request) setState(() => error = friendlyError(e));
    } finally {
      if (mounted && epoch == request) setState(() => busy = false);
    }
  }

  Future<void> stop() async {
    epoch++;
    await client.endSession();
    if (mounted) {
      setState(() {
        active = false;
        busy = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    epoch++;
    WidgetsBinding.instance.removeObserver(this);
    client.removeListener(changed);
    client.dispose();
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Wonder out loud', style: TextStyle(fontSize: 15)),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          children: [
            Center(
              child: Eyebrow(
                widget.cardId == null
                    ? 'A conversation with a wiki'
                    : 'A living, talking story',
              ),
            ),
            const SizedBox(height: 25),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 210,
              child: Center(
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (_, _) => Container(
                    width: 170 + pulse.value * (active ? 20 : 8),
                    height: 170 + pulse.value * (active ? 20 : 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Palette.moss.withValues(alpha: .5),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.forest.withValues(
                            alpha: .08 + pulse.value * .05,
                          ),
                          spreadRadius: 12 + pulse.value * 16,
                        ),
                        BoxShadow(
                          color: Palette.forest.withValues(alpha: .04),
                          spreadRadius: 30 + pulse.value * 25,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipOval(
                        child: widget.image.isNotEmpty
                            ? Photo(url: widget.image, width: 140, height: 140)
                            : Image.asset(
                                'assets/images/picamo.webp',
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Semantics(
              liveRegion: true,
              child: Text(
                busy
                    ? 'Making a little connection…'
                    : active
                    ? (client.isSpeaking
                          ? 'A story is unfolding…'
                          : client.isMuted
                          ? 'Microphone muted'
                          : 'I’m listening.')
                    : 'Some stories are better as a conversation.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.muted),
              ),
            ),
            const SizedBox(height: 20),
            if (!active) ...[
              Center(
                child: DropdownButton<String>(
                  value: language,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'fr', child: Text('Français')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'pt', child: Text('Português')),
                    DropdownMenuItem(value: 'ja', child: Text('日本語')),
                    DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                  ],
                  onChanged: busy ? null : (v) => setState(() => language = v!),
                ),
              ),
              const SizedBox(height: 12),
              BusyButton(
                busy: busy,
                label: 'Start a conversation',
                onPressed: start,
                icon: Icons.mic_none_rounded,
              ),
              const SizedBox(height: 12),
              const Text(
                'Uses your microphone while the conversation is open.\nVoice is powered by ElevenLabs.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Palette.muted),
              ),
            ] else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => client.toggleMute(),
                    icon: Icon(
                      client.isMuted
                          ? Icons.mic_off_outlined
                          : Icons.mic_none_rounded,
                    ),
                    label: Text(client.isMuted ? 'Unmute' : 'Mute'),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.coral,
                    ),
                    onPressed: stop,
                    icon: const Icon(Icons.call_end_outlined),
                    label: const Text('End conversation'),
                  ),
                ],
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (transcript.isNotEmpty) ...[
              SectionHeading(
                'The conversation',
                action: 'Copy',
                onAction: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text: transcript
                          .map((m) => '${m['role']}: ${m['text']}')
                          .join('\n\n'),
                    ),
                  );
                  if (context.mounted) toast(context, 'Transcript copied.');
                },
              ),
              for (final message in transcript)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(stringValue(message['role'])),
                        const SizedBox(height: 8),
                        SelectableText(stringValue(message['text'])),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
