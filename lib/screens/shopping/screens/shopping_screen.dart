import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/cart_provider.dart';
import '../models/firebase_product.dart';
import '../models/product_item.dart';
import 'customer_cart_screen.dart';
import 'customer_product_details_screen.dart';
import 'widgets/shopping/category_chip.dart';
import 'widgets/shopping/product_grid.dart';
import 'widgets/shopping/section_header.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String _selectedCategory = 'All';
  String _selectedCondition = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<String> _categories = ['All'];
  List<String> _conditions = ['All'];
  Set<String> _favoriteProductIds = {};
  List<ProductItem> _allProducts = [];
  List<ProductItem> _filteredProducts = [];

  bool _loading = true;
  bool _isFilterExpanded = false;

  double _minAvailablePrice = 0;
  double _maxAvailablePrice = 1000000;
  RangeValues _priceRange = const RangeValues(0, 1000000);
  final ScrollController _trendingScrollController = ScrollController();
  Timer? _trendingAutoScrollTimer;
  static const double _trendingScrollStep = 180;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadFavoriteProducts();
  }

  @override
  void dispose() {
    _trendingAutoScrollTimer?.cancel();
    _trendingScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);

    try {
      final firebaseSnap = await FirebaseFirestore.instance
          .collection('products')
          .get();

      _allProducts = firebaseSnap.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .map(ProductItem.fromFirebaseProduct)
          .toList();

      final dynamicCategories =
          _allProducts
              .map((p) => p.category.trim())
              .where((c) => c.isNotEmpty)
              .map(_normalizeCategoryLabel)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      final dynamicConditions =
          _allProducts
              .map((p) => p.condition?.trim() ?? '')
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      _categories = ['All', ...dynamicCategories];
      _conditions = ['All', ...dynamicConditions];

      if (_allProducts.isNotEmpty) {
        final prices = _allProducts
            .map((p) => double.tryParse(p.price) ?? 0)
            .where((p) => p >= 0)
            .toList();

        if (prices.isNotEmpty) {
          _minAvailablePrice = prices.reduce((a, b) => a < b ? a : b);
          _maxAvailablePrice = prices.reduce((a, b) => a > b ? a : b);
          if (_maxAvailablePrice <= _minAvailablePrice) {
            _maxAvailablePrice = _minAvailablePrice + 1;
          }
          _priceRange = RangeValues(_minAvailablePrice, _maxAvailablePrice);
        }
      }

      _filterProducts();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load products: $e');
      }
      _allProducts = [];
      _categories = ['All'];
      _conditions = ['All'];
      _filterProducts();
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadFavoriteProducts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = userDoc.data();
      final favoritesRaw = data?['favoriteProducts'];
      if (favoritesRaw is List) {
        setState(() {
          _favoriteProductIds = favoritesRaw.map((e) => e.toString()).toSet();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load favorite products: $e');
      }
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesCategory =
            _selectedCategory == 'All' ||
            _normalize(product.category) == _normalize(_selectedCategory);

        final query = _normalize(_searchQuery);
        final searchable = [
          _normalize(product.name),
          _normalize(product.category),
          _normalize(product.subCategory ?? ''),
        ];
        final matchesSearch =
            query.isEmpty || searchable.any((field) => field.contains(query));

        final matchesCondition =
            _selectedCondition == 'All' ||
            (product.condition?.toLowerCase() ?? '') ==
                _selectedCondition.toLowerCase();

        final productPrice = double.tryParse(product.price) ?? 0;
        final matchesPrice =
            productPrice >= _priceRange.start &&
            productPrice <= _priceRange.end;

        return matchesCategory &&
            matchesSearch &&
            matchesCondition &&
            matchesPrice;
      }).toList();
    });
    _configureTrendingAutoScroll();
  }

  void _configureTrendingAutoScroll() {
    _trendingAutoScrollTimer?.cancel();
    if (_filteredProducts.length <= 2) return;

    _trendingAutoScrollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_trendingScrollController.hasClients) return;

      final position = _trendingScrollController.position;
      if (position.maxScrollExtent <= 0) return;

      final bool atEnd = position.pixels >= position.maxScrollExtent - 8;
      final double target = atEnd
          ? 0
          : (position.pixels + _trendingScrollStep).clamp(
              0,
              position.maxScrollExtent,
            );

      _trendingScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
    _filterProducts();
  }

  void _onConditionSelected(String value) {
    setState(() => _selectedCondition = value);
    _filterProducts();
  }

  void _onPriceRangeChanged(RangeValues values) {
    setState(() => _priceRange = values);
    _filterProducts();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _filterProducts();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedCondition = 'All';
      _searchQuery = '';
      _priceRange = RangeValues(_minAvailablePrice, _maxAvailablePrice);
      _searchController.clear();
    });
    _filterProducts();
  }

  Future<void> _refreshShoppingData() async {
    await Future.wait([_loadProducts(), _loadFavoriteProducts()]);
  }

  Future<void> _onProductTap(ProductItem product) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .get();

      if (!doc.exists || !mounted) return;

      final firebaseProduct = FirebaseProduct.fromMap(doc.id, doc.data()!);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CustomerProductDetailsScreen(product: firebaseProduct),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching product: $e');
      }
    }
  }

  Future<void> _toggleFavorite(ProductItem product) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required to save favorites')),
      );
      return;
    }

    final wasFavorite = _favoriteProductIds.contains(product.id);
    setState(() {
      if (wasFavorite) {
        _favoriteProductIds.remove(product.id);
      } else {
        _favoriteProductIds.add(product.id);
      }
    });

    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(userId);
      await docRef.set({
        'favoriteProducts': wasFavorite
            ? FieldValue.arrayRemove([product.id])
            : FieldValue.arrayUnion([product.id]),
      }, SetOptions(merge: true));
    } catch (e) {
      setState(() {
        if (wasFavorite) {
          _favoriteProductIds.add(product.id);
        } else {
          _favoriteProductIds.remove(product.id);
        }
      });
      if (kDebugMode) {
        print('Error updating favorites: $e');
      }
    }
  }

  Map<String, List<ProductItem>> get _productsByCategory {
    final grouped = <String, List<ProductItem>>{};
    for (final product in _filteredProducts) {
      final category = product.category.trim();
      grouped.putIfAbsent(category, () => []).add(product);
    }
    return grouped;
  }

  String _normalize(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase();
  }

  String _normalizeCategoryLabel(String value) {
    final n = _normalize(value);
    if (n.isEmpty) return '';
    return n[0].toUpperCase() + n.substring(1);
  }

  Widget _buildCartButton() {
    return Stack(
      children: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerCartScreen()),
            );
          },
          icon: const Icon(Icons.shopping_bag_outlined),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Consumer<CartProvider>(
            builder: (context, cart, child) {
              if (cart.itemCount == 0) {
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
                  '${cart.itemCount}',
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
                hintText: 'Search products, categories...',
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() => _isFilterExpanded = !_isFilterExpanded);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _isFilterExpanded
                    ? const Color(0xFF0E7C86)
                    : const Color(0xFFE9EFF4),
              ),
              child: Icon(
                _isFilterExpanded ? Icons.tune : Icons.tune_outlined,
                color: _isFilterExpanded
                    ? Colors.white
                    : const Color(0xFF203040),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(bool isDark) {
    final int dealsCount = _filteredProducts
        .where(
          (product) =>
              product.discountPrice != null &&
              product.discountPrice!.isNotEmpty,
        )
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1D2D44), Color(0xFF0D1B2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFDDF4FF), Color(0xFFF0F8FF)],
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
                  'Discover your next favorite',
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0C3147),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_filteredProducts.length} products live • $dealsCount special deals',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : const Color(0xFF39566A),
                  ),
                ),
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
              Icons.local_mall_outlined,
              color: isDark ? Colors.white : const Color(0xFF0E7C86),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(bool isDark) {
    final bool sliderEnabled = _maxAvailablePrice > _minAvailablePrice;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: !_isFilterExpanded
          ? const SizedBox.shrink()
          : Container(
              key: const ValueKey('filters'),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1F27)
                    : const Color(0xFFF8FBFE),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E3440)
                      : const Color(0xFFE4EAF0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  Text(
                    'Price: Tsh ${_priceRange.start.toInt()} - Tsh ${_priceRange.end.toInt()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: _minAvailablePrice,
                    max: _maxAvailablePrice,
                    divisions: sliderEnabled ? 30 : null,
                    onChanged: sliderEnabled ? _onPriceRangeChanged : null,
                    activeColor: const Color(0xFF0E7C86),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _conditions.map((condition) {
                      final selected =
                          _normalize(_selectedCondition) ==
                          _normalize(condition);
                      return ChoiceChip(
                        selected: selected,
                        onSelected: (_) => _onConditionSelected(condition),
                        label: Text(condition),
                        selectedColor: const Color(
                          0xFF0E7C86,
                        ).withValues(alpha: 0.2),
                        side: BorderSide(
                          color: selected
                              ? const Color(0xFF0E7C86)
                              : Colors.grey.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
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
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Huruchati Shopping',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Curated products picked for you',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [_buildCartButton(), const SizedBox(width: 8)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshShoppingData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildPromoCard(isDark)),
                  SliverToBoxAdapter(child: _buildModernSearchBar(isDark)),
                  SliverToBoxAdapter(child: _buildFilterPanel(isDark)),
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
                  if (_filteredProducts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No products match your filters',
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
                    if (_filteredProducts.length > 2)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ShoppingSectionHeader(title: 'Trending now'),
                        ),
                      ),
                    if (_filteredProducts.length > 2)
                      SliverToBoxAdapter(
                        child: ProductGrid(
                          products: _filteredProducts.take(10).toList(),
                          scrollController: _trendingScrollController,
                          onProductTap: _onProductTap,
                          onFavoriteTap: _toggleFavorite,
                          favoriteProductIds: _favoriteProductIds,
                        ),
                      ),
                    for (final entry in _productsByCategory.entries)
                      if (entry.value.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ShoppingSectionHeader(
                              title: entry.key.isEmpty ? 'Other' : entry.key,
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: ProductGrid(
                            products: entry.value,
                            onProductTap: _onProductTap,
                            onFavoriteTap: _toggleFavorite,
                            favoriteProductIds: _favoriteProductIds,
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
