import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String mandal;
  final String village;
  final String photoUrl;
  final String age;
  final String bloodGroup;
  final String role;
  final bool isBloodDonor;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.mandal,
    required this.village,
    required this.photoUrl,
    required this.age,
    required this.bloodGroup,
    required this.role,
    this.isBloodDonor = false,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  // Create from Firestore document
  // Maps old field names (village/street) to new terminology (mandal/village)
  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      mandal: data['village'] ?? '', // Maps Firestore 'village' to 'mandal'
      village: data['street'] ?? '', // Maps Firestore 'street' to 'village'
      photoUrl: data['photoUrl'] ?? '',
      age: data['age'] ?? '',
      bloodGroup: data['bloodGroup'] ?? '',
      role: data['role'] ?? 'citizen', // Default to citizen if not set
      isBloodDonor: data['isBloodDonor'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
    );
  }

  // Convert to Firestore document
  // Maps new terminology (mandal/village) to old field names (village/street)
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'village': mandal, // Maps 'mandal' to Firestore 'village'
      'street': village, // Maps 'village' to Firestore 'street'
      'photoUrl': photoUrl,
      'age': age,
      'bloodGroup': bloodGroup,
      'role': role,
      'isBloodDonor': isBloodDonor,
      'createdAt': Timestamp.fromDate(createdAt),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  // Create copy with updated fields
  UserModel copyWith({
    String? name,
    String? phone,
    String? mandal,
    String? village,
    String? photoUrl,
    String? age,
    String? bloodGroup,
    String? role,
    bool? isBloodDonor,
    double? latitude,
    double? longitude,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      mandal: mandal ?? this.mandal,
      village: village ?? this.village,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      role: role ?? this.role,
      isBloodDonor: isBloodDonor ?? this.isBloodDonor,
      createdAt: createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() {
    return 'UserModel(uid: $uid, name: $name, phone: $phone, mandal: $mandal, village: $village, photoUrl: $photoUrl, age: $age, bloodGroup: $bloodGroup, role: $role, isBloodDonor: $isBloodDonor, createdAt: $createdAt)';
  }
}
