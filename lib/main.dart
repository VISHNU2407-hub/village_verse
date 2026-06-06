import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile/guardian_setup_screen.dart';
import 'screens/profile/profile_setup_screen.dart';
import 'screens/home/main_screen.dart';
import 'screens/permissions_setup_screen.dart';

import 'services/firestore_service.dart';
import 'services/guardian_alert_service.dart';
import 'services/permissions_setup_service.dart';
import 'services/stealth_sos_trigger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await GuardianAlertService.instance.initialize();
  await StealthSOSTriggerService.instance.initialize();

  runApp(const VillageAssistanceApp());
}

class VillageAssistanceApp extends StatelessWidget {
  const VillageAssistanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Village Assistance',
      debugShowCheckedModeBanner: false,
      routes: {'/guardian-setup': (context) => const GuardianSetupScreen()},
      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),

        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),

          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 2,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),

        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          final User? user = snapshot.data;

          // User not logged in
          if (user == null) {
            return const AuthScreen();
          }

          // User logged in → check if profile exists
          return FutureBuilder<bool>(
            future: _checkProfileExists(user.uid),

            builder: (context, profileSnapshot) {
              // Loading while checking profile
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              // Error fallback - if error, assume profile doesn't exist
              if (profileSnapshot.hasError) {
                debugPrint('Profile check error: ${profileSnapshot.error}');
                return const ProfileSetupScreen();
              }

              final bool profileExists = profileSnapshot.data ?? false;

              // If profile doesn't exist → Profile Setup Screen
              if (!profileExists) {
                return const ProfileSetupScreen();
              }

              // Profile exists → Main Screen
              return FutureBuilder<bool>(
                future: PermissionsSetupService.isCompleted(),
                builder: (context, permissionSnapshot) {
                  if (permissionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const SplashScreen();
                  }

                  final bool setupCompleted =
                      permissionSnapshot.data ?? false;
                  if (!setupCompleted) {
                    return PermissionsSetupScreen(
                      onCompleted: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MainScreen(),
                          ),
                        );
                      },
                    );
                  }

                  return const MainScreen();
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Check if user profile exists in Firestore
  Future<bool> _checkProfileExists(String uid) async {
    try {
      final firestoreService = FirestoreService();
      final profile = await firestoreService.getUser(uid);
      return profile != null;
    } catch (e) {
      debugPrint('Profile Check Error: $e');
      return false;
    }
  }
}
