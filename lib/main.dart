import 'package:car_parking/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseUIAuth.configureProviders([
    GoogleProvider(clientId: '...'),
    EmailAuthProvider(),
  ]);

  runApp(const CarParkingApp());
}

class CarParkingApp extends StatelessWidget {
  const CarParkingApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Parking Assistant',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.white),
      ),
      home: const AuthGate(),
    );
  }
}
