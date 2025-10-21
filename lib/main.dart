import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:huruchat/firebase_options.dart';
import 'package:huruchat/screens/auth/phone_screen.dart';
import 'package:huruchat/screens/auth/register_screen.dart';
import 'package:huruchat/screens/auth/login_screen.dart';
import 'package:huruchat/screens/chat/presence_service.dart';
import 'package:huruchat/screens/home/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/theme/app_theme.dart';
import 'screens/profile/account_screen.dart';
import 'welcome_screen.dart';

final presenceService = PresenceService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Hive.initFlutter();
  await Hive.openBox('messages');
  presenceService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HURUchat App',
      theme: AppTheme.lightTheme, // ✅ Use custom theme
      darkTheme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
      routes: {
        '/welcome_screen': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/phone': (context) => const PhoneAuthPage(),
        '/account_settings': (context) => const AccountScreen(),
      },
    );
  }
}
