// lib/auth/controller/auth_controller.dart

import 'package:flutter/foundation.dart';
import '../model/user_model.dart';

/// State enum untuk status autentikasi
enum AuthStatus { idle, loading, authenticated, error }

/// AuthController menggunakan ChangeNotifier (kompatibel dengan Provider dari Proyek 4).
/// Bertanggung jawab atas:
/// - Login dengan email + password
/// - Penyimpanan sesi user (in-memory; bisa diperluas ke Hive)
/// - RBAC: expose role user agar view dapat menyesuaikan tampilan
class AuthController extends ChangeNotifier {
  AuthStatus _status = AuthStatus.idle;
  UserModel? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // ── Login ────────────────────────────────────────────────────────────────

  /// Login menggunakan email dan password.
  /// Untuk saat ini menggunakan mock data; ganti dengan MongoDB/REST call sesuai Proyek 4.
  Future<void> login({required String email, required String password}) async {
    _setLoading();

    try {
      // Simulasi network delay (ganti dengan actual API call dari Proyek 4)
      await Future.delayed(const Duration(milliseconds: 800));

      final user = _mockAuthenticate(email: email, password: password);

      if (user == null) {
        _setError('Email atau password salah.');
        return;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Terjadi kesalahan: ${e.toString()}');
    }
  }

  /// Logout: hapus sesi dan kembali ke idle
  void logout() {
    _currentUser = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ── RBAC Helpers ─────────────────────────────────────────────────────────

  /// Cek apakah user yang login boleh akses rute tertentu.
  /// Digunakan oleh GoRouter atau Navigator guard.
  bool canAccess(UserRole requiredRole) {
    if (_currentUser == null) return false;
    // Supervisor bisa akses semua; PetugasK3 hanya role-nya sendiri
    if (_currentUser!.role == UserRole.supervisor) return true;
    return _currentUser!.role == requiredRole;
  }

  // ── Private Helpers ──────────────────────────────────────────────────────

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  /// Mock auth — sesuai data MongoDB Atlas (project-4 > apd_detection_db > users).
  /// Password di MongoDB sudah di-hash; untuk mock kita terima plaintext lalu
  /// ganti dengan bcrypt/hash comparison saat integrasi penuh.
  ///
  /// Struktur dokumen aktual:
  /// { _id: ObjectId, name, email, password (hashed), role, created_at }
  /// Role yang diketahui: "hse_inspector", "supervisor"
  UserModel? _mockAuthenticate({
    required String email,
    required String password,
  }) {
    // Mock credentials — ganti dengan query MongoDB + hash verify dari Proyek 4
    const mockUsers = [
      {
        '_id': '69fdeecee2d5ab000000001', // contoh ObjectId hex
        'name': 'Budi Santoso',
        'email': 'budi@k3.com', // sesuai data MongoDB
        'password': 'hashed_password', // placeholder; cocokkan dengan bcrypt
        'role': 'hse_inspector', // sesuai nilai di MongoDB
        'created_at': '2026-05-08T14:10:22.000Z',
      },
      {
        '_id': '69fdeecee2d5ab000000002',
        'name': 'Admin Supervisor',
        'email': 'supervisor@k3.com',
        'password': 'supervisor123',
        'role': 'supervisor',
        'created_at': '2026-05-08T14:10:22.000Z',
      },
    ];

    for (final u in mockUsers) {
      // TODO: ganti perbandingan password dengan BCrypt.checkpw() dari Proyek 4
      if (u['email'] == email && u['password'] == password) {
        return UserModel.fromMap(Map<String, dynamic>.from(u));
      }
    }
    return null;
  }
}
