import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../seller/upload_product.dart';
import '../../theme/app_theme.dart';
import '../models/firebase_product.dart';
import 'edit_product_screen.dart';
import 'product_details_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  final String sellerId;

  const SellerProductsScreen({super.key, required this.sellerId});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<FirebaseProduct> products = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

  Future<void> loadProducts() async {
    if (!loading) setState(() => loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection("products")
          .where("sellerId", isEqualTo: widget.sellerId)
          .get();

      products = snap.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .toList();

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (kDebugMode) print("❌ Failed to load products: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance.collection("products").doc(productId).delete();
      if (mounted) {
        setState(() {
          products.removeWhere((p) => p.id == productId);
        });
      }
    } catch (e) {
      if (kDebugMode) print("❌ Delete failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12151B) : const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: const Text("My Dashboard", style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceUploadPage())).then((_) => loadProducts());
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? _buildEmptyState(context, primary)
              : RefreshIndicator(
                  onRefresh: loadProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    itemBuilder: (context, index) => _ModernProductListItem(
                      product: products[index],
                      onEdit: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => EditProductScreen(product: products[index]))).then((_) => loadProducts());
                      },
                      onDelete: deleteProduct,
                      onView: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(productId: products[index].id)));
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.storefront_rounded, size: 80, color: primary),
            ),
            const SizedBox(height: 32),
            const Text("Your storefront is empty", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text("Start your business journey today! Upload your first product to reach more customers.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.5)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketplaceUploadPage())).then((_) => loadProducts());
                },
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text("Add Product", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(backgroundColor: primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernProductListItem extends StatelessWidget {
  final FirebaseProduct product;
  final VoidCallback onEdit;
  final Function(String productId) onDelete;
  final VoidCallback onView;

  final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'TZS ', decimalDigits: 0);

  _ModernProductListItem({super.key, required this.product, required this.onEdit, required this.onDelete, required this.onView});

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Product?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to permanently delete '${_capitalize(product.name)}'?"),
        actions: <Widget>[
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(context).pop()),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () { Navigator.of(context).pop(); onDelete(product.id); },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;
    final formattedPrice = _currencyFormat.format(product.price);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(product.imageUrl, width: 85, height: 85, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_capitalize(product.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(formattedPrice, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: primary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSmallActionBtn(Icons.edit_rounded, primary.withValues(alpha: 0.1), primary, onEdit),
                        const SizedBox(width: 8),
                        _buildSmallActionBtn(Icons.delete_outline_rounded, Colors.red.withValues(alpha: 0.1), Colors.red, () => _showDeleteConfirmationDialog(context)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallActionBtn(IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(width: 85, height: 85, color: Colors.grey.shade100, child: const Icon(Icons.image_outlined, color: Colors.grey));
  }
}
