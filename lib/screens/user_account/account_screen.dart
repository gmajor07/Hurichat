import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'update_profile_page.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool _loading = true;

  static const Color themeColor = Color(0xFF4CAFAB);

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
          userData = doc.exists ? doc.data() as Map<String, dynamic>? : null;
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
    // Navigate to update page and refresh on return
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UpdateProfilePage()),
    );

    if (result == true) {
      // user saved changes — refresh
      await _fetchUserData();
    }
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: themeColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final DateTime dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'Not set';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF121212)
        : Colors.grey.shade50;

    return Scaffold(
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
                    // Profile Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : themeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                                backgroundImage:
                                    (userData?['photoUrl'] as String?)
                                            ?.isNotEmpty ==
                                        true
                                    ? NetworkImage(
                                        userData!['photoUrl'] as String,
                                      )
                                    : null,
                                child:
                                    (userData?['photoUrl'] as String?)
                                            ?.isNotEmpty ==
                                        true
                                    ? null
                                    : Icon(
                                        Icons.person,
                                        size: 40,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey,
                                      ),
                              ),
                              // small edit overlay indicator
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
                                    Icons.edit,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userData?['name'] ?? 'Unknown User',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userData?['phone'] ?? 'No phone number',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (userData?['age'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${userData!['age']} years old',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Personal Info Section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildInfoRow(
                      context,
                      Icons.person_outline,
                      'Full Name',
                      userData?['name'] ?? 'Not set',
                    ),

                    _buildInfoRow(
                      context,
                      Icons.phone_iphone_outlined,
                      'Phone Number',
                      userData!['phone'] as String,
                    ),

                    if (userData?['gender'] != null)
                      _buildInfoRow(
                        context,
                        Icons.transgender,
                        'Gender',
                        userData!['gender'] as String,
                      ),

                    if (userData?['age'] != null)
                      _buildInfoRow(
                        context,
                        Icons.cake_outlined,
                        'Age',
                        '${userData!['age']} years old',
                      ),

                    if (userData?['birthDate'] != null)
                      _buildInfoRow(
                        context,
                        Icons.calendar_today_outlined,
                        'Birth Date',
                        _formatDate(userData!['birthDate']),
                      ),

                    _buildInfoRow(
                      context,
                      Icons.circle,
                      'Status',
                      userData?['status'] ?? 'Active',
                    ),

                    const SizedBox(height: 30),

                    // Update Profile Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _openUpdateProfile,
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Logout button (smaller)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(
                          Icons.logout,
                          color: Color(0xFF4CAFAB),
                        ),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF4CAFAB),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF4CAFAB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
