// 'customer_product_details_screen.dart'
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/cart_provider.dart';
import '../models/firebase_product.dart';
import '../models/product_item.dart';
import 'customer_cart_screen.dart';
import 'widgets/shopping/product_grid.dart';

extension StringExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class CustomerProductDetailsScreen extends StatefulWidget {
  final FirebaseProduct product;

  const CustomerProductDetailsScreen({super.key, required this.product});

  @override
  State<CustomerProductDetailsScreen> createState() =>
      _CustomerProductDetailsScreenState();
}

class _CustomerProductDetailsScreenState
    extends State<CustomerProductDetailsScreen> {
  List<ProductItem> _relatedProducts = [];
  bool _loadingRelated = true;
  int _currentImageIndex = 0;
  Map<String, dynamic>? _sellerInfo;
  late final PageController _pageController;
  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadRelatedProducts();
    _loadSellerInfo();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    if (widget.product.images.length > 1) {
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          int nextIndex = _currentImageIndex + 1;
          if (nextIndex >= widget.product.images.length) {
            nextIndex = 0;
          }
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadRelatedProducts() async {
    if (!mounted) return;
    setState(() => _loadingRelated = true);

    try {
      final tappedSubCategory = _normalize(widget.product.subCategory);

      // Fetch ALL ACTIVE products
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('status', isEqualTo: 'active')
          .get();

      // Filter ONLY same subCategory (EXCLUDES tapped product)
      final related = snap.docs
          .map((d) => FirebaseProduct.fromMap(d.id, d.data()))
          .where(
            (p) =>
                _normalize(p.subCategory) == tappedSubCategory &&
                p.id != widget.product.id,
          )
          .map((p) => ProductItem.fromFirebaseProduct(p))
          .take(10) // Limit to 10 related products
          .toList();

      if (mounted) {
        setState(() {
          _relatedProducts = related;
          _loadingRelated = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Related products error: $e');
      if (mounted) {
        setState(() => _loadingRelated = false);
      }
    }
  }

  Future<void> _loadSellerInfo() async {
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.product.sellerId)
          .get();

      if (sellerDoc.exists && mounted) {
        setState(() {
          _sellerInfo = sellerDoc.data();
        });
      }
    } catch (e) {
      debugPrint('❌ Seller info error: $e');
    }
  }

  String _normalize(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _formatPrice(double price, String currency) {
    final symbol = currency == 'USD' ? '\$' : 'Tsh';
    return '$symbol${_addCommas(price.toStringAsFixed(2))}';
  }

  String _addCommas(String price) {
    // Simple comma formatting
    List<String> parts = price.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '00';

    String formatted = '';
    for (int i = integerPart.length - 1, count = 0; i >= 0; i--, count++) {
      if (count % 3 == 0 && count > 0) {
        formatted = ',' + formatted;
      }
      formatted = integerPart[i] + formatted;
    }
    return '$formatted.$decimalPart';
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  void _onRelatedProductTap(ProductItem product) async {
    // Fetch the full FirebaseProduct
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();
      if (doc.exists) {
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

  void _addRelatedToCart(ProductItem product) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();
      if (doc.exists) {
        final firebaseProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        cartProvider.addItem(firebaseProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${firebaseProduct.name.capitalizeFirst()} added to cart!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  void _addToCart(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Check if already in cart
    final isInCart = cartProvider.isInCart(widget.product.id);

    if (!isInCart) {
      cartProvider.addItem(widget.product);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.product.name.capitalizeFirst()} added to cart!'),
          action: SnackBarAction(
            label: 'View Cart',
            onPressed: () {
              // Dismiss snackbar first, then navigate
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _navigateToCartScreen(context);
            },
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.product.name.capitalizeFirst()} is already in your cart!'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToCartScreen(BuildContext context) {
    // Use Navigator.of(context) to ensure proper navigation stack
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const CustomerCartScreen()));
  }

  void _buyNow(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Clear current cart and add only this item
    cartProvider.clearCart();
    cartProvider.addItem(widget.product);

    // Navigate directly to checkout
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CustomerCartScreen(), // Go to cart first, then they can proceed to checkout
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to cart! Proceed to checkout.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name.capitalizeFirst()),
        actions: [
          // Cart Icon with Badge
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      onPressed: () {
                        _navigateToCartScreen(context);
                      },
                    ),
                    if (cartProvider.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            cartProvider.itemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product images carousel
            if (widget.product.images.isNotEmpty)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.product.images.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.product.images[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: Icon(Icons.broken_image, size: 50),
                                ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  // Image indicators
                  if (widget.product.images.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.product.images.length,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              // Fallback single image
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      widget.product.imageUrl != null &&
                          widget.product.imageUrl!.isNotEmpty
                      ? Image.network(
                          widget.product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(Icons.broken_image, size: 50),
                              ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                ),
              ),

            const SizedBox(height: 20),

            // Product name
            Text(
              widget.product.name.capitalizeFirst(),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Price section with discount
            Row(
              children: [
                if (widget.product.discountPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Original price (strikethrough)
                      Text(
                        _formatPrice(
                          widget.product.price.toDouble(),
                          widget.product.currency,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      // Discounted price
                      Text(
                        '${widget.product.currency == 'USD' ? '\$' : 'Tsh'} ${widget.product.discountPrice}',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.product.discountDescription != null)
                        Text(
                          widget.product.discountDescription!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    _formatPrice(
                      widget.product.price.toDouble(),
                      widget.product.currency,
                    ),
                    style: TextStyle(
                      fontSize: 24,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                const Spacer(),

                // Sold count badge
                if (widget.product.soldCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag,
                          size: 16,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.product.soldCount} sold',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Product details grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Condition and Quantity row
                  Row(
                    children: [
                      if (widget.product.condition != null)
                        Expanded(
                          child: _buildDetailRow(
                            Icons.inventory_2,
                            'Condition',
                            widget.product.condition!.capitalizeFirst(),
                          ),
                        ),
                      if (widget.product.quantity > 0)
                        Expanded(
                          child: _buildDetailRow(
                            Icons.numbers,
                            'Available',
                            '${widget.product.quantity} left',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location and Delivery row
                  Row(
                    children: [
                      if (widget.product.location.isNotEmpty)
                        Expanded(
                          child: _buildDetailRow(
                            Icons.location_on,
                            'Location',
                            widget.product.location,
                          ),
                        ),
                      if (widget.product.deliveryOptions.isNotEmpty)
                        Expanded(
                          child: _buildDetailRow(
                            Icons.local_shipping,
                            'Delivery',
                            widget.product.deliveryOptions.join(', '),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category and Subcategory row
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          Icons.category,
                          'Category',
                          widget.product.category.capitalizeFirst(),
                        ),
                      ),
                      if (widget.product.subCategory != null)
                        Expanded(
                          child: _buildDetailRow(
                            Icons.label,
                            'Type',
                            widget.product.subCategory!.capitalizeFirst(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Description
            Text(
              widget.product.description ??
                  "No description available.", // Safe null check
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),

            const SizedBox(height: 25),

            // Seller Information Section
            if (_sellerInfo != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.blue[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.store,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Seller Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            (_sellerInfo?['name'] ?? 'S')[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (_sellerInfo?['name'] ?? 'Seller').toString().capitalizeFirst(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _sellerInfo?['phone'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Verified Seller',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Location: ${_sellerInfo?['location'] ?? 'Not specified'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            // Buttons
            Consumer<CartProvider>(
              builder: (context, cartProvider, child) {
                final isInCart = cartProvider.isInCart(widget.product.id);
                final cartQuantity = cartProvider.getQuantity(
                  widget.product.id,
                );

                return Column(
                  children: [
                    // ... inside Consumer<CartProvider>
                    // ...
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _addToCart(context),
                            icon: Icon(
                              isInCart ? Icons.check : Icons.shopping_cart,
                            ),
                            label: Text(
                              isInCart
                                  ? "In Cart ($cartQuantity)"
                                  : "Add to Cart",
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              // Set foregroundColor to white for text/icon color
                              foregroundColor:
                                  Colors.white, // <-- ADDED THIS LINE
                              backgroundColor: isInCart
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _buyNow(context),
                            icon: const Icon(Icons.bolt),
                            label: const Text("Buy Now"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors
                                  .white, // Already correctly set to white
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ...
                    // Quantity controls if in cart
                    if (isInCart)
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                onPressed: () {
                                  cartProvider.removeSingleItem(
                                    widget.product.id,
                                  );
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                              ),
                              Text(
                                'Quantity: $cartQuantity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  cartProvider.addItem(widget.product);
                                },
                                icon: const Icon(Icons.add_circle_outline),
                                color: Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              cartProvider.removeItem(widget.product.id);
                            },
                            icon: const Icon(Icons.remove_shopping_cart),
                            label: const Text('Remove from cart'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Related Products
            if (_relatedProducts.isNotEmpty) ...[
              Text(
                'Related Products',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ProductGrid(
                products: _relatedProducts,
                onProductTap: _onRelatedProductTap,
                onAddToCart: _addRelatedToCart,
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
