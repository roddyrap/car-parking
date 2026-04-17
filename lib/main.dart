import 'package:car_parking_tracker/auth_gate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:car_parking_tracker/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider('6LeTzoMsAAAAACcZJYEmnMoCDWHexD_hT9bnCxq-'),
  );

  FirebaseUIAuth.configureProviders([
    GoogleProvider(clientId: '...'),
    EmailAuthProvider(),
  ]);

  await initSavedTheme();

  runApp(const CarParkingTrackerApp());
}

class CarParkingTrackerApp extends StatelessWidget {
  const CarParkingTrackerApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Car Parking Tracker',
          theme: ThemeData(
            colorScheme: .fromSeed(seedColor: Color(0xff0083ff), brightness: Brightness.light),
            extensions: [
              CarStatusColors(
                occupiedByMeColor: Colors.blue.shade100,
                occupiedByOtherColor: Colors.red.shade100,
              )
            ]
          ),
          darkTheme: ThemeData(
            colorScheme: .fromSeed(seedColor: Color(0xff0083ff), brightness: Brightness.dark),
            extensions: [
              CarStatusColors(
                occupiedByMeColor: Colors.blue.shade900,
                occupiedByOtherColor: Colors.pink.shade900,
              )
            ]
          ),
          themeMode: themeMode,
          home: const AuthGate(),
        );
      }
    );
  }
}
