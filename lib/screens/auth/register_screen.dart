import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final Color themeColor = const Color(0xFF497A72);

  late AnimationController _animationController;
  late Animation<double> _animation;

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (password != confirmPassword) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showError('Google Sign-In failed');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.grey[700]),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF4F4F4),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF12151B) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Let's, Create\nAccount",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _inputDecoration('Enter your email', Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _inputDecoration('Enter your password', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[600]),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: _inputDecoration('Confirm your password', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[600]),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading ? _buildLoadingIndicator() : const Text('Create Account', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[400], thickness: 0.8)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Or Continue with', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  ),
                  Expanded(child: Divider(color: isDark ? Colors.white24 : Colors.grey[400], thickness: 0.8)),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon('assets/images/google.png', _signInWithGoogle, isDark),
                  const SizedBox(width: 18),
                  _socialIcon('assets/images/phone.png', () {
                    if (mounted) Navigator.pushNamed(context, '/phone');
                  }, isDark),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Already have an Account? ", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 15)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: Text('Sign-In', style: TextStyle(color: themeColor, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(String assetPath, VoidCallback onTap, bool isDark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Image.asset(assetPath),
      ),
    );
  }
}
