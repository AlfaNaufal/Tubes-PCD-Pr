// lib/auth/model/user_model.dart

/// Role sesuai nilai di koleksi MongoDB: field "role"
///
/// Nilai aktual dari MongoDB Atlas (apd_detection_db > users):
///   "hse_inspector"  → Petugas K3
///   "hse_supervisor" → Admin/Supervisor
///   "supervisor"     → alias lama, tetap didukung (backward-compat)
enum UserRole {
  hseInspector, // "hse_inspector"
  supervisor, // "hse_supervisor" atau "supervisor"
  unknown, // fallback jika ada role tidak dikenal
}

extension UserRoleX on UserRole {
  /// Nilai string canonical yang tersimpan di MongoDB
  String get dbValue {
    switch (this) {
      case UserRole.hseInspector:
        return 'hse_inspector';
      case UserRole.supervisor:
        return 'hse_supervisor'; // nilai aktual di MongoDB
      case UserRole.unknown:
        return 'unknown';
    }
  }

  /// Label tampilan di UI
  String get displayName {
    switch (this) {
      case UserRole.hseInspector:
        return 'HSE Inspector';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.unknown:
        return 'Unknown';
    }
  }

  /// Parse string role dari MongoDB → enum.
  /// Mendukung "hse_supervisor" (nilai aktual) dan "supervisor" (lama).
  static UserRole fromString(String? value) {
    switch (value) {
      case 'hse_inspector':
        return UserRole.hseInspector;
      case 'hse_supervisor': // nilai aktual di MongoDB Atlas
      case 'supervisor': // backward-compat
        return UserRole.supervisor;
      default:
        return UserRole.unknown;
    }
  }
}

class UserModel {
  /// ObjectId MongoDB disimpan sebagai String hex (24 karakter)
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  // ── RBAC helpers ──────────────────────────────────────────────────────────

  bool get isSupervisor => role == UserRole.supervisor;
  bool get isHseInspector => role == UserRole.hseInspector;

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Parse dari dokumen MongoDB.
  /// [map] boleh berisi ObjectId sebagai String atau Map {'\$oid': '...'}.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawId = map['_id'];
    final String id;
    if (rawId is Map) {
      id = rawId['\$oid'] as String? ?? rawId['oid'] as String? ?? '';
    } else {
      id = rawId?.toString() ?? '';
    }

    DateTime? createdAt;
    final rawDate = map['created_at'];
    if (rawDate is DateTime) {
      createdAt = rawDate;
    } else if (rawDate is String) {
      createdAt = DateTime.tryParse(rawDate);
    } else if (rawDate is Map) {
      final ms = rawDate['\$date'];
      if (ms is int) createdAt = DateTime.fromMillisecondsSinceEpoch(ms);
    }

    return UserModel(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: UserRoleX.fromString(map['role'] as String?),
      createdAt: createdAt,
    );
  }

  /// Serialize untuk disimpan ke Hive atau dikirim ke API.
  /// Password TIDAK pernah disimpan di sisi klien.
  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role.dbValue,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'UserModel(id: $id, name: $name, email: $email, role: ${role.dbValue})';
}
