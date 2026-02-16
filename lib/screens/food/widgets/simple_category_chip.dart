import 'package:flutter/material.dart';

class SimpleCategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SimpleCategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Chip(
          backgroundColor: isSelected
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.primary.withValues(alpha: 0.15),
          label: Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          side: isSelected
              ? BorderSide(color: colorScheme.primary, width: 1)
              : BorderSide.none,
        ),
      ),
    );
  }
}
