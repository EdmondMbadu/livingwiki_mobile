typedef Json = Map<String, dynamic>;

String stringValue(dynamic value, [String fallback = '']) =>
    value is String ? value : fallback;
Json mapValue(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Json> maps(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : [];
List<String> strings(dynamic value) =>
    value is List ? value.whereType<String>().toList() : [];
int intValue(dynamic value) => value is num ? value.toInt() : 0;
String slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Same stable photo URL contract used by the web client. Google photo names expire.
String stablePhotoUrl(String source, {String? placeId, String? boardId}) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.host != 'us-central1-living-atlas-7622a.cloudfunctions.net' ||
      uri.path != '/boardPlacePhoto') {
    return source;
  }
  bool safe(String? value) =>
      value != null && RegExp(r'^[A-Za-z0-9_-]{10,300}$').hasMatch(value);
  final fromName = RegExp(
    r'^places/([^/]+)/photos/',
  ).firstMatch(uri.queryParameters['name'] ?? '')?.group(1);
  final id = safe(placeId)
      ? placeId
      : safe(uri.queryParameters['placeId'])
      ? uri.queryParameters['placeId']
      : safe(fromName)
      ? fromName
      : null;
  if (id != null) {
    return uri.replace(queryParameters: {'placeId': id}).toString();
  }
  final board = boardId ?? uri.queryParameters['boardId'];
  return board != null && RegExp(r'^[A-Za-z0-9_-]{1,180}$').hasMatch(board)
      ? uri.replace(queryParameters: {'boardId': board}).toString()
      : source;
}

String boardCover(Json data, String id) {
  var source = stringValue(data['imageUrl'], stringValue(data['image_url']));
  final cards = maps(data['cards']).where((c) => c['authorOnly'] != true);
  if (source.isEmpty) {
    source =
        cards
            .map((c) => stringValue(c['imageUrl']))
            .where((v) => v.isNotEmpty)
            .firstOrNull ??
        '';
  }
  final match = cards.where((c) => c['imageUrl'] == source).firstOrNull;
  return stablePhotoUrl(
    source,
    placeId: match?['placeId'],
    boardId: data['visibility'] == 'public' || data['visibility'] == 'unlisted'
        ? id
        : null,
  );
}

class Atlas {
  const Atlas({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    this.image = '',
    this.kind = 'city',
    this.region = '',
    this.country = '',
    this.latitude,
    this.longitude,
    this.data = const {},
  });
  final String id, name, slug, description, image, kind, region, country;
  final double? latitude, longitude;
  final Json data;
  factory Atlas.fromJson(String id, Json d) {
    final city = mapValue(d['city_config']);
    final university = mapValue(d['university_config']);
    return Atlas(
      id: id,
      name: stringValue(city['city_name']).isNotEmpty
          ? stringValue(city['city_name'])
          : stringValue(university['official_name']).isNotEmpty
          ? stringValue(university['official_name'])
          : stringValue(d['name']),
      slug: stringValue(d['slug']),
      description: stringValue(
        d['landing_summary'],
        stringValue(d['description']),
      ),
      image: stringValue(d['hero_url']),
      kind: stringValue(d['wiki_type'], 'city'),
      region: stringValue(
        city['region_name'],
        stringValue(university['state']),
      ),
      country: stringValue(
        city['country_code'],
        stringValue(university['country_code']),
      ),
      latitude: ((city['latitude'] ?? university['latitude']) as num?)
          ?.toDouble(),
      longitude: ((city['longitude'] ?? university['longitude']) as num?)
          ?.toDouble(),
      data: d,
    );
  }
  String get localImage => switch (slug) {
    'philadelphia' || 'philly' => 'assets/images/philly-hero.jpg',
    'new-york' ||
    'new-york-city' ||
    'nyc' => 'assets/images/new-york-city-hero.jpg',
    'san-francisco' => 'assets/images/san-francisco-hero.jpg',
    'boston' => 'assets/images/boston-hero.jpg',
    'austin' => 'assets/images/austin-hero.jpg',
    'portland' => 'assets/images/portland-hero.jpg',
    'gainesville' => 'assets/images/gainesville-hero.jpg',
    'guatemala-city' => 'assets/images/guatemala-city-hero.jpg',
    _ => '',
  };
  String get location =>
      [region, country].where((s) => s.isNotEmpty).join(' · ');
}

class WikiCard {
  const WikiCard(this.data);
  final Json data;
  String get id => stringValue(data['id']);
  String get title => stringValue(data['title'], 'Untitled story');
  String get subtitle => stringValue(data['subtitle']);
  String get notes =>
      stringValue(data['notes'], stringValue(data['description']));
  String get image => stablePhotoUrl(
    stringValue(data['imageUrl'], stringValue(data['image_url'])),
    placeId: stringValue(data['placeId']),
  );
  String get type => stringValue(data['type'], 'note');
  String get status => stringValue(data['status'], 'saved');
  String get source => stringValue(data['sourceUrl']);
  String get mapUrl => stringValue(data['googleMapsUrl']);
  String get audio => stringValue(data['audioPreviewUrl']);
  List<String> get tags => strings(data['tags']);
  String get narration => stringValue(data['stackNarration'], notes);
  WikiCard copyWith(Json patch) => WikiCard({...data, ...patch});
}

class Board {
  const Board({
    required this.id,
    required this.title,
    this.description = '',
    this.image = '',
    this.kind = 'standard',
    this.ownerId = '',
    this.ownerName = '',
    this.visibility = 'public',
    this.atlasId = '',
    this.cards = const [],
    this.count = 0,
    this.data = const {},
  });
  final String id,
      title,
      description,
      image,
      kind,
      ownerId,
      ownerName,
      visibility,
      atlasId;
  final List<WikiCard> cards;
  final int count;
  final Json data;
  factory Board.fromJson(String id, Json d) => Board(
    id: stringValue(d['board_id'], id),
    title: stringValue(d['title'], 'Untitled board'),
    description: stringValue(d['description']),
    image: boardCover(d, stringValue(d['board_id'], id)),
    kind: stringValue(d['kind'], 'standard'),
    ownerId: stringValue(d['owner_user_id']),
    ownerName: stringValue(
      d['owner_display_name'],
      stringValue(d['publisher_name'], 'LivingWiki'),
    ),
    visibility: stringValue(d['visibility'], 'public'),
    atlasId: stringValue(d['atlas_id']),
    cards: maps(d['cards']).map(WikiCard.new).toList(),
    count: d['cards'] is List
        ? (d['cards'] as List).length
        : intValue(d['card_count'] ?? d['summaryCardCount']),
    data: d,
  );
  bool get isMusic {
    final sample = cards.take(24).toList();
    if (sample.isEmpty) return false;
    final count = sample
        .where(
          (c) =>
              c.audio.isNotEmpty ||
              stringValue(c.data['spotifyTrackId']).isNotEmpty ||
              stringValue(c.data['spotifyTrackUrl']).isNotEmpty ||
              c.data['mediaKind'] == 'song' ||
              c.tags.any(
                (t) => [
                  'song',
                  'songs',
                  'music-track',
                  'spotify-track',
                ].contains(t.toLowerCase()),
              ),
        )
        .length;
    return count >= (sample.length * .35).ceil();
  }

  String get label => switch (kind) {
    'trip' || 'tour' || 'walking-tour' => 'Walking tour',
    'driving-tour' => 'Driving tour',
    'song' || 'songs' => 'Music',
    'real-estate' || 'property' || 'listing' => 'TalkThru',
    'nearby-gems' => 'Nearby gems',
    _ => 'Story board',
  };
}

class Gem {
  const Gem(this.data);
  final Json data;
  String get id => stringValue(data['id']);
  String get title => stringValue(data['title']);
  String get tip => stringValue(data['tip']);
  String get image =>
      stringValue(data['coverLargeUrl'], stringValue(data['coverUrl']));
  String get creator => stringValue(data['creatorName'], 'A local explorer');
  Json get location => mapValue(data['location']);
  double? get lat => (location['lat'] as num?)?.toDouble();
  double? get lng => (location['lng'] as num?)?.toDouble();
}

class DataPage<T> {
  const DataPage(this.items, {this.cursor, this.hasMore = false});
  final List<T> items;
  final dynamic cursor;
  final bool hasMore;
}

/// Applies the web app's translation segment contract without accepting arbitrary paths.
List<WikiCard> translateCards(List<WikiCard> cards, Json result) {
  final segments = maps(result['segments']);
  if (segments.length != intValue(result['expectedSegmentCount'])) {
    throw StateError('The translation was incomplete. Please try again.');
  }
  final byId = <String, Json>{
    for (final card in cards) card.id: {...card.data},
  };
  final seen = <String>{};
  for (final segment in segments) {
    final key = stringValue(segment['key']);
    if (!seen.add(key)) throw StateError('The translation was incomplete.');
    final match = RegExp(
      r'^cardsById\.([A-Za-z0-9_-]+)\.(title|subtitle|notes|stackNarration|shortSummary)$',
    ).firstMatch(key);
    if (match == null) continue;
    final target = byId[match.group(1)];
    if (target != null && segment['text'] is String) {
      target[match.group(2)!] = segment['text'];
    }
  }
  return cards.map((card) => WikiCard(byId[card.id]!)).toList();
}
