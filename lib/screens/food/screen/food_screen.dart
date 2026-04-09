import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/cart_provider.dart';
import '../../shopping/models/firebase_product.dart';
import '../../shopping/models/product_item.dart';
import '../../shopping/screens/customer_cart_screen.dart';
import '../../shopping/screens/customer_product_details_screen.dart';
import '../../shopping/screens/widgets/shopping/category_chip.dart';
import '../../shopping/screens/widgets/shopping/product_grid.dart';
import '../../shopping/screens/widgets/shopping/section_header.dart';
import '../models/restaurant.dart';
import '../widgets/restaurant_card.dart';
import 'restaurant_details_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<String> _categories = ['All'];
  List<FirebaseProduct> _allFoodProducts = [];
  List<FirebaseProduct> _filteredFoodProducts = [];
  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('products')
            .where('sellerType', isEqualTo: 'food')
            .where('status', isEqualTo: 'active')
            .get(),
        FirebaseFirestore.instance
            .collection('businesses')
            .where('serviceType', isEqualTo: 'food')
            .get(),
      ]);

      final productSnap = results[0];
      final businessSnap = results[1];

      _allFoodProducts =
          productSnap.docs
              .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
              .toList()
            ..sort(_compareProductsForListing);

      _restaurants =
          businessSnap.docs.map((doc) {
            final data = doc.data();
            return Restaurant(
              id: (data['userId'] ?? doc.id).toString(),
              name: (data['name'] ?? 'Restaurant').toString(),
              imagePath: (data['imageUrl'] ?? '').toString(),
              distance: 1.0,
              rating: _parseRating(data),
              cuisine: (data['description'] ?? 'Fresh meals').toString(),
              deliveryTime: 30,
            );
          }).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

      _categories = [
        'All',
        ..._allFoodProducts
            .map((food) => food.category.trim())
            .where((category) => category.isNotEmpty)
            .map(_normalizeCategoryLabel)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
      ];

      _filterFoods();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load food data: $e');
      }
      _allFoodProducts = [];
      _filteredFoodProducts = [];
      _restaurants = [];
      _categories = ['All'];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _filterFoods() {
    final query = _normalize(_searchQuery);

    setState(() {
      _filteredFoodProducts = _allFoodProducts.where((food) {
        final matchesCategory =
            _selectedCategory == 'All' ||
            _normalize(food.category) == _normalize(_selectedCategory);

        final matchesRestaurant =
            _selectedRestaurant == null ||
            food.sellerId == _selectedRestaurant!.id;

        final searchable = [
          _normalize(food.name),
          _normalize(food.category),
          _normalize(food.subCategory),
          _normalize(food.description ?? ''),
        ];

        final matchesSearch =
            query.isEmpty || searchable.any((field) => field.contains(query));

        return matchesCategory && matchesRestaurant && matchesSearch;
      }).toList();
    });
  }

  List<ProductItem> get _productItems =>
      _filteredFoodProducts.map(ProductItem.fromFirebaseProduct).toList();

  Map<String, List<ProductItem>> get _productsByCategory {
    final grouped = <String, List<ProductItem>>{};
    for (final product in _productItems) {
      final category = product.category.trim();
      grouped.putIfAbsent(category, () => []).add(product);
    }
    return grouped;
  }

  List<Restaurant> get _filteredRestaurants {
    final query = _normalize(_searchQuery);
    if (query.isEmpty) return _restaurants;

    return _restaurants.where((restaurant) {
      final searchable = [
        _normalize(restaurant.name),
        _normalize(restaurant.cuisine),
      ];
      return searchable.any((field) => field.contains(query));
    }).toList();
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _filterFoods();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _filterFoods();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedRestaurant = null;
      _searchQuery = '';
      _searchController.clear();
    });
    _filterFoods();
  }

  void _onProductTap(ProductItem product) {
    final foodProduct = _filteredFoodProducts.firstWhere(
      (item) => item.id == product.id,
      orElse: () =>
          _allFoodProducts.firstWhere((item) => item.id == product.id),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerProductDetailsScreen(product: foodProduct),
      ),
    );
  }

  void _onAddToCart(ProductItem product) {
    final foodProduct = _filteredFoodProducts.firstWhere(
      (item) => item.id == product.id,
      orElse: () =>
          _allFoodProducts.firstWhere((item) => item.id == product.id),
    );

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final result = cartProvider.addItem(foodProduct);

    if (!result.success) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message!),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${foodProduct.name} added to food cart!'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'View Cart', onPressed: _openFoodCart),
      ),
    );
  }

  void _onRestaurantTap(Restaurant restaurant) {
    setState(() {
      _selectedRestaurant = restaurant;
    });
    _filterFoods();
  }

  void _openFoodCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerCartScreen(scope: CartScope.food),
      ),
    );
  }

  int _compareProductsForListing(FirebaseProduct a, FirebaseProduct b) {
    final createdAtComparison =
        (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
    if (createdAtComparison != 0) {
      return createdAtComparison;
    }

    final soldCountComparison = b.soldCount.compareTo(a.soldCount);
    if (soldCountComparison != 0) {
      return soldCountComparison;
    }

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  String _normalize(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase();
  }

  String _normalizeCategoryLabel(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return '';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  double _parseRating(Map<String, dynamic> data) {
    final rawRating =
        data['rating'] ?? data['averageRating'] ?? data['avgRating'];
    if (rawRating is num) return rawRating.toDouble();
    if (rawRating is String) return double.tryParse(rawRating) ?? 4.5;
    return 4.5;
  }

  Widget _buildCartButton() {
    return Stack(
      children: [
        IconButton(
          onPressed: _openFoodCart,
          icon: const Icon(Icons.shopping_basket_outlined),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Consumer<CartProvider>(
            builder: (context, cart, child) {
              final itemCount = cart.itemCountForScope(CartScope.food);
              if (itemCount == 0) {
                return const SizedBox.shrink();
              }

              return Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0E7C86),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModernSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20242C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3440) : const Color(0xFFE4E8EE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search meals, cuisines, or restaurants...',
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedRestaurant != null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _resetFilters,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFE9EFF4),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF203040),
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(bool isDark) {
    final featuredRestaurants = _restaurants.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF3E2723), Color(0xFF1B1B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFF0D9), Color(0xFFFFFBF3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fresh meals, fast checkout',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF4B2E19),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_filteredFoodProducts.length} meals ready • $featuredRestaurants food vendors nearby',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF7A5C49),
                  ),
                ),
                if (_selectedRestaurant != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Showing menu from ${_selectedRestaurant!.name}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF8B4513),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.75),
            ),
            child: Icon(
              Icons.fastfood_rounded,
              color: isDark ? Colors.white : const Color(0xFFE77B2E),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantSection() {
    if (_filteredRestaurants.isEmpty) {
      return const SizedBox.shrink();
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: ShoppingSectionHeader(title: 'Restaurants near you'),
          ),
          SizedBox(
            height: 208,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              scrollDirection: Axis.horizontal,
              itemCount: _filteredRestaurants.length,
              itemBuilder: (context, index) {
                final restaurant = _filteredRestaurants[index];
                return RestaurantCard(
                  restaurant: restaurant,
                  isSelected: _selectedRestaurant?.id == restaurant.id,
                  onTap: () {
                    _onRestaurantTap(restaurant);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RestaurantDetailsScreen(restaurant: restaurant),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12151B)
          : const Color(0xFFF2F5F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Food',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Meals and restaurants picked for you',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [_buildCartButton(), const SizedBox(width: 8)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildPromoCard(isDark)),
                  SliverToBoxAdapter(child: _buildModernSearchBar(isDark)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 54,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        scrollDirection: Axis.horizontal,
                        children: _categories.map((category) {
                          return CategoryChip(
                            label: category,
                            isSelected:
                                _normalize(_selectedCategory) ==
                                _normalize(category),
                            onTap: () => _onCategorySelected(category),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  _buildRestaurantSection(),
                  if (_productItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.ramen_dining_outlined,
                              size: 64,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No meals match your filters',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _resetFilters,
                              child: const Text('Clear filters'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: ShoppingSectionHeader(
                          title: _selectedRestaurant == null
                              ? 'Popular meals'
                              : '${_selectedRestaurant!.name} menu',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ProductGrid(
                        products: _productItems.take(10).toList(),
                        onProductTap: _onProductTap,
                        onAddToCart: _onAddToCart,
                      ),
                    ),
                    for (final entry in _productsByCategory.entries)
                      if (entry.value.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ShoppingSectionHeader(
                              title: entry.key.isEmpty
                                  ? 'More meals'
                                  : entry.key,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: ProductGrid(
                            products: entry.value,
                            onProductTap: _onProductTap,
                            onAddToCart: _onAddToCart,
                          ),
                        ),
                      ],
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ],
              ),
            ),
    );
  }
}
