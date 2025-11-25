import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/firebase_product.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  FirebaseProduct? product;
  Map<String, dynamic>? seller;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    // Fetch product
    final doc = await FirebaseFirestore.instance
        .collection("products")
        .doc(widget.productId)
        .get();

    if (!doc.exists) return;

    final fbProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);

    // Fetch seller
    final sellerDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(fbProduct.sellerId)
        .get();

    if (mounted) {
      setState(() {
        product = fbProduct;
        seller = sellerDoc.data();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔑 Access Theme Colors
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textColor = Theme.of(context).textTheme.bodyMedium!.color!;

    if (product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool hasImage = product!.imageUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(product!.name), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Product Image Section (with error handling) ---
            hasImage
                ? Image.network(
                    product!.imageUrl,
                    height: 280,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 280,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 280,
                        width: double.infinity,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    height: 280,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  ),
            // ---------------------------------------------------

            // --- Product Info Section ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product!.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "TZS ${product!.price}",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: primaryColor, // Use primary color for emphasis
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Use a structured row for key details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DetailChip(
                        label: product!.condition,
                        icon: Icons.straighten,
                        color: primaryColor,
                      ),
                      _DetailChip(
                        label: product!.category,
                        icon: Icons.category,
                        color: primaryColor,
                      ),
                      _DetailChip(
                        label: product!.subCategory,
                        icon: Icons.subtitles,
                        color: primaryColor,
                      ),
                    ],
                  ),

                  if (product!.description != null &&
                      product!.description!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      "Description",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product!.description!,
                      style: TextStyle(
                        fontSize: 15,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // --- Modernized Seller Information ---
                  if (seller != null)
                    _SellerCard(seller: seller!, primaryColor: primaryColor),
                  // ------------------------------------
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// CUSTOM WIDGET 1: Seller Information Card
// -------------------------------------------------------------------

class _SellerCard extends StatelessWidget {
  final Map<String, dynamic> seller;
  final Color primaryColor;

  const _SellerCard({required this.seller, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: primaryColor, size: 28),
                const SizedBox(width: 8),
                Text(
                  "Seller Information",
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            _SellerDetailRow(
              icon: Icons.person_outline,
              label: "Name",
              value: seller['name'] ?? 'N/A',
            ),
            _SellerDetailRow(
              icon: Icons.phone_outlined,
              label: "Phone",
              value: seller['phone'] ?? 'N/A',
            ),
            _SellerDetailRow(
              icon: Icons.badge_outlined,
              label: "Role",
              // Changed from sellerType to role as per your latest code
              value: seller['role'] ?? 'N/A',
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// CUSTOM WIDGET 2: Seller Detail Row
// -------------------------------------------------------------------

class _SellerDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SellerDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).textTheme.bodySmall!.color,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// CUSTOM WIDGET 3: Detail Chip
// -------------------------------------------------------------------
class _DetailChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _DetailChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
