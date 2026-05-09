import 'package:flutter/material.dart';
import 'inference/service/apd_interpreter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APD Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const APDHome(),
    );
  }
}

class APDHome extends StatefulWidget {
  const APDHome({super.key});

  @override
  State<APDHome> createState() => _APDHomeState();
}

class _APDHomeState extends State<APDHome> {
  final ApdInterpreter _interpreter = ApdInterpreter();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _setupInterpreter();
  }

  Future<void> _setupInterpreter() async {
    try {
      await _interpreter.init();
      setState(() {
        _isReady = true;
      });
    } catch (e) {
      debugPrint("Error initializing interpreter: $e");
    }
  }

  @override
  void dispose() {
    _interpreter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isReady
            ? const Text('APD Detection App Ready!')
            : const CircularProgressIndicator(),
      ),
    );
  }
}
