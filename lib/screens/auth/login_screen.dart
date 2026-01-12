import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'complete_profile.dart';
import '../home/home_screen.dart';
import 'phone_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// 1. ADD TickerProviderStateMixin
class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscure = true;
  bool _loading = false;

  // 2. Animation controller and animation for the pulsating dots
  late AnimationController _animationController;
  late Animation<double> _animation;
  final themeColor = const Color(0xFF497A72); // Defined here for use in methods

  @override
  void initState() {
    super.initState();
    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Define the animation: goes from 0.5 (smaller) to 1.0 (larger) and back
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  // Email/Password login
  /// 🔐 Login with Email & Password
  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text.trim(),
      );

      final user = cred.user;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (!doc.exists || !(doc.data()?['name']?.isNotEmpty ?? false)) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = 'Login failed. Please try again later.';
      }

      _showError(message);
    } catch (_) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("❌ $message")));
  }

  // Google login
  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _loading = true);

      if (kDebugMode) print('🔄 Starting Google Sign-In...');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        if (kDebugMode) print('❌ Google Sign-In was cancelled by user');
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('Failed to get authentication tokens');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) {
        throw Exception('Failed to get user from Firebase');
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists || !(doc.data()?['name']?.isNotEmpty ?? false)) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Google Sign-In Error: $e');

      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Google Sign-In Error: $e"),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // 3. NEW: Animated Loading Indicator Widget
  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // Define scale based on animation for staggered effect
            final dot1Scale = _animation.value;
            final dot2Scale = Tween<double>(begin: 0.5, end: 1.0)
                .animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
                  ),
                )
                .value;
            final dot3Scale = Tween<double>(begin: 0.5, end: 1.0)
                .animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
                  ),
                )
                .value;

            const dot = Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
            );

            return Row(
              children: [
                Transform.scale(scale: dot1Scale, child: dot),
                Transform.scale(scale: dot2Scale, child: dot),
                Transform.scale(scale: dot3Scale, child: dot),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fieldFillColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF4F4F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Hey,",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 40),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email
                      TextFormField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Enter your email",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(
                            r'^[^@]+@[^@]+\.[^@]+',
                          ).hasMatch(v.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password
                      TextFormField(
                        controller: _passwordCtl,
                        obscureText: _obscure,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Enter your password",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: isDark ? Colors.white70 : Colors.grey,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 characters';
                          }
                          return null;
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(color: themeColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _loginWithEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _loading
                              ? _buildLoadingIndicator() // 4. REPLACED CircularProgressIndicator
                              : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              thickness: 0.8,
                              color: isDark ? Colors.white24 : Colors.grey,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              "Or Continue with",
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[600],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              thickness: 0.8,
                              color: isDark ? Colors.white24 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // Social Icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(
                            "assets/images/google.png",
                            _loginWithGoogle,
                            isDark,
                          ),

                          const SizedBox(width: 18),
                          _socialButton("assets/images/phone.png", () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PhoneAuthPage(),
                              ),
                            );
                          }, isDark),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // Sign up prompt
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don’t have an Account? ",
                            style: TextStyle(color: textColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: Text(
                              "Sign-Up",
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String asset, VoidCallback onPressed, bool isDark) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(asset),
      ),
    );
  }
}
