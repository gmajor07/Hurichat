import 'package:flutter/material.dart';

import '../connection/connection_screen.dart';
import '../connection/discovery_connection_screen.dart';

Widget? buildFAB({
  required int currentIndex,
  required Color themeColor,
  required BuildContext context,
}) {
  switch (currentIndex) {
    case 0:
      return PopupMenuButton<String>(
        color: const Color(0xFF4A4A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        offset: const Offset(0, -220),
        onSelected: (value) {
          switch (value) {
            case 'new_chat':
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select a user below to start a chat'),
                ),
              );
              break;
            case 'add_contacts':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectionScreen()),
              );
              break;
            case 'scan':
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Scan coming soon')));
              break;
            case 'money':
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Money coming soon')),
              );
              break;
            case 'discover_people':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ConnectionsDiscoveryScreen()),
              );
              break;
          }
        },
        itemBuilder: (BuildContext context) => const [
          PopupMenuItem(
            value: 'new_chat',
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('New Chat', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuDivider(height: 8),
          PopupMenuItem(
            value: 'add_contacts',
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Colors.white),
                SizedBox(width: 12),
                Text('Add Contacts', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuDivider(height: 8),
          PopupMenuItem(
            value: 'scan',
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white),
                SizedBox(width: 12),
                Text('Scan', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuDivider(height: 8),
          PopupMenuItem(
            value: 'discover_people',
            child: Row(
              children: [
                Icon(Icons.group_add, color: Colors.white),
                SizedBox(width: 12),
                Text('Discover People', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
          PopupMenuDivider(height: 8),
          PopupMenuItem(
            value: 'money',
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Text('Money', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
        child: FloatingActionButton(
          backgroundColor: themeColor,
          elevation: 4,
          onPressed: null,
          child: const Icon(Icons.person_add, color: Colors.white, size: 28),
        ),
      );
    case 4:
      return FloatingActionButton(
        backgroundColor: themeColor,
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ConnectionsDiscoveryScreen()),
          );
        },
        child: const Icon(Icons.group_add, color: Colors.white, size: 28),
      );
    default:
      return null;
  }
}
