import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/widgets.dart';
import '../data/models.dart';

Future<Atlas?> chooseConversationWiki(BuildContext context) {
  final state = AppScope.of(context);
  if (state.atlases.isEmpty && !state.loadingAtlases) {
    unawaited(state.loadAtlases(refresh: true));
  }
  return showModalBottomSheet<Atlas>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom) *
            .75,
        child: const _ConversationWikiPicker(),
      ),
    ),
  );
}

class _ConversationWikiPicker extends StatefulWidget {
  const _ConversationWikiPicker();
  @override
  State<_ConversationWikiPicker> createState() =>
      _ConversationWikiPickerState();
}

class _ConversationWikiPickerState extends State<_ConversationWikiPicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final available = {
      for (final atlas in [?state.selectedAtlas, ...state.atlases])
        atlas.id: atlas,
    }.values;
    final items = available
        .where(
          (atlas) => atlas.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where shall we explore?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Pick a wiki to start your conversation with Picamo.'),
              const SizedBox(height: 18),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Find a city or wiki',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => query = value.trim()),
              ),
            ],
          ),
        ),
        if (state.loadingAtlases) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              for (final atlas in items)
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text(atlas.name),
                  subtitle: Text(atlas.kind),
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onTap: () => Navigator.pop(context, atlas),
                ),
              if (state.catalogError != null)
                EmptyState(
                  title: 'Let’s reconnect.',
                  message: state.catalogError!,
                  action: 'Try again',
                  onAction: () => state.loadAtlases(refresh: true),
                )
              else if (items.isEmpty && !state.loadingAtlases)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No wikis found. Try another name or load more below.',
                  ),
                ),
              if (state.moreAtlases && state.catalogError == null)
                TextButton(
                  onPressed: state.loadingAtlases
                      ? null
                      : () => state.loadAtlases(),
                  child: const Text('Load more wikis'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
