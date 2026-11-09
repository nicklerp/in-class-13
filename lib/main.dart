import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// Generated for YOUR registered Flutter app by flutterfire configure.
// Copy it from your Part 1 app if you are keeping the SAME Android app,
// or rerun flutterfire configure against the SAME Firebase project.
import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autumn Product Manager',
      theme: ThemeData(
        colorSchemeSeed: Colors.brown,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
