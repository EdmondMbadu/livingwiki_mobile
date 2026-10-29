import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livingwiki_mobile/data/repository.dart';

void main() {
  test('a stale board editor cannot overwrite newer web edits', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      mockUser: MockUser(uid: 'owner-user'),
      signedIn: true,
    );
    final repo = LivingRepository(database: db, auth: auth);
    await db.collection('boards').doc('board').set({
      'owner_user_id': 'owner-user',
      'title': 'Original',
      'visibility': 'unlisted',
      'updated_at_iso': 'first',
      'cards': [],
    });
    final original = await repo.board('board');
    await db.collection('boards').doc('board').update({
      'title': 'New web edit',
      'updated_at_iso': 'second',
    });
    expect(
      () => repo.saveBoard(
        original,
        title: 'Stale edit',
        description: '',
        image: '',
        visibility: 'unlisted',
        kind: 'standard',
        cards: [],
      ),
      throwsStateError,
    );
    expect(
      (await db.collection('boards').doc('board').get()).data()!['title'],
      'New web edit',
    );
  });
}
