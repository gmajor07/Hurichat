import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Make sure to import your actual theme file path here
// import 'package:your_app/theme/app_theme.dart';

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
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[50]
            : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Use primary color from theme
          Icon(icon, color: const Color(0xFF4CAFaa), size: 22),
          const SizedBox(width: 12),
          // Wrap in Expanded to prevent the 90px overflow error
          Expanded(
            child: Column(
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black87
                        : Colors.white,
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
    final primaryColor = const Color(0xFF4CAFaa);

    return Scaffold(
      appBar: AppBar(
        title: Text("Friend"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
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
                        ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userData?['name'] ?? 'Unknown User',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData?['phone'] ?? 'No phone number',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
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