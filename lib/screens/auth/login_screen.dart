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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _obscure = true;
  bool _loading = false;

  late AnimationController _animationController;
  late Animation<double> _animation;
  final themeColor = const Color(0xFF497A72);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

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
    if (!mounted) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C1C1C) : const Color(0xFFFFEBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      message,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _loading = true);
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user == null) throw Exception('Failed to get user');

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!doc.exists || !(doc.data()?['name']?.isNotEmpty ?? false)) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()));
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      _showError("Google Sign-In Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final dot1Scale = _animation.value;
            final dot2Scale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.3, 1.0, curve: Curves.easeInOut))).value;
            final dot3Scale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeInOut))).value;
            const dot = Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: CircleAvatar(radius: 4, backgroundColor: Colors.white));
            return Row(children: [Transform.scale(scale: dot1Scale, child: dot), Transform.scale(scale: dot2Scale, child: dot), Transform.scale(scale: dot3Scale, child: dot)]);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF12151B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fieldFillColor = isDark ? const Color(0xFF1E222D) : const Color(0xFFF4F4F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text("Hey,", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 6),
                Text("Welcome Back", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: textColor)),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Enter your email",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.white70 : Colors.grey[700]),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim()) ? 'Enter a valid email' : null),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _passwordCtl,
                        obscureText: _obscure,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Enter your password",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white70 : Colors.grey[700]),
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: isDark ? Colors.white70 : Colors.grey), onPressed: () => setState(() => _obscure = !_obscure)),
                          filled: true,
                          fillColor: fieldFillColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : (v.length < 6 ? 'Minimum 6 characters' : null),
                      ),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: Text("Forgot Password?", style: TextStyle(color: themeColor)))),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _loginWithEmail,
                          style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          child: _loading ? _buildLoadingIndicator() : const Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(child: Divider(thickness: 0.8, color: isDark ? Colors.white24 : Colors.grey)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("Or Continue with", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600]))),
                          Expanded(child: Divider(thickness: 0.8, color: isDark ? Colors.white24 : Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton("assets/images/google.png", _loginWithGoogle, isDark),
                          const SizedBox(width: 18),
                          _socialButton("assets/images/phone.png", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneAuthPage())), isDark),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don’t have an Account? ", style: TextStyle(color: textColor)),
                          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: Text("Sign-Up", style: TextStyle(color: themeColor, fontWeight: FontWeight.w600))),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(14),
        child: Image.asset(asset),
      ),
    );
  }
}
