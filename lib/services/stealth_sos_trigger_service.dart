import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sos_service.dart';

class StealthSOSTriggerService {
  StealthSOSTriggerService._();

  static final StealthSOSTriggerService instance = StealthSOSTriggerService._();

  static const MethodChannel _channel = MethodChannel(
    'village_verse/stealth_sos_trigger',
  );

  final SOSService _sosService = SOSService();
  bool _isInitialized = false;
  bool _isActivating = false;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _channel.setMethodCallHandler(_handleMethodCall);
    _isInitialized = true;

    try {
      await _channel.invokeMethod('startPowerButtonWatcher');
    } catch (e) {
      debugPrint('Error starting stealth SOS watcher: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'activateStealthSOS':
        return _activateStealthSOS();
      default:
        throw MissingPluginException(call.method);
    }
  }

  Future<bool> _activateStealthSOS() async {
    if (_isActivating || _sosService.isEmergencyActive) {
      return false;
    }

    _isActivating = true;
    try {
      final result = await _sosService.activateSOS(
        silent: true,
        playGuardianEmergencyCall: false,
      );
      if (!result.success) {
        debugPrint('Stealth SOS activation failed: ${result.error}');
      }
      return result.success;
    } catch (e) {
      debugPrint('Error activating stealth SOS: $e');
      return false;
    } finally {
      _isActivating = false;
    }
  }

  Future<void> dispose() async {
    _sosService.dispose();
  }
}
