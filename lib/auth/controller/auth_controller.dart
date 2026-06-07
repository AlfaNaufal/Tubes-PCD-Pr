import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_model.dart';

/// State enum untuk status autentikasi
enum AuthStatus { idle, loading, authenticated, error }

/// - Login dengan email + password
/// - Auto login: sesi disimpan ke SharedPreferences, restore saat app dibuka
/// - Logout: hapus sesi dari memory + SharedPreferences
/// - RBAC: login berdasarkan role user agar view dapat menyesuaikan tampilan
class AuthController extends ChangeNotifier {
  AuthStatus _status = AuthStatus.idle;
  UserModel? _currentUser;
  String? _errorMessage;

  static const _kSessionKey = 'apd_guard_session';

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  // ── Auto Login ────────────────────────────────────────────────────────────

  Future<void> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_kSessionKey);

      if (sessionJson == null) return;

      final map = jsonDecode(sessionJson) as Map<String, dynamic>;
      final user = UserModel.fromMap(map);

      if (user.role == UserRole.unknown) {
        await prefs.remove(_kSessionKey);
        return;
      }

      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
      debugPrint('Session restore failed: $e');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  /// Login menggunakan email dan password.
  Future<void> login({required String email, required String password}) async {
    _setLoading();

    try {
      await Future.delayed(const Duration(milliseconds: 800));

      final user = _mockAuthenticate(email: email, password: password);

      if (user == null) {
        _setError('Email atau password salah.');
        return;
      }

      await _saveSession(user);

      _currentUser = user;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Terjadi kesalahan: ${e.toString()}');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionKey);
    } catch (e) {
      debugPrint('Logout clear session error: $e');
    }

    _currentUser = null;
    _status = AuthStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  // ── RBAC Helpers ──────────────────────────────────────────────────────────

  bool canAccess(UserRole requiredRole) {
    if (_currentUser == null) return false;
    if (_currentUser!.role == UserRole.supervisor) return true;
    return _currentUser!.role == requiredRole;
  }

  // ── Private Helpers ───────────────────────────────────────────────────────

  Future<void> _saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionKey, jsonEncode(user.toMap()));
  }

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

  /// Mock auth — sesuai data MongoDB Atlas.
  UserModel? _mockAuthenticate({
    required String email,
    required String password,
  }) {
    const mockUsers = [
      {
        '_id': '69fdeecee2d5ab000000001',
        'name': 'Budi Santoso',
        'email': 'budi@k3.com',
        'password': 'inspector123',
        'role': 'hse_inspector',
        'created_at': '2026-05-08T14:10:22.000Z',
      },
      {
        '_id': '69fe936c6a60b7000000002',
        'name': 'Admin Supervisor',
        'email': 'supervisor@k3.com',
        'password': 'supervisor123',
        'role': 'hse_supervisor',
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
