import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiverDetailsScreen extends StatefulWidget {
  final String userId;
  const ReceiverDetailsScreen({super.key, required this.userId});

  @override
  State<ReceiverDetailsScreen> createState() => _ReceiverDetailsScreenState();
}

class _ReceiverDetailsScreenState extends State<ReceiverDetailsScreen> {
  Map<String, dynamic>? userData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (doc.exists) {
      setState(() {
        userData = doc.data();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4CAFAB), size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(userData?['name'] ?? 'User Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAFAB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: userData?['photoUrl'] != null
                              ? NetworkImage(userData!['photoUrl'] as String)
                              : null,
                          child: userData?['photoUrl'] == null
                              ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey[600],
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userData?['phone'] ?? 'No phone number',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              if (userData?['age'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${userData!['age']} years old',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
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
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    Icons.person_outline,
                    'Full Name',
                    userData?['name'] ?? 'Not set',
                  ),
                  _buildInfoRow(
                    Icons.phone_iphone_outlined,
                    'Phone Number',
                    userData?['phone'] ?? 'Not set',
                  ),
                  if (userData?['gender'] != null)
                    _buildInfoRow(
                      Icons.transgender,
                      'Gender',
                      userData!['gender'] as String,
                    ),
                  if (userData?['age'] != null)
                    _buildInfoRow(
                      Icons.cake_outlined,
                      'Age',
                      '${userData!['age']} years old',
                    ),
                  if (userData?['birthDate'] != null)
                    _buildInfoRow(
                      Icons.calendar_today_outlined,
                      'Birth Date',
                      userData!['birthDate'].toString(),
                    ),
                  _buildInfoRow(
                    Icons.circle,
                    'Status',
                    userData?['status'] ?? 'Active',
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
