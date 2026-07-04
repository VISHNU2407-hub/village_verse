import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/complaint_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/profile_image_widget.dart';
import '../profile/profile_screen.dart';
import '../medical_emergency_screen.dart';
import 'complaint_screen.dart';
import 'complaint_detail_screen.dart';
import 'admin_dashboard_screen.dart';
import 'info_screen.dart';
import 'my_complaints_screen.dart';
import 'blood_bank_screen.dart';
import 'missing_person_alerts_screen.dart';
import 'notifications_screen.dart';
import '../sos_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  int _currentIndex = 0;
  UserModel? _currentUser;

  // ── Staggered entrance animation ────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _greetingAnim;
  late final Animation<double> _sectionTitleAnim;
  late final Animation<double> _sosCardAnim; // fade + scale
  late final Animation<double> _medicalCardAnim;
  late final Animation<double> _missingCardAnim;
  late final Animation<double> _bloodCardAnim;
  late final Animation<double> _moreFeaturesAnim;
  @override
  void initState() {
    super.initState();
    _initEntryAnimations();
    _loadCurrentUser();
    // Start the entrance animation immediately — content fades in while
    // user data loads in the background.
    _entryController.forward();
  }

  void _initEntryAnimations() {
    // Total stagger window: ~700ms, controller gives 800ms for a brief
    // settle before the last item finishes.
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Greeting card (start 0%, end 18%)
    _greetingAnim = _makeStaggeredAnim(0.00, 0.18);

    // "Emergency Services" section title (start 15%, end 30%)
    _sectionTitleAnim = _makeStaggeredAnim(0.15, 0.30);

    // SOS card gets a subtle scale entrance to draw attention (start 25%, end 42%)
    _sosCardAnim = _makeStaggeredAnim(0.25, 0.42);

    // Medical card (start 38%, end 54%)
    _medicalCardAnim = _makeStaggeredAnim(0.38, 0.54);

    // Missing Person card (start 50%, end 66%)
    _missingCardAnim = _makeStaggeredAnim(0.50, 0.66);

    // Blood Bank card (start 62%, end 78%)
    _bloodCardAnim = _makeStaggeredAnim(0.62, 0.78);

    // More Features section (start 72%, end 90%)
    _moreFeaturesAnim = _makeStaggeredAnim(0.72, 0.90);
  }

  Animation<double> _makeStaggeredAnim(double start, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
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
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to load user data: $e');
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              title: Text(
                AppConstants.appName,
                style: const TextStyle(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: true,
              actions: [
                if (_currentUser != null)
                  StreamBuilder<int>(
                    stream: _firestoreService.getUnreadNotificationCount(
                      userId: _auth.currentUser!.uid,
                      userMandal: _currentUser!.mandal,
                    ),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NotificationsScreen(
                                    currentUser: _currentUser!,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppConstants.primaryColor,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 7,
                              top: 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                if (_currentUser != null)
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: _currentUser!),
                        ),
                      );
                      if (result == true && mounted) {
                        _loadCurrentUser();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ProfileImageWidget(
                        imageUrl: _currentUser!.photoUrl,
                        name: _currentUser!.name,
                        size: 40,
                        showBorder: false,
                      ),
                    ),
                  ),
              ],
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildAlertsScreen(),
          _buildInfoScreen(),
          _buildComplaintScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppConstants.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.emergency), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Info'),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_note),
            label: 'Complaint',
          ),
        ],
      ),
    );
  }

  // ── Animated entry helpers ──────────────────────────────────────────

  /// Wraps [child] with a fade + slide-up entrance tied to [animation].
  Widget _buildFadeSlideEntry({
    required Animation<double> animation,
    required Widget child,
    double slideOffset = 30,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1.0 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Wraps [child] with a fade + subtle scale-up entrance.
  /// Used for the SOS card to subtly differentiate the most critical action.
  Widget _buildFadeScaleEntry({
    required Animation<double> animation,
    required Widget child,
    double scaleFrom = 0.92,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.scale(
            scale: scaleFrom + (1.0 - scaleFrom) * animation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ── Alerts screen ───────────────────────────────────────────────────

  Widget _buildAlertsScreen() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Greeting Section
          _buildFadeSlideEntry(
            animation: _greetingAnim,
            slideOffset: 20,
            child: _buildGreetingSection(),
          ),

          const SizedBox(height: 28),

          // Emergency Section Title
          _buildFadeSlideEntry(
            animation: _sectionTitleAnim,
            slideOffset: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Services',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to get immediate assistance',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Emergency Cards List — each card has its own staggered entrance.
          // SOS uses a subtle scale-up; the rest use slide-up.
          ...AppConstants.emergencyTypes.map((emergency) {
            final bool isSos = emergency['type'] == 'sos';

            if (isSos) {
              return _buildFadeScaleEntry(
                animation: _sosCardAnim,
                child: _buildPaddedCard(emergency),
              );
            }

            // Determine which animation to use based on emergency type.
            final Animation<double> cardAnim;
            switch (emergency['type'] as String) {
              case 'medical':
                cardAnim = _medicalCardAnim;
                break;
              case 'missing_person':
                cardAnim = _missingCardAnim;
                break;
              case 'blood_bank':
                cardAnim = _bloodCardAnim;
                break;
              default:
                cardAnim = _medicalCardAnim;
            }

            return _buildFadeSlideEntry(
              animation: cardAnim,
              slideOffset: 24,
              child: _buildPaddedCard(emergency),
            );
          }),

          const SizedBox(height: 32),

          // More Features Coming Soon Section
          _buildFadeSlideEntry(
            animation: _moreFeaturesAnim,
            slideOffset: 20,
            child: _buildMoreFeaturesSection(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGreetingSection() {
    return Container(
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${AppHelpers.getGreeting()}, ${_currentUser?.name ?? 'User'} 👋',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'How can we help you today?',
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 16,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreFeaturesSection() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upcoming, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Text(
              'More Features Coming Soon',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns [_buildEmergencyCard] wrapped in bottom padding.
  /// Keeps the card-to-card spacing consistent without duplicating padding.
  Widget _buildPaddedCard(Map<String, dynamic> emergency) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildEmergencyCard(emergency),
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> emergency) {
    final Color emergencyColor = emergency['color'] as Color;

    return GestureDetector(
      onTap: () {
        _handleEmergencyTap(emergency['type'] as String);
      },
      child: Container(
        decoration: BoxDecoration(
          color: emergencyColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: emergencyColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: emergencyColor.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Icon Container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: emergencyColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: emergencyColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    emergency['icon'] as IconData,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 20),

                // Title and Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emergency['title'] as String,
                        style: TextStyle(
                          color: emergencyColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        emergency['description'] as String,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right Arrow Icon
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: emergencyColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      color: emergencyColor,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleEmergencyTap(String emergencyType) {
    switch (emergencyType.toLowerCase()) {
      case 'medical':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicalEmergencyScreen()),
        );
        break;
      case 'blood_bank':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BloodBankScreen()),
        );
        break;
      case 'fire':
        _makeEmergencyCall('101'); // Fire
        break;
      case 'sos':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SOSScreen()),
        );
        break;
      case 'missing_person':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MissingPersonAlertsScreen()),
        );
        break;
      default:
        AppHelpers.showErrorSnackBar(context, 'Emergency type not recognized');
    }
  }

  void _makeEmergencyCall(String number) {
    // In a real app, this would make an actual phone call
    AppHelpers.showSnackBar(
      context,
      'Calling emergency number: $number',
      color: Colors.green,
    );
  }

  Widget _buildInfoScreen() {
    return const InfoScreen();
  }

  Widget _buildComplaintScreen() {
    if (_currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check user role
    final isCitizen = _currentUser!.role.toLowerCase() == 'citizen';

    if (isCitizen) {
      // Show Complaint Box for citizens
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Greeting Section
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppHelpers.getGreeting()}, ${_currentUser?.name ?? 'User'} 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Submit your complaints and help improve our village services',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Complaint Box Card - Full width with modern gradient
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ComplaintScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.secondaryColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.primaryColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_note,
                        color: AppConstants.primaryColor,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Complaint Box',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to submit a new complaint',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // My Complaints Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Complaints',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.primaryColor,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyComplaintsScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Realtime Complaint List
            _buildComplaintsList(),
          ],
        ),
      );
    } else {
      // Show Admin Dashboard for admins
      return const AdminDashboardScreen();
    }
  }

  Widget _buildComplaintsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getComplaintsByUserId(_auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading complaints',
                    style: TextStyle(color: Colors.red[300]),
                  ),
                ],
              ),
            ),
          );
        }

        final complaints = snapshot.data?.docs ?? [];

        if (complaints.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No complaints yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: complaints.length > 3 ? 3 : complaints.length,
          itemBuilder: (context, index) {
            final doc = complaints[index];
            final complaint = ComplaintModel.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
            return _buildComplaintCard(complaint);
          },
        );
      },
    );
  }

  Widget _buildComplaintCard(ComplaintModel complaint) {
    final statusColor = _getStatusColor(complaint.status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintDetailScreen(complaint: complaint),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _getCategoryIcon(complaint.category),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.title.isNotEmpty
                                    ? complaint.title
                                    : 'No Title',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppHelpers.formatDate(complaint.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      _formatStatus(complaint.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Category chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getCategoryIcon(complaint.category),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      complaint.category,
                      style: TextStyle(
                        color: AppConstants.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Description preview
              Text(
                complaint.description,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.blue;
      case 'reviewing':
        return Colors.orange;
      case 'in_progress':
        return Colors.yellow.shade700;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'reviewing':
        return 'Reviewing';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'Roads':
        return '🛣';
      case 'Water':
        return '💧';
      case 'Electricity':
        return '⚡';
      case 'Drainage':
        return '🚰';
      case 'Garbage':
        return '🗑';
      case 'Street Lights':
        return '💡';
      case 'Internet':
        return '🌐';
      case 'Public Safety':
        return '🛡';
      case 'Other':
        return '📋';
      default:
        return '📋';
    }
  }
}
