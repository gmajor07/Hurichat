import 'package:flutter/material.dart';
import '../../../models/product_item.dart';

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class ProductCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
  });

  String _formatPrice(String price) {
    final clean = price.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(clean) ?? 0;
    return "Tsh ${value.toStringAsFixed(0)}";
  }

  String _formatDiscountPrice(String? discountPrice) {
    if (discountPrice == null) return '';
    final clean = discountPrice.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(clean) ?? 0;
    return "Tsh ${value.toStringAsFixed(0)}";
  }

  String _getShortDescription(String? description) {
    if (description == null || description.isEmpty) return '';
    return description.length > 60 ? '${description.substring(0, 60)}...' : description;
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'used':
        return Colors.orange;
      case 'refurbished':
        return Colors.blue;
      case 'damaged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 165,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ FLEXIBLE IMAGE (THIS FIXES THE OVERFLOW)
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                    child: SizedBox.expand(
                      child: Image.network(
                        product.displayImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: isDark
                              ? Colors.grey[900]
                              : Colors.grey[200],
                          child:
                          const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  ),

                  // ADD BUTTON
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: InkWell(
                      onTap: onAddToCart,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary
                                  .withOpacity(0.35),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TEXT (natural height)
            Padding(
              padding:
              const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    product.name.capitalizeFirst(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Short description
                  if (product.description != null && product.description!.isNotEmpty)
                    Text(
                      _getShortDescription(product.description),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        height: 1.3,
                      ),
                    ),

                  const SizedBox(height: 6),

                  // Price section with discount
                  Row(
                    children: [
                      if (product.discountPrice != null && product.discountPrice!.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Original price (strikethrough)
                              Text(
                                _formatPrice(product.price),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                              // Discounted price
                              Text(
                                _formatDiscountPrice(product.discountPrice),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          _formatPrice(product.price),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      // Sold count
                      if (product.soldCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${product.soldCount} sold',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Condition badge
                  if (product.condition != null && product.condition!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getConditionColor(product.condition!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.condition!.capitalizeFirst(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getConditionColor(product.condition!),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Rating
                  if (product.rating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          product.rating!.toStringAsFixed(1),
                          style:
                          theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
