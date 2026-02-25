import 'package:flutter/material.dart';
import '../../../constants/shopping_constants.dart';

class ShoppingSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeMoreTap;

  const ShoppingSectionHeader({
    super.key,
    required this.title,
    this.onSeeMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF16263A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          if (onSeeMoreTap != null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onSeeMoreTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF222938)
                      : const Color(0xFFEAF4F6),
                ),
                child: Text(
                  ShoppingConstants.seeMoreText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ShoppingConstants.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
