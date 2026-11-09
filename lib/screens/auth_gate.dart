import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'authentication_screen.dart';
import 'signed_in_home.dart';

/// All signed-in pages are ONLY built inside the authenticated branch.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Unable to check sign-in status. Try again.'),
            ),
          );
        }
        if (snapshot.hasData) return const SignedInHome();
        return const AuthenticationScreen();
      },
    );
  }
}
