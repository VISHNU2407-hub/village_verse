import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with WidgetsBindingObserver {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _currentUser;
  Map<String, dynamic>? _emergencyContacts;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload data when screen becomes visible again (e.g., after returning from profile)
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        // Get latest user data from Firestore
        final userData = await _firestoreService.getUser(user.uid);
        if (userData != null && mounted) {
          setState(() {
            _currentUser = userData;
          });

          // Fetch emergency contacts based on user's mandal
          if (userData.mandal.isNotEmpty) {
            // Convert mandal to lowercase and trim spaces
            final userMandal = userData.mandal.trim().toLowerCase();
            print(
              'DEBUG: Fetched mandal from users collection: ${userData.mandal}',
            );
            print('DEBUG: Processed mandal (lowercase, trimmed): $userMandal');

            // Fetch exact document from emergency_contacts collection
            final docRef = FirebaseFirestore.instance
                .collection('emergency_contacts')
                .doc(userMandal);
            print(
              'DEBUG: Firestore document path: emergency_contacts/$userMandal',
            );

            final docSnapshot = await docRef.get();
            print('DEBUG: Document exists: ${docSnapshot.exists}');

            if (docSnapshot.exists) {
              final data = docSnapshot.data() as Map<String, dynamic>;
              print('DEBUG: Fetched document data: $data');

              if (mounted) {
                setState(() {
                  _emergencyContacts = data;
                  _isLoading = false;
                });
              }
            } else {
              print('DEBUG: No document found for mandal: $userMandal');
              if (mounted) {
                setState(() {
                  _emergencyContacts = null;
                  _isLoading = false;
                });
              }
            }
          } else {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Mandal not set in your profile';
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'User data not found';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'User not authenticated';
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading emergency contacts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load emergency contacts: $e';
        });
        AppHelpers.showErrorSnackBar(
          context,
          'Failed to load emergency contacts: $e',
        );
      }
    }
  }

  Future<void> _sendMessage(String number) async {
    final Uri smsUri = Uri(scheme: 'sms', path: number);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Could not launch SMS app');
      }
    }
  }

  Future<void> _makeCall(String number) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Could not launch dialer');
      }
    }
  }

  String _formatMandalName(String mandal) {
    // Capitalize first letter of each word for display
    return mandal
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppConstants.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _emergencyContacts == null
          ? _buildEmptyState()
          : _buildContactsList(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppConstants.primaryColor),
          SizedBox(height: 16),
          Text(
            'Loading emergency contacts...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.contact_phone_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Emergency contacts for your mandal will be added soon.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_currentUser?.mandal != null && _currentUser!.mandal.isNotEmpty)
              Text(
                'Mandal: ${_formatMandalName(_currentUser!.mandal)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    final contacts = _emergencyContacts!;
    final contactItems = _getContactItems(contacts);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppConstants.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mandal info
            if (_currentUser?.mandal != null && _currentUser!.mandal.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppConstants.primaryColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppConstants.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mandal: ${_formatMandalName(_currentUser!.mandal)}',
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Contact cards
            ...contactItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildContactCard(item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<ContactItem> _getContactItems(Map<String, dynamic> contacts) {
    final items = <ContactItem>[];
    print('DEBUG: Processing contact fields dynamically');

    // Dynamically iterate through all fields in the document
    contacts.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        print('DEBUG: Field: $key, Value: $value');

        // Format the field name for display (convert snake_case to Title Case)
        final displayName = _formatFieldName(key);

        // Get icon and color based on field name
        final iconData = _getIconForField(key);
        final colorData = _getColorForField(key);

        items.add(
          ContactItem(
            icon: iconData,
            title: displayName,
            subtitle: _formatMandalName(_currentUser?.mandal ?? ''),
            number: value.toString(),
            color: colorData,
          ),
        );
      }
    });

    print('DEBUG: Total contact items: ${items.length}');
    return items;
  }

  String _formatFieldName(String fieldName) {
    // Convert snake_case to Title Case
    return fieldName
        .split('_')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  IconData _getIconForField(String fieldName) {
    final lowerField = fieldName.toLowerCase();

    if (lowerField.contains('police')) return Icons.local_police;
    if (lowerField.contains('hospital') ||
        lowerField.contains('medical') ||
        lowerField.contains('health')) {
      return Icons.local_hospital;
    }
    if (lowerField.contains('fire')) return Icons.local_fire_department;
    if (lowerField.contains('woman') || lowerField.contains('women')) {
      return Icons.woman;
    }
    if (lowerField.contains('electric') || lowerField.contains('power')) {
      return Icons.electrical_services;
    }
    if (lowerField.contains('ambulance')) return Icons.airport_shuttle;
    if (lowerField.contains('blood')) return Icons.bloodtype;
    if (lowerField.contains('child') || lowerField.contains('helpline')) {
      return Icons.phone;
    }

    // Default icon for unknown fields
    return Icons.contact_phone;
  }

  Color _getColorForField(String fieldName) {
    final lowerField = fieldName.toLowerCase();

    if (lowerField.contains('police')) return Colors.blue;
    if (lowerField.contains('hospital') ||
        lowerField.contains('medical') ||
        lowerField.contains('health')) {
      return Colors.red;
    }
    if (lowerField.contains('fire')) return Colors.orange;
    if (lowerField.contains('woman') || lowerField.contains('women')) {
      return Colors.purple;
    }
    if (lowerField.contains('electric') || lowerField.contains('power')) {
      return Colors.amber;
    }
    if (lowerField.contains('ambulance')) return Colors.red;
    if (lowerField.contains('blood')) return Colors.red;
    if (lowerField.contains('child') || lowerField.contains('helpline')) {
      return Colors.teal;
    }

    // Default color for unknown fields
    return Colors.grey;
  }

  Widget _buildContactCard(ContactItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Left icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),

            const SizedBox(width: 16),

            // Contact info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.number,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: item.color,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Message button
                IconButton(
                  onPressed: () => _sendMessage(item.number),
                  icon: Icon(Icons.message, color: Colors.grey[600], size: 20),
                  tooltip: 'Message',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),

                // Call button
                Container(
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    onPressed: () => _makeCall(item.number),
                    icon: const Icon(Icons.call, color: Colors.white, size: 20),
                    tooltip: 'Call',
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContactItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String number;
  final Color color;

  ContactItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.number,
    required this.color,
  });
}
