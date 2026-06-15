import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fyp/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'app_localizations.dart';
import 'UserAccount/login.dart';
import 'UserAccount/welcome_screen.dart';
import 'User/main_screen.dart';
import 'Counsellor/counsellor_main.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Stripe
  Stripe.publishableKey = 'pk_test_51Tdp70GqRs3M9AcHB0xHdGDGuOunAIR0WO2ws0JKcpn9cFawsEwKHnCL8rNe8B15fkhNabnYQi8KPaTLUbvMRCqE00HH6OsTat';
  await Stripe.instance.applySettings();

  // Initialize Firebase Cloud Messaging for Push Notifications
  await FCMService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final String languageCode = prefs.getString('languageCode') ?? 'en';

  runApp(MyApp(defaultLocale: Locale(languageCode)));
}

class MyApp extends StatelessWidget {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));

  MyApp({super.key, Locale? defaultLocale}) {
    if (defaultLocale != null) {
      localeNotifier.value = defaultLocale;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, child) {
        return MaterialApp(
          title: 'Eunoia',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('zh', ''),
            Locale('ms', ''),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: const Color(0xFFF2F1EC));
        }

        if (snapshot.hasData) {
          final User user = snapshot.data!;
          
          // Ensure FCM token is registered now that we definitely have a user
          FCMService.registerToken();

          // We check if the user has a completed profile in Firestore
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator(color: Color(0xFF7B9E89))),
                );
              }

              // If the user document doesn't exist, they haven't finished registration.
              // We keep them on the LoginPage/Registration flow.
              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                // Check if it's a first-time entry (from login/start) or a rebuild
                // Since we want the splash only on fresh login/start,
                // we can check if we were already showing something else
                return FutureBuilder<SharedPreferences>(
                  future: SharedPreferences.getInstance(),
                  builder: (context, prefsSnapshot) {
                    if (!prefsSnapshot.hasData) {
                      return Container(color: const Color(0xFFF2F1EC));
                    }

                    final prefs = prefsSnapshot.data!;
                    final String lastSide = prefs.getString('last_used_side') ?? 'user';

                    // If it's the first time in this build cycle or fresh login
                    // we show the splash. But to avoid lag during app use,
                    // we could show the main content directly.

                    // For simplicity and to solve the lag, we'll return the screen directly here.
                    // The SplashTransitionScreen should be used explicitly from Welcome/Login
                    // Register/refresh FCM token now that we know the user is logged in
                    FCMService.registerToken();

                    if (lastSide == 'counsellor') {
                      return const CounsellorMainScreen();
                    } else {
                      return const MainScreen();
                    }
                  },
                );
              } else {
                return const LoginPage();
              }
            },
          );  
        }
        return const WelcomeScreen();
      },
    );
  }
}
