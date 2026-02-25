import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/firebase_product.dart';
import '../models/product_item.dart';
import 'customer_product_details_screen.dart';
import '../../provider/cart_provider.dart';
import 'widgets/shopping/product_grid.dart';

class RelatedProductsScreen extends StatefulWidget {
  final String productId;

  const RelatedProductsScreen({super.key, required this.productId});

  @override
  State<RelatedProductsScreen> createState() => _RelatedProductsScreenState();
}

class _RelatedProductsScreenState extends State<RelatedProductsScreen> {
  bool _loading = true;
  List<ProductItem> _products = [];
  String _subCategoryLabel = '';

  @override
  void initState() {
    super.initState();
    _loadRelatedProducts();
  }

  Future<void> _loadRelatedProducts() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // 1️⃣ Fetch tapped product
      final tappedDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .get();

      if (!tappedDoc.exists) {
        _stopLoading();
        return;
      }

      final tappedProduct = FirebaseProduct.fromMap(
        tappedDoc.id,
        tappedDoc.data()!,
      );

      final tappedSubCategory = _normalize(tappedProduct.subCategory);

      debugPrint('Tapped product subCategory: ${tappedProduct.subCategory}');

      // 2️⃣ Fetch ALL ACTIVE products
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'active')
          .get();

      // 3️⃣ Filter ONLY same subCategory (INCLUDES tapped product)
      final related = snap.docs
          .map((d) => FirebaseProduct.fromMap(d.id, d.data()))
          .where((p) => _normalize(p.subCategory) == tappedSubCategory)
          .map((p) => ProductItem.fromFirebaseProduct(p))
          .toList();

      debugPrint('Related products found: ${related.length}');

      if (mounted) {
        setState(() {
          _products = related;
          _subCategoryLabel = _capitalize(tappedProduct.subCategory);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Related products error: $e');
      _stopLoading();
    }
  }

  void _stopLoading() {
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  String _normalize(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _capitalize(String? value) {
    if (value == null || value.isEmpty) return '';
    final v = value.trim();
    return v[0].toUpperCase() + v.substring(1);
  }

  void _onProductTap(ProductItem product) async {
    // Fetch the full FirebaseProduct
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();
      if (doc.exists && mounted) {
        final firebaseProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);
        // Navigate to product details screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CustomerProductDetailsScreen(product: firebaseProduct),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching product: $e');
    }
  }

  void _onAddToCart(ProductItem product) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();
      if (doc.exists && mounted) {
        final firebaseProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        cartProvider.addItem(firebaseProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${firebaseProduct.name} added to cart!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12151B)
          : const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _subCategoryLabel.isEmpty
              ? 'Related Products'
              : 'More $_subCategoryLabel',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
          ? const Center(
              child: Text(
                'No related products found',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1F28) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.24 : 0.07,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF0E7C86)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_products.length} matched products',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ProductGrid(
                      products: _products,
                      onProductTap: _onProductTap,
                      onAddToCart: _onAddToCart,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
