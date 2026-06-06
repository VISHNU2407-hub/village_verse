import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/mandal_data_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/profile_image_widget.dart';

class BloodBankScreen extends StatefulWidget {
  const BloodBankScreen({super.key});

  @override
  State<BloodBankScreen> createState() => _BloodBankScreenState();
}

class _BloodBankScreenState extends State<BloodBankScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Blood group options
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // Filter values
  String? _selectedBloodGroup;
  String? _selectedMandal;

  // Mandal autocomplete
  List<String> _allMandals = [];
  List<String> _filteredMandals = [];
  final TextEditingController _mandalController = TextEditingController();

  // Search state
  bool _isSearching = false;
  List<UserModel> _donors = [];
  String? _errorMessage;

  // Current user
  UserModel? _currentUser;

  // Location state
  Position? _currentPosition;
  bool _locationPermissionGranted = false;
  bool _isFetchingLocation = false;
  String? _locationErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMandals();
    _requestLocationAndFetch();
  }

  @override
  void dispose() {
    _mandalController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final userData = await _firestoreService.getUser(user.uid);
        if (mounted) {
          setState(() {
            _currentUser = userData;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user: $e');
    }
  }

  Future<void> _loadMandals() async {
    try {
      final mandals = await MandalDataService.loadMandals();
      if (mounted) {
        setState(() {
          _allMandals = mandals;
          _filteredMandals = mandals;
        });
      }
    } catch (e) {
      debugPrint('Error loading mandals: $e');
    }
  }

  Future<void> _requestLocationAndFetch() async {
    setState(() {
      _isFetchingLocation = true;
      _locationErrorMessage = null;
    });

    try {
      // Request location permission
      final status = await Permission.location.request();

      if (status.isGranted) {
        // Permission granted, fetch current location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentPosition = position;
            _locationPermissionGranted = true;
            _isFetchingLocation = false;
          });
        }

        // Update user's location in Firebase
        await _updateUserLocationInFirebase(position);
      } else {
        // Permission denied
        if (mounted) {
          setState(() {
            _locationPermissionGranted = false;
            _isFetchingLocation = false;
            _locationErrorMessage = 'Enable location for nearest donor results';
          });
        }
        debugPrint('Location permission denied');
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
      if (mounted) {
        setState(() {
          _locationPermissionGranted = false;
          _isFetchingLocation = false;
          _locationErrorMessage = 'Enable location for nearest donor results';
        });
      }
    }
  }

  Future<void> _updateUserLocationInFirebase(Position position) async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.updateUserLocation(
          user.uid,
          position.latitude,
          position.longitude,
        );
        debugPrint(
          'User location updated in Firebase: ${position.latitude}, ${position.longitude}',
        );
      }
    } catch (e) {
      debugPrint('Error updating user location in Firebase: $e');
    }
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m away';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km away';
    }
  }

  void _onMandalQueryChanged(String query) {
    setState(() {
      _filteredMandals = MandalDataService.filterMandals(query, _allMandals);
    });
  }

  void _selectMandal(String mandal) {
    setState(() {
      _selectedMandal = mandal;
      _mandalController.text = mandal;
      _filteredMandals = _allMandals;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _searchDonors() async {
    if (_selectedBloodGroup == null || _selectedBloodGroup!.isEmpty) {
      AppHelpers.showErrorSnackBar(context, 'Please select a blood group');
      return;
    }

    if (_selectedMandal == null || _selectedMandal!.isEmpty) {
      AppHelpers.showErrorSnackBar(context, 'Please select a mandal');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _donors = [];
    });

    try {
      // Debug prints
      debugPrint('Blood Bank Search:');
      debugPrint('  Selected Blood Group: $_selectedBloodGroup');
      debugPrint('  Selected Mandal: $_selectedMandal');
      debugPrint(
        '  Selected Mandal (lowercase): ${_selectedMandal!.toLowerCase().trim()}',
      );
      debugPrint('  Current User ID: ${_auth.currentUser?.uid}');

      final stream = _firestoreService.getBloodDonors(
        _selectedBloodGroup!,
        _selectedMandal!,
        _auth.currentUser?.uid ?? '',
      );

      stream.listen(
        (snapshot) {
          if (!mounted) return;

          debugPrint('  Firestore Snapshot Size: ${snapshot.docs.length}');

          // Convert all documents to UserModel
          final allDonors = snapshot.docs
              .map(
                (doc) => UserModel.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();

          debugPrint('  All Blood Donors from Firestore: ${allDonors.length}');
          for (var donor in allDonors) {
            debugPrint(
              '    - ${donor.name}, Blood: ${donor.bloodGroup}, Mandal: ${donor.mandal}, isBloodDonor: ${donor.isBloodDonor}',
            );
          }

          // Filter locally: bloodGroup match, mandal match (case-insensitive), exclude current user
          final selectedMandalLower = _selectedMandal!.toLowerCase().trim();
          final filteredDonors = allDonors.where((donor) {
            final bloodGroupMatch = donor.bloodGroup == _selectedBloodGroup;
            final mandalMatch =
                donor.mandal.toLowerCase().trim() == selectedMandalLower;
            final notCurrentUser = donor.uid != (_auth.currentUser?.uid);

            debugPrint(
              '    Filtering ${donor.name}: bloodGroupMatch=$bloodGroupMatch, mandalMatch=$mandalMatch, notCurrentUser=$notCurrentUser',
            );

            return bloodGroupMatch && mandalMatch && notCurrentUser;
          }).toList();

          debugPrint('  Filtered Donors Count: ${filteredDonors.length}');
          for (var donor in filteredDonors) {
            debugPrint(
              '    - ${donor.name}, Blood: ${donor.bloodGroup}, Mandal: ${donor.mandal}, Village: ${donor.village}',
            );
          }

          // Calculate distances and sort if location is available
          List<UserModel> sortedDonors = filteredDonors;
          if (_currentPosition != null) {
            sortedDonors = filteredDonors.map((donor) {
              double distance = 0.0;
              if (donor.latitude != null && donor.longitude != null) {
                distance = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  donor.latitude!,
                  donor.longitude!,
                );
              }
              return donor.copyWith(
                latitude: donor.latitude,
                longitude: donor.longitude,
              );
            }).toList();

            // Sort by distance (nearest first)
            sortedDonors.sort((a, b) {
              double distanceA = 0.0;
              double distanceB = 0.0;

              if (a.latitude != null && a.longitude != null) {
                distanceA = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  a.latitude!,
                  a.longitude!,
                );
              }

              if (b.latitude != null && b.longitude != null) {
                distanceB = Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  b.latitude!,
                  b.longitude!,
                );
              }

              return distanceA.compareTo(distanceB);
            });

            debugPrint('  Donors sorted by distance');
          }

          setState(() {
            _donors = sortedDonors;
            _isSearching = false;
          });
        },
        onError: (error) {
          debugPrint('  Firestore Error: $error');
          if (mounted) {
            setState(() {
              _errorMessage = error.toString();
              _isSearching = false;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('  Search Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  String _formatWhatsAppNumber(String phoneNumber) {
    // Convert to String
    final phoneStr = phoneNumber.toString();

    // Remove ALL non-digit characters using regex
    final cleanedPhone = phoneStr.replaceAll(RegExp(r'[^\d]'), '');

    // If cleaned number length == 10, prepend 91
    if (cleanedPhone.length == 10) {
      return '91$cleanedPhone';
    }

    // If number already starts with 91 AND length == 12, keep unchanged
    if (cleanedPhone.length == 12 && cleanedPhone.startsWith('91')) {
      return cleanedPhone;
    }

    // Return cleaned number as-is (will be validated later)
    return cleanedPhone;
  }

  Future<void> _makeCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      AppHelpers.showErrorSnackBar(context, 'Could not launch phone dialer');
    }
  }

  Future<void> _openWhatsApp(UserModel donor) async {
    if (_currentUser == null) {
      AppHelpers.showErrorSnackBar(context, 'User data not available');
      return;
    }

    // Show dialog to get hospital/location
    final locationController = TextEditingController();

    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hospital / Location'),
        content: TextField(
          controller: locationController,
          decoration: const InputDecoration(
            hintText: 'Enter hospital or location name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (locationController.text.trim().isNotEmpty) {
                Navigator.pop(context, locationController.text.trim());
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (location == null || location.isEmpty) return;

    // Format phone number using dedicated helper function
    final formattedNumber = _formatWhatsAppNumber(donor.phone);

    // Validation: Check formattedNumber.length >= 12
    if (formattedNumber.length < 12) {
      AppHelpers.showErrorSnackBar(context, 'Invalid phone number');
      return;
    }

    // Debug print before launch
    print("FINAL WHATSAPP NUMBER: $formattedNumber");

    // Generate WhatsApp message
    final message =
        '''Hello, I urgently need $_selectedBloodGroup blood.

Hospital/Location: $location

Please contact me as soon as possible.

My contact number: ${_currentUser!.phone}''';

    // Open WhatsApp with prefilled message
    final whatsappUrl = Uri.parse(
      'https://wa.me/$formattedNumber?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(
      whatsappUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open WhatsApp')));
    }
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
          'Blood Bank',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFD32F2F), const Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bloodtype,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find Blood Donors',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Search by blood group and location',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Blood Group Dropdown
            const Text(
              'Blood Group',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBloodGroup,
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Select blood group'),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  items: _bloodGroups.map((group) {
                    return DropdownMenuItem<String>(
                      value: group,
                      child: Text(group, style: const TextStyle(fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBloodGroup = value;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Mandal Autocomplete
            const Text(
              'Mandal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                _onMandalQueryChanged(textEditingValue.text);
                return _filteredMandals.where(
                  (mandal) => mandal.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              onSelected: (String mandal) {
                _selectMandal(mandal);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    _mandalController.text = controller.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Search mandal',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFD32F2F),
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  },
            ),

            const SizedBox(height: 24),

            // Location message
            if (_locationErrorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_off,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationErrorMessage!,
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (_isFetchingLocation)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Fetching location...',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Search Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSearching ? null : _searchDonors,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSearching
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Search Donors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Results Section
            if (_isSearching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red[300]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (_donors.isEmpty &&
                _selectedBloodGroup != null &&
                _selectedMandal != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No donors found for selected filters',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else if (_donors.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Found ${_donors.length} donor${_donors.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._donors.map((donor) => _buildDonorCard(donor)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorCard(UserModel donor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Donor info row
            Row(
              children: [
                // Profile image
                ProfileImageWidget(
                  imageUrl: donor.photoUrl,
                  name: donor.name,
                  size: 56,
                  showBorder: false,
                ),
                const SizedBox(width: 16),
                // Name and details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donor.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD32F2F),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              donor.bloodGroup,
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              donor.village,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Distance display
                      if (_currentPosition != null &&
                          donor.latitude != null &&
                          donor.longitude != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.near_me,
                                size: 12,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDistance(
                                  Geolocator.distanceBetween(
                                    _currentPosition!.latitude,
                                    _currentPosition!.longitude,
                                    donor.latitude!,
                                    donor.longitude!,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(donor.phone),
                    icon: const Icon(Icons.call, size: 20),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openWhatsApp(donor),
                    icon: const Icon(Icons.chat, size: 20),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
