import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/guardian_model.dart';
import '../models/complaint_model.dart';
import '../models/post_model.dart';
import '../models/announcement_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // User operations
  Future<void> saveUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toFirestore());
  }

  Future<UserModel?> getUser(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc.data() as Map<String, dynamic>, uid);
    }
    return null;
  }

  Future<bool> userExists(String uid) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(user.toFirestore());
  }

  Future<void> updateUserLocation(
    String uid,
    double latitude,
    double longitude,
  ) async {
    await _firestore.collection('users').doc(uid).update({
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // Guardian operations
  Future<void> saveGuardian(String uid, GuardianModel guardian) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .doc(guardian.id)
        .set(guardian.toFirestore());
  }

  Future<List<GuardianModel>> getGuardians(String uid) async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map(
          (doc) => GuardianModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Future<void> deleteGuardian(String uid, String guardianId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .doc(guardianId)
        .delete();
  }

  Future<void> updateGuardian(String uid, GuardianModel guardian) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .doc(guardian.id)
        .update(guardian.toFirestore());
  }

  Future<bool> hasGuardians(String uid) async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('guardians')
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Complaint operations
  Future<void> submitComplaint(Map<String, dynamic> complaint) async {
    await _firestore.collection('complaints').add(complaint);
  }

  // Get complaints by user ID (realtime stream)
  Stream<QuerySnapshot> getComplaintsByUserId(String userId) {
    return _firestore
        .collection('complaints')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get complaints by village and mandal for admins (realtime stream)
  Stream<QuerySnapshot> getComplaintsByVillageAndMandal(
    String village,
    String mandal,
  ) {
    return _firestore
        .collection('complaints')
        .where('userVillage', isEqualTo: village)
        .where('userMandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Admin operations - get all complaints
  Future<List<ComplaintModel>> getAllComplaints() async {
    QuerySnapshot snapshot = await _firestore
        .collection('complaints')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map(
          (doc) => ComplaintModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  // Update complaint status
  Future<void> updateComplaintStatus(String complaintId, String status) async {
    await _firestore.collection('complaints').doc(complaintId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Add message to complaint
  Future<void> addComplaintMessage(
    String complaintId,
    Map<String, dynamic> message,
  ) async {
    await _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .add(message);
  }

  // Get messages for a complaint (realtime stream)
  Stream<QuerySnapshot> getComplaintMessages(String complaintId) {
    return _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // Delete complaint and its messages
  Future<void> deleteComplaint(String complaintId) async {
    // Delete complaint messages subcollection
    final messagesSnapshot = await _firestore
        .collection('complaints')
        .doc(complaintId)
        .collection('messages')
        .get();

    for (var doc in messagesSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete complaint document
    await _firestore.collection('complaints').doc(complaintId).delete();
  }

  // Emergency contacts operations
  Future<Map<String, dynamic>?> getEmergencyContacts(String mandal) async {
    // Convert mandal to lowercase for Firestore lookup
    final mandalLower = mandal.toLowerCase();

    DocumentSnapshot doc = await _firestore
        .collection('emergency_contacts')
        .doc(mandalLower)
        .get();

    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  // Post operations
  Future<void> createPost(PostModel post) async {
    print('DEBUG: createPost - Creating post with ID: ${post.postId}');
    print(
      'DEBUG: createPost - Post userVillage: ${post.userVillage}, userMandal: ${post.userMandal}',
    );
    print('DEBUG: createPost - Post data: ${post.toString()}');
    try {
      await _firestore
          .collection('posts')
          .doc(post.postId)
          .set(post.toFirestore());
      print('DEBUG: createPost - Successfully saved post to Firestore');
    } catch (e) {
      print('DEBUG: createPost - Error saving post: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getPostsByVillage(String village) {
    print('DEBUG: getPostsByVillage called with village: $village');
    return _firestore
        .collection('posts')
        .where('userVillage', isEqualTo: village)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPostsByVillageAndMandal(
    String village,
    String mandal,
  ) {
    print(
      'DEBUG: getPostsByVillageAndMandal called with village: $village, mandal: $mandal',
    );
    return _firestore
        .collection('posts')
        .where('userVillage', isEqualTo: village)
        .where('userMandal', isEqualTo: mandal)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getPostsByUserId(String userId) {
    print('DEBUG: getPostsByUserId called with userId: $userId');
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deletePost(String postId) async {
    // Delete post document
    await _firestore.collection('posts').doc(postId).delete();

    // Delete reactions subcollection
    final reactionsSnapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .get();

    for (var doc in reactionsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Note: Pinned posts are stored separately and will be handled by cleanup logic
    // They reference postId, so when post is deleted, the pin reference becomes invalid
    // We could add a cleanup job later to remove orphaned pin references
  }

  // Update post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await _firestore.collection('posts').doc(postId).update(updates);
  }

  // Pin operations
  Future<void> pinPost(String userId, String postId, Duration duration) async {
    final expiresAt = DateTime.now().add(duration);
    await _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .set({
          'postId': postId,
          'pinnedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });
  }

  Future<void> unpinPost(String userId, String postId) async {
    await _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .delete();
  }

  Stream<QuerySnapshot> getPinnedPosts(String userId) {
    return _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .orderBy('pinnedAt', descending: true)
        .snapshots();
  }

  Stream<DocumentSnapshot> checkIfPinned(String userId, String postId) {
    return _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .snapshots();
  }

  Future<bool> isPostPinned(String userId, String postId) async {
    final doc = await _firestore
        .collection('pinned_posts')
        .doc(userId)
        .collection('posts')
        .doc(postId)
        .get();

    if (!doc.exists) return false;

    // Check if pin has expired
    final data = doc.data() as Map<String, dynamic>;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      // Pin has expired, delete it
      await unpinPost(userId, postId);
      return false;
    }

    return true;
  }

  // Reaction operations
  Future<void> toggleReaction(
    String postId,
    String userId,
    String reactionType,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('posts').doc(postId);
      final reactionRef = postRef.collection('reactions').doc(userId);

      final postDoc = await transaction.get(postRef);
      final reactionDoc = await transaction.get(reactionRef);

      if (!postDoc.exists) {
        throw Exception('Post does not exist');
      }

      final currentReaction = reactionDoc.exists
          ? (reactionDoc.data()?['reaction'] as String?)
          : null;

      if (currentReaction == null) {
        // CASE 1: User has no previous reaction - add new reaction
        transaction.set(reactionRef, {'reaction': reactionType});
        transaction.update(postRef, {
          '${reactionType}Count': FieldValue.increment(1),
        });
      } else if (currentReaction == reactionType) {
        // CASE 2: User already selected same reaction - remove it (toggle off)
        transaction.delete(reactionRef);
        transaction.update(postRef, {
          '${reactionType}Count': FieldValue.increment(-1),
        });
      } else {
        // CASE 3: User changes reaction - switch from old to new
        transaction.set(reactionRef, {'reaction': reactionType});
        transaction.update(postRef, {
          '${currentReaction}Count': FieldValue.increment(-1),
          '${reactionType}Count': FieldValue.increment(1),
        });
      }
    });
  }

  Future<String?> getUserReaction(String postId, String userId) async {
    final doc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .get();

    if (doc.exists) {
      return doc.data()?['reaction'] as String?;
    }
    return null;
  }

  Stream<DocumentSnapshot> getUserReactionStream(String postId, String userId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('reactions')
        .doc(userId)
        .snapshots();
  }

  // Announcement operations
  Future<void> createAnnouncement(AnnouncementModel announcement) async {
    final docRef = await _firestore
        .collection('announcements')
        .add(announcement.toFirestore());
    // Update the announcement with the generated ID
    await docRef.update({'id': docRef.id});
  }

  Future<List<AnnouncementModel>> getAnnouncements({int limit = 20}) async {
    QuerySnapshot snapshot = await _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map(
          (doc) => AnnouncementModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        )
        .toList();
  }

  Stream<QuerySnapshot> getAnnouncementsStream() {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).delete();
  }

  Future<void> updateAnnouncement(AnnouncementModel announcement) async {
    await _firestore
        .collection('announcements')
        .doc(announcement.id)
        .update(announcement.toFirestore());
  }

  // Blood donor operations
  Stream<QuerySnapshot> getBloodDonors(
    String bloodGroup,
    String currentUserId,
  ) {
    print('DEBUG: getBloodDonors called');
    print('  bloodGroup: $bloodGroup');
    print('  currentUserId: $currentUserId');

    return _firestore
        .collection('users')
        .where('isBloodDonor', isEqualTo: true)
        .where('bloodGroup', isEqualTo: bloodGroup)
        .snapshots();
  }

  // Notification operations
  Future<void> createNotification(NotificationModel notification) async {
    await _firestore
        .collection('notifications')
        .add(notification.toFirestore());
  }

  Stream<List<NotificationModel>> getNotificationsForUser({
    required String userId,
    required String userMandal,
  }) {
    return _firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => NotificationModel.fromFirestore(
                  doc.data(),
                  doc.id,
                ),
              )
              .where((notification) {
                final targetUserId = notification.targetUserId?.trim() ?? '';
                final targetMandal = notification.targetMandal.trim();
                final normalizedUserMandal = userMandal.trim();

                if (targetUserId.isNotEmpty) {
                  return targetUserId == userId;
                }

                if (targetMandal.isEmpty) {
                  return true;
                }

                return targetMandal.toLowerCase() ==
                    normalizedUserMandal.toLowerCase();
              })
              .toList();
        });
  }

  Stream<int> getUnreadNotificationCount({
    required String userId,
    required String userMandal,
  }) {
    return getNotificationsForUser(userId: userId, userMandal: userMandal).map(
      (notifications) => notifications.where((n) => !n.isRead).length,
    );
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }
}
