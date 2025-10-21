import 'package:flutter/material.dart';
import '../../../constants/shopping_constants.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Chip(
          backgroundColor: isSelected
              ? ShoppingConstants.primaryColor.withOpacity(0.3)
              : ShoppingConstants.primaryColor.withOpacity(0.15),
          label: Text(
            label,
            style: TextStyle(
              color: ShoppingConstants.primaryColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          side: isSelected
              ? BorderSide(color: ShoppingConstants.primaryColor, width: 1)
              : BorderSide.none,
        ),
      ),
    );
  }
}
