import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../constants/shopping_constants.dart';
import '../../../models/firebase_product.dart';

class FirebaseProductCard extends StatelessWidget {
  final FirebaseProduct product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const FirebaseProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
  });

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: SvgPicture.asset('assets/icon/gallery.svg', width: 34, height: 34),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    final String priceText = product.price == product.price.toInt()
        ? product.price.toInt().toString()
        : product.price.toString();
    final String formattedPrice = 'TZS $priceText';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 188,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(
            ShoppingConstants.cardBorderRadius,
          ),
          border: Border.all(
            color: ShoppingConstants.primaryColor.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(ShoppingConstants.cardBorderRadius),
                  ),
                  child: SizedBox(
                    height: 122,
                    width: double.infinity,
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return _buildImagePlaceholder();
                            },
                          )
                        : _buildImagePlaceholder(),
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
                        color: ShoppingConstants.primaryColor.withValues(
                          alpha: 0.9,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

                    // Price
                    Text(
                      formattedPrice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2A3B47),
                        fontWeight: FontWeight.bold,
                      ),
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
