// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'auth/controller/auth_controller.dart';
import 'auth/model/user_model.dart';
import 'auth/view/login_view.dart';
import 'core/env_config.dart';

// ── Stub imports — uncomment saat role lain sudah siap ───────────────────────
// import 'dashboard/controller/dashboard_controller.dart';
// import 'dashboard/view/dashboard_view.dart';
// import 'dashboard/view/history_view.dart';
// import 'inspection/controller/inspection_controller.dart';
// import 'inspection/view/camera_view.dart';
// import 'inspection/view/session_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientasi: portrait only (kamera K3 selalu portrait) ─────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Hive init (Role 4) ────────────────────────────────────────────────────
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);
  // TODO Role 4: Daftarkan adapter Hive di sini setelah generate
  // Hive.registerAdapter(InspectionSessionModelAdapter());
  // Hive.registerAdapter(APDResultAdapter());

  // ── Env config init (Role 3 & 2) ─────────────────────────────────────────
  // EnvConfig.init() membaca nilai dari assets/.env
  // TODO: uncomment saat env_config.dart sudah diisi Role 3
  // await EnvConfig.init();

  runApp(const APDGuardApp());
}

class APDGuardApp extends StatelessWidget {
  const APDGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Role 1: Auth ────────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => AuthController()),

        // ── Role 4: Dashboard (uncomment saat siap) ─────────────────────────
        // ChangeNotifierProvider(create: (_) => DashboardController()),

        // ── Role 2+3: Inspection (uncomment saat siap) ──────────────────────
        // ChangeNotifierProvider(create: (_) => InspectionController()),
      ],
      child: MaterialApp(
        title: 'APD Guard',
        debugShowCheckedModeBanner: false,

        // ── Tema aplikasi ───────────────────────────────────────────────────
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFB800),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          useMaterial3: true,
        ),

        // ── Entry point: selalu mulai dari login ────────────────────────────
        home: const _AuthGate(),

        // ── Named routes ────────────────────────────────────────────────────
        routes: {
          '/login': (_) => const LoginView(),

          // Role 1 → halaman inspeksi kamera
          // '/inspection': (_) => const CameraView(),

          // Role 4 → dashboard supervisor & riwayat
          // '/dashboard': (_) => const DashboardView(),
          // '/history': (_) => const HistoryView(),
        },

        // ── Route guard: redirect berdasarkan role ───────────────────────────
        onGenerateRoute: (settings) {
          // Digunakan untuk route yang butuh cek autentikasi/RBAC
          // Implementasi lengkap bisa memakai GoRouter di iterasi berikutnya
          return null;
        },
      ),
    );
  }
}

/// _AuthGate menentukan halaman awal berdasarkan status autentikasi.
/// - Belum login → LoginView
/// - Sudah login sebagai hse_inspector → CameraView (stub: LoginView sementara)
/// - Sudah login sebagai supervisor → DashboardView (stub: LoginView sementara)
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        // Belum autentikasi
        if (!auth.isAuthenticated) {
          return const LoginView();
        }

        final user = auth.currentUser!;

        // Supervisor → Dashboard
        if (user.isSupervisor) {
          // TODO: return const DashboardView();
          return _RolePlaceholder(
            role: user.role.displayName,
            destination: 'Dashboard Supervisor',
            icon: Icons.dashboard_outlined,
          );
        }

        // HSE Inspector → Halaman Kamera
        // TODO: return const CameraView();
        return _RolePlaceholder(
          role: user.role.displayName,
          destination: 'Halaman Inspeksi Kamera',
          icon: Icons.camera_alt_outlined,
        );
      },
    );
  }
}

/// Placeholder sementara sampai Role 2/3/4 siap diintegrasikan.
/// Hapus class ini setelah semua CameraView & DashboardView tersedia.
class _RolePlaceholder extends StatelessWidget {
  final String role;
  final String destination;
  final IconData icon;

  const _RolePlaceholder({
    required this.role,
    required this.destination,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFB800).withOpacity(0.4),
                    ),
                  ),
                  child: Icon(icon, color: const Color(0xFFFFB800), size: 36),
                ),
                const SizedBox(height: 24),
                Text(
                  'Login berhasil sebagai\n$role',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Menunggu integrasi:\n$destination',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => auth.logout(),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    side: const BorderSide(color: Color(0xFF30363D)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
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
}
