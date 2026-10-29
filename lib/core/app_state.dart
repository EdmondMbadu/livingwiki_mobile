import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models.dart';
import '../data/repository.dart';

class AppState extends ChangeNotifier {
  AppState(this.repository, this.preferences) {
    dark = preferences.getBool('dark') ?? false;
    visitorId =
        preferences.getString('visitorId') ??
        'mobile-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
    unawaited(preferences.setString('visitorId', visitorId));
    user = repository.auth.currentUser;
    _loadSaved();
    _authSubscription = repository.auth.userChanges().listen((value) {
      final changed = user?.uid != value?.uid;
      user = value;
      if (changed) {
        _loadSaved();
        profile = {};
        selectedAtlas = null;
      }
      notifyListeners();
      if (value != null) unawaited(_refreshProfile(value.uid));
    });
  }
  final LivingRepository repository;
  final SharedPreferences preferences;
  StreamSubscription<User?>? _authSubscription;
  User? user;
  Json profile = {};
  List<Atlas> atlases = [];
  dynamic atlasCursor;
  bool moreAtlases = true, loadingAtlases = false;
  String? catalogError;
  Atlas? selectedAtlas;
  Set<String> saved = {};
  late String visitorId;
  bool dark = false;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  String get name {
    final value = user?.displayName?.trim() ?? '';
    return value.isEmpty ? 'explorer' : value.split(' ').first;
  }

  String get _saveKey => 'lw-board-actions:${user?.uid ?? 'guest'}';
  void _loadSaved() {
    saved = (preferences.getStringList(_saveKey) ?? []).toSet();
  }

  Future<void> _refreshProfile(String uid) async {
    try {
      await repository.syncProfile();
      final data = await repository.profile();
      if (user?.uid == uid) {
        profile = data;
        notifyListeners();
      }
    } catch (_) {
      /* Auth remains usable when the profile service is offline. */
    }
  }

  Future<void> loadAtlases({bool refresh = false}) async {
    if (loadingAtlases || (!refresh && !moreAtlases)) return;
    loadingAtlases = true;
    catalogError = null;
    notifyListeners();
    try {
      final page = await repository.atlases(
        cursor: refresh ? null : atlasCursor,
      );
      final all = refresh ? page.items : [...atlases, ...page.items];
      atlases = {for (final atlas in all) atlas.id: atlas}.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      atlasCursor = page.cursor;
      moreAtlases = page.hasMore;
    } catch (e) {
      catalogError = friendlyError(e);
    } finally {
      loadingAtlases = false;
      notifyListeners();
    }
  }

  Future<void> toggleSaved(String id) async {
    final key = _saveKey;
    final before = {...saved};
    saved = {...saved};
    if (!saved.add(id)) saved.remove(id);
    notifyListeners();
    try {
      final success = await preferences.setStringList(key, saved.toList());
      if (!success) throw StateError('Could not save on this device.');
    } catch (_) {
      if (key == _saveKey) {
        saved = before;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> setDark(bool value) async {
    dark = value;
    notifyListeners();
    await preferences.setBool('dark', value);
  }

  void selectAtlas(Atlas atlas) {
    selectedAtlas = atlas;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'The email or password is incorrect.',
      'email-already-in-use' =>
        'An account already uses this email. Try signing in.',
      'weak-password' => 'Choose a password with at least 8 characters.',
      'invalid-email' => 'Enter a valid email address.',
      'too-many-requests' => 'Please wait a moment before trying again.',
      'network-request-failed' => 'Check your connection and try again.',
      'requires-recent-login' => 'Sign in again before changing this account.',
      'operation-not-allowed' =>
        'This sign-in method is not enabled yet. Use email to continue.',
      _ => error.message ?? 'Unable to sign in. Please try again.',
    };
  }
  if (error is StateError) return error.message.toString();
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Your account does not have access to this. Check your membership or sign in again.';
  }
  if (text.contains('resource-exhausted')) {
    return 'You have reached the current limit. Please try again later.';
  }
  if (text.contains('unavailable') ||
      text.contains('network') ||
      text.contains('TimeoutException')) {
    return 'We could not connect. Check your connection and try again.';
  }
  if (text.contains('failed-precondition')) {
    return 'This action needs an active membership or an updated account. Check your account on LivingWiki.';
  }
  return 'Something went wrong. Please try again.';
}
