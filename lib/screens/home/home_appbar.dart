import 'package:flutter/material.dart';

AppBar buildHomeAppBar({
  required BuildContext context,
  required Color themeColor,
  required void Function(String value) onSelectMenu,
}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    title: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Huruchat',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              size: 22,
              color: isDark ? Colors.white : Colors.black87,
            ),
            color: isDark ? Colors.grey.shade800 : Colors.white,
            onSelected: onSelectMenu,
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: themeColor),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('My Profile')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: themeColor),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Settings')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'requests',
                child: Row(
                  children: [
                    Icon(Icons.person_add_outlined, color: themeColor),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Connection Requests')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'add_contacts',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1, color: themeColor),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Add Contacts')),
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
                    const Expanded(
                      child: Text(
                        'Logout',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
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
