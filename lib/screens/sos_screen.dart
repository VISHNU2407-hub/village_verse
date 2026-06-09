import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/guardian_model.dart';
import '../../services/firestore_service.dart';
import '../../services/permission_service.dart';
import '../../services/sos_service.dart';
import '../../widgets/sos_button.dart';
import '../../widgets/guardian_card.dart';
import '../../widgets/permission_status_card.dart';
import 'emergency_history_screen.dart';
import 'profile/guardian_setup_screen.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final SOSService _sosService = SOSService();

  List<GuardianModel> _guardians = [];
  bool _isLoading = true;
  bool _smsGranted = false;
  bool _phoneGranted = false;
  bool _locationGranted = false;
  bool _isActivatingSOS = false;
  bool _isSOSActive = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadGuardians(),
        _checkPermissions(),
        _restoreActiveSOSState(),
      ]);
    } catch (e) {
      debugPrint('Error loading SOS data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreActiveSOSState() async {
    final activeEmergency = await _sosService.restoreActiveEmergency();
    if (mounted) {
      setState(() {
        _isSOSActive = activeEmergency != null;
      });
    }
  }

  Future<void> _loadGuardians() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      final guardians = await _firestoreService.getGuardians(currentUser.uid);
      if (mounted) {
        setState(() {
          _guardians = guardians;
        });
      }
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = await PermissionService.checkAllPermissions();
    if (mounted) {
      setState(() {
        _smsGranted = permissions['sms'] ?? false;
        _phoneGranted = permissions['phone'] ?? false;
        _locationGranted = permissions['location'] ?? false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    final results = await PermissionService.requestAllPermissions();
    if (mounted) {
      setState(() {
        _smsGranted = results['sms'] ?? false;
        _phoneGranted = results['phone'] ?? false;
        _locationGranted = results['location'] ?? false;
      });

      if (!(results['sms'] ?? false) ||
          !(results['phone'] ?? false) ||
          !(results['location'] ?? false)) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'SMS, Phone, and Location permissions are required for the SOS feature to work properly. Please grant all permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sosService.dispose();
    super.dispose();
  }

  Future<void> _handleSOSActivated() async {
    if (_isActivatingSOS || _isSOSActive) {
      return;
    }

    setState(() {
      _isActivatingSOS = true;
    });

    try {
      final result = await _sosService.activateSOS();

      if (mounted) {
        if (result.success) {
          setState(() {
            _isSOSActive = true;
          });

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFFE91E63),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'SOS Activated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notified ${result.guardiansNotified}/${result.totalGuardians} guardians',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Emergency help is on the way',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFE91E63),
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('SOS Activation Failed'),
              content: Text(result.error ?? 'Unknown error'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to activate SOS: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingSOS = false;
        });
      }
    }
  }

  Future<void> _handleStopSOS() async {
    if (!_isSOSActive || _isActivatingSOS) {
      return;
    }

    setState(() {
      _isActivatingSOS = true;
    });

    try {
      final stopped = await _sosService.deactivateSOS();

      if (!mounted) {
        return;
      }

      if (stopped) {
        setState(() {
          _isSOSActive = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('SOS Stopped'),
            content: const Text('Emergency location sharing has been stopped.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unable to Stop SOS'),
            content: const Text('No active SOS session was found.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to stop SOS: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActivatingSOS = false;
        });
      }
    }
  }

  void _navigateToGuardianSetup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GuardianSetupScreen()),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            color: Color(0xFFE91E63),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Emergency History',
            icon: const Icon(Icons.history, color: Color(0xFFE91E63)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmergencyHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // SOS Button
                    IgnorePointer(
                      ignoring: _isActivatingSOS || _isSOSActive,
                      child: Opacity(
                        opacity: _isActivatingSOS || _isSOSActive ? 0.55 : 1,
                        child: SOSButton(
                          onSOSActivated: _handleSOSActivated,
                          size: 200,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSOSActive
                          ? 'SOS is active'
                          : _isActivatingSOS
                          ? 'Activating SOS...'
                          : 'Press and hold for emergency help',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isSOSActive
                            ? const Color(0xFFE91E63)
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_isSOSActive) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isActivatingSOS ? null : _handleStopSOS,
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('Stop SOS'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Permission Status Card
                    PermissionStatusCard(
                      smsGranted: _smsGranted,
                      phoneGranted: _phoneGranted,
                      locationGranted: _locationGranted,
                      guardianCount: _guardians.length,
                    ),
                    const SizedBox(height: 16),

                    // Request Permissions Button
                    if (!_smsGranted || !_phoneGranted || !_locationGranted)
                      ElevatedButton.icon(
                        onPressed: _requestPermissions,
                        icon: const Icon(Icons.security),
                        label: const Text('Grant Permissions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Guardians Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Emergency Contacts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE91E63),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _navigateToGuardianSetup,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE91E63),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Guardians List
                    if (_guardians.isEmpty)
                      _buildEmptyGuardiansState()
                    else
                      ..._guardians.map(
                        (guardian) => GuardianCard(
                          guardian: guardian,
                          onEdit: () => _navigateToGuardianSetup(),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyGuardiansState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.contact_phone, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts added',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add guardians to receive emergency alerts',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _navigateToGuardianSetup,
            icon: const Icon(Icons.add),
            label: const Text('Add Guardian'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
