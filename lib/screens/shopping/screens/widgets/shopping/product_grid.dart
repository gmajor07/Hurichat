import 'package:flutter/material.dart';
import '../../../models/product_item.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final List<ProductItem> products;
  final Function(ProductItem)? onProductTap;
  final Function(ProductItem)? onAddToCart;

  const ProductGrid({
    super.key,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    // Increased height to fit the new, taller ProductCard design
    return SizedBox(
      height: 230, // Adjusted from 170 to 230
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: onProductTap != null ? () => onProductTap!(product) : null,
            // We keep the onAddToCart handler in the ProductCard wrapper,
            // but it's now visually removed from the card itself.
            onAddToCart: onAddToCart != null
                ? () => onAddToCart!(product)
                : null,
          );
        },
      ),
    );
  }
}
