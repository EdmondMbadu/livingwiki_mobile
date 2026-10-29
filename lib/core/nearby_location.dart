import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class NearbyLocationFailure implements Exception {
  const NearbyLocationFailure(
    this.message, {
    this.settings = false,
    this.serviceSettings = false,
  });
  final String message;
  final bool settings, serviceSettings;
  @override
  String toString() => message;
}

class NearbyLocation {
  Future<Position> current() async {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      throw const NearbyLocationFailure(
        'Location services are off. Turn them on, or enter a starting place.',
        serviceSettings: true,
      );
    }
    // On the web, getCurrentPosition both prompts and enforces the timeout.
    // A separate requestPermission performs an unbounded position lookup.
    if (!kIsWeb) {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw NearbyLocationFailure(
          'Location access is blocked. Allow it in settings, or enter a starting place.',
          settings: !kIsWeb,
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw const NearbyLocationFailure(
          'Location access was not allowed. Enter a city, neighborhood, or address instead.',
        );
      }
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on TimeoutException {
      throw const NearbyLocationFailure(
        'Finding your location took too long. Try again, or enter a starting place.',
      );
    } on LocationServiceDisabledException {
      throw const NearbyLocationFailure(
        'Location services are off. Enter a starting place instead.',
        serviceSettings: true,
      );
    } on PermissionDeniedException {
      throw const NearbyLocationFailure(
        'Location access was not allowed. Enter a starting place instead.',
      );
    } catch (_) {
      throw const NearbyLocationFailure(
        'Your location could not be determined. Enter a starting place instead.',
      );
    }
  }

  Future<bool> openSettings({bool service = false}) => service
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
