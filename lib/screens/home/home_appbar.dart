import 'package:flutter/material.dart';
import '../connection/discovery_connection_screen.dart';
import '../connection/connection_request.dart';

AppBar buildHomeAppBar({
  required BuildContext context,
  required Color themeColor,
  required void Function(String value) onSelectMenu,
}) {
  return AppBar(
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.white,
            onSelected: (value) {
              switch (value) {
                case 'discover':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConnectionsDiscoveryScreen(),
                    ),
                  );
                  break;
                case 'requests':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ConnectionRequestsScreen(),
                    ),
                  );
                  break;
                case 'logout':
                  onSelectMenu(value);
                  break;
              }
            },
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
                    Text('Logout', style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
