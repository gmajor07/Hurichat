import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:huruchat/screens/food/screen/food_screen.dart';
import '../connection/discovery_connection_screen.dart';
import '../connection/connection_request.dart';
import '../connection/connection_screen.dart';
import '../huru/huru_screen.dart';
import '../users_list_screen.dart';
import '../transport_screen.dart';
import '../user_account/account_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Default tab: Chats
  final Color themeColor = const Color(0xFF4CAFAB);

  final List<Widget> _screens = [
    const FoodScreen(),
    const TransportScreen(),
    UsersListScreen(),
    const HuruScreen(),
    const AccountScreen(),
  ];

  String firstName = '';

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    return name
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
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
      print('Error fetching user name: $e');
      if (mounted) {
        setState(() {
          firstName = 'User';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'HuruChat',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),

              Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 22),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.white,
                    onSelected: (value) => _handleMenuSelection(value, context),
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'discover',
                        child: Row(
                          children: [
                            Icon(Icons.explore_outlined, color: themeColor),
                            const SizedBox(width: 12),
                            const Text('Discover Connections'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'requests',
                        child: Row(
                          children: [
                            Icon(Icons.person_add_outlined, color: themeColor),
                            const SizedBox(width: 12),
                            const Text('Connection Requests'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.redAccent),
                            const SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      body: Column(
        children: [
          // Welcome message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Welcome back, ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
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
          // Your existing screen
          Expanded(child: _screens[_currentIndex]),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          selectedItemColor: themeColor,
          unselectedItemColor: isDark
              ? Colors.grey.shade400
              : Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.food_bank),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.food_bank),
              ),
              label: 'Food',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.car_rental),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.car_rental),
              ),
              label: 'Transport',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.chat_outlined),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat),
              ),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.menu),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu),
              ),
              label: 'Huru',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(Icons.person_outline),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),

      floatingActionButton: _buildFloatingActionButton(isDark),
    );
  }

  Widget? _buildFloatingActionButton(bool isDark) {
    switch (_currentIndex) {
      case 0: // Transport
        return FloatingActionButton(
          backgroundColor: themeColor,
          elevation: 4,
          child: const Icon(Icons.group_add, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ConnectionsDiscoveryScreen()),
            );
          },
        );

      case 1: // Chats
        return FloatingActionButton(
          backgroundColor: themeColor,
          elevation: 4,
          child: const Icon(Icons.person_add, color: Colors.white, size: 28),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            );
          },
        );

      default:
        return null;
    }
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
}
