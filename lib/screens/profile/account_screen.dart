import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user_account/update_profile_page.dart';
import 'date_formatter.dart';
import 'info_row.dart';
import 'profile_actions.dart';
import 'profile_header.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) {
      setState(() {
        userData = null;
        _loading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (mounted) {
        setState(() {
          userData = doc.exists ? doc.data() : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _openUpdateProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpdateProfilePage()),
    );

    if (result == true) {
      await _fetchUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : Colors.grey.shade50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: backgroundColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ProfileHeader(userData: userData),
                    const SizedBox(height: 30),
                    _buildPersonalInfoSection(context),
                    const SizedBox(height: 30),
                    ProfileActions(
                      onUpdateProfile: _openUpdateProfile,
                      onSignOut: _signOut,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        InfoRow(
          icon: Icons.person_outline,
          title: 'Full Name',
          value: userData?['name'] ?? 'Not set',
        ),
        InfoRow(
          icon: Icons.phone_iphone_outlined,
          title: 'Phone Number',
          value: userData?['phone'] ?? 'Not set',
        ),
        if (userData?['gender'] != null)
          InfoRow(
            icon: Icons.transgender,
            title: 'Gender',
            value: userData!['gender'] as String,
          ),
        if (userData?['age'] != null)
          InfoRow(
            icon: Icons.cake_outlined,
            title: 'Age',
            value: '${userData!['age']} years old',
          ),
        if (userData?['birthDate'] != null)
          InfoRow(
            icon: Icons.calendar_today_outlined,
            title: 'Birth Date',
            value: DateFormatter.formatDate(userData!['birthDate']),
          ),
        InfoRow(
          icon: Icons.circle,
          title: 'Status',
          value: userData?['status'] ?? 'Active',
        ),
      ],
    );
  }
}
