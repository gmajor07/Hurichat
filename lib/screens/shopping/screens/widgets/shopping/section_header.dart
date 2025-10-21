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
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          GestureDetector(
            onTap: onSeeMoreTap,
            child: Text(
              ShoppingConstants.seeMoreText,
              style: TextStyle(
                fontSize: 14,
                color: ShoppingConstants.accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
