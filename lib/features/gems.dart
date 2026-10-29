import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models.dart';
import 'auth.dart';
import 'boards.dart';

class GemsScreen extends StatefulWidget {
  const GemsScreen({super.key});
  @override
  State<GemsScreen> createState() => _GemsScreenState();
}

class _GemsScreenState extends State<GemsScreen> {
  final search = TextEditingController();
  List<Gem> gems = [];
  Json? cursor;
  bool busy = true, more = false, map = false;
  String scope = 'explore';
  String? error;
  int run = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load(reset: true));
  }

  Future<void> load({bool reset = false}) async {
    final request = ++run;
    setState(() {
      busy = true;
      error = null;
      if (reset) {
        gems = [];
        cursor = null;
      }
    });
    try {
      final page = await AppScope.of(context).repository.gems(
        cursor: reset ? null : cursor,
        search: search.text.trim(),
        scope: scope,
      );
      if (mounted && run == request) {
        setState(() {
          gems.addAll(page.items);
          cursor = page.cursor == null ? null : mapValue(page.cursor);
          more = page.hasMore;
        });
      }
    } catch (e) {
      if (mounted && run == request) setState(() => error = friendlyError(e));
    } finally {
      if (mounted && run == request) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    run++;
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Off Grids'),
      actions: [
        IconButton(
          tooltip: 'Mark a gem',
          onPressed: () async {
            if (await requireSignIn(context) && context.mounted) {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const GemEditor()),
              );
              if (mounted) load(reset: true);
            }
          },
          icon: const Icon(Icons.add_location_alt_outlined),
        ),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('The good kind of getting lost'),
              const SizedBox(height: 12),
              Text(
                'Some places\nfind you.',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                onSubmitted: (_) => load(reset: true),
                decoration: InputDecoration(
                  hintText: 'Find a hidden gem',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Search gems',
                    onPressed: () => load(reset: true),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in {
                    'explore': 'Explore',
                    'mine': 'My gems',
                    'saved': 'Saved',
                  }.entries)
                    ChoiceChip(
                      selected: scope == entry.key,
                      label: Text(entry.value),
                      onSelected: busy
                          ? null
                          : (_) async {
                              if (entry.key != 'explore' &&
                                  !await requireSignIn(context)) {
                                return;
                              }
                              if (!mounted) return;
                              setState(() => scope = entry.key);
                              load(reset: true);
                            },
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: map
              ? FlutterMap(
                  options: MapOptions(
                    initialCenter:
                        gems.any((g) => g.lat != null && g.lng != null)
                        ? LatLng(
                            gems
                                .firstWhere(
                                  (g) => g.lat != null && g.lng != null,
                                )
                                .lat!,
                            gems
                                .firstWhere(
                                  (g) => g.lat != null && g.lng != null,
                                )
                                .lng!,
                          )
                        : const LatLng(35, -40),
                    initialZoom: 4,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.livingwiki.mobile',
                    ),
                    MarkerLayer(
                      markers: gems
                          .where((g) => g.lat != null && g.lng != null)
                          .map(
                            (g) => Marker(
                              point: LatLng(g.lat!, g.lng!),
                              width: 42,
                              height: 42,
                              child: IconButton(
                                tooltip: g.title,
                                onPressed: () =>
                                    openScreen(context, GemScreen(gemId: g.id)),
                                icon: const Icon(
                                  Icons.location_on,
                                  color: Palette.coral,
                                  size: 32,
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
                          onTap: () => openUrl(
                            context,
                            'https://www.openstreetmap.org/copyright',
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: () => load(reset: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    children: [
                      if (error != null)
                        EmptyState(
                          title: 'A turn in the road',
                          message: error!,
                          action: 'Try again',
                          onAction: () => load(reset: true),
                        ),
                      if (gems.isEmpty && !busy && error == null)
                        const EmptyState(
                          title: 'The path is yours',
                          message:
                              'No gems here yet. Try a new search or mark your own discovery.',
                        ),
                      for (final g in gems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 22),
                          child: InkWell(
                            onTap: () =>
                                openScreen(context, GemScreen(gemId: g.id)),
                            borderRadius: BorderRadius.circular(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: AspectRatio(
                                    aspectRatio: 1.6,
                                    child: Photo(url: g.image),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  g.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                Text(
                                  g.tip,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Palette.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Eyebrow('Found by ${g.creator}'),
                              ],
                            ),
                          ),
                        ),
                      if (busy)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (more && !busy)
                        OutlinedButton(
                          onPressed: load,
                          child: const Text('Follow the trail'),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

class GemScreen extends StatefulWidget {
  const GemScreen({super.key, required this.gemId});
  final String gemId;
  @override
  State<GemScreen> createState() => _GemScreenState();
}

class _GemScreenState extends State<GemScreen> {
  Set<String>? saved;
  bool busy = false;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = AppScope.of(context);
      if (state.user == null) return;
      try {
        final ids = await state.repository.savedGemIds();
        if (mounted) setState(() => saved = ids);
      } catch (_) {}
    });
  }

  double uploadProgress = 0;
  Future<void> addPinTalk(Gem gem) async {
    final state = AppScope.of(context);
    if (!await requireSignIn(context) || !mounted) return;
    final fileResult = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'webm'],
      withData: true,
    );
    if (fileResult == null || !mounted) return;
    final file = fileResult.files.single;
    if (file.bytes == null || file.size > 100 * 1024 * 1024) {
      toast(context, 'Choose a video under 100 MB.');
      return;
    }
    final caption = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add your side of the story'),
        content: TextField(
          controller: caption,
          maxLength: 600,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'A caption for your PinTalk',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, caption.text.trim()),
            child: const Text('Add PinTalk'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 350), caption.dispose);
    if (text == null || !mounted) return;
    setState(() {
      busy = true;
      uploadProgress = 0;
    });
    try {
      await state.repository.uploadPinTalk(
        gem.id,
        file.bytes!,
        file.extension == 'mov'
            ? 'video/quicktime'
            : file.extension == 'webm'
            ? 'video/webm'
            : 'video/mp4',
        text,
        (value) {
          if (mounted) setState(() => uploadProgress = value);
        },
      );
      if (mounted) {
        setState(() => revision++);
        toast(
          context,
          'Your PinTalk is uploaded. It may need the gem owner’s approval.',
        );
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('A local little secret'),
        actions: [
          IconButton(
            tooltip: 'Share gem',
            onPressed: () => shareLink(
              context,
              'A gem on LivingWiki',
              'https://livingwiki.com/off-grids/${widget.gemId}',
            ),
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: AsyncContent<Gem>(
        key: ValueKey(revision),
        load: () => state.repository.gem(widget.gemId),
        builder: (g) => PageBody(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(aspectRatio: 1.25, child: Photo(url: g.image)),
            ),
            const SizedBox(height: 26),
            const Eyebrow('Off the beaten path'),
            const SizedBox(height: 14),
            Text(g.title, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 16),
            Text(g.tip, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 14),
            Text(
              'Found by ${g.creator}',
              style: const TextStyle(color: Palette.muted, fontSize: 12),
            ),
            if (stringValue(g.data['accessNote']).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Surface(
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 14),
                      Expanded(child: Text(stringValue(g.data['accessNote']))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: g.lat == null || g.lng == null
                      ? null
                      : () => openUrl(
                          context,
                          'https://www.google.com/maps/dir/?api=1&destination=${g.lat},${g.lng}',
                        ),
                  icon: const Icon(Icons.directions_outlined),
                  label: const Text('Take me there'),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!await requireSignIn(context)) return;
                          if (!mounted) return;
                          setState(() => busy = true);
                          try {
                            saved ??= await state.repository.savedGemIds();
                            final save = !saved!.contains(g.id);
                            await state.repository.saveGem(g.id, save);
                            if (mounted) {
                              setState(() {
                                if (save) {
                                  saved!.add(g.id);
                                } else {
                                  saved!.remove(g.id);
                                }
                              });
                            }
                          } catch (e) {
                            if (context.mounted) {
                              toast(context, friendlyError(e));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  icon: Icon(
                    saved?.contains(g.id) == true
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                  label: Text(
                    saved?.contains(g.id) == true ? 'Saved' : 'Save gem',
                  ),
                ),
              ],
            ),
            if (g.data['canContribute'] == true)
              MenuRow(
                icon: Icons.add_to_photos_outlined,
                title: 'Add a PinTalk',
                subtitle: 'Share a short glimpse of this place',
                onTap: busy ? null : () => addPinTalk(g),
              ),
            if (busy && uploadProgress > 0)
              LinearProgressIndicator(
                value: uploadProgress < 1 ? uploadProgress : null,
              ),
            if (g.data['ownerUid'] == state.user?.uid)
              MenuRow(
                icon: Icons.edit_outlined,
                title: 'Edit your gem',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => GemEditor(gem: g)),
                  );
                  if (mounted) setState(() => revision++);
                },
              ),
            if (maps(g.data['clips']).isNotEmpty) ...[
              const SectionHeading(
                'PinTalks',
                subtitle: 'A place, through someone else’s eyes.',
              ),
              for (final clip in maps(g.data['clips']))
                MenuRow(
                  icon: Icons.play_circle_outline,
                  title: stringValue(clip['caption'], 'A little glimpse'),
                  subtitle: stringValue(clip['contributorName']),
                  onTap: () => openScreen(
                    context,
                    VideoScreen(
                      url: stringValue(clip['playbackUrl']),
                      title: g.title,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class GemEditor extends StatefulWidget {
  const GemEditor({super.key, this.gem});
  final Gem? gem;
  @override
  State<GemEditor> createState() => _GemEditorState();
}

class _GemEditorState extends State<GemEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, tip, access, latitude, longitude;
  late String id;
  String visibility = 'private';
  Uint8List? photo;
  String extension = 'jpg';
  String? coverTicket, error;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    final g = widget.gem;
    id = g?.id ?? 'gem-${DateTime.now().microsecondsSinceEpoch}';
    title = TextEditingController(text: g?.title);
    tip = TextEditingController(text: g?.tip);
    access = TextEditingController(text: stringValue(g?.data['accessNote']));
    latitude = TextEditingController(text: g?.lat?.toString());
    longitude = TextEditingController(text: g?.lng?.toString());
    visibility = stringValue(g?.data['visibility'], 'private');
    if (visibility == 'unlisted') visibility = 'private';
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || busy) return;
    if (visibility == 'public' &&
        photo == null &&
        widget.gem?.data['cover'] != true) {
      setState(() => error = 'Add a cover photo before publishing your gem.');
      return;
    }
    final repo = AppScope.of(context).repository;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.gem == null) {
        await repo.call('offGridCommand', {'action': 'draft', 'spotId': id});
      }
      if (photo != null) {
        final mime = extension == 'jpg' || extension == 'jpeg'
            ? 'image/jpeg'
            : 'image/$extension';
        final ticket = await repo.call('offGridCommand', {
          'action': 'beginUpload',
          'spotId': id,
          'kind': 'cover',
          'bytes': photo!.length,
          'contentType': mime,
        });
        coverTicket = stringValue(ticket['ticketId']);
        final response = await http
            .put(
              Uri.parse(ticket['uploadUrl']),
              headers: {
                'Content-Type': mime,
                'Content-Range':
                    'bytes 0-${photo!.length - 1}/${photo!.length}',
              },
              body: photo,
            )
            .timeout(const Duration(seconds: 90));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError('The photo upload was interrupted. Try again.');
        }
        await repo.call('offGridCommand', {
          'action': 'finishUpload',
          'spotId': id,
          'ticketId': coverTicket,
        });
      }
      await repo.call('offGridCommand', {
        'action': 'save',
        'spotId': id,
        'title': title.text.trim(),
        'tip': tip.text.trim(),
        'accessNote': access.text.trim(),
        'visibility': visibility,
        'status': 'active',
        'allowContributions': true,
        if (coverTicket != null) 'coverTicketId': coverTicket,
        'location': {
          'lat': double.parse(latitude.text),
          'lng': double.parse(longitude.text),
          'source': 'coordinates',
          'confirmedAt': DateTime.now().toUtc().toIso8601String(),
        },
      });
      if (mounted) {
        toast(context, 'Your gem is on the map.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [title, tip, access, latitude, longitude]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mark a gem')),
    body: PageBody(
      children: [
        const Eyebrow('Good things deserve to be found'),
        const SizedBox(height: 14),
        Text(
          'You know a place.',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: title,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Name this little discovery',
                ),
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Give it a name.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: tip,
                minLines: 4,
                maxLines: 8,
                maxLength: 1600,
                decoration: const InputDecoration(
                  labelText: 'What makes it special?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: access,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Anything visitors should know?',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final point = await Navigator.push<LatLng>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GemLocationPicker(
                              initial:
                                  double.tryParse(latitude.text) != null &&
                                      double.tryParse(longitude.text) != null
                                  ? LatLng(
                                      double.parse(latitude.text),
                                      double.parse(longitude.text),
                                    )
                                  : null,
                            ),
                          ),
                        );
                        if (point != null && mounted) {
                          setState(() {
                            latitude.text = point.latitude.toStringAsFixed(6);
                            longitude.text = point.longitude.toStringAsFixed(6);
                          });
                        }
                      },
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  latitude.text.isEmpty
                      ? 'Pin the spot on the map'
                      : 'Location pinned · adjust on map',
                ),
              ),
              ExpansionTile(
                title: const Text(
                  'Use exact coordinates',
                  style: TextStyle(fontSize: 12),
                ),
                maintainState: true,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: latitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return n == null || !n.isFinite || n < -90 || n > 90
                                ? 'Use −90 to 90.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: longitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                          validator: (v) {
                            final n = double.tryParse(v ?? '');
                            return n == null ||
                                    !n.isFinite ||
                                    n < -180 ||
                                    n > 180
                                ? 'Use −180 to 180.'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                          withData: true,
                        );
                        if (result == null || !context.mounted) return;
                        final file = result.files.single;
                        if (file.size > 10 * 1024 * 1024 ||
                            file.bytes == null) {
                          toast(context, 'Choose a photo under 10 MB.');
                          return;
                        }
                        setState(() {
                          photo = file.bytes;
                          extension = file.extension ?? 'jpg';
                        });
                      },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  photo == null ? 'Add a cover photo' : 'Change cover photo',
                ),
              ),
              if (photo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      photo!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: visibility,
                decoration: const InputDecoration(
                  labelText: 'Who can discover it?',
                ),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('Only me')),
                  DropdownMenuItem(value: 'public', child: Text('Everyone')),
                ],
                onChanged: busy ? null : (v) => setState(() => visibility = v!),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: BusyButton(
                  busy: busy,
                  label: 'Keep this gem',
                  onPressed: save,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GemLocationPicker extends StatefulWidget {
  const GemLocationPicker({super.key, this.initial});
  final LatLng? initial;
  @override
  State<GemLocationPicker> createState() => _GemLocationPickerState();
}

class _GemLocationPickerState extends State<GemLocationPicker> {
  LatLng? selected;
  @override
  void initState() {
    super.initState();
    selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Put a little wonder on the map')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Zoom in, then tap the place you want to remember.',
            style: TextStyle(color: Palette.muted),
          ),
        ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: selected ?? const LatLng(25, -25),
              initialZoom: selected == null ? 2 : 14,
              onTap: (_, point) => setState(() => selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.livingwiki.mobile',
              ),
              if (selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selected!,
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: Palette.coral,
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
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                icon: const Icon(Icons.check),
                label: const Text('This is the spot'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
