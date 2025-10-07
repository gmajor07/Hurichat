import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:huruchat/firebase_options.dart';
import 'package:huruchat/screens/phone_screen.dart';
import 'package:huruchat/screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  //  Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('messages');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HURUchat App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 76, 175, 170),
          brightness: Brightness.light,
        ),
        useMaterial3: true, // Enable Material 3 for better theming
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
      routes: {
        '/welcome_screen': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/phone': (context) => const PhoneAuthPage(),
      },
    );
  }
}
