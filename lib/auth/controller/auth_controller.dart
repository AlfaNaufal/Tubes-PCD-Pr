// lib/auth/controller/auth_controller.dart

import 'package:flutter/foundation.dart';
import '../model/user_model.dart';

/// State enum untuk status autentikasi
enum AuthStatus { idle, loading, authenticated, error }

/// AuthController menggunakan ChangeNotifier (kompatibel dengan Provider).
///
/// Tanggung jawab:
/// - Login dengan email + password
/// - Penyimpanan sesi user (in-memory)
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
  /// Saat ini menggunakan mock data yang sesuai dengan dokumen aktual
  /// di MongoDB Atlas (apd_detection_db > users).
  /// TODO: ganti dengan MongoDB query + bcrypt verify dari Proyek 4.
  Future<void> login({required String email, required String password}) async {
    _setLoading();

    try {
      // Simulasi network delay
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
  /// Supervisor bisa akses semua; HSE Inspector hanya role-nya sendiri.
  bool canAccess(UserRole requiredRole) {
    if (_currentUser == null) return false;
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

  /// Mock auth — data SESUAI dengan dokumen aktual di MongoDB Atlas.
  ///
  /// Screenshot MongoDB menunjukkan:
  ///   Doc 1: email "budi@k3.com",       password "inspector123",  role "hse_inspector"
  ///   Doc 2: email "supervisor@k3.com", password "supervisor123", role "hse_supervisor"
  ///
  /// TODO: Ganti dengan MongoDB query + bcrypt.checkpw() saat integrasi penuh.
  UserModel? _mockAuthenticate({
    required String email,
    required String password,
  }) {
    const mockUsers = [
      {
        '_id': '69fdeecee2d5ab000000001',
        'name': 'Budi Santoso',
        'email': 'budi@k3.com',
        'password': 'inspector123', // sesuai MongoDB Atlas screenshot
        'role': 'hse_inspector',
        'created_at': '2026-05-08T14:10:22.000Z',
      },
      {
        '_id': '69fe936c6a60b7000000002',
        'name': 'Admin Supervisor',
        'email': 'supervisor@k3.com',
        'password': 'supervisor123',
        'role': 'hse_supervisor', // sesuai MongoDB Atlas screenshot
        'created_at': '2026-05-09T08:36:00.000Z',
      },
    ];

    for (final u in mockUsers) {
      if (u['email'] == email && u['password'] == password) {
        return UserModel.fromMap(Map<String, dynamic>.from(u));
      }
    }
    return null;
  }
}
