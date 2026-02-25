import 'package:flutter/material.dart';
import '../../../models/product_item.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<ProductItem> products;
  final Function(ProductItem)? onProductTap;
  final Function(ProductItem)? onFavoriteTap;
  final Function(ProductItem)? onAddToCart;
  final Set<String> favoriteProductIds;

  const ProductGrid({
    super.key,
    required this.products,
    this.onProductTap,
    this.onFavoriteTap,
    this.onAddToCart,
    this.favoriteProductIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 272,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            isFavorite: favoriteProductIds.contains(product.id),
            onTap: onProductTap != null ? () => onProductTap!(product) : null,
            onFavoriteTap: onFavoriteTap != null
                ? () => onFavoriteTap!(product)
                : null,
            onAddToCart: onAddToCart != null
                ? () => onAddToCart!(product)
                : null,
          );
        },
      ),
    );
  }
}
