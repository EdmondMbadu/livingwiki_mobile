import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/models.dart';
import 'app_state.dart';
import 'theme.dart';

void openScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
void toast(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
Future<void> openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !['https', 'http', 'mailto', 'tel'].contains(uri.scheme)) {
    toast(context, 'This link is unavailable.');
    return;
  }
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      toast(context, 'Unable to open this link.');
    }
  } catch (_) {
    if (context.mounted) toast(context, 'Unable to open this link.');
  }
}

Future<void> shareLink(BuildContext context, String title, String url) async {
  final box = context.findRenderObject() as RenderBox?;
  try {
    await SharePlus.instance.share(
      ShareParams(
        title: title,
        text: '$title\n$url',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) toast(context, 'Link copied.');
  }
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.padding = 24});
  final List<Widget> children;
  final double padding;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: ListView(padding: EdgeInsets.all(padding), children: children),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.subtitle,
  });
  final String title;
  final String? action, subtitle;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action!, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
      ],
    ),
  );
}

class Photo extends StatelessWidget {
  const Photo({
    super.key,
    this.url = '',
    this.asset = '',
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });
  final String url, asset;
  final double? width, height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF678776), Color(0xFF233C32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.spa_outlined, color: Color(0xFFDAE4D4), size: 38),
      ),
    );
    Widget local() => asset.isEmpty
        ? fallback
        : Image.asset(
            asset,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => fallback,
          );
    final resolvedUrl = url.startsWith('/')
        ? 'https://livingwiki.com$url'
        : url;
    return resolvedUrl.startsWith('https://') ||
            resolvedUrl.startsWith('http://')
        ? Image.network(
            resolvedUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, _, _) => local(),
            loadingBuilder: (_, child, event) =>
                event == null ? child : local(),
          )
        : local();
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.auto_awesome_outlined,
    this.action,
    this.onAction,
  });
  final String title, message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 9),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: FilledButton(onPressed: onAction, child: Text(action!)),
          ),
      ],
    ),
  );
}

class AsyncContent<T> extends StatefulWidget {
  const AsyncContent({
    super.key,
    required this.load,
    required this.builder,
    this.loadingHeight = 180,
  });
  final Future<T> Function() load;
  final Widget Function(T) builder;
  final double loadingHeight;
  @override
  State<AsyncContent<T>> createState() => _AsyncContentState<T>();
}

class _AsyncContentState<T> extends State<AsyncContent<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return EmptyState(
          title: 'A little interruption',
          message: friendlyError(snapshot.error!),
          icon: Icons.cloud_off_outlined,
          action: 'Try again',
          onAction: () => setState(() => future = widget.load()),
        );
      }
      if (!snapshot.hasData) {
        return SizedBox(
          height: widget.loadingHeight,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .5),
      ),
    ),
    child: child,
  );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.icon, this.light = false});
  final String label;
  final IconData? icon;
  final bool light;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: light
          ? Colors.white.withValues(alpha: .19)
          : Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: light ? Colors.white : null),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: light ? Colors.white : null,
          ),
        ),
      ],
    ),
  );
}

class BoardTile extends StatelessWidget {
  const BoardTile({
    super.key,
    required this.board,
    required this.onTap,
    this.compact = false,
  });
  final Board board;
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Semantics(
      button: true,
      label: board.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: compact ? 1.65 : 1.35,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Photo(url: board.image),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.white.withValues(alpha: .95),
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: state.saved.contains(board.id)
                                ? 'Unsave board'
                                : 'Save board',
                            onPressed: () async {
                              try {
                                await state.toggleSaved(board.id);
                              } catch (e) {
                                if (context.mounted) {
                                  toast(context, friendlyError(e));
                                }
                              }
                            },
                            icon: Icon(
                              state.saved.contains(board.id)
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: Palette.ink,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Eyebrow('${board.label} · ${board.count} cards'),
              const SizedBox(height: 5),
              Text(
                board.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                board.ownerName.isEmpty ? 'LivingWiki' : board.ownerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Palette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BoardGrid extends StatelessWidget {
  const BoardGrid({super.key, required this.boards, required this.onTap});
  final List<Board> boards;
  final void Function(Board) onTap;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final columns = constraints.maxWidth > 850
          ? 3
          : constraints.maxWidth > 550
          ? 2
          : 1;
      return Wrap(
        spacing: 20,
        runSpacing: 26,
        children: boards
            .map(
              (b) => SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 20) / columns,
                child: BoardTile(
                  board: b,
                  compact: true,
                  onTap: () => onTap(b),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    leading: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22),
    ),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: Palette.muted),
          ),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
    onTap: onTap,
  );
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.busy,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final bool busy;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 9),
              ],
              Text(label),
            ],
          ),
  );
}
