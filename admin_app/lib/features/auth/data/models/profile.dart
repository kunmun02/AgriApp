/// Profile model — mirrors customer_app's profile exactly.
///
/// Role strings from the DB are lowercase ('customer', 'admin').
/// Any unrecognised value maps to [ProfileRole.customer] (safe default).
enum ProfileRole {
  customer,
  admin;

  static ProfileRole fromJson(String? value) {
    switch (value) {
      case 'admin':
        return ProfileRole.admin;
      default:
        return ProfileRole.customer;
    }
  }

  String toJson() => name; // 'customer' | 'admin'
}

/// Immutable profile record.
class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final ProfileRole role;
  final bool isActive;
  final DateTime createdAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: ProfileRole.fromJson(json['role'] as String?),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role.toJson(),
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  Profile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    ProfileRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Profile(id: $id, email: $email, role: ${role.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Profile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
