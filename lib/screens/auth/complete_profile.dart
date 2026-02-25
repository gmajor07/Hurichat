import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:huruchat/utils/phone_hash_utils.dart';

class ProfileCompletionScreen extends StatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  State<ProfileCompletionScreen> createState() =>
      _ProfileCompletionScreenState();
}

// 1. ADD TickerProviderStateMixin
class _ProfileCompletionScreenState extends State<ProfileCompletionScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _imageFile;
  bool _loading = false;

  final Color themeColor = const Color(0xFF4CAFAB);

  // New fields
  String? _selectedGender;
  DateTime? _selectedDate;
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];

  // 2. Animation controller and animation for the pulsating dots
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (authPhone != null && authPhone.isNotEmpty) {
      _phoneController.text = authPhone;
    }
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
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 20),
      ), // 20 years old
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Validation
    if (_nameController.text.trim().isEmpty) {
      _showSnack("Please enter your name");
      return;
    }

    setState(() => _loading = true);

    String? photoUrl;
    if (_imageFile != null) {
      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_pics')
            .child('${user.uid}.jpg');
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
      } catch (e) {
        _showSnack("Failed to upload profile picture.");
        // Continue without photo URL if upload fails
      }
    }

    // Calculate age from selected date
    int? age;
    if (_selectedDate != null) {
      final now = DateTime.now();
      age = now.year - _selectedDate!.year;
      if (now.month < _selectedDate!.month ||
          (now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
        age--;
      }
    }

    try {
      final rawPhone = _phoneController.text.trim();
      final normalizedPhone = normalizePhoneNumber(rawPhone);
      final phoneHash = normalizedPhone.isEmpty
          ? ''
          : hashPhoneNumber(normalizedPhone);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': rawPhone,
        'phoneNormalized': normalizedPhone,
        'phoneHash': phoneHash,
        'gender': _selectedGender,
        'birthDate': _selectedDate,
        'age': age,
        // Use the new photoUrl if available, otherwise fallback to existing or null
        'photoUrl': photoUrl ?? user.photoURL,
        'status': 'active',
        'profileCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showSnack("Failed to save profile data.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              // Welcome Back Title
              Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              // Main Welcome Title
              Text(
                "Complete Your Profile",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),

              // Description text
              Text(
                "Add your details to get started. We use this to personalize your experience.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              // Profile Picture Section
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey[500],
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: themeColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Add Profile Photo",
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Name Input Field
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(
                  'Enter your full name',
                  Icons.person_outline,
                ),
              ),
              const SizedBox(height: 20),

              // Phone Input Field
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(
                  'Enter your phone number',
                  Icons.phone_iphone_outlined,
                ),
              ),
              const SizedBox(height: 20),

              // Gender Dropdown
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedGender = newValue;
                    });
                  },
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.transgender,
                      color: Colors.grey[600],
                    ),
                    hintText: 'Select Gender',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 15,
                    ),
                  ),
                  items: _genders.map((String gender) {
                    return DropdownMenuItem<String>(
                      value: gender,
                      child: Text(
                        gender,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Birth Date Picker
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 15,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined, color: Colors.grey[600]),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? 'Select Birth Date'
                              : 'Birth Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                          style: TextStyle(
                            color: _selectedDate == null
                                ? Colors.grey
                                : isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (_selectedDate != null)
                        Icon(Icons.check_circle, color: themeColor, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 35),

              // Save Profile Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? _buildLoadingIndicator() // 4. REPLACED CircularProgressIndicator
                      : const Text(
                          'Complete Profile',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Learn more text
              Center(
                child: Text(
                  "Learn more about us at all. We use",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
