import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../advanced_search_bar.dart';
import '../../provider/cart_provider.dart';
import '../models/product_item.dart';
import '../models/firebase_product.dart';
import 'customer_product_details_screen.dart';
import 'customer_cart_screen.dart';
import 'widgets/shopping/category_chip.dart';
import 'widgets/shopping/product_grid.dart';
import 'widgets/shopping/section_header.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String _selectedSubCategory = "All";
  String _searchQuery = '';
  List<String> _subCategories = ["All"];
  final TextEditingController _searchController = TextEditingController();
  List<ProductItem> _allProducts = [];
  List<ProductItem> _filteredProducts = [];
  bool _loading = true;
  bool _isFilterExpanded = false;

  // Advanced filters
  RangeValues _priceRange = const RangeValues(0, 1000000);
  String _selectedCondition = "All";

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);

    try {
      final firebaseSnap = await FirebaseFirestore.instance
          .collection("products")
          .get();

      final firebaseProducts = firebaseSnap.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .map((fp) => ProductItem.fromFirebaseProduct(fp))
          .toList();

      _allProducts = firebaseProducts;
      
      final Set<String> dynamicSubCats = _allProducts
          .map((p) => p.subCategory?.trim() ?? '')
          .where((c) => c.isNotEmpty)
          .map((c) => _normalizeCategoryLabel(c))
          .toSet();

      final Set<String> dynamicConditions = _allProducts
          .map((p) => p.condition?.trim() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();

      final List<String> merged = ["All"];
      for (final c in dynamicSubCats) {
        if (!merged.map((e) => e.toLowerCase()).contains(c.toLowerCase())) {
          merged.add(c);
        }
      }
      _subCategories = merged;

      final List<String> conditions = ["All"];
      for (final c in dynamicConditions) {
        if (!conditions.map((e) => e.toLowerCase()).contains(c.toLowerCase())) {
          conditions.add(c);
        }
      }

      if (_allProducts.isNotEmpty) {
        final prices = _allProducts
            .map((p) => double.tryParse(p.price) ?? 0)
            .toList();
        final minPrice = prices.reduce((a, b) => a < b ? a : b);
        final maxPrice = prices.reduce((a, b) => a > b ? a : b);
        _priceRange = RangeValues(minPrice, maxPrice);
      }

      _filterProducts();
    } catch (e) {
      if (kDebugMode) {
        print("❌ Failed to load products: $e");
      }
      _allProducts = [];
      _filterProducts();
    }

    setState(() => _loading = false);
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesSubCategory =
            _selectedSubCategory == "All" ||
            _normalize(product.subCategory ?? '') ==
                _normalize(_selectedSubCategory);

        final matchesSearch = product.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );

        final matchesCondition =
            _selectedCondition == "All" ||
            (product.condition?.toLowerCase() ?? '') ==
                _selectedCondition.toLowerCase();

        final productPrice = double.tryParse(product.price) ?? 0;
        final matchesPrice =
            productPrice >= _priceRange.start &&
            productPrice <= _priceRange.end;

        return matchesSubCategory &&
            matchesSearch &&
            matchesCondition &&
            matchesPrice;
      }).toList();
    });
  }

  void _onSubCategorySelected(String subCategory) {
    setState(() {
      _selectedSubCategory = subCategory;
    });
    _filterProducts();
  }

  void _onConditionSelected(String condition) {
    setState(() {
      _selectedCondition = condition;
    });
    _filterProducts();
  }

  void _onPriceRangeChanged(RangeValues values) {
    setState(() {
      _priceRange = values;
    });
    _filterProducts();
  }

  void _resetFilters() {
    setState(() {
      _selectedSubCategory = "All";
      _searchQuery = '';
      _selectedCondition = "All";
      if (_allProducts.isNotEmpty) {
        final prices = _allProducts
            .map((p) => double.tryParse(p.price) ?? 0)
            .toList();
        final minPrice = prices.reduce((a, b) => a < b ? a : b);
        final maxPrice = prices.reduce((a, b) => a > b ? a : b);
        _priceRange = RangeValues(minPrice, maxPrice);
      }
      _searchController.clear();
    });
    _filterProducts();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterProducts();
  }

  void _onProductTap(ProductItem product) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();
      if (doc.exists) {
        final firebaseProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CustomerProductDetailsScreen(product: firebaseProduct),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching product: $e');
      }
    }
  }

  Future<void> _onAddToCart(ProductItem product) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();

      if (!doc.exists) return;

      final firebaseProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);

      if (mounted) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        cartProvider.addItem(firebaseProduct);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart!'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerCartScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding to cart: $e');
      }
    }
  }

  Map<String, List<ProductItem>> get _productsBySubCategory {
    final Map<String, List<ProductItem>> grouped = {};
    for (final product in _filteredProducts) {
      final subCategory = product.subCategory ?? '';
      if (!grouped.containsKey(subCategory)) {
        grouped[subCategory] = [];
      }
      grouped[subCategory]!.add(product);
    }
    return grouped;
  }

  String _normalize(String? s) {
    if (s == null) return '';
    return s.trim().toLowerCase();
  }

  String _normalizeCategoryLabel(String s) {
    final n = _normalize(s);
    if (n.isEmpty) return '';
    return n[0].toUpperCase() + n.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Shopping'),
        backgroundColor: bgColor,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerCartScreen(),
                    ),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Consumer<CartProvider>(
                  builder: (context, cart, child) {
                    return cart.itemCount > 0
                        ? Container(
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
                              '${cart.itemCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 🔍 Search + Filter Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: AdvancedSearchBar(
                            hintText: "Search...",
                            onSearchChanged: _onSearchChanged,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _isFilterExpanded
                                ? Icons.filter_list_off
                                : Icons.filter_list,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _isFilterExpanded = !_isFilterExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // 🎛️ Collapsible Filters Section
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: _isFilterExpanded ? null : 0,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Price Range',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextButton(
                                  onPressed: _resetFilters,
                                  child: const Text('Reset'),
                                ),
                              ],
                            ),
                            Text(
                              'Tsh ${_priceRange.start.toInt()} - Tsh ${_priceRange.end.toInt()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            RangeSlider(
                              values: _priceRange,
                              min: 0,
                              max: 1000000,
                              divisions: 100,
                              onChanged: _onPriceRangeChanged,
                              activeColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subcategories horizontal scroll
                          SizedBox(
                            height: 48,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _subCategories.map((subCategory) {
                                return CategoryChip(
                                  label: subCategory,
                                  isSelected:
                                      _normalize(_selectedSubCategory) ==
                                      _normalize(subCategory),
                                  onTap: () =>
                                      _onSubCategorySelected(subCategory),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 10),

                          if (_filteredProducts.isEmpty)
                            const Center(
                              child: Column(
                                children: [
                                  SizedBox(height: 40),
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No products found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            for (final entry
                                in _productsBySubCategory.entries) ...[
                              if (entry.value.isNotEmpty) ...[
                                ShoppingSectionHeader(
                                  title: entry.key.isEmpty
                                      ? "Other"
                                      : entry.key,
                                ),
                                const SizedBox(height: 8),
                                ProductGrid(
                                  products: entry.value,
                                  onProductTap: _onProductTap,
                                  onAddToCart: _onAddToCart,
                                ),
                                const SizedBox(height: 16),
                              ],
                            ],
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
