import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/hospital_model.dart';

class HospitalService {
  static const List<String> andhraPradeshDistricts = [
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

  static Future<List<Hospital>> loadHospitalsByDistrict(String district) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/hospitals/$district.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;

      final hospitals = <Hospital>[];
      for (final item in jsonData) {
        final hospital = Hospital.fromJson(item as Map<String, dynamic>);
        if (hospital.hasValidCoordinates) {
          hospitals.add(hospital);
        }
      }

      return hospitals;
    } catch (e) {
      return [];
    }
  }

  static Future<List<Hospital>> getNearestHospitals(
    double userLat,
    double userLng,
    String district,
  ) async {
    final hospitals = await loadHospitalsByDistrict(district);

    for (final hospital in hospitals) {
      final distanceInMeters = Geolocator.distanceBetween(
        userLat,
        userLng,
        hospital.latitude,
        hospital.longitude,
      );
      hospital.distanceKm = double.parse(
        (distanceInMeters / 1000).toStringAsFixed(1),
      );
    }

    hospitals.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return hospitals;
  }

  static String formatDistance(double distanceKm) {
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}
