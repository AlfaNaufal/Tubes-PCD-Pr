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

import 'inference/model/apd_result.dart';
import 'inspection/model/report_model.dart';
import 'supervisor/controller/dashboard_controller.dart';
import 'supervisor/view/dashboard_view.dart';

import 'inspection/controller/inspection_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Orientasi: portrait ──────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar ──────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Hive init & Registrasi Adapter ────────────────────────────────────────
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);

  Hive.registerAdapter(ApdResultAdapter());
  Hive.registerAdapter(ReportModelAdapter());

  // ── Env config init ───────────────────────────────────────────────────────
  await dotenv.load();
  // await EnvConfig.init();

  final dashboardController = DashboardController();
  await dashboardController.init();

  // await Hive.openBox<ReportModel>('reports_box');

  // ── Auto login: restore sesi sebelum runApp ─────────────────────────────
  // AuthController dibuat di sini agar tryRestoreSession() selesai
  // sebelum widget tree dibangun — langsung masuk tanpa loading screen.
  final authController = AuthController();
  await authController.tryRestoreSession();

  runApp(
    APDGuardApp(
      dashboardController: dashboardController,
      authController: authController,
    ),
  );
}

class APDGuardApp extends StatelessWidget {
  final DashboardController dashboardController;
  final AuthController authController;

  const APDGuardApp({
    super.key,
    required this.dashboardController,
    required this.authController,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),

        ChangeNotifierProvider.value(value: dashboardController),

        ChangeNotifierProvider(create: (_) => InspectionController()),
      ],
      child: MaterialApp(
        title: 'APD Guard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFB800),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),

        home: const _AuthGate(),
        routes: {
          '/login': (_) => const LoginView(),
          '/inspection/home': (_) => const InspectionHomeView(),
          '/inspection/camera': (_) => const CameraView(),
          '/inspection': (_) => const InspectionHomeView(),
          '/dashboard': (_) => const DashboardView(),
        },
      ),
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────

/// Menentukan halaman awal berdasarkan status autentikasi dan role.
///
/// Flow:
///   Belum login     → LoginView
///   hse_inspector   → InspectionHomeView
///   supervisor      → DashboardView
///   unknown         → paksa logout → LoginView
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

        // Supervisor → Dashboard
        if (user.isSupervisor) {
          return const DashboardView();
        }

        // HSE Inspector → Inspection Home
        return const InspectionHomeView();
      },
    );
  }
}
