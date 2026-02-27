import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  final Color activeColor = themeColor.withValues(alpha: 0.95);
  const icons = [
    Icons.handyman_outlined,
    Icons.shopping_bag_outlined,
    Icons.explore_outlined,
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
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (index) {
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
                    ? activeColor
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? dockColor.withValues(alpha: 0.85)
                      : Colors.transparent,
                  width: 1.4,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _buildNavIcon(
                  index: index,
                  color: selected ? Colors.white : inactiveColor,
                  icons: icons,
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

Widget _buildNavIcon({
  required int index,
  required Color color,
  required List<IconData> icons,
}) {
  if (index == 0) {
    return SvgPicture.asset(
      'assets/icon/chat.svg',
      width: 21,
      height: 21,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
  if (index == 4) {
    return SvgPicture.asset(
      'assets/icon/user.svg',
      width: 21,
      height: 21,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  final IconData icon = switch (index) {
    1 => icons[0],
    2 => icons[1],
    3 => icons[2],
    _ => Icons.help_outline,
  };
  return Icon(icon, size: 22, color: color);
}
