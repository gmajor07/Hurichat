// 'customer_product_details_screen.dart'
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  int _currentImageIndex = 0;
  Map<String, dynamic>? _sellerInfo;
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  double _averageRating = 0;
  int _ratingCount = 0;
  double _myRating = 0;
  bool _savingRating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadRelatedProducts();
    _loadSellerInfo();
    _loadRatings();
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

  Future<void> _loadRatings() async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id)
          .get();
      final data = productDoc.data() ?? {};

      final dynamic ratingRaw = data['rating'];
      final dynamic countRaw = data['ratingCount'];
      final avg = ratingRaw is num ? ratingRaw.toDouble() : 0.0;
      final count = countRaw is num ? countRaw.toInt() : 0;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      double myRating = 0;
      if (userId != null) {
        final myDoc = await FirebaseFirestore.instance
            .collection('products')
            .doc(widget.product.id)
            .collection('ratings')
            .doc(userId)
            .get();
        final myData = myDoc.data();
        if (myData != null && myData['rating'] is num) {
          myRating = (myData['rating'] as num).toDouble();
        }
      }

      if (!mounted) return;
      setState(() {
        _averageRating = avg;
        _ratingCount = count;
        _myRating = myRating;
      });
    } catch (e) {
      debugPrint('❌ Rating load error: $e');
    }
  }

  Future<void> _rateProduct(double newRating) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to rate this product')),
      );
      return;
    }
    if (_savingRating) return;

    setState(() => _savingRating = true);
    try {
      final productRef = FirebaseFirestore.instance
          .collection('products')
          .doc(widget.product.id);
      final ratingRef = productRef.collection('ratings').doc(userId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final productSnap = await tx.get(productRef);
        final ratingSnap = await tx.get(ratingRef);

        final productData = productSnap.data() ?? {};
        final existingAvg = productData['rating'];
        final existingCount = productData['ratingCount'];
        final existingTotal = productData['ratingTotal'];

        double avg = existingAvg is num ? existingAvg.toDouble() : 0;
        int count = existingCount is num ? existingCount.toInt() : 0;
        double total = existingTotal is num
            ? existingTotal.toDouble()
            : avg * count;

        final oldData = ratingSnap.data();
        final oldRating = oldData != null && oldData['rating'] is num
            ? (oldData['rating'] as num).toDouble()
            : null;

        if (oldRating != null) {
          total = total - oldRating + newRating;
        } else {
          total += newRating;
          count += 1;
        }

        final nextAvg = count > 0 ? total / count : 0.0;
        tx.set(ratingRef, {
          'rating': newRating,
          'updatedAt': FieldValue.serverTimestamp(),
          'userId': userId,
        });
        tx.update(productRef, {
          'rating': nextAvg,
          'ratingCount': count,
          'ratingTotal': total,
        });
      });

      if (!mounted) return;
      await _loadRatings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You rated this product ${newRating.toStringAsFixed(1)}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Rating update error: $e');
    } finally {
      if (mounted) {
        setState(() => _savingRating = false);
      }
    }
  }

  Future<void> _loadRelatedProducts() async {
    if (!mounted) return;

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
        });
      }
    } catch (e) {
      debugPrint('❌ Related products error: $e');
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
        formatted = ',$formatted';
      }
      formatted = '${integerPart[i]}$formatted';
    }
    return '$formatted.$decimalPart';
  }

  Widget _buildGalleryPlaceholder() {
    return Container(
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: SvgPicture.asset('assets/icon/gallery.svg', width: 72, height: 72),
    );
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

  void _addRelatedToCart(ProductItem product) async {
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
            content: Text(
              '${firebaseProduct.name.capitalizeFirst()} added to cart!',
            ),
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
          content: Text(
            '${widget.product.name.capitalizeFirst()} added to cart!',
          ),
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
          content: Text(
            '${widget.product.name.capitalizeFirst()} is already in your cart!',
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark
          ? const Color(0xFF12151B)
          : const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        title: const Text('Detail Product'),
        actions: [
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
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 430,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.product.images.isNotEmpty)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.product.images.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return Image.network(
                          widget.product.images[index],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildGalleryPlaceholder(),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        );
                      },
                    )
                  else if (widget.product.imageUrl.isNotEmpty)
                    Image.network(
                      widget.product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildGalleryPlaceholder(),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    )
                  else
                    _buildGalleryPlaceholder(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.22),
                        ],
                      ),
                    ),
                  ),
                  if (widget.product.images.length > 1)
                    Positioned(
                      bottom: 26,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.product.images.length,
                          (index) => Container(
                            width: _currentImageIndex == index ? 16 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: _currentImageIndex == index
                                  ? const Color(0xFF0E7C86)
                                  : Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF12151B)
                      : const Color(0xFFF3F5F8),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name.capitalizeFirst(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const [
                        _MetaChip(label: 'Colors'),
                        _MetaChip(label: 'Size'),
                        _MetaChip(label: 'Premium'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final starValue = index + 1.0;
                          return IconButton(
                            onPressed: _savingRating
                                ? null
                                : () => _rateProduct(starValue),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: Icon(
                              _myRating >= starValue
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFF8B332),
                              size: 22,
                            ),
                          );
                        }),
                        const SizedBox(width: 6),
                        Text(
                          '${_averageRating.toStringAsFixed(1)} ($_ratingCount)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (widget.product.discountPrice != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              Text(
                                '${widget.product.currency == 'USD' ? '\$' : 'Tsh'} ${widget.product.discountPrice}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  color: Color(0xFFE77B2E),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (widget.product.discountDescription != null)
                                Text(
                                  widget.product.discountDescription!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFE77B2E),
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
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF0E7C86),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const Spacer(),
                        if (widget.product.soldCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7EE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shopping_bag,
                                  size: 16,
                                  color: Color(0xFF289653),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.product.soldCount} sold',
                                  style: const TextStyle(
                                    color: Color(0xFF289653),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B1F28) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2F3642)
                              : const Color(0xFFE4E8EE),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (widget.product.condition.isNotEmpty)
                                Expanded(
                                  child: _buildDetailRow(
                                    Icons.inventory_2,
                                    'Condition',
                                    widget.product.condition.capitalizeFirst(),
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
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailRow(
                                  Icons.category,
                                  'Category',
                                  widget.product.category.capitalizeFirst(),
                                ),
                              ),
                              if (widget.product.subCategory.isNotEmpty)
                                Expanded(
                                  child: _buildDetailRow(
                                    Icons.label,
                                    'Type',
                                    widget.product.subCategory
                                        .capitalizeFirst(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.product.description ?? 'No description available.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? Colors.grey.shade200 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 25),
                    if (_sellerInfo != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B1F28)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2F3642)
                                : const Color(0xFFE4E8EE),
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
                                        Theme.of(context).brightness ==
                                            Brightness.dark
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
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    (_sellerInfo?['name'] ?? 'S')[0]
                                        .toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (_sellerInfo?['name'] ?? 'Seller')
                                            .toString()
                                            .capitalizeFirst(),
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
                                    color: Colors.green.withValues(alpha: 0.1),
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
                    Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                        final isInCart = cartProvider.isInCart(
                          widget.product.id,
                        );
                        final cartQuantity = cartProvider.getQuantity(
                          widget.product.id,
                        );
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addToCart(context),
                                    icon: Icon(
                                      isInCart
                                          ? Icons.check
                                          : Icons.shopping_cart,
                                    ),
                                    label: Text(
                                      isInCart
                                          ? 'In Cart ($cartQuantity)'
                                          : 'Add to Cart',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      backgroundColor: isInCart
                                          ? const Color(0xFF2BAA57)
                                          : const Color(0xFF0E7C86),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _buyNow(context),
                                    icon: const Icon(Icons.bolt),
                                    label: const Text('Buy Now'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE77B2E),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
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
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      cartProvider.removeItem(
                                        widget.product.id,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.remove_shopping_cart,
                                    ),
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
                    if (_relatedProducts.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Related Products',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${_relatedProducts.length} items',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
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
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF16364A),
        ),
      ),
    );
  }
}
