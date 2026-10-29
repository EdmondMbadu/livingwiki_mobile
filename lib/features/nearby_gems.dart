import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/app_state.dart';
import '../core/nearby_location.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import '../data/nearby_gems.dart';
import 'auth.dart';
import 'boards.dart';

class NearbyGemsDoorway extends StatelessWidget {
  const NearbyGemsDoorway({super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: Palette.forest,
    borderRadius: BorderRadius.circular(23),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => openScreen(context, const NearbyGemsScreen()),
      child: Padding(
        padding: const EdgeInsets.all(21),
        child: Row(
          children: [
            const Icon(Icons.explore_outlined, size: 35, color: Palette.gold),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A LITTLE WONDER, CLOSE BY',
                    style: TextStyle(
                      color: Palette.gold,
                      fontSize: 9,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Find gems near me',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'A walk. A short drive. A lovely surprise.',
                    style: TextStyle(color: Color(0xFFDCE5D9), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 20,
              color: Palette.gold,
            ),
          ],
        ),
      ),
    ),
  );
}

class NearbyGemsScreen extends StatefulWidget {
  const NearbyGemsScreen({super.key, this.location});
  final NearbyLocation? location;
  @override
  State<NearbyGemsScreen> createState() => _NearbyGemsScreenState();
}

class _NearbyGemsScreenState extends State<NearbyGemsScreen> {
  final scroll = ScrollController();
  final place = TextEditingController(),
      details = TextEditingController(),
      title = TextEditingController();
  late final location = widget.location ?? NearbyLocation();
  NearbyRange range = NearbyRange.walk;
  int count = 8;
  bool manual = false, busy = false, saving = false;
  String? error, owner;
  NearbyLocationFailure? locationFailure;
  NearbyGemsDraft? draft;
  Set<String> selected = {};
  String loading = '';
  int request = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = AppScope.of(context).user?.uid ?? '';
    if (owner != null && owner!.isNotEmpty && owner != account) {
      request++;
      draft = null;
      selected = {};
      busy = false;
      saving = false;
      title.clear();
      place.clear();
      error = 'Your account changed. Start a new search.';
    }
    owner = account;
  }

  Future<void> search() async {
    if (busy || saving) return;
    if (manual && place.text.trim().length < 2) {
      setState(() => error = 'Enter a city, neighborhood, or address.');
      return;
    }
    if (!await requireSignIn(context) || !mounted) return;
    final state = AppScope.of(context);
    final account = state.repository.uid;
    final run = ++request;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
      locationFailure = null;
      loading = manual
          ? 'Looking for little wonders…'
          : 'Finding your starting point…';
    });
    try {
      final position = manual ? null : await location.current();
      if (!mounted || run != request || state.repository.uid != account) return;
      setState(() => loading = 'Finding places worth stepping out for…');
      final result = await state.repository.discoverNearbyGems(
        range: range,
        count: count,
        details: details.text,
        manualLocation: manual ? place.text : null,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      if (!mounted || run != request || state.repository.uid != account) return;
      setState(() {
        draft = result;
        selected = result.cards.map((c) => c.id).toSet();
        title.text = stringValue(result.board['title']);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && run == request && scroll.hasClients) scroll.jumpTo(0);
      });
    } catch (e) {
      if (mounted && run == request) {
        setState(() {
          if (e is NearbyLocationFailure) {
            locationFailure = e;
            manual = true;
          }
          error = e is NearbyLocationFailure ? e.message : friendlyError(e);
        });
      }
    } finally {
      if (mounted && run == request) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final result = draft;
    if (result == null || saving || selected.isEmpty) return;
    if (title.text.trim().isEmpty) {
      setState(() => error = 'Give your gems board a name.');
      return;
    }
    final repository = AppScope.of(context).repository;
    final run = request;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await repository.saveBoard(
        null,
        title: title.text.trim(),
        description: stringValue(result.board['description']),
        image:
            result.cards
                .where((c) => selected.contains(c.id))
                .map((c) => c.image)
                .where((s) => s.isNotEmpty)
                .firstOrNull ??
            '',
        visibility: 'private',
        kind: 'nearby-gems',
        nearbyDraft: result,
        cards: result.cards.where((c) => selected.contains(c.id)).toList(),
      );
      if (!mounted || request != run || repository.uid != result.ownerId) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BoardScreen(boardId: result.id),
        ),
      );
    } catch (e) {
      if (mounted && request == run) setState(() => error = friendlyError(e));
    } finally {
      if (mounted && request == run) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    request++;
    scroll.dispose();
    place.dispose();
    details.dispose();
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = draft;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nearby gems'),
          actions: [
            if (result != null)
              TextButton(
                onPressed: saving
                    ? null
                    : () => setState(() {
                        draft = null;
                        error = null;
                      }),
                child: const Text('Refine'),
              ),
          ],
        ),
        bottomNavigationBar: result == null || busy
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: FilledButton.icon(
                  onPressed: saving || selected.isEmpty ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline, size: 18),
                  label: Text(
                    saving
                        ? 'Keeping your gems…'
                        : 'Keep ${selected.length} ${selected.length == 1 ? 'gem' : 'gems'} · private board',
                  ),
                ),
              ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
              children: [
                const Eyebrow('Let curiosity take the scenic route'),
                const SizedBox(height: 15),
                Text(
                  result == null
                      ? 'There’s wonder\nright around you.'
                      : 'Your next\nlittle adventure.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 14),
                Text(
                  result == null
                      ? 'A tucked-away garden. A bookshop with character. Somewhere you’ll be glad you found.'
                      : 'Discoveries around ${result.location}. Take a look and keep the ones that feel like you.',
                  style: const TextStyle(color: Palette.muted),
                ),
                const SizedBox(height: 24),
                if (busy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 22),
                  Text(
                    loading,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Checking real places and travel times. This can take about a minute.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Palette.muted),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      request++;
                      busy = false;
                    }),
                    child: const Text('Cancel search'),
                  ),
                ] else if (result == null) ...[
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make room for discovery',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$count gems · We’ll choose the strongest matches available.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Palette.muted,
                          ),
                        ),
                        Slider(
                          value: count.toDouble(),
                          min: 4,
                          max: 16,
                          divisions: 12,
                          label: '$count gems',
                          semanticFormatterCallback: (n) => '${n.round()} gems',
                          onChanged: (v) => setState(() => count = v.round()),
                        ),
                        const Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              '4 · A few favorites',
                              style: TextStyle(fontSize: 10),
                            ),
                            Text(
                              '16 · Go exploring',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'How far shall we wander?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<NearbyRange>(
                    groupValue: range,
                    onChanged: (v) => setState(() => range = v!),
                    child: Column(
                      children: [
                        for (final r in NearbyRange.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Semantics(
                              selected: range == r,
                              child: Surface(
                                padding: EdgeInsets.zero,
                                child: RadioListTile<NearbyRange>(
                                  value: r,
                                  title: Text(
                                    r.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${r.description}\n${r.radius}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  secondary: Icon(
                                    r == NearbyRange.walk
                                        ? Icons.directions_walk_rounded
                                        : r == NearbyRange.quickDrive
                                        ? Icons.directions_car_outlined
                                        : Icons.explore_outlined,
                                    color: Palette.coral,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: details,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'What sounds good? (optional)',
                      hintText: 'Gardens, history, bookstores, pastries…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Use my location'),
                        selected: !manual,
                        onSelected: (_) => setState(() {
                          manual = false;
                          error = null;
                        }),
                      ),
                      ChoiceChip(
                        label: const Text('Enter a place'),
                        selected: manual,
                        onSelected: (_) => setState(() {
                          manual = true;
                          error = null;
                        }),
                      ),
                    ],
                  ),
                  if (manual) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: place,
                      maxLength: 240,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => search(),
                      decoration: const InputDecoration(
                        labelText: 'Starting place',
                        hintText: 'City, neighborhood, or full address',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'Your starting point is used for this search and isn’t stored on your board. Gems are saved privately. Travel times are a guide; check directions before you go.',
                    style: TextStyle(fontSize: 11, color: Palette.muted),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: search,
                    icon: Icon(
                      manual
                          ? Icons.explore_outlined
                          : Icons.my_location_rounded,
                      size: 18,
                    ),
                    label: const Text('Find my gems'),
                  ),
                ] else ...[
                  TextField(
                    controller: title,
                    maxLength: 90,
                    enabled: !saving,
                    decoration: const InputDecoration(
                      labelText: 'Your board’s name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  NearbyGemsCollection(
                    cards: result.cards,
                    walking: result.metadata['travelMode'] == 'walking',
                    selected: selected,
                    onToggle: saving
                        ? null
                        : (id) => setState(() {
                            selected.contains(id)
                                ? selected.remove(id)
                                : selected.add(id);
                          }),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 18),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (locationFailure?.settings == true ||
                      locationFailure?.serviceSettings == true)
                    TextButton(
                      onPressed: () async {
                        try {
                          await location.openSettings(
                            service: locationFailure!.serviceSettings,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            toast(
                              context,
                              'Open your device settings to allow location access.',
                            );
                          }
                        }
                      },
                      child: const Text('Open location settings'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NearbyGemsCollection extends StatefulWidget {
  const NearbyGemsCollection({
    super.key,
    required this.cards,
    required this.walking,
    this.selected,
    this.onToggle,
    this.onOpen,
  });
  final List<WikiCard> cards;
  final bool walking;
  final Set<String>? selected;
  final ValueChanged<String>? onToggle;
  final ValueChanged<WikiCard>? onOpen;
  @override
  State<NearbyGemsCollection> createState() => _NearbyGemsCollectionState();
}

class _NearbyGemsCollectionState extends State<NearbyGemsCollection> {
  String sort = 'travel-time';
  bool map = false;
  WikiCard? focused;
  @override
  Widget build(BuildContext context) {
    final cards = sortNearbyCards(widget.cards, sort);
    final points = cards.where((c) => nearbyPoint(c) != null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('List'),
              avatar: const Icon(Icons.view_list_outlined, size: 17),
              selected: !map,
              onSelected: (_) => setState(() => map = false),
            ),
            ChoiceChip(
              label: const Text('Map'),
              avatar: const Icon(Icons.map_outlined, size: 17),
              selected: map,
              onSelected: points.isEmpty
                  ? null
                  : (_) => setState(() => map = true),
            ),
            DropdownButton<String>(
              value: sort,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(
                  value: 'travel-time',
                  child: Text('Travel time', style: TextStyle(fontSize: 12)),
                ),
                DropdownMenuItem(
                  value: 'distance',
                  child: Text('Distance', style: TextStyle(fontSize: 12)),
                ),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (map && points.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 340,
              child: FlutterMap(
                key: ValueKey(points.map((c) => c.id).join(',')),
                options: MapOptions(
                  initialCenter: nearbyPoint(points.first)!,
                  initialZoom: 13,
                  initialCameraFit: points.length > 1
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(
                            points.map((c) => nearbyPoint(c)!).toList(),
                          ),
                          padding: const EdgeInsets.all(42),
                          maxZoom: 15,
                        )
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.livingwiki.mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      for (final c in points)
                        Marker(
                          point: nearbyPoint(c)!,
                          width: 44,
                          height: 48,
                          child: Tooltip(
                            message: c.title,
                            child: IconButton(
                              onPressed: () => setState(() => focused = c),
                              icon: Icon(
                                Icons.location_on,
                                size: 38,
                                color:
                                    widget.selected == null ||
                                        widget.selected!.contains(c.id)
                                    ? Palette.coral
                                    : Palette.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                        onTap: () => openUrl(
                          context,
                          'https://www.openstreetmap.org/copyright',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap a pin to discover the place.',
            style: TextStyle(fontSize: 11, color: Palette.muted),
          ),
          const SizedBox(height: 12),
          if (focused != null) cardTile(focused!),
        ] else
          for (final c in cards) cardTile(c),
      ],
    );
  }

  Widget cardTile(WikiCard c) {
    final keep = widget.selected == null || widget.selected!.contains(c.id);
    final category = stringValue(
      mapValue(c.data['nearby'])['category'],
      'Local discovery',
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Surface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.image.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: AspectRatio(
                  aspectRatio: 1.9,
                  child: Photo(url: c.image),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Eyebrow(category)),
                      if (widget.selected != null)
                        Checkbox(
                          value: keep,
                          semanticLabel: 'Keep ${c.title}',
                          onChanged: widget.onToggle == null
                              ? null
                              : (_) => widget.onToggle!(c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nearbyTravelLabel(c, walking: widget.walking),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Palette.coral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(c.notes, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => openUrl(
                          context,
                          nearbyDirections(c, widget.walking),
                        ),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Directions'),
                      ),
                      if (widget.onOpen != null)
                        TextButton(
                          onPressed: () => widget.onOpen!(c),
                          child: const Text('Open story'),
                        ),
                      if (c.mapUrl.isNotEmpty)
                        TextButton(
                          onPressed: () => openUrl(context, c.mapUrl),
                          child: const Text('Place details'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
