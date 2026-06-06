import 'dart:convert';
import 'package:flutter/services.dart';

class MandalDataService {
  static List<String>? _cachedMandals;

  static Future<List<String>> loadMandals() async {
    if (_cachedMandals != null) {
      return _cachedMandals!;
    }

    try {
      final String jsonString = await rootBundle.loadString('assets/data/andhra_pradesh.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      final List<String> mandals = [];

      if (data.containsKey('districts')) {
        final List<dynamic> districts = data['districts'];
        
        for (var district in districts) {
          if (district.containsKey('subDistricts')) {
            final List<dynamic> subDistricts = district['subDistricts'];
            
            for (var subDistrict in subDistricts) {
              if (subDistrict.containsKey('subDistrict')) {
                mandals.add(subDistrict['subDistrict'].toString());
              }
            }
          }
        }
      }

      // Remove duplicates and sort alphabetically
      final uniqueMandals = mandals.toSet().toList();
      uniqueMandals.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      _cachedMandals = uniqueMandals;
      return uniqueMandals;
    } catch (e) {
      throw Exception('Failed to load mandal data: $e');
    }
  }

  static List<String> filterMandals(String query, List<String> mandals) {
    if (query.isEmpty) {
      return mandals;
    }

    final lowerQuery = query.toLowerCase();
    return mandals
        .where((mandal) => mandal.toLowerCase().contains(lowerQuery))
        .toList();
  }

  static void clearCache() {
    _cachedMandals = null;
  }
}
