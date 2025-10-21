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
    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: onProductTap != null ? () => onProductTap!(product) : null,
            onAddToCart: onAddToCart != null
                ? () => onAddToCart!(product)
                : null,
          );
        },
      ),
    );
  }
}
