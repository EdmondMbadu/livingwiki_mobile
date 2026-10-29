import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

enum NearbyRange {
  walk('walk', 'On foot', 'Up to a 30-minute walk', 'Within about 2 miles'),
  quickDrive(
    'quick-drive',
    'Quick drive',
    'Up to a 10-minute drive',
    'Within about 10 miles',
  ),
  adventure(
    'adventure',
    'A little adventure',
    'Up to a 20-minute drive',
    'Within about 20 miles',
  );

  const NearbyRange(this.id, this.label, this.description, this.radius);
  final String id, label, description, radius;
}

class NearbyGemsDraft {
  const NearbyGemsDraft({
    required this.id,
    required this.ownerId,
    required this.board,
    required this.cards,
  });
  final String id, ownerId;
  final Json board;
  final List<WikiCard> cards;
  Json get metadata => mapValue(board['nearbyGems']);
  String get location => stringValue(metadata['locationLabel'], 'your area');
  factory NearbyGemsDraft.fromResponse(String id, String ownerId, Json result) {
    final board = mapValue(result['board']);
    final meta = mapValue(board['nearbyGems']);
    if (board['kind'] != 'nearby-gems' ||
        meta['generationGrantId'] != id ||
        meta['originStored'] != false ||
        !NearbyRange.values.any((r) => r.id == meta['range']) ||
        !['walking', 'driving'].contains(meta['travelMode']) ||
        !['travel-time', 'distance'].contains(meta['defaultSort']) ||
        stringValue(meta['locationLabel']).isEmpty ||
        stringValue(meta['locationLabel']).length > 120 ||
        stringValue(meta['generatedAt']).isEmpty) {
      throw StateError(
        'Nearby gems returned an incomplete board. Please try again shortly.',
      );
    }
    final cards = maps(
      result['cards'],
    ).map((c) => WikiCard({...c, 'id': const Uuid().v4()})).toList();
    if (cards.isEmpty) {
      throw StateError(
        'No gems found. Try a wider range or a different starting place.',
      );
    }
    return NearbyGemsDraft(
      id: id,
      ownerId: ownerId,
      board: board,
      cards: cards,
    );
  }
}

LatLng? nearbyPoint(WikiCard card) {
  final lat = card.data['locationLat'], lng = card.data['locationLng'];
  if (lat is! num ||
      lng is! num ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180) {
    return null;
  }
  return LatLng(lat.toDouble(), lng.toDouble());
}

List<WikiCard> sortNearbyCards(List<WikiCard> cards, String sort) {
  double value(WikiCard c, String key) {
    final n = mapValue(c.data['nearby'])[key];
    return n is num && n.isFinite && n >= 0 ? n.toDouble() : double.infinity;
  }

  final result = [...cards];
  final primary = sort == 'distance' ? 'distanceMeters' : 'durationSeconds';
  final secondary = sort == 'distance' ? 'durationSeconds' : 'distanceMeters';
  result.sort((a, b) {
    var v = value(a, primary).compareTo(value(b, primary));
    if (v == 0) v = value(a, secondary).compareTo(value(b, secondary));
    if (v == 0) v = cards.indexOf(a).compareTo(cards.indexOf(b));
    return v;
  });
  return result;
}

String nearbyTravelLabel(WikiCard card, {required bool walking}) {
  final meta = mapValue(card.data['nearby']);
  final seconds = meta['durationSeconds'];
  final meters = meta['distanceMeters'];
  final parts = <String>[];
  if (meta['measurement'] != 'route') parts.add('Est.');
  if (seconds is num && seconds.isFinite && seconds > 0) {
    parts.add(
      '${(seconds / 60).round().clamp(1, 9999)} min ${walking ? 'walk' : 'drive'}',
    );
  }
  if (meters is num && meters.isFinite && meters > 0) {
    parts.add('${(meters / 1609.344).toStringAsFixed(1)} mi');
  }
  return parts.isEmpty || (parts.length == 1 && parts.first == 'Est.')
      ? 'Nearby · travel time unavailable'
      : parts.join(' · ');
}

String nearbyDirections(WikiCard card, bool walking) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': nearbyPoint(card) == null
          ? card.title
          : '${nearbyPoint(card)!.latitude},${nearbyPoint(card)!.longitude}',
      if (stringValue(card.data['placeId']).isNotEmpty)
        'destination_place_id': stringValue(card.data['placeId']),
      'travelmode': walking ? 'walking' : 'driving',
    }).toString();
