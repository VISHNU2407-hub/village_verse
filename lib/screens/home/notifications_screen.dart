import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/complaint_model.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/helpers.dart';
import 'complaint_detail_screen.dart';
import 'info_screen.dart';
import 'missing_person_alerts_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final UserModel currentUser;

  const NotificationsScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: firestoreService.getNotificationsForUser(
          userId: userId,
          userMandal: currentUser.mandal,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load notifications',
                style: TextStyle(color: Colors.red.shade300),
              ),
            );
          }

          final notifications = snapshot.data ?? <NotificationModel>[];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                onTap: () async {
                  if (!notification.isRead) {
                    await firestoreService.markNotificationAsRead(
                      notification.id,
                    );
                  }
                  await _navigateFromNotification(context, notification);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 56,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 12),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will see alerts and updates here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateFromNotification(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final relatedId = notification.relatedDocumentId?.trim() ?? '';

    switch (notification.type) {
      case 'missing_person':
        if (relatedId.isEmpty) {
          _showMissingLinkMessage(context);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MissingPersonAlertsScreen(initialAlertId: relatedId),
          ),
        );
        return;
      case 'complaint':
        if (relatedId.isEmpty) {
          _showMissingLinkMessage(context);
          return;
        }
        final complaintDoc = await FirebaseFirestore.instance
            .collection('complaints')
            .doc(relatedId)
            .get();
        if (!complaintDoc.exists || complaintDoc.data() == null) {
          _showRecordNotFoundMessage(context);
          return;
        }
        final complaint = ComplaintModel.fromFirestore(
          complaintDoc.data()!,
          complaintDoc.id,
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaint: complaint),
          ),
        );
        return;
      case 'community_post':
        if (relatedId.isEmpty) {
          _showMissingLinkMessage(context);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InfoScreen(initialPostId: relatedId),
          ),
        );
        return;
      case 'system':
        AppHelpers.showSnackBar(context, 'Opened: ${notification.title}', color: Colors.green);
        break;
      default:
        AppHelpers.showSnackBar(context, 'Opened notification', color: Colors.green);
    }
  }

  void _showMissingLinkMessage(BuildContext context) {
    AppHelpers.showSnackBar(
      context,
      'This notification has no linked item.',
      color: Colors.red,
    );
  }

  void _showRecordNotFoundMessage(BuildContext context) {
    AppHelpers.showSnackBar(
      context,
      'The related item was not found.',
      color: Colors.red,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notification.isRead;
    final iconData = _iconForType(notification.type);
    final iconColor = _colorForType(notification.type);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead ? Colors.grey.shade200 : iconColor.withOpacity(0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppHelpers.formatDateTime(notification.createdAt),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isRead ? Colors.grey.shade400 : Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isRead ? 'Read' : 'Unread',
                            style: TextStyle(
                              fontSize: 12,
                              color: isRead ? Colors.grey.shade600 : Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'missing_person':
        return Icons.person_search;
      case 'complaint':
        return Icons.report_problem_outlined;
      case 'community_post':
        return Icons.campaign_outlined;
      case 'system':
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'missing_person':
        return Colors.orange;
      case 'complaint':
        return Colors.redAccent;
      case 'community_post':
        return Colors.blueAccent;
      case 'system':
      default:
        return Colors.teal;
    }
  }
}
