import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livingwiki_mobile/data/models.dart';
import 'package:livingwiki_mobile/data/repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late LivingRepository repo;
  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(
      mockUser: MockUser(
        uid: 'test-user',
        displayName: 'Test Explorer',
        email: 'test@example.test',
      ),
      signedIn: true,
    );
    repo = LivingRepository(database: db, auth: auth);
  });
  test(
    'discovery never returns private atlases or non-root/private summaries',
    () async {
      await db.collection('atlases').doc('public').set({
        'name': 'Public',
        'is_public': true,
      });
      await db.collection('atlases').doc('private').set({
        'name': 'Private',
        'is_public': false,
      });
      expect((await repo.atlases()).items.map((a) => a.id), ['public']);
      for (final d in [
        {'id': 'root', 'visibility': 'public', 'is_root': true},
        {'id': 'child', 'visibility': 'public', 'is_root': false},
        {'id': 'private', 'visibility': 'private', 'is_root': true},
      ]) {
        await db
            .collection('public_board_summaries')
            .doc(d['id'] as String)
            .set(d);
      }
      expect((await repo.publicBoards()).items.map((a) => a.id), ['root']);
    },
  );
  test(
    'city stories require the same published and listed state as the web app',
    () async {
      for (final d in [
        {
          'id': 'a',
          'editorial_status': 'published',
          'city_listing_status': 'listed',
        },
        {
          'id': 'b',
          'editorial_status': 'draft',
          'city_listing_status': 'listed',
        },
        {
          'id': 'c',
          'editorial_status': 'published',
          'city_listing_status': 'unlisted',
        },
      ]) {
        await db.collection('city_board_listings').doc(d['id']!).set({
          ...d,
          'atlas_id': 'city',
          'visibility': 'public',
          'board_id': d['id'],
        });
      }
      expect((await repo.cityBoards('city')).map((b) => b.id), ['a']);
    },
  );
  test(
    'board editing preserves server and media fields and never changes ownership',
    () async {
      await db.collection('boards').doc('mine').set({
        'id': 'mine',
        'title': 'Before',
        'owner_user_id': 'test-user',
        'visibility': 'unlisted',
        'cards': [],
        'custom_slug': 'my-story',
        'conversation': {'important': true},
        'generated_for_atlas_id': 'keep',
        'socialVideoUrl': 'https://example.test/video.mp4',
      });
      final original = await repo.board('mine');
      await repo.saveBoard(
        original,
        title: 'After',
        description: 'A story',
        image: '',
        visibility: 'unlisted',
        kind: 'standard',
        cards: [
          const WikiCard({
            'id': 'card-1',
            'title': 'One',
            'notes': 'Words',
            'status': 'favorite',
          }),
        ],
      );
      final result = (await db.collection('boards').doc('mine').get()).data()!;
      expect(result['title'], 'After');
      expect(result['owner_user_id'], 'test-user');
      expect(result['custom_slug'], 'my-story');
      expect(result['conversation'], {'important': true});
      expect(result['generated_for_atlas_id'], 'keep');
      expect(result['socialVideoUrl'], 'https://example.test/video.mp4');
      expect(result['socialVideoRenderVersion'], '');
      expect(result['cards'][0]['status'], 'favorite');
    },
  );
  test('owner guard rejects another user’s edits and deletion', () async {
    const other = Board(id: 'other', title: 'Other', ownerId: 'someone-else');
    expect(
      () => repo.saveBoard(
        other,
        title: 'Bad',
        description: '',
        image: '',
        visibility: 'public',
        kind: 'standard',
        cards: [],
      ),
      throwsStateError,
    );
    expect(() => repo.deleteBoard(other), throwsStateError);
  });
  test('new boards use the web schema and explicit audience', () async {
    await repo.saveBoard(
      null,
      title: 'A first board',
      description: 'Hello',
      image: '',
      visibility: 'unlisted',
      kind: 'standard',
      cards: [],
    );
    final d = (await db.collection('boards').get()).docs.single.data();
    expect(d['owner_user_id'], 'test-user');
    expect(d['visibility'], 'unlisted');
    expect(d['visibility_schema_version'], 1);
    expect(d['cards'], isEmpty);
    expect(
      d['owner_public_slug'],
      matches(RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$')),
    );
    expect(d.containsKey('ownerUserId'), isFalse);
    expect(d.containsKey('createdAt'), isFalse);
    expect(d['server_updated_at'], isNotNull);
    const fixturePath = String.fromEnvironment('EXPORT_BOARD_FIXTURE');
    if (fixturePath.isNotEmpty) {
      File(fixturePath).writeAsStringSync(
        jsonEncode(
          d,
          toEncodable: (v) =>
              v is Timestamp ? v.toDate().toIso8601String() : null,
        ),
      );
    }
  });
  test('guest cannot create or query personal content', () async {
    await auth.signOut();
    expect(() => repo.myBoards(), throwsStateError);
    expect(() => repo.myAtlases(), throwsStateError);
    expect(
      () => repo.saveBoard(
        null,
        title: 'No',
        description: '',
        image: '',
        visibility: 'public',
        kind: 'standard',
        cards: [],
      ),
      throwsStateError,
    );
  });
}
