import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Screens
import '../huru/discover.dart';
import '../users_list_screen.dart';
import '../food/screen/food_screen.dart';
import '../shopping/screens/shopping_screen.dart';
import '../huru/huru_screen.dart';

// Parts
import 'home_appbar.dart';
import 'home_bottom_nav.dart';
import 'home_fab.dart';
import '../connection/connection_request.dart';
import '../connection/discovery_connection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Start with UsersListScreen
  final Color themeColor = const Color(0xFF4CAFAB);
  String firstName = '';

  final List<Widget> _screens = [
    UsersListScreen(), // Chats (start)
    const FoodScreen(),
    const ShoppingScreen(),
    const DiscoverScreen(),
    const HuruScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  Future<void> _fetchUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && mounted) {
          setState(() {
            firstName = _capitalizeName(doc.data()?['name'] ?? 'User');
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => firstName = 'User');
      }
    }
  }

  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    return name
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _handleMenuSelection(String value, BuildContext context) {
    switch (value) {
      case 'logout':
        _showLogoutDialog(context);
        break;
      case 'requests':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConnectionRequestsScreen()),
        );
        break;
      case 'discover':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ConnectionsDiscoveryScreen()),
        );
        break;
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: buildHomeAppBar(
        context: context,
        themeColor: themeColor,
        onSelectMenu: (value) => _handleMenuSelection(value, context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  firstName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.waving_hand, color: themeColor, size: 18),
              ],
            ),
          ),
          Expanded(child: _screens[_currentIndex]),
        ],
      ),
      bottomNavigationBar: buildBottomNavigationBar(
        context: context,
        currentIndex: _currentIndex,
        themeColor: themeColor,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      floatingActionButton: buildFAB(
        currentIndex: _currentIndex,
        themeColor: themeColor,
        context: context,
      ),
    );
  }
}
