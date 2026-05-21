// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth/controller/auth_controller.dart';
import 'auth/model/user_model.dart';
import 'auth/view/login_view.dart';
import 'inspection/view/camera_view.dart';
import 'inspection/view/inspection_home_view.dart';

// ── Import Tambahan untuk Role Supervisor & Database ─────────────────────
import 'inference/model/apd_result.dart';
import 'inspection/model/report_model.dart';
import 'supervisor/controller/dashboard_controller.dart';
import 'supervisor/view/dashboard_view.dart';

// ── Stub imports — uncomment saat role lain sudah siap ───────────────────
// import 'core/env_config.dart';                             // Role 3
// import 'dashboard/view/history_view.dart';                // Role 4
// import 'inspection/controller/inspection_controller.dart';// Role 2

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientasi: portrait only ──────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Hive init & Registrasi Adapter ────────────────────────────────────────
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);

  // Daftarkan adapter untuk database lokal
  Hive.registerAdapter(ApdResultAdapter());
  Hive.registerAdapter(ReportModelAdapter());

  // Hive.registerAdapter(InspectionSessionModelAdapter());

  // ── Env config init ───────────────────────────────────────────────────────
  await dotenv.load();
  // await EnvConfig.init();

  // ── Inisialisasi Database Controller Supervisor ───────────────────────────
  final dashboardController = DashboardController();
  await dashboardController.init(); // Buka box Hive dan muat data offline

  // Lempar controller yang sudah siap ke dalam App
  runApp(APDGuardApp(dashboardController: dashboardController));
}

class APDGuardApp extends StatelessWidget {
  final DashboardController dashboardController;

  const APDGuardApp({super.key, required this.dashboardController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Role 1: Auth ────────────────────────────────────────────────────
        ChangeNotifierProvider(create: (_) => AuthController()),

        // ── Role 4: Dashboard Supervisor ────────────────────────────────────
        ChangeNotifierProvider.value(value: dashboardController),

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
          '/inspection/home': (_) => const InspectionHomeView(),
          '/inspection/camera': (_) => const CameraView(),
          // Alias lama
          '/inspection': (_) => const InspectionHomeView(),
          // Supervisor routes
          '/dashboard': (_) => const DashboardView(),
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
///   hse_inspector        → InspectionHomeView
///   hse_supervisor       → DashboardView
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

        // Supervisor → Langsung masuk ke Dashboard Asli
        if (user.isSupervisor) {
          return const DashboardView();
        }

        // HSE Inspector → Inspection Home
        return const InspectionHomeView();
      },
    );
  }
}
