import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'nearby_gems.dart';
import 'package:uuid/uuid.dart';

class LivingRepository {
  LivingRepository({
    FirebaseFirestore? database,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : db = database ?? FirebaseFirestore.instance,
       _functions = functions,
       auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore db;
  final FirebaseFunctions? _functions;
  FirebaseFunctions get functions =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');
  final FirebaseAuth auth;
  String get uid => auth.currentUser?.uid ?? '';
  String requireUser() {
    if (uid.isEmpty) throw StateError('Sign in to continue.');
    return uid;
  }

  Future<Json> call(String name, [Json arguments = const {}]) async {
    final result = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(
            timeout: Duration(
              seconds:
                  name == 'offGridCommand' ||
                      name == 'generateBoardWizardBatch' ||
                      name == 'translateBoard'
                  ? 290
                  : 120,
            ),
          ),
        )
        .call<dynamic>(arguments);
    return mapValue(result.data);
  }

  Future<DataPage<Atlas>> atlases({DocumentSnapshot? cursor}) async {
    Query<Json> query = db
        .collection('atlases')
        .where('is_public', isEqualTo: true)
        .orderBy(FieldPath.documentId)
        .limit(100);
    if (cursor != null) query = query.startAfterDocument(cursor);
    final snapshot = await query.get();
    return DataPage(
      snapshot.docs.map((d) => Atlas.fromJson(d.id, d.data())).toList(),
      cursor: snapshot.docs.lastOrNull,
      hasMore: snapshot.docs.length == 100,
    );
  }

  Future<Atlas?> atlasBySlug(String slug) async {
    final snapshot = await db
        .collection('atlases')
        .where('slug', isEqualTo: slug)
        .where('is_public', isEqualTo: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return Atlas.fromJson(snapshot.docs.first.id, snapshot.docs.first.data());
  }

  Future<Atlas?> atlas(String id) async {
    final doc = await db.collection('atlases').doc(id).get();
    return doc.exists ? Atlas.fromJson(doc.id, doc.data()!) : null;
  }

  Future<List<Atlas>> myAtlases() async {
    final snapshot = await db
        .collection('atlases')
        .where('user_id', isEqualTo: requireUser())
        .limit(100)
        .get();
    return snapshot.docs.map((d) => Atlas.fromJson(d.id, d.data())).toList();
  }

  Future<DataPage<Board>> publicBoards({DocumentSnapshot? cursor}) async {
    Query<Json> query = db
        .collection('public_board_summaries')
        .where('visibility', isEqualTo: 'public')
        .where('is_root', isEqualTo: true)
        .orderBy(FieldPath.documentId)
        .limit(24);
    if (cursor != null) query = query.startAfterDocument(cursor);
    final snapshot = await query.get();
    return DataPage(
      snapshot.docs.map((d) => Board.fromJson(d.id, d.data())).toList(),
      cursor: snapshot.docs.lastOrNull,
      hasMore: snapshot.docs.length == 24,
    );
  }

  Future<List<Board>> cityBoards(String atlasId) async {
    final snapshot = await db
        .collection('city_board_listings')
        .where('atlas_id', isEqualTo: atlasId)
        .limit(250)
        .get();
    final listed = snapshot.docs
        .where(
          (d) =>
              d.data()['visibility'] == 'public' &&
              d.data()['editorial_status'] == 'published' &&
              d.data()['city_listing_status'] == 'listed',
        )
        .toList();
    listed.sort((a, b) {
      final rankA = a.data()['featured_rank'] is num
          ? intValue(a.data()['featured_rank'])
          : 9999;
      final rankB = b.data()['featured_rank'] is num
          ? intValue(b.data()['featured_rank'])
          : 9999;
      if (rankA != rankB) return rankA.compareTo(rankB);
      DateTime date(Json d) {
        final value =
            d['approved_at'] ?? d['updated_at_iso'] ?? d['server_updated_at'];
        return value is Timestamp
            ? value.toDate()
            : DateTime.tryParse(stringValue(value)) ??
                  DateTime.fromMillisecondsSinceEpoch(0);
      }

      final recent = date(b.data()).compareTo(date(a.data()));
      return recent != 0
          ? recent
          : stringValue(a.data()['title']).toLowerCase().compareTo(
              stringValue(b.data()['title']).toLowerCase(),
            );
    });
    return listed.map((d) => Board.fromJson(d.id, d.data())).toList();
  }

  Future<Board> board(String id) async {
    final snapshot = await db.collection('boards').doc(id).get();
    if (!snapshot.exists) {
      throw StateError('This board is no longer available.');
    }
    return Board.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<List<Board>> myBoards() async {
    final snapshot = await db
        .collection('boards')
        .where('owner_user_id', isEqualTo: requireUser())
        .limit(200)
        .get();
    final docs = snapshot.docs.toList()
      ..sort(
        (a, b) => stringValue(
          b.data()['updated_at_iso'],
        ).compareTo(stringValue(a.data()['updated_at_iso'])),
      );
    return docs.map((d) => Board.fromJson(d.id, d.data())).toList();
  }

  Future<List<Board>> savedBoards(Set<String> ids) async {
    if (ids.isEmpty) return [];
    final boards = <Board>[];
    // Deleted/revoked boards are omitted; other saved boards remain available.
    for (final id in ids) {
      try {
        boards.add(await board(id));
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
      } on StateError {
        continue;
      }
    }
    return boards;
  }

  Future<Json> wiki(Atlas atlas) async {
    if (atlas.data['is_public'] == true) {
      return call('getPublicWikiContent', {'atlasId': atlas.id});
    }
    final articles = await db
        .collection('wiki_articles')
        .where('user_id', isEqualTo: requireUser())
        .where('atlas_id', isEqualTo: atlas.id)
        .get();
    final topics = await db
        .collection('wiki_topics')
        .where('user_id', isEqualTo: uid)
        .where('atlas_id', isEqualTo: atlas.id)
        .get();
    return {
      'articles': articles.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      'topics': topics.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    };
  }

  Future<Json> ask(
    Atlas atlas,
    String question, {
    String? threadId,
    String mode = 'wiki',
    required String visitorId,
  }) => call(atlas.data['is_public'] == true ? 'askPublicAtlas' : 'askAtlas', {
    'question': question,
    'atlasId': atlas.id,
    'threadId': threadId,
    'answerMode': mode,
    if (atlas.data['is_public'] == true) 'anonymousVisitorId': visitorId,
  });
  Future<List<Json>> history() async {
    final result = await db
        .collection('chat_threads')
        .where('user_id', isEqualTo: requireUser())
        .orderBy('updated_at', descending: true)
        .limit(50)
        .get();
    return result.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<List<Json>> messages(String threadId) async {
    final result = await db
        .collection('chat_messages')
        .where('user_id', isEqualTo: requireUser())
        .where('thread_id', isEqualTo: threadId)
        .orderBy('created_at')
        .get();
    return result.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<DataPage<Gem>> gems({
    Json? cursor,
    String search = '',
    String scope = 'explore',
  }) async {
    Json response;
    if (scope == 'explore') {
      final uri = Uri.https(
        'us-central1-living-atlas-7622a.cloudfunctions.net',
        '/offGridDirectory',
        {
          if (search.isNotEmpty) 'search': search,
          if (cursor != null) 'id': stringValue(cursor['id']),
          if (cursor != null) 'createdAt': stringValue(cursor['createdAt']),
        },
      );
      final result = await http.get(uri).timeout(const Duration(seconds: 30));
      if (result.statusCode != 200) {
        throw StateError('Unable to load gems. Please try again.');
      }
      response = mapValue(jsonDecode(result.body));
    } else {
      requireUser();
      response = await call('offGridCommand', {
        'action': 'list',
        'spotId': 'directory',
        'scope': scope,
        'cursor': cursor,
        'search': search,
      });
    }
    return DataPage(
      maps(response['items']).map(Gem.new).toList(),
      cursor: response['cursor'],
      hasMore: response['cursor'] != null,
    );
  }

  Future<Gem> gem(String id) async =>
      Gem(await call('offGridCommand', {'action': 'detail', 'spotId': id}));
  Future<void> uploadPinTalk(
    String spotId,
    Uint8List bytes,
    String contentType,
    String caption,
    void Function(double) progress,
  ) async {
    requireUser();
    final ticket = await call('offGridCommand', {
      'action': 'beginUpload',
      'spotId': spotId,
      'kind': 'video',
      'bytes': bytes.length,
      'contentType': contentType,
      'caption': caption,
    });
    final ticketId = stringValue(ticket['ticketId']);
    try {
      const chunk = 8 * 1024 * 1024;
      for (var offset = 0; offset < bytes.length; offset += chunk) {
        final end = (offset + chunk).clamp(0, bytes.length);
        final response = await http
            .put(
              Uri.parse(ticket['uploadUrl']),
              headers: {
                'Content-Type': contentType,
                'Content-Range': 'bytes $offset-${end - 1}/${bytes.length}',
              },
              body: Uint8List.sublistView(bytes, offset, end),
            )
            .timeout(const Duration(seconds: 90));
        if (response.statusCode != 308 &&
            (response.statusCode < 200 || response.statusCode >= 300)) {
          throw StateError('The upload was interrupted. Please try again.');
        }
        progress(end / bytes.length);
      }
      await call('offGridCommand', {
        'action': 'finishUpload',
        'spotId': spotId,
        'ticketId': ticketId,
      });
    } catch (_) {
      try {
        await call('offGridCommand', {
          'action': 'cancelUpload',
          'spotId': spotId,
          'ticketId': ticketId,
        });
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> saveGem(String id, bool saved) async {
    final ref = db
        .collection('users')
        .doc(requireUser())
        .collection('saved_off_grid_spots')
        .doc(id);
    if (saved) {
      await ref.set({'createdAt': DateTime.now().toUtc().toIso8601String()});
    } else {
      await ref.delete();
    }
  }

  Future<Set<String>> savedGemIds() async =>
      (await db
              .collection('users')
              .doc(requireUser())
              .collection('saved_off_grid_spots')
              .get())
          .docs
          .map((d) => d.id)
          .toSet();
  Stream<List<Json>> accountCollection(String name) {
    return db
        .collection('users')
        .doc(requireUser())
        .collection(name)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> markRead(String id) => db
      .collection('users')
      .doc(requireUser())
      .collection('team_notifications')
      .doc(id)
      .update({'read': true});
  Future<Json> profile() async =>
      (await db.collection('users').doc(requireUser()).get()).data() ?? {};
  Future<void> syncProfile() async {
    final user = auth.currentUser!;
    await db.collection('users').doc(user.uid).set({
      'id': user.uid,
      'authUid': user.uid,
      'email': user.email?.trim().toLowerCase(),
      'displayName': user.displayName,
      'emailVerified': user.emailVerified,
      'photoURL': user.photoURL,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'creationTime': user.metadata.creationTime?.toUtc().toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toUtc().toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProfile(String name, {String? city}) async {
    requireUser();
    await auth.currentUser!.updateDisplayName(name.trim());
    await db.collection('users').doc(uid).set({
      'displayName': name.trim(),
      'preferredCitySlug': ?city,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Atlas> createWiki(String name, String description) async {
    final ref = db.collection('atlases').doc();
    final data = {
      'user_id': requireUser(),
      'wiki_type': 'topic',
      'response_perspective': 'auto',
      'name': name.trim(),
      'slug': '${slugify(name)}-${ref.id.substring(0, 6).toLowerCase()}',
      'description': description.trim(),
      'is_public': false,
      'logo_url': null,
      'hero_url': null,
      'video_url': null,
      'cover_color': null,
      'default_answer_mode': 'wiki',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
    await ref.set(data);
    return Atlas.fromJson(ref.id, data);
  }

  Future<List<Json>> documents(Atlas atlas) async {
    if (atlas.data['is_public'] == true) {
      return maps(
        (await call('getPublicAtlasDocuments', {
          'atlasId': atlas.id,
        }))['documents'],
      );
    }
    final result = await db
        .collection('documents')
        .where('user_id', isEqualTo: requireUser())
        .where('atlas_id', isEqualTo: atlas.id)
        .where('visible', isEqualTo: true)
        .get();
    return result.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> uploadDocument(
    Atlas atlas,
    String name,
    String mimeType,
    Uint8List bytes,
    void Function(double) progress,
  ) async {
    requireUser();
    final ticket = await call('prepareDocumentUpload', {
      'filename': name,
      'mimeType': mimeType,
      'fileSize': bytes.length,
      'atlasId': atlas.id,
    });
    final path = stringValue(ticket['storagePath']);
    if (path.isEmpty) throw StateError('The upload could not be prepared.');
    final task = FirebaseStorage.instance
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: mimeType,
            customMetadata: {
              'documentId': stringValue(ticket['documentId']),
              'originalFilename': name,
            },
          ),
        );
    final subscription = task.snapshotEvents.listen(
      (s) =>
          progress(s.totalBytes == 0 ? 0 : s.bytesTransferred / s.totalBytes),
    );
    try {
      await task;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> saveBoard(
    Board? original, {
    required String title,
    required String description,
    required String image,
    required String visibility,
    required String kind,
    required List<WikiCard> cards,
    dynamic tourMeta,
    NearbyGemsDraft? nearbyDraft,
  }) async {
    final user = auth.currentUser;
    requireUser();
    if (original == null && kind == 'nearby-gems') {
      if (nearbyDraft == null ||
          nearbyDraft.ownerId != uid ||
          nearbyDraft.metadata['generationGrantId'] != nearbyDraft.id ||
          visibility != 'private' ||
          cards.isEmpty ||
          cards.any(
            (c) => !nearbyDraft.cards.any((source) => source.id == c.id),
          )) {
        throw StateError('Reopen the nearby gems finder to create this board.');
      }
    } else if (nearbyDraft != null) {
      throw StateError(
        'This discovery can only be saved as a new nearby gems board.',
      );
    }
    if (original != null && original.ownerId != uid) {
      throw StateError('Only the owner can edit this board.');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    if (original != null) {
      // Focused update preserves all fields the native editor does not expose.
      final reference = db.collection('boards').doc(original.id);
      await db.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        if (!snapshot.exists ||
            snapshot.data()?['owner_user_id'] != user!.uid) {
          throw StateError('This board is no longer editable by your account.');
        }
        if (snapshot.data()?['updated_at_iso'] !=
            original.data['updated_at_iso']) {
          throw StateError(
            'This board changed on another device. Reopen it before saving your edits.',
          );
        }
        transaction.update(reference, {
          'title': title,
          'description': description,
          'imageUrl': image,
          'cards': cards.map((c) => c.data).toList(),
          'socialVideoRenderVersion': '',
          'socialLandscapeVideoRenderVersion': '',
          'trailerVideoRenderVersion': '',
          'trailerLandscapeVideoRenderVersion': '',
          'trailerVideoSourceFingerprint': '',
          'studioSaveNonce': 'cards:${DateTime.now().microsecondsSinceEpoch}',
          'updated_at_iso': now,
          'server_updated_at': FieldValue.serverTimestamp(),
        });
      });
      if (original.visibility != visibility) {
        await db.collection('boards').doc(original.id).update({
          'visibility': visibility,
          'updated_at_iso': now,
          'server_updated_at': FieldValue.serverTimestamp(),
        });
      }
      return;
    }
    final ref = db.collection('boards').doc(nearbyDraft?.id);
    final d = <String, dynamic>{
      'id': ref.id,
      'owner_user_id': uid,
      'owner_public_slug':
          '${slugify(user!.displayName ?? 'explorer')}-${uid.substring(0, 6).toLowerCase()}',
      'owner_display_name': user.displayName ?? 'LivingWiki explorer',
      'owner_photo_url': user.photoURL ?? '',
      'owner_profile_icon': '',
      'owner_profile_picture_type': null,
      'visibility': visibility,
      'visibility_schema_version': 1,
      'kind': kind,
      'sortOrder': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'description': description,
      'backNote': '',
      'icon': nearbyDraft == null ? 'dashboard_customize' : 'explore_nearby',
      'tone': nearbyDraft == null ? 'teal' : 'green',
      'imageUrl': image,
      'logoUrl': '',
      'logoLinkUrl': '',
      'stackCtaLabel': '',
      'stackCtaUrl': '',
      'socialVideoUrl': '',
      'socialVideoMimeType': '',
      'socialVideoUpdatedAt': '',
      'socialVideoRatio': 'vertical',
      'socialVideoAudioTrackId': '',
      'socialVideoAudioVolume': .2,
      'socialVideoClosingHeadline': 'Keep exploring',
      'socialVideoClosingMessage': '',
      'socialVideoClosingShowQrCode': true,
      'socialVideoClosingImage': 'cover',
      'socialVideoClosingCustomImageUrl': '',
      'socialVideoClosingDurationSeconds': 5,
      'narrationStyle': 'standard',
      'narrationSecondsPerCard': 30,
      'stickers': [],
      'tourMeta': tourMeta,
      if (nearbyDraft != null) 'nearbyGems': nearbyDraft.metadata,
      'insideCardsDisplay': 'nested',
      'showCardNumbers': true,
      'cards': cards.map((c) => c.data).toList(),
      'created_at_iso': now,
      'updated_at_iso': now,
      'server_updated_at': FieldValue.serverTimestamp(),
    };
    await ref.set(d);
  }

  Future<NearbyGemsDraft> discoverNearbyGems({
    required NearbyRange range,
    required int count,
    String details = '',
    String? manualLocation,
    double? latitude,
    double? longitude,
  }) async {
    final owner = requireUser();
    final id = const Uuid().v4();
    final place = manualLocation?.trim() ?? '';
    if (place.isEmpty &&
        (latitude == null ||
            longitude == null ||
            !latitude.isFinite ||
            !longitude.isFinite ||
            latitude.abs() > 90 ||
            longitude.abs() > 180)) {
      throw StateError('Choose your location or enter a starting place.');
    }
    Json result;
    try {
      result = await call('discoverNearbyGems', {
        'boardId': id,
        'range': range.id,
        'count': count.clamp(4, 16),
        'details': details.trim().substring(
          0,
          details.trim().length.clamp(0, 500),
        ),
        if (place.isNotEmpty)
          'manualLocation': place.substring(0, place.length.clamp(0, 240)),
        if (place.isEmpty) ...{'latitude': latitude, 'longitude': longitude},
      });
    } on FirebaseFunctionsException catch (e) {
      throw StateError(switch (e.code) {
        'not-found' =>
          'No strong matches were found. Try a wider travel range or another starting place.',
        'invalid-argument' =>
          'We could not use that starting place. Try a city, neighborhood, or full address.',
        'resource-exhausted' =>
          'You’ve reached the nearby search limit. Please try again later.',
        'unauthenticated' => 'Sign in again to find nearby gems.',
        'deadline-exceeded' =>
          'The search took too long. Try again or choose another starting place.',
        'failed-precondition' =>
          'Nearby place search is temporarily unavailable. Please try again later.',
        _ =>
          'Nearby gems could not connect. Check your connection and try again.',
      });
    }
    if (uid != owner) {
      throw StateError('Your account changed. Please search again.');
    }
    return NearbyGemsDraft.fromResponse(id, owner, result);
  }

  Future<void> deleteBoard(Board board) async {
    if (board.ownerId != requireUser()) {
      throw StateError('Only the owner can delete this board.');
    }
    await db.collection('boards').doc(board.id).delete();
  }
}
