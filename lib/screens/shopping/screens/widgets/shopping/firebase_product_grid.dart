import 'package:flutter/material.dart';

import '../../../models/firebase_product.dart';
import 'firebase_product_card.dart';

class FirebaseProductGrid extends StatelessWidget {
  final List<FirebaseProduct> products;
  final Function(FirebaseProduct)? onProductTap;
  final Function(FirebaseProduct)? onAddToCart;

  const FirebaseProductGrid({
    super.key,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return FirebaseProductCard(
          product: product,
          onTap: onProductTap != null ? () => onProductTap!(product) : null,
          onAddToCart: onAddToCart != null ? () => onAddToCart!(product) : null,
        );
      },
    );
  }
}
