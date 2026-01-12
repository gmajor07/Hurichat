import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../advanced_search_bar.dart';
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

  // Advanced filters
  RangeValues _priceRange = const RangeValues(0, 1000000);
  String _selectedCondition = "All";
  List<String> _availableConditions = ["All"];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);

    try {
      // Load Firebase products only
      final firebaseSnap = await FirebaseFirestore.instance
          .collection("products")
          .get();

      final firebaseProducts = firebaseSnap.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .map((fp) => ProductItem.fromFirebaseProduct(fp))
          .toList();

      _allProducts = firebaseProducts;
      // Build subcategories list from uploaded product subCategories
      final Set<String> dynamicSubCats = _allProducts
          .map((p) => p.subCategory?.trim() ?? '')
          .where((c) => c.isNotEmpty)
          .map((c) => _normalizeCategoryLabel(c))
          .toSet();

      // Build conditions list
      final Set<String> dynamicConditions = _allProducts
          .map((p) => p.condition?.trim() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();

      // Create subcategories list starting with "All"
      final List<String> merged = ["All"];
      for (final c in dynamicSubCats) {
        if (!merged.map((e) => e.toLowerCase()).contains(c.toLowerCase())) {
          merged.add(c);
        }
      }
      _subCategories = merged;

      // Create conditions list starting with "All"
      final List<String> conditions = ["All"];
      for (final c in dynamicConditions) {
        if (!conditions.map((e) => e.toLowerCase()).contains(c.toLowerCase())) {
          conditions.add(c);
        }
      }
      _availableConditions = conditions;

      // Set up price range based on available products
      if (_allProducts.isNotEmpty) {
        final prices = _allProducts.map((p) => double.tryParse(p.price) ?? 0).toList();
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
        // Subcategory filter
        final matchesSubCategory =
            _selectedSubCategory == "All" ||
            _normalize(product.subCategory ?? '') ==
                _normalize(_selectedSubCategory);

        // Search query filter
        final matchesSearch = product.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );

        // Condition filter
        final matchesCondition =
            _selectedCondition == "All" ||
            (product.condition?.toLowerCase() ?? '') ==
                _selectedCondition.toLowerCase();

        // Price range filter
        final productPrice = double.tryParse(product.price) ?? 0;
        final matchesPrice = productPrice >= _priceRange.start &&
                           productPrice <= _priceRange.end;

        return matchesSubCategory && matchesSearch && matchesCondition && matchesPrice;
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
        final prices = _allProducts.map((p) => double.tryParse(p.price) ?? 0).toList();
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
      if (kDebugMode) {
        print('Error fetching product: $e');
      }
    }
  }

  void _onAddToCart(ProductItem product) {
    // Add product to cart
    if (kDebugMode) {
      print('Added to cart: ${product.name}');
    }

    // Show confirmation snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart!'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            // Navigate to cart screen
            if (kDebugMode) {
              print('Navigate to cart');
            }
          },
        ),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
    _filterProducts();
  }

  // Group products by subcategory for dynamic sections
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

  // Helpers to normalize category/strings so uploaded values match UI filters
  String _normalize(String? s) {
    if (s == null) return '';
    return s.trim().toLowerCase();
  }

  // Take a raw category value and return a normalized display label
  String _normalizeCategoryLabel(String s) {
    final n = _normalize(s);
    if (n.isEmpty) return '';
    // Capitalize first letter for display
    return n[0].toUpperCase() + n.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 🔍 Advanced Search Bar
                  AdvancedSearchBar(
                    hintText: "Search products...",
                    onSearchChanged: _onSearchChanged,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),

                  // 🎛️ Advanced Filters Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _resetFilters,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset'),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Price Range Filter
                        Text(
                          'Price Range: Tsh ${_priceRange.start.toInt()} - Tsh ${_priceRange.end.toInt()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        RangeSlider(
                          values: _priceRange,
                          min: 0,
                          max: 1000000,
                          divisions: 100,
                          labels: RangeLabels(
                            'Tsh ${_priceRange.start.toInt()}',
                            'Tsh ${_priceRange.end.toInt()}',
                          ),
                          onChanged: _onPriceRangeChanged,
                          activeColor: Theme.of(context).colorScheme.primary,
                        ),

                        const SizedBox(height: 12),

                        // Condition Filter
                        Text(
                          'Condition',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableConditions.map((condition) {
                            final isSelected = _selectedCondition == condition;
                            return FilterChip(
                              label: Text(condition),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  _onConditionSelected(condition);
                                }
                              },
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              checkmarkColor: Theme.of(context).colorScheme.primary,
                            );
                          }).toList(),
                        ),
                      ],
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

                          // Show message if no products found
                          if (_filteredProducts.isEmpty)
                            const Center(
                              child: Column(
                                children: [
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
                                  SizedBox(height: 8),
                                  Text(
                                    'Try a different search or category',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            // Dynamic sections for each subcategory
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerCartScreen()),
          );
        },
        backgroundColor: const Color(0xFF4CAFAB),
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
