import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/guardian_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/mandal_autocomplete.dart';
import '../../widgets/district_autocomplete.dart';

import '../../widgets/profile_image_widget.dart';
import '../permissions_setup_screen.dart';
import '../auth_screen.dart';
import 'guardian_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isUploadingImage = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _mandalController;
  late TextEditingController _villageController;
  late TextEditingController _stateController;
  late TextEditingController _districtController;
  late TextEditingController _ageController;
  late TextEditingController _bloodGroupController;
  bool _isBloodDonor = false;
  UserModel? _currentUser;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _mandalController = TextEditingController(text: widget.user.mandal);
    _villageController = TextEditingController(text: widget.user.village);
    _stateController = TextEditingController(text: widget.user.state);
    _districtController = TextEditingController(text: widget.user.district);
    _ageController = TextEditingController(text: widget.user.age);
    _bloodGroupController = TextEditingController(text: widget.user.bloodGroup);
    _isBloodDonor = widget.user.isBloodDonor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _mandalController.dispose();
    _villageController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _ageController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
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
          'Profile',
          style: TextStyle(
            color: AppConstants.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: AppConstants.primaryColor,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.secondaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            ProfileImageWidget(
                              imageUrl: _currentUser?.photoUrl,
                              name: _currentUser?.name ?? 'User',
                              size: 100,
                              showBorder: true,
                            ),
                            if (_isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _isUploadingImage
                                      ? null
                                      : _pickAndUploadImage,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _isUploadingImage
                                          ? Colors.grey
                                          : AppConstants.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploadingImage
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 20),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser?.name ?? 'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              const Text(
                                'Village Resident',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
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

              const SizedBox(height: 24),

              // Profile Information
              _buildInfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppConstants.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.person,
            'Full Name',
            _currentUser?.name ?? '',
            _nameController,
          ),
          _buildInfoRow(
            Icons.phone,
            'Phone Number',
            AppHelpers.formatPhoneNumber(_currentUser?.phone ?? ''),
            _phoneController,
          ),
          _buildInfoRow(
            Icons.public,
            'State',
            _currentUser?.state ?? '',
            _stateController,
          ),
          _buildInfoRow(
            Icons.map,
            'District',
            _currentUser?.district ?? '',
            _districtController,
          ),
          _buildInfoRow(
            Icons.location_city,
            'Mandal',
            _currentUser?.mandal ?? '',
            _mandalController,
          ),
          _buildInfoRow(
            Icons.home,
            'Village',
            _currentUser?.village ?? '',
            _villageController,
          ),
          _buildInfoRow(
            Icons.cake,
            'Age',
            _currentUser?.age ?? '',
            _ageController,
          ),
          _buildInfoRow(
            Icons.bloodtype,
            'Blood Group',
            _currentUser?.bloodGroup ?? '',
            _bloodGroupController,
          ),

          // Blood Donor Toggle
          _buildBloodDonorRow(),

          _buildInfoRow(
            Icons.person_outline,
            'Role',
            _currentUser?.role ?? '',
            null,
          ),

          const SizedBox(height: 20),

          // Guardians Section
          FutureBuilder<List<GuardianModel>>(
            future: _loadGuardians(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final guardians = snapshot.data ?? [];

              if (guardians.isEmpty) {
                return _buildEmptyGuardiansSection();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contacts',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...guardians.map((guardian) => _buildGuardianCard(guardian)),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // Action Buttons
          if (_isEditing)
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Cancel',
                    onPressed: _cancelEdit,
                    isOutlined: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(text: 'Save', onPressed: _saveProfile),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Edit Profile',
                        onPressed: _enableEditMode,
                        isOutlined: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Logout',
                        onPressed: _logout,
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PermissionsSetupScreen(
                            canSkip: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.security),
                    label: const Text('Open Permissions Setup'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, [
    TextEditingController? controller,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                if (_isEditing && controller != null)
                  label == 'Mandal'
                      ? MandalAutocomplete(
                          controller: controller,
                          labelText: null,
                          hintText: 'Search mandal...',
                          prefixIcon: null,
                          validator: (val) =>
                              val?.isEmpty ?? true ? 'Required' : null,
                          textInputAction: TextInputAction.next,
                        )
                      : label == 'District'
                          ? DistrictAutocomplete(
                              controller: controller,
                              labelText: null,
                              hintText: 'Search district...',
                              prefixIcon: null,
                              validator: (val) =>
                                  val?.isEmpty ?? true ? 'Required' : null,
                              textInputAction: TextInputAction.next,
                            )
                      : TextField(
                          controller: controller,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppConstants.primaryColor,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        )
                else
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppConstants.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodDonorRow() {
    final age = int.tryParse(_currentUser?.age ?? '');
    final isUnder18 = age != null && age < 18;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(
            Icons.bloodtype,
            color: AppConstants.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available to Donate Blood?',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                if (_isEditing)
                  Row(
                    children: [
                      Switch(
                        value: _isBloodDonor,
                        onChanged: isUnder18
                            ? null
                            : (value) {
                                setState(() {
                                  _isBloodDonor = value;
                                });
                              },
                        activeThumbColor: AppConstants.primaryColor,
                      ),
                      if (isUnder18)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Only users above 18 can register as blood donors.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    _currentUser?.isBloodDonor == true ? 'Yes' : 'No',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppConstants.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianCard(GuardianModel guardian) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: AppConstants.primaryColor,
          child: Text(
            guardian.name.isNotEmpty ? guardian.name[0].toUpperCase() : 'G',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          guardian.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guardian.relation,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              AppHelpers.formatPhoneNumber(guardian.phone),
              style: const TextStyle(
                color: AppConstants.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    GuardianSetupScreen(editGuardian: guardian),
              ),
            );
            if (result == true && mounted) {
              setState(() {});
            }
          },
          icon: const Icon(Icons.edit, color: AppConstants.primaryColor),
        ),
      ),
    );
  }

  Widget _buildEmptyGuardiansSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_phone, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts added',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add emergency contacts for your safety',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Add Guardians',
            onPressed: () => Navigator.pushNamed(context, '/guardian-setup'),
            icon: const Icon(Icons.add),
            width: 200,
          ),
        ],
      ),
    );
  }

  Future<List<GuardianModel>> _loadGuardians() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestoreService = FirestoreService();
        return await firestoreService.getGuardians(currentUser.uid);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  void _enableEditMode() {
    setState(() {
      _isEditing = true;
      _nameController.text = _currentUser?.name ?? '';
      _phoneController.text = _currentUser?.phone ?? '';
      _stateController.text = _currentUser?.state ?? '';
      _districtController.text = _currentUser?.district ?? '';
      _mandalController.text = _currentUser?.mandal ?? '';
      _villageController.text = _currentUser?.village ?? '';
      _ageController.text = _currentUser?.age ?? '';
      _bloodGroupController.text = _currentUser?.bloodGroup ?? '';
      _isBloodDonor = _currentUser?.isBloodDonor ?? false;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveProfile() async {
    try {
      final updatedUser = widget.user.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        mandal: _mandalController.text.trim().toLowerCase(),
        village: _villageController.text.trim(),
        age: _ageController.text.trim(),
        bloodGroup: _bloodGroupController.text.trim(),
        photoUrl: _currentUser?.photoUrl, // Preserve current photoUrl
        isBloodDonor: _isBloodDonor,
      );

      final firestoreService = FirestoreService();
      await firestoreService.updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isEditing = false;
        });
        AppHelpers.showSuccessSnackBar(context, 'Profile updated successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to update profile: $e');
      }
    }
  }

  Future<void> _logout() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to logout: $e');
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Pick image from gallery
      final File? imageFile = await _cloudinaryService.pickImageFromGallery();

      if (imageFile == null) {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
          });
        }
        return;
      }

      // Upload to Cloudinary
      final String imageUrl = await _cloudinaryService.uploadImage(imageFile);

      // Update user model with new image URL
      final updatedUser = _currentUser!.copyWith(photoUrl: imageUrl);

      // Save to Firestore
      final firestoreService = FirestoreService();
      await firestoreService.updateUser(updatedUser);

      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isUploadingImage = false;
        });
        AppHelpers.showSuccessSnackBar(
          context,
          'Profile image updated successfully',
        );
        // Return success to parent screen to trigger reload
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        AppHelpers.showErrorSnackBar(
          context,
          'Failed to update profile image: $e',
        );
      }
    }
  }
}
