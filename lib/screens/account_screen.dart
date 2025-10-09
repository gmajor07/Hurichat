import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          _loading = false;
        });
      }
    }
    setState(() => _loading = false);
  }

  void _updateProfile() {
    Navigator.pushNamed(context, '/completeProfile');
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
          Icon(icon, color: const Color(0xFF497A72), size: 22),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFF497A72).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: isDark
                              ? Colors.grey[700]
                              : Colors.grey[300],
                          backgroundImage: userData?['photoUrl'] != null
                              ? NetworkImage(userData!['photoUrl'] as String)
                              : null,
                          child: userData?['photoUrl'] == null
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey,
                                )
                              : null,
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
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.phoneNumber ?? 'No phone number',
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
                    user?.phoneNumber ?? 'Not set',
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
                      onPressed: _updateProfile,
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
                        backgroundColor: const Color(0xFF497A72),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
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
}
