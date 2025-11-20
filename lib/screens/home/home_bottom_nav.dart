import 'package:flutter/material.dart';

BottomNavigationBar buildBottomNavigationBar({
  required BuildContext context,
  required int currentIndex,
  required Color themeColor,
  required ValueChanged<int> onTap,
}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  return BottomNavigationBar(
    currentIndex: currentIndex,
    onTap: onTap,
    type: BottomNavigationBarType.fixed,
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    selectedItemColor: themeColor,
    unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.chat_outlined),
        activeIcon: Icon(Icons.chat),
        label: 'Chats',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.food_bank_outlined),
        activeIcon: Icon(Icons.food_bank),
        label: 'Food',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Shopping'),
      BottomNavigationBarItem(
        icon: Icon(Icons.lightbulb_outline),
        activeIcon: Icon(Icons.lightbulb),
        label: 'Discover',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Me',
      ),
    ],
  );
}
