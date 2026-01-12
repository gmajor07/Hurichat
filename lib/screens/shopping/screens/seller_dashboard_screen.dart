import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 1. Added for price formatting

import '../../seller/upload_product.dart';
import '../models/firebase_product.dart';
import 'edit_product_screen.dart';
import 'product_details_screen.dart';

// -------------------------------------------------------------------
// 1. SELLER PRODUCTS SCREEN (STATEFUL WIDGET)
// -------------------------------------------------------------------

class SellerProductsScreen extends StatefulWidget {
  final String sellerId; // logged-in user id

  const SellerProductsScreen({super.key, required this.sellerId});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  List<FirebaseProduct> products = [];
  bool loading = true;
  String _sellerName = "Loading seller name...";

  // --- Initialization and Data Loading (Unchanged logic) ---
  @override
  void initState() {
    super.initState();
    loadProducts();
    _fetchSellerName();
  }

  Future<void> _fetchSellerName() async {
    // ... (unchanged fetch logic)
    if (widget.sellerId.isEmpty) {
      if (mounted) setState(() => _sellerName = 'No Seller ID provided');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.sellerId)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          final name = userDoc.data()?['name'] ?? 'Name not set';
          setState(() {
            _sellerName = name;
          });
        } else {
          setState(() {
            _sellerName = 'User document not found';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sellerName = 'Error loading name';
        });
      }
    }
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
      if (kDebugMode) {
        print("❌ Failed to load products: $e");
      }
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection("products")
          .doc(productId)
          .delete();

      if (mounted) {
        setState(() {
          products.removeWhere((p) => p.id == productId);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ Delete failed: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("My Products"), centerTitle: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Info Header ---
          const Divider(height: 24, indent: 16, endIndent: 16),

          // --------------------------------
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Visual Cue
                    Icon(
                      Icons.storefront_outlined,
                      size: 80,
                      color: const Color(0xFF4CAFaa).withOpacity(0.5),
                    ),
                    const SizedBox(height: 24),
                    // Encouraging Text
                    Text(
                      "Your storefront is empty",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Start your business journey today! Upload your first product to reach more customers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    // Directional Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MarketplaceUploadPage(),
                          ),
                        ).then((_) => loadProducts()); // Reload list when they come back
                      },
                      icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                      label: const Text(
                        "Add Your First Product",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAFaa),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                return _ModernProductListItem(
                  product: p,
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProductScreen(product: p),
                      ),
                    ).then((_) => loadProducts());
                  },
                  onDelete: deleteProduct,
                  onView: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailsScreen(productId: p.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// 2. CUSTOM WIDGET: Modern Product List Item (with new actions/formatting)
// -------------------------------------------------------------------

class _ModernProductListItem extends StatelessWidget {
  final FirebaseProduct product;
  final VoidCallback onEdit;
  final Function(String productId) onDelete;
  final VoidCallback onView;

  // 1. Price Formatter: This field requires runtime initialization
  // and is NOT a compile-time constant.
  final _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'TZS ',
    decimalDigits: 0,
  );

  // FIX: Removed 'const' keyword here because of the non-constant field above.
  // The super key must still be passed to the superclass constructor.
  _ModernProductListItem({
    super.key, // Ensure super.key is passed if you have a key field
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });


  // Helper method to capitalize the first letter of a string
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  // Helper method to show the confirmation dialog (Unchanged logic)
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Confirm Deletion",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          content: Text(
            "Are you sure you want to permanently delete '${_capitalize(product.name)}'? This action cannot be undone.",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                onDelete(product.id);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final formattedPrice = _currencyFormat.format(product.price);
    final capitalizedName = _capitalize(product.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // --- Image / Placeholder ---
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported,
                              size: 30,
                              color: colorScheme.onSurfaceVariant,
                            );
                          },
                        )
                      : Icon(
                          Icons.image_not_supported,
                          size: 30,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // --- Product Details (Name Capitalized & Price Formatted) ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitalizedName, // 3. Capitalized Name
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedPrice, // 1. Formatted Price
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // --- Actions (Replaced 3-dot with explicit buttons) ---
              // 2. Explicit Edit Button
              IconButton(
                icon: Icon(Icons.edit_outlined, color: colorScheme.secondary),
                onPressed: onEdit,
                tooltip: "Edit Product",
              ),

              // 2. Explicit Delete Button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red, // Use red to signify caution
                ),
                onPressed: () => _showDeleteConfirmationDialog(context),
                tooltip: "Delete Product",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
