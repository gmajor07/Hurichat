import 'package:flutter/material.dart';

import '../../../constants/shopping_constants.dart';
import '../../../models/product_item.dart';

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

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 160, // Fixed total height
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(
            ShoppingConstants.cardBorderRadius,
          ),
          border: Border.all(
            color: ShoppingConstants.primaryColor.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section - Fixed height
            Stack(
              children: [
                Container(
                  height: 100, // Fixed image height
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(ShoppingConstants.cardBorderRadius),
                    ),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(ShoppingConstants.cardBorderRadius),
                    ),
                    child: Image.asset(
                      product.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.shopping_bag,
                            color: Colors.grey,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Cart Button
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onAddToCart,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ShoppingConstants.primaryColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_shopping_cart,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content Section - Fixed height
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                      ),
                    ),

                    // Price and Rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.price,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (product.rating != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 10),
                              const SizedBox(width: 2),
                              Text(
                                product.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
