import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'complete_profile.dart';
import '../home/home_screen.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

// 1. ADD TickerProviderStateMixin
class _PhoneAuthPageState extends State<PhoneAuthPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;

  final Color themeColor = const Color(0xFF4CAFAB);

  // 2. Animation controller and animation for the pulsating dots
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(); // Start repeating the animation

    // Define the base animation scale
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // Step 1: Send OTP
  Future<void> _verifyPhone() async {
    setState(() => _loading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        _showSnack("✅ Logged in automatically!");
        // We typically handle navigation after auto-login successful
        if (mounted) _navigateToNextScreen();
      },
      verificationFailed: (FirebaseAuthException e) {
        _showSnack("❌ Verification failed: ${e.message}");
        if (mounted) setState(() => _loading = false);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _otpSent = true;
            _verificationId = verificationId;
            _loading = false;
          });
          _showSnack("📩 OTP sent! Enter the code.");
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // Step 2: Verify OTP
  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await _auth.signInWithCredential(credential);
      _showSnack("✅ Logged in successfully!");

      if (mounted) _navigateToNextScreen();
    } catch (e) {
      _showSnack("❌ Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Helper to check profile completion and navigate
  Future<void> _navigateToNextScreen() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists || !(doc.data()?['name']?.isNotEmpty ?? false)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfileCompletionScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
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

  // 3. Animated Loading Indicator Widget (Pulsing Dots)
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
                _otpSent ? "Enter Verification Code" : "Phone Verification",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 35),

              // Phone input
              if (!_otpSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(
                    'Enter your phone number',
                    Icons.phone,
                  ),
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? _buildLoadingIndicator() // 4. REPLACED CircularProgressIndicator
                        : const Text(
                            'Send OTP',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],

              // OTP input
              if (_otpSent) ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'Enter OTP code',
                    Icons.sms_outlined,
                  ),
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? _buildLoadingIndicator() // 4. REPLACED CircularProgressIndicator
                        : const Text(
                            'Verify OTP',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: _loading
                      ? null
                      : _verifyPhone, // Disable resend while loading
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
