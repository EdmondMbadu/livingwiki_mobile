import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'atlas.dart';
import 'boards.dart';
import 'gems.dart';
import 'chat.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String selected = 'For you';
  int revision = 0;
  Future<void> refresh() async {
    setState(() => revision++);
    await AppScope.of(context).loadAtlases(refresh: true);
  }

  Future<void> openFeatured() async {
    final state = AppScope.of(context);
    try {
      final local = state.atlases
          .where(
            (a) => a.slug.contains('philly') || a.slug.contains('philadelphia'),
          )
          .firstOrNull;
      final atlas =
          local ??
          await state.repository.atlasBySlug('philadelphia') ??
          await state.repository.atlasBySlug('philly');
      if (!mounted) return;
      if (atlas == null) {
        openScreen(context, const DirectoryScreen());
        return;
      }
      openScreen(context, AtlasScreen(atlas: atlas));
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return RefreshIndicator(
      onRefresh: refresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
            children: [
              Row(
                children: [
                  const Expanded(child: Eyebrow('For the endlessly curious')),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Palette.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Go somewhere new',
                    style: TextStyle(fontSize: 10, color: Palette.muted),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                'The world has\nstories. Find yours.',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Little-known places. Big ideas. A little wonder.',
                style: TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 22),
              InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () => openScreen(
                  context,
                  const DirectoryScreen(focusSearch: true),
                ),
                child: Surface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 17,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 21,
                        color: Palette.muted,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Where does your curiosity lead?',
                          style: TextStyle(color: Palette.muted, fontSize: 12),
                        ),
                      ),
                      const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Palette.muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in [
                      'For you',
                      'Cities',
                      'Universities',
                      'Off Grids',
                      'Properties',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: ChoiceChip(
                          label: Text(
                            category,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: selected == category,
                          showCheckmark: false,
                          onSelected: (_) {
                            if (category == 'Off Grids') {
                              openScreen(context, const GemsScreen());
                            } else if (category == 'Properties') {
                              openScreen(
                                context,
                                const BoardsScreen(initialFilter: 'Properties'),
                              );
                            } else if (category != 'For you') {
                              openScreen(
                                context,
                                DirectoryScreen(
                                  initialKind: category == 'Cities'
                                      ? 'city'
                                      : 'university',
                                ),
                              );
                            } else {
                              setState(() => selected = category);
                            }
                          },
                          selectedColor: Palette.forest,
                          labelStyle: TextStyle(
                            color: selected == category ? Colors.white : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                label: 'Explore Philadelphia',
                child: GestureDetector(
                  onTap: openFeatured,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: SizedBox(
                      height: 330,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const Photo(asset: 'assets/images/philly-hero.jpg'),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x100C231A), Color(0xE50C231A)],
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 22,
                            top: 22,
                            child: Pill(
                              'THE CITY EDIT',
                              icon: Icons.near_me_outlined,
                              light: true,
                            ),
                          ),
                          Positioned(
                            left: 23,
                            right: 23,
                            bottom: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Eyebrow(
                                  'More than a place on the map',
                                  color: Color(0xFFD6E5CF),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Hello, Philadelphia.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 38,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Revolutionary roots. Neighborhood soul.\nA thousand stories around the corner.',
                                  style: TextStyle(
                                    color: Color(0xFFE3E9DD),
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    const Text(
                                      'Step inside',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white38,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.explore_outlined,
                                      color: Colors.white60,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SectionHeading(
                'A world of possibility',
                subtitle: 'Follow a feeling. Discover something real.',
                action: 'See all',
                onAction: () => openScreen(context, const DirectoryScreen()),
              ),
              SizedBox(
                height: 285 * MediaQuery.textScalerOf(context).scale(1),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _JourneyTile(
                      title: 'City stories',
                      caption: 'GET TO KNOW A PLACE',
                      image: 'assets/images/new-york-city-hero.jpg',
                      onTap: () => openScreen(
                        context,
                        const DirectoryScreen(initialKind: 'city'),
                      ),
                    ),
                    _JourneyTile(
                      title: 'The scenic route',
                      caption: 'STORIES TO WALK INTO',
                      image: 'assets/images/walking-tour.jpg',
                      onTap: () => openScreen(
                        context,
                        const BoardsScreen(initialFilter: 'Trips'),
                      ),
                    ),
                    _JourneyTile(
                      title: 'Hidden in plain sight',
                      caption: 'OFF GRIDS',
                      image: 'assets/images/coffee.jpg',
                      onTap: () => openScreen(context, const GemsScreen()),
                    ),
                  ],
                ),
              ),
              SectionHeading(
                'Made for curious minds',
                subtitle: 'Stories and collections from the community.',
                action: 'Explore boards',
                onAction: () => openScreen(context, const BoardsScreen()),
              ),
              AsyncContent<DataPage<Board>>(
                key: ValueKey(revision),
                load: () => state.repository.publicBoards(),
                builder: (page) => page.items.isEmpty
                    ? const EmptyState(
                        title: 'Room for a little wonder',
                        message:
                            'New stories will appear here as the community publishes them.',
                      )
                    : SizedBox(
                        height: 340 * MediaQuery.textScalerOf(context).scale(1),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: page.items.take(8).length,
                          separatorBuilder: (_, _) => const SizedBox(width: 18),
                          itemBuilder: (_, i) {
                            final b = page.items[i];
                            return SizedBox(
                              width: 235,
                              child: BoardTile(
                                board: b,
                                onTap: () => openScreen(
                                  context,
                                  BoardScreen(boardId: b.id),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              Material(
                color: Palette.moss,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => openScreen(context, const ChatScreen()),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/picamo.webp',
                            semanticLabel: 'Picamo, your curiosity companion',
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Eyebrow(
                                'Your curiosity companion',
                                color: Palette.forest,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Meet Picamo.',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: Palette.ink),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Ask a wiki. See where it takes you.',
                                style: TextStyle(
                                  color: Palette.forest,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_outward_rounded,
                          color: Palette.forest,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Center(child: Eyebrow('A living world. A little closer.')),
              const SizedBox(height: 8),
              const Center(
                child: Icon(Icons.spa_outlined, size: 22, color: Palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyTile extends StatelessWidget {
  const _JourneyTile({
    required this.title,
    required this.caption,
    required this.image,
    required this.onTap,
  });
  final String title, caption, image;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: SizedBox(
      width: 185,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                image,
                width: 185,
                height: 137,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 12),
            Eyebrow(caption),
            const SizedBox(height: 5),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 21),
            ),
          ],
        ),
      ),
    ),
  );
}

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({
    super.key,
    this.initialKind = 'all',
    this.focusSearch = false,
  });
  final String initialKind;
  final bool focusSearch;
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final search = TextEditingController();
  late String kind;
  bool map = false;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    kind = widget.initialKind;
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = search.text.trim().toLowerCase();
    final items = state.atlases
        .where(
          (a) =>
              (kind == 'all' || a.kind == kind) &&
              '${a.name} ${a.location} ${a.description}'.toLowerCase().contains(
                query,
              ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find your next chapter'),
        actions: [
          IconButton(
            tooltip: map ? 'List view' : 'Map view',
            onPressed: () => setState(() => map = !map),
            icon: Icon(map ? Icons.view_agenda_outlined : Icons.map_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: TextField(
              controller: search,
              autofocus: widget.focusSearch,
              onChanged: (_) {
                setState(() {});
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 500), () async {
                  while (mounted &&
                      state.moreAtlases &&
                      search.text.trim().isNotEmpty &&
                      !state.loadingAtlases) {
                    await state.loadAtlases();
                    if (state.catalogError != null) break;
                  }
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search cities, universities, and ideas',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                for (final entry in {
                  'all': 'All wikis',
                  'city': 'Cities',
                  'university': 'Universities',
                  'topic': 'Ideas',
                  'person': 'People',
                  'organization': 'Organizations',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: kind == entry.key,
                      onSelected: (_) => setState(() => kind = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: map
                ? AtlasMap(atlases: items)
                : RefreshIndicator(
                    onRefresh: () => state.loadAtlases(refresh: true),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          '${items.length} discoveries${state.moreAtlases ? ' · keep exploring for more' : ''}',
                          style: const TextStyle(
                            color: Palette.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (state.catalogError != null)
                          EmptyState(
                            title: 'Couldn’t load the directory',
                            message: state.catalogError!,
                            action: 'Try again',
                            onAction: () => state.loadAtlases(),
                          ),
                        if (items.isEmpty &&
                            !state.loadingAtlases &&
                            state.catalogError == null)
                          const EmptyState(
                            title: 'The search continues',
                            message: 'Try a different place or topic.',
                          ),
                        LayoutBuilder(
                          builder: (_, c) {
                            final columns = c.maxWidth > 750
                                ? 3
                                : c.maxWidth > 500
                                ? 2
                                : 1;
                            return Wrap(
                              spacing: 18,
                              runSpacing: 20,
                              children: items
                                  .map(
                                    (a) => SizedBox(
                                      width:
                                          (c.maxWidth - (columns - 1) * 18) /
                                          columns,
                                      child: _AtlasTile(atlas: a),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                        if (state.loadingAtlases)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (state.moreAtlases && !state.loadingAtlases)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: OutlinedButton(
                              onPressed: () => state.loadAtlases(),
                              child: const Text('Discover more wikis'),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AtlasTile extends StatelessWidget {
  const _AtlasTile({required this.atlas});
  final Atlas atlas;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: () => openScreen(context, AtlasScreen(atlas: atlas)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.7,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Photo(url: atlas.image, asset: atlas.localImage),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Pill(atlas.kind.toUpperCase(), light: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(atlas.name, style: Theme.of(context).textTheme.titleLarge),
        if (atlas.location.isNotEmpty)
          Text(
            atlas.location,
            style: const TextStyle(color: Palette.muted, fontSize: 12),
          ),
      ],
    ),
  );
}

class AtlasMap extends StatelessWidget {
  const AtlasMap({super.key, required this.atlases});
  final List<Atlas> atlases;
  @override
  Widget build(BuildContext context) => FlutterMap(
    options: const MapOptions(initialCenter: LatLng(26, -25), initialZoom: 2),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.livingwiki.mobile',
      ),
      MarkerLayer(
        markers: atlases
            .where((a) => a.latitude != null && a.longitude != null)
            .map(
              (a) => Marker(
                point: LatLng(a.latitude!, a.longitude!),
                width: 46,
                height: 46,
                child: IconButton(
                  tooltip: a.name,
                  onPressed: () => openScreen(context, AtlasScreen(atlas: a)),
                  icon: const Icon(
                    Icons.location_on,
                    color: Palette.forest,
                    size: 34,
                  ),
                ),
              ),
            )
            .toList(),
      ),
      RichAttributionWidget(
        attributions: [
          TextSourceAttribution(
            'OpenStreetMap contributors',
            onTap: () =>
                openUrl(context, 'https://www.openstreetmap.org/copyright'),
          ),
        ],
      ),
    ],
  );
}
