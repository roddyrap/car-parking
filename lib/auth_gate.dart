import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:car_parking_tracker/cars_view/cars_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loadingSignRemoved = false;

  void _removeLoadingSign() {
    if (_loadingSignRemoved) return;
    _loadingSignRemoved = true;

    // Wait until the current frame finishes rendering.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loaderElement = web.document.querySelector('#loading-screen');
      loaderElement?.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Return nothing becuase the HTML loading indicator exists.
        print("Autgate connection state: ${snapshot.connectionState}");
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); 
        }

        _removeLoadingSign();

        if (!snapshot.hasData) {
          return const SignInScreen();
        }

        return const CarsPage(); 
      },
    );
  }
}