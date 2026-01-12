import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final Color themeColor = const Color(0xFF4CAFAB);

  // Animation controller and animation for the pulsating dots
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize the animation controller for the pulsating dots
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Define the base animation scale
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
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
      _showSnackBar('Please fill in all fields');
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar('Passwords do not match');
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

      _showSnackBar('Account created successfully!');
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Registration failed');
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if(mounted) setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _showSnackBar('Signed in with Google');
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showSnackBar('Google Sign-In failed');
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: themeColor, width: 1.3),
      ),
    );
  }

  // Animated Loading Indicator Widget (Pulsing Dots)
  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            // Define scale based on animation for staggered effect
            final dot1Scale = _animation.value;
            final dot2Scale = Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
              ),
            ).value;
            final dot3Scale = Tween<double>(begin: 0.5, end: 1.0).animate(
              CurvedAnimation(
                parent: _animationController,
                curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
              ),
            ).value;

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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate space needed to push content down (15% of the screen height)
    final verticalSpace = MediaQuery.of(context).size.height * 0.15;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
          ),
        ),
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

              // Apply large vertical space to push content down
              SizedBox(height: verticalSpace),

              // Email
              TextField(
                controller: _emailController,
                decoration: _inputDecoration('Enter your email', Icons.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration:
                _inputDecoration(
                  'Enter your password',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[600],
                    ),
                    onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm password
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration:
                _inputDecoration(
                  'Confirm your password',
                  Icons.lock_outline,
                ).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[600],
                    ),
                    onPressed: () => setState(
                          () => _obscureConfirmPassword =
                      !_obscureConfirmPassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Create Account Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF497A72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? _buildLoadingIndicator() // Animated Dots Loader
                      : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Divider with "Or Continue with"
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey[400],
                      thickness: 0.8,
                      endIndent: 8,
                    ),
                  ),
                  Text(
                    'Or Continue with',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey[400],
                      thickness: 0.8,
                      indent: 8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Google and Phone icons side-by-side
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialIcon('assets/images/google.png', _signInWithGoogle),
                  const SizedBox(width: 28),
                  _socialIcon('assets/images/phone.png', () {
                    if (mounted) Navigator.pushNamed(context, '/phone');
                  }),
                ],
              ),

              const SizedBox(height: 30),

              // Already have an account?
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an Account? ",
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: Text(
                      'Sign-In',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialIcon(String assetPath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Image.asset(assetPath, width: 28, height: 28),
      ),
    );
  }
}