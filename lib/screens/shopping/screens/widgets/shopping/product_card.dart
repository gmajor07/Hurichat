import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../models/product_item.dart';
import '../common/shimmer_loading.dart';

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class ProductCard extends StatelessWidget {
  final ProductItem product;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onAddToCart;
  final bool isFavorite;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onFavoriteTap,
    this.onAddToCart,
    this.isFavorite = false,
  });

  String _formatCurrency(String? price, String currency) {
    if (price == null || price.isEmpty) return '';
    final clean = price.replaceAll(RegExp(r'[^0-9.]'), '');
    final value = double.tryParse(clean) ?? 0;
    final symbol = currency.toUpperCase() == 'USD' ? '\$' : 'TZS ';
    final formattedValue = value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$symbol$formattedValue';
  }

  String _subtitle() {
    final sub = (product.subCategory ?? '').trim();
    if (sub.isNotEmpty) {
      return sub.capitalizeFirst();
    }
    return '${product.category.capitalizeFirst()} product';
  }

  Color _tileColor(int seed) {
    const palette = [
      Color(0xFFF7D7EA),
      Color(0xFFF2E9D6),
      Color(0xFFDCEFD9),
      Color(0xFFDDEBFA),
      Color(0xFFE8DDF8),
      Color(0xFFF2E7D9),
    ];
    return palette[seed % palette.length];
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.white.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: SvgPicture.asset('assets/icon/gallery.svg', width: 34, height: 34),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        product.discountPrice != null && product.discountPrice!.isNotEmpty;
    final basePrice = _formatCurrency(
      hasDiscount ? product.discountPrice : product.price,
      product.currency,
    );

    final int colorSeed = product.id.hashCode.abs();
    final Color tile = _tileColor(colorSeed);
    final double ratingValue = (product.rating ?? 0).clamp(0, 5).toDouble();
    final String ratingText = ratingValue.toStringAsFixed(1);
    final bool hasRating = ratingValue > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: tile,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2438).withValues(alpha: 0.09),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                top: 34,
                right: 16,
                child: Icon(
                  Icons.star_rounded,
                  size: 92,
                  color: Colors.white.withValues(alpha: 0.34),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        width: double.infinity,
                        height: 156,
                        child: Hero(
                          tag: 'product_image_${product.id}',
                          child: Image.network(
                            product.displayImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const ShimmerLoading(
                                width: 120,
                                height: 68,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) =>
                                _buildImagePlaceholder(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.name.capitalizeFirst(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF102D3D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5A6E7E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hasRating)
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ratingText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF102D3D),
                            ),
                          ),
                        ],
                      ),
                    if (hasRating) const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            basePrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0B2433),
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onFavoriteTap ?? onAddToCart,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: onFavoriteTap == null
                                  ? const Color(0xFFE9F5FF)
                                  : (isFavorite
                                        ? const Color(0xFFFBE2EA)
                                        : const Color(0xFFF0E8EC)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              onFavoriteTap == null
                                  ? Icons.shopping_bag_outlined
                                  : (isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border),
                              size: 14,
                              color: onFavoriteTap == null
                                  ? const Color(0xFF0E7C86)
                                  : const Color(0xFFE1275A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
