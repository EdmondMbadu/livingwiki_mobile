import 'package:flutter_test/flutter_test.dart';
import 'package:livingwiki_mobile/data/models.dart';

void main() {
  test('full boards and projected summaries share one model', () {
    final full = Board.fromJson('a', {
      'title': 'Full',
      'cards': [
        {'id': 'c', 'title': 'Card'},
      ],
      'owner_user_id': 'u',
      'imageUrl': 'https://example.test/a.jpg',
    });
    final summary = Board.fromJson('projection', {
      'board_id': 'a',
      'title': 'Summary',
      'card_count': 12,
      'image_url': 'https://example.test/b.jpg',
      'publisher_name': 'Curator',
    });
    expect(full.count, 1);
    expect(full.cards.single.id, 'c');
    expect(summary.id, 'a');
    expect(summary.count, 12);
    expect(summary.ownerName, 'Curator');
  });
  test('translation applies only supported fields and matching card IDs', () {
    const source = [
      WikiCard({
        'id': 'one',
        'title': 'Hello',
        'notes': 'Original',
        'imageUrl': 'https://example.test/real.jpg',
      }),
    ];
    final translated = translateCards(source, {
      'expectedSegmentCount': 4,
      'segments': [
        {'key': 'cardsById.one.title', 'text': 'Bonjour'},
        {'key': 'cardsById.one.notes', 'text': 'Une histoire'},
        {'key': 'cardsById.one.imageUrl', 'text': 'bad'},
        {'key': 'cardsById.missing.title', 'text': 'Missing'},
      ],
    });
    expect(translated.single.title, 'Bonjour');
    expect(translated.single.notes, 'Une histoire');
    expect(translated.single.image, source.single.image);
    expect(source.single.title, 'Hello');
  });
  test('incomplete and duplicate translation segments fail visibly', () {
    expect(
      () => translateCards([], {'expectedSegmentCount': 1, 'segments': []}),
      throwsStateError,
    );
    expect(
      () => translateCards([], {
        'expectedSegmentCount': 2,
        'segments': [
          {'key': 'a', 'text': 'a'},
          {'key': 'a', 'text': 'b'},
        ],
      }),
      throwsStateError,
    );
  });
  test('university coordinates and location use university configuration', () {
    final a = Atlas.fromJson('university', {
      'name': 'College',
      'wiki_type': 'university',
      'university_config': {
        'latitude': 40,
        'longitude': -75,
        'state': 'PA',
        'country_code': 'US',
      },
    });
    expect(a.latitude, 40);
    expect(a.longitude, -75);
    expect(a.location, 'PA · US');
  });

  test('expired place photo names become stable references', () {
    const url =
        'https://us-central1-living-atlas-7622a.cloudfunctions.net/boardPlacePhoto?name=places/ChIJ1234567890/photos/expired';
    expect(Uri.parse(stablePhotoUrl(url)).queryParameters, {
      'placeId': 'ChIJ1234567890',
    });
    expect(
      stablePhotoUrl('https://example.test/photo.jpg'),
      'https://example.test/photo.jpg',
    );
  });
  test('board cover fallback never selects an author-only card', () {
    final b = Board.fromJson('board', {
      'visibility': 'public',
      'cards': [
        {
          'id': 'secret',
          'imageUrl': 'https://example.test/private.jpg',
          'authorOnly': true,
        },
        {'id': 'public', 'imageUrl': 'https://example.test/public.jpg'},
      ],
    });
    expect(b.image, 'https://example.test/public.jpg');
  });
}
