import 'package:flutter/material.dart';
import '../../advanced_search_bar.dart';
import '../models/product_item.dart';
import '../constants/shopping_constants.dart';
import 'widgets/shopping/category_chip.dart';
import 'widgets/shopping/product_grid.dart';
import 'widgets/shopping/section_header.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String _selectedCategory = "All";
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<ProductItem> _filteredProducts = ProductItem.sampleProducts;

  @override
  void initState() {
    super.initState();
    _filterProducts();
  }

  void _filterProducts() {
    setState(() {
      if (_selectedCategory == "All" && _searchQuery.isEmpty) {
        _filteredProducts = ProductItem.sampleProducts;
      } else {
        _filteredProducts = ProductItem.sampleProducts.where((product) {
          final matchesCategory =
              _selectedCategory == "All" ||
              product.category == _selectedCategory;
          final matchesSearch = product.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          return matchesCategory && matchesSearch;
        }).toList();
      }
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterProducts();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    _filterProducts();
  }

  void _onProductTap(ProductItem product) {
    // Navigate to product details
    print('Product tapped: ${product.name}');
  }

  void _onAddToCart(ProductItem product) {
    // Add product to cart
    print('Added to cart: ${product.name}');

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
            print('Navigate to cart');
          },
        ),
      ),
    );
  }

  void _onSeeMoreTap(String section) {
    // Navigate to category or section
    print('See more tapped for: $section');
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
    _filterProducts();
  }

  // Get products for different sections based on current filters
  List<ProductItem> get _topDealsProducts => _filteredProducts.take(3).toList();
  List<ProductItem> get _groceryKitchenProducts => _filteredProducts
      .where((product) => product.category == "Grocery")
      .take(3)
      .toList();
  List<ProductItem> get _viewMoreProducts =>
      _filteredProducts.skip(6).take(2).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 Advanced Search Bar
            AdvancedSearchBar(
              hintText: "Search products...",
              onSearchChanged: _onSearchChanged,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categories horizontal scroll
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: ShoppingConstants.categories.map((category) {
                          return CategoryChip(
                            label: category,
                            isSelected: _selectedCategory == category,
                            onTap: () => _onCategorySelected(category),
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
                      // Top Deals Section
                      if (_topDealsProducts.isNotEmpty) ...[
                        ShoppingSectionHeader(
                          title: ShoppingConstants.topDealsTitle,
                          onSeeMoreTap: () =>
                              _onSeeMoreTap(ShoppingConstants.topDealsTitle),
                        ),
                        const SizedBox(height: 8),
                        ProductGrid(
                          products: _topDealsProducts,
                          onProductTap: _onProductTap,
                          onAddToCart: _onAddToCart,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Grocery and Kitchen Section
                      if (_groceryKitchenProducts.isNotEmpty) ...[
                        ShoppingSectionHeader(
                          title: ShoppingConstants.groceryKitchenTitle,
                          onSeeMoreTap: () => _onSeeMoreTap(
                            ShoppingConstants.groceryKitchenTitle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ProductGrid(
                          products: _groceryKitchenProducts,
                          onProductTap: _onProductTap,
                          onAddToCart: _onAddToCart,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // View More Section
                      if (_viewMoreProducts.isNotEmpty) ...[
                        ShoppingSectionHeader(
                          title: ShoppingConstants.viewMoreTitle,
                          onSeeMoreTap: () =>
                              _onSeeMoreTap(ShoppingConstants.viewMoreTitle),
                        ),
                        const SizedBox(height: 8),
                        ProductGrid(
                          products: _viewMoreProducts,
                          onProductTap: _onProductTap,
                          onAddToCart: _onAddToCart,
                        ),
                        const SizedBox(height: 24),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
