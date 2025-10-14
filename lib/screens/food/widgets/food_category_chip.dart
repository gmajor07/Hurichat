import 'package:flutter/material.dart';

class FoodCategoryChip extends StatelessWidget {
  final String title;
  final String imagePath;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;
  final bool isSelected;

  const FoodCategoryChip({
    super.key,
    required this.title,
    required this.imagePath,
    required this.colorScheme,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 1)
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundImage: AssetImage(imagePath)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
