import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/widgets.dart';
import '../data/city_guide.dart';
import 'chat.dart';
import 'conversation_picker.dart';
import 'voice.dart';

enum _ConversationMode { voice, text }

class PicamoWelcome extends StatefulWidget {
  const PicamoWelcome({super.key});
  @override
  State<PicamoWelcome> createState() => _PicamoWelcomeState();
}

class _PicamoWelcomeState extends State<PicamoWelcome> {
  _ConversationMode mode = _ConversationMode.voice;
  bool opening = false;

  Future<void> begin() async {
    if (opening) return;
    setState(() => opening = true);
    final state = AppScope.of(context);
    final selectedMode = mode;
    try {
      final atlas =
          state.selectedAtlas ?? await chooseConversationWiki(context);
      if (atlas == null || !mounted) return;
      state.selectAtlas(atlas);
      openScreen(
        context,
        selectedMode == _ConversationMode.voice
            ? VoiceScreen(
                title: atlas.name,
                atlasId: atlas.id,
                image: atlas.image,
                picamoGuide: usesPicamoCityGuide(atlas),
              )
            : ChatScreen(atlas: atlas),
      );
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final atlas = AppScope.of(context).selectedAtlas;
    final voice = mode == _ConversationMode.voice;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .23),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.primary.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meet Picamo.',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your curiosity companion.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Little-known places.\nA little more wonder.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                'assets/images/picamo-city-guide.webp',
                width: 100,
                height: 136,
                fit: BoxFit.contain,
                semanticLabel: 'Picamo, your friendly guide, holding a map',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<_ConversationMode>(
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            style: SegmentedButton.styleFrom(
              minimumSize: const Size(48, 48),
              selectedBackgroundColor: colors.primary,
              selectedForegroundColor: colors.onPrimary,
              backgroundColor: colors.surface,
              foregroundColor: colors.onSurfaceVariant,
              side: BorderSide(color: colors.primary.withValues(alpha: .18)),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            segments: const [
              ButtonSegment(
                value: _ConversationMode.voice,
                icon: Icon(Icons.mic_none_rounded, size: 19),
                label: Text('Talk to me'),
              ),
              ButtonSegment(
                value: _ConversationMode.text,
                icon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text('Text me'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: opening
                ? null
                : (selection) {
                    HapticFeedback.selectionClick();
                    setState(() => mode = selection.single);
                  },
          ),
          const SizedBox(height: 14),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: Text(
                voice
                    ? 'Wonder out loud. I’m all ears.'
                    : 'A good question is a lovely place to start.',
                key: ValueKey(mode),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: opening ? null : begin,
            icon: Icon(
              voice ? Icons.graphic_eq_rounded : Icons.edit_outlined,
              size: 20,
            ),
            label: Text(voice ? 'Start talking' : 'Start chatting'),
          ),
          const SizedBox(height: 8),
          if (atlas == null)
            Text(
              'Choose a wiki. Then ${voice ? 'talk' : 'type'} your way into its stories.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            )
          else
            TextButton.icon(
              onPressed: opening
                  ? null
                  : () async {
                      final state = AppScope.of(context);
                      final chosen = await chooseConversationWiki(context);
                      if (chosen != null && mounted) state.selectAtlas(chosen);
                    },
              icon: const Icon(Icons.public, size: 16),
              label: Text(
                '${atlas.name} · Change wiki',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
