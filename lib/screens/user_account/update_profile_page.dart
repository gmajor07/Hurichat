import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_update_logic.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _ageCtl = TextEditingController();
  final TextEditingController _genderCtl = TextEditingController();

  File? _pickedImage;
  bool _loading = false;
  bool _loadingProfile = true;
  String? _profileLoadError;
  String? _currentPhotoUrl;

  static const Color themeColor = Color(0xFF4CAFAB);

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  Future<void> _loadCurrentData() async {
    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _profileLoadError = 'Sign in to load your profile.';
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      if (!mounted) return;

      _nameCtl.text = profileStringValue(
        data['name'],
        fallback: user!.displayName ?? '',
      );
      _ageCtl.text = data['age']?.toString() ?? '';
      _genderCtl.text = profileStringValue(data['gender'], fallback: '');
      _currentPhotoUrl = profileStringValue(
        data['photoUrl'],
        fallback: user!.photoURL ?? '',
      );
      setState(() {
        _loadingProfile = false;
        _profileLoadError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load profile for editing: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileLoadError = 'Could not load your profile. Please try again.';
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    if (_loading) return;
    setState(() {
      _pickedImage = File(xfile.path);
    });
  }

  Future<String?> _uploadProfilePic(File file) async {
    if (user == null) return null;
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_pics')
        .child('${user!.uid}.jpg');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask.whenComplete(() => {});
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  Future<void> _saveProfile() async {
    if (user == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    var photoUploadFailed = false;
    var authSyncFailed = false;
    try {
      String? photoUrl;
      if (_pickedImage != null) {
        photoUrl = await uploadProfilePhotoSafely(
          () => _uploadProfilePic(_pickedImage!),
          onError: (error, stackTrace) {
            debugPrint('Profile photo upload failed: $error\n$stackTrace');
            photoUploadFailed = true;
          },
        );
      }

      final updates = buildProfileUpdateFields(
        name: _nameCtl.text,
        age: _ageCtl.text,
        gender: _genderCtl.text,
        photoUrl: photoUrl,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .set(updates, SetOptions(merge: true));

      try {
        await user!.updateDisplayName(_nameCtl.text.trim());
        if (photoUrl != null) {
          await user!.updatePhotoURL(photoUrl);
        }
      } catch (error, stackTrace) {
        debugPrint('Failed to sync Firebase Auth profile: $error\n$stackTrace');
        authSyncFailed = true;
      }

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoUploadFailed
                ? 'Profile saved, but the photo could not be uploaded. Your existing photo was kept.'
                : authSyncFailed
                ? 'Profile saved, but sign-in profile details could not be synced.'
                : 'Profile updated',
          ),
        ),
      );
      Navigator.pop(context, true); // indicate success to caller
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _ageCtl.dispose();
    _genderCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey.shade50;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _loadingProfile
            ? const Center(child: CircularProgressIndicator())
            : _profileLoadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_profileLoadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadCurrentData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: isDark
                                ? Colors.grey[700]
                                : Colors.grey[300],
                            backgroundImage: _pickedImage != null
                                ? FileImage(_pickedImage!)
                                : ((_currentPhotoUrl ?? '').isNotEmpty
                                      ? NetworkImage(_currentPhotoUrl!)
                                      : null),
                            child:
                                (_pickedImage == null &&
                                    (_currentPhotoUrl ?? '').isEmpty)
                                ? Icon(
                                    Icons.person,
                                    size: 48,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: themeColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white,
                                  width: 2,
                                ),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // name
                          TextFormField(
                            controller: _nameCtl,
                            decoration: InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: const Icon(Icons.person_outline),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey[850]
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // age
                          TextFormField(
                            controller: _ageCtl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Age',
                              prefixIcon: const Icon(Icons.cake_outlined),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey[850]
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = int.tryParse(v.trim());
                              if (val == null || val <= 0) {
                                return 'Enter a valid age';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // gender
                          TextFormField(
                            controller: _genderCtl,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: const Icon(Icons.transgender),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.grey[850]
                                  : Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Save button
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
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
