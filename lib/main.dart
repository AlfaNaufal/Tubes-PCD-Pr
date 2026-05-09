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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
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
  String _status = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initInterpreter();
  }

  Future<void> _initInterpreter() async {
    try {
      await _interpreter.init();
      setState(() {
        _status = 'Interpreter Ready!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _hasError = true;
      });
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
      appBar: AppBar(title: const Text('APD Detection Debug')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_hasError && _status == 'Initializing...')
              const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hasError ? Colors.red : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_hasError)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _status = 'Retrying...';
                  });
                  _initInterpreter();
                },
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
