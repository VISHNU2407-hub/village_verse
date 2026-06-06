import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/guardian_model.dart';

class GuardianAlertService {
  GuardianAlertService._();

  static final GuardianAlertService instance = GuardianAlertService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MethodChannel _emergencyAlertChannel = const MethodChannel(
    'village_verse/emergency_alert',
  );

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _emergencySubscription;
  final Set<String> _alertedEmergencyIds = <String>{};

  Future<void> initialize() async {
    _authSubscription ??= _auth.authStateChanges().listen(
      (user) => unawaited(_startListeningForUser(user)),
    );
    await _startListeningForUser(_auth.currentUser);
  }

  Future<void> _startListeningForUser(User? user) async {
    await _emergencySubscription?.cancel();
    _emergencySubscription = null;
    _alertedEmergencyIds.clear();

    if (user == null) {
      return;
    }

    try {
      final phone = await _currentUserPhone(user);
      final phoneNormalized = normalizePhone(phone);
      if (phoneNormalized.isEmpty) {
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'phoneNormalized': phoneNormalized,
      }, SetOptions(merge: true));

      _emergencySubscription = _firestore
          .collection('emergencies')
          .where('status', isEqualTo: 'active')
          .where('guardianPhonesNormalized', arrayContains: phoneNormalized)
          .snapshots()
          .listen(_handleEmergencySnapshot, onError: _handleListenError);
    } catch (e) {
      debugPrint('Error starting guardian emergency listener: $e');
    }
  }

  Future<String> _currentUserPhone(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    return (data?['phone'] as String?) ?? user.phoneNumber ?? '';
  }

  void _handleEmergencySnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    for (final change in snapshot.docChanges) {
      final emergencyId = change.doc.id;
      if (change.type == DocumentChangeType.removed) {
        _alertedEmergencyIds.remove(emergencyId);
        continue;
      }

      if (!_alertedEmergencyIds.add(emergencyId)) {
        continue;
      }

      final data = change.doc.data();
      if (data != null) {
        unawaited(_showLocalEmergencyAlert(emergencyId, data));
      }
    }
  }

  void _handleListenError(Object error) {
    debugPrint('Guardian emergency listener error: $error');
  }

  Future<void> _showLocalEmergencyAlert(
    String emergencyId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _emergencyAlertChannel.invokeMethod('showEmergencyAlert', {
        'emergencyId': emergencyId,
        'victimUserId': data['userId'] ?? '',
        'victimName': data['userName'] ?? 'Emergency contact',
        'victimPhone': data['userPhone'] ?? '',
        'locationLink': data['locationLink'] ?? '',
        'latitude': data['latitude']?.toString() ?? '',
        'longitude': data['longitude']?.toString() ?? '',
        'startedAtMillis': _startedAtMillis(data['timestamp']),
      });
    } catch (e) {
      debugPrint('Error showing local guardian emergency alert: $e');
    }
  }

  int _startedAtMillis(Object? timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  Map<String, dynamic> buildEmergencyTargetFields(
    List<GuardianModel> guardians,
  ) {
    final guardianPhonesNormalized = guardians
        .map((guardian) => normalizePhone(guardian.phone))
        .where((phone) => phone.isNotEmpty)
        .toSet()
        .toList();

    return {
      'guardianPhonesNormalized': guardianPhonesNormalized,
      'guardianAlertMode': 'firestore_realtime',
      'guardianAlertCreatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _emergencySubscription?.cancel();
    _emergencySubscription = null;
    _alertedEmergencyIds.clear();
  }
}
