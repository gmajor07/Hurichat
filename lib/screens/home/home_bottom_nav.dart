import 'package:flutter/material.dart';

Widget buildBottomNavigationBar({
  required BuildContext context,
  required int currentIndex,
  required Color themeColor,
  required ValueChanged<int> onTap,
}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  final Color dockColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
  final Color inactiveColor = isDark
      ? Colors.grey.shade400
      : Colors.grey.shade600;
  const icons = [
    Icons.chat_bubble_outline,
    Icons.miscellaneous_services_outlined,
    Icons.more_horiz,
    Icons.lightbulb_outline,
    Icons.person_outline,
  ];

  return SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dockColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(icons.length, (index) {
          final bool selected = index == currentIndex;
          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? themeColor
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icons[index],
                size: 22,
                color: selected ? Colors.white : inactiveColor,
              ),
            ),
          );
        }),
      ),
    ),
  );
}
