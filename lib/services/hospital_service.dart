import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/hospital_model.dart';

class HospitalService {
  static const List<String> _allDistricts = [
    'anantapuramu',
    'chittoor',
    'east_godavari',
    'guntur',
    'kakinada',
    'krishna',
    'kurnool',
    'nandyal',
    'prakasam',
    'spsr_nellore',
    'srikakulam',
    'tirupati',
    'visakhapatnam',
    'vizianagaram',
    'west_godavari',
    'ysr_kadapa',
  ];

  /// Exposed for display purposes (e.g., to show district names in filters).
  static List<String> get allDistricts => List.unmodifiable(_allDistricts);

  // ── In-memory cache ──

  static List<Hospital>? _cachedAllHospitals;
  static bool _isLoadingCache = false;
  static Completer<void>? _cacheCompleter;

  /// Loads & caches all hospitals from every district JSON asset.
  ///
  /// Subsequent calls return the cached list instantly. Concurrent calls
  /// during an in-flight load share the same [Future] so the work is
  /// only done once.
  static Future<List<Hospital>> loadAllHospitals() async {
    if (_cachedAllHospitals != null) return _cachedAllHospitals!;

    if (_isLoadingCache) {
      await _cacheCompleter?.future;
      return _cachedAllHospitals!;
    }

    _isLoadingCache = true;
    _cacheCompleter = Completer<void>();

    try {
      final all = <Hospital>[];
      for (final district in _allDistricts) {
        try {
          final jsonString = await rootBundle.loadString(
            'assets/data/hospitals/$district.json',
          );
          final List<dynamic> jsonData =
              json.decode(jsonString) as List<dynamic>;

          for (final item in jsonData) {
            final hospital =
                Hospital.fromJson(item as Map<String, dynamic>);
            if (hospital.hasValidCoordinates) {
              all.add(hospital);
            }
          }
        } catch (e) {
          // Log but continue — a single district failure should not
          // prevent showing results from other districts.
          debugPrint('HospitalService: failed to load district '
              '$district: $e');
        }
      }

      _cachedAllHospitals = all;
      return all;
    } finally {
      _isLoadingCache = false;
      _cacheCompleter?.complete();
    }
  }

  /// Returns all hospitals sorted by distance from [userLat]/[userLng],
  /// nearest first.
  ///
  /// Hospitals are loaded from the in-memory cache (populated on first
  /// call) and distances are computed on every invocation so that the
  /// sort reflects the user's current GPS fix.
  static Future<List<Hospital>> getNearestHospitals(
    double userLat,
    double userLng,
  ) async {
    final hospitals = await loadAllHospitals();

    for (final hospital in hospitals) {
      final distanceInMeters = Geolocator.distanceBetween(
        userLat,
        userLng,
        hospital.latitude,
        hospital.longitude,
      );
      hospital.distanceKm =
          double.parse((distanceInMeters / 1000).toStringAsFixed(1));
    }

    hospitals.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return hospitals;
  }

  /// Formats a distance value in km for display.
  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Clears the in-memory cache (useful for testing or data refresh).
  static void clearCache() {
    _cachedAllHospitals = null;
    _isLoadingCache = false;
    _cacheCompleter = null;
  }
}
