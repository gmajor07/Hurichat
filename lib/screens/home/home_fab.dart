import 'package:flutter/material.dart';
import '../connection/connection_screen.dart';
import '../connection/discovery_connection_screen.dart';

Widget? buildFAB({
  required int currentIndex,
  required Color themeColor,
  required BuildContext context,
}) {
  switch (currentIndex) {
    case 0: // UsersListScreen
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
    case 3: // Transport
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
    default:
      return null;
  }
}
