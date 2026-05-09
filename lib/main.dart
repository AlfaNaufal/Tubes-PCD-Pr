// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'auth/controller/auth_controller.dart';
import 'auth/model/user_model.dart';
import 'auth/view/login_view.dart';
import 'inspection/view/camera_view.dart';
import 'inspection/view/inspection_home_view.dart'; // ← baru

// ── Stub imports — uncomment saat role lain sudah siap ───────────────────────
// import 'core/env_config.dart';                             // Role 3
// import 'dashboard/controller/dashboard_controller.dart';  // Role 4
// import 'dashboard/view/dashboard_view.dart';              // Role 4
// import 'dashboard/view/history_view.dart';                // Role 4
// import 'inspection/controller/inspection_controller.dart';// Role 2

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientasi: portrait only ──────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Hive init (Role 4) ────────────────────────────────────────────────────
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);
  // TODO Role 4: Daftarkan adapter Hive setelah generate
  // Hive.registerAdapter(InspectionSessionModelAdapter());
  // Hive.registerAdapter(APDResultAdapter());

  // ── Env config init (Role 3) ──────────────────────────────────────────────
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFB800),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          useMaterial3: true,
        ),
        home: const _AuthGate(),
        routes: {
          '/login': (_) => const LoginView(),
          // Inspector routes
          '/inspection/home': (_) => const InspectionHomeView(), // ← baru
          '/inspection/camera': (_) => const CameraView(), // ← baru (spesifik)
          // Alias lama — tetap ada agar tidak ada referensi yang rusak
          '/inspection': (_) => const InspectionHomeView(), // ← arahkan ke home
          // '/dashboard': (_) => const DashboardView(), // Role 4
          // '/history':   (_) => const HistoryView(),   // Role 4
        },
      ),
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────

/// Menentukan halaman awal berdasarkan status autentikasi dan role.
///
/// Flow:
///   Belum login          → LoginView
///   hse_inspector        → InspectionHomeView   ← diubah dari CameraView
///   hse_supervisor       → DashboardView (stub: _RolePlaceholder)
///   unknown              → paksa logout → LoginView
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) return const LoginView();

        final user = auth.currentUser!;

        // Role tidak dikenal → paksa logout
        if (user.role == UserRole.unknown) {
          WidgetsBinding.instance.addPostFrameCallback((_) => auth.logout());
          return const LoginView();
        }

        // Supervisor → Dashboard (stub sampai Role 4 siap)
        if (user.isSupervisor) {
          // TODO: return const DashboardView();
          return _RolePlaceholder(
            role: user.role.displayName,
            destination: 'Dashboard Supervisor',
            icon: Icons.dashboard_outlined,
          );
        }

        // HSE Inspector → Inspection Home (bukan langsung CameraView)
        return const InspectionHomeView();
      },
    );
  }
}

// ── Role Placeholder (supervisor, sementara sampai Role 4 siap) ───────────────

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
