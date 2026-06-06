import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime createdAt;
  final String postedBy;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.createdAt,
    required this.postedBy,
  });

  // Create copy with updated fields
  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? createdAt,
    String? postedBy,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      postedBy: postedBy ?? this.postedBy,
    );
  }

  // Convert from Firestore document
  factory AnnouncementModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return AnnouncementModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.parse(data['createdAt']))
          : DateTime.now(),
      postedBy: data['postedBy'] ?? '',
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'postedBy': postedBy,
    };
  }

  @override
  String toString() {
    return 'AnnouncementModel(id: $id, title: $title, description: $description, imageUrl: $imageUrl, createdAt: $createdAt, postedBy: $postedBy)';
  }
}
