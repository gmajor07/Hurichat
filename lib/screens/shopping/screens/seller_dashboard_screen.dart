import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    loadProducts();
    _fetchSellerName();
  }

  Future<void> _fetchSellerName() async {
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
    setState(() => loading = true);

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
      print("❌ Failed to load products: $e");
      if (mounted) setState(() => loading = false);
    }
  }

  // The actual function that performs the deletion and updates the list
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
      print("❌ Delete failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access the primary color from the current theme's color scheme
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Products"),
        centerTitle: true,
        elevation: 4,
        shadowColor: Theme.of(context).shadowColor.withOpacity(0.5),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Styled Debug/Info Header ---
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "👤 Seller: $_sellerName",
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                Text(
                  "🆔 ID: ${widget.sellerId}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).textTheme.bodySmall!.color!.withOpacity(0.6),
                  ),
                ),
                const Divider(height: 18, thickness: 1),
              ],
            ),
          ),

          // --------------------------------
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? Center(
                    child: Text(
                      "You haven't uploaded any products yet.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
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

                      return _ProductListItem(
                        product: p,
                        primaryColor: primaryColor,
                        // Edit: navigates and reloads upon return
                        onEdit: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProductScreen(product: p),
                            ),
                          ).then((_) => loadProducts());
                        },
                        // Delete: calls the main delete function
                        onDelete: deleteProduct,
                        // View: navigates to details screen
                        onView: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailsScreen(productId: p.id),
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
// 2. CUSTOM WIDGET: Modern Product List Item (WITH DELETE WARNING)
// -------------------------------------------------------------------

class _ProductListItem extends StatelessWidget {
  final FirebaseProduct product;
  final Color primaryColor;
  final VoidCallback onEdit;
  // Function signature now matches the stateful widget's deleteProduct
  final Function(String productId) onDelete;
  final VoidCallback onView;

  const _ProductListItem({
    required this.product,
    required this.primaryColor,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
  });

  // Helper method to show the confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: Text(
            "Are you sure you want to permanently delete '${product.name}'? This action cannot be undone.",
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Use red for destructive action
              ),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                onDelete(product.id); // Execute the deletion
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onView,
      // Use a Card with more shadow and rounded corners for a modern feel
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 6, // Increased elevation for a floating look
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Product Image / Placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 70,
                            height: 70,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              size: 30,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 70,
                        height: 70,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 30,
                          color: Colors.grey,
                        ),
                      ),
              ),

              const SizedBox(width: 16),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "TZS ${product.price}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor, // Themed color for price
                      ),
                    ),
                  ],
                ),
              ),

              // Actions (PopupMenuButton)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: primaryColor), // Themed icon
                onSelected: (value) {
                  if (value == "edit") {
                    onEdit();
                  } else if (value == "delete") {
                    // 🔑 Action now triggers the confirmation dialog
                    _showDeleteConfirmationDialog(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "edit",
                    child: Text("Edit Product"),
                  ),
                  const PopupMenuItem(
                    value: "delete",
                    child: Text(
                      "Delete Product",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
