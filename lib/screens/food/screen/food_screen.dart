import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../advanced_search_bar.dart';
import '../../provider/cart_provider.dart';
import '../../shopping/models/firebase_product.dart';
import '../../shopping/screens/customer_cart_screen.dart';
import '../../shopping/screens/customer_product_details_screen.dart';
import '../widgets/food_category_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/food_card.dart';
import '../widgets/restaurant_card.dart';
import '../models/food_item.dart';
import '../models/restaurant.dart';
import '../constants/app_constants.dart';
import 'restaurant_details_screen.dart';

class FoodScreen extends StatefulWidget {
  const FoodScreen({super.key});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;
  List<FirebaseProduct> _allFoodProducts = [];
  List<FirebaseProduct> _filteredFoodProducts = [];
  List<Restaurant> _restaurants = [];
  Restaurant? _selectedRestaurant;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Load Food Products
      final productSnap = await FirebaseFirestore.instance
          .collection("products")
          .where("sellerType", isEqualTo: "food")
          .where("status", isEqualTo: "active")
          .get();

      _allFoodProducts = productSnap.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .toList();

      // Load Restaurants (Businesses of type 'food')
      final businessSnap = await FirebaseFirestore.instance
          .collection("businesses")
          .where("serviceType", isEqualTo: "food")
          .get();

      _restaurants = businessSnap.docs.map((doc) {
        final data = doc.data();
        return Restaurant(
          id: data['userId'] ?? doc.id,
          name: data['name'] ?? 'Restaurant',
          imagePath: data['imageUrl'] ?? 'assets/images/food/6.png',
          distance: 1.0,
          rating: 4.5,
          cuisine: data['description'] ?? 'Local',
          deliveryTime: 30,
        );
      }).toList();

      _filterFoods();
    } catch (e) {
      if (kDebugMode) {
        print("❌ Failed to load food data: $e");
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _filterFoods() {
    setState(() {
      _filteredFoodProducts = _allFoodProducts.where((food) {
        // Search query filter
        final matchesSearch = food.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );

        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            food.category.toLowerCase() == _selectedCategory.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterFoods();
  }

  void _onFoodTap(FirebaseProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerProductDetailsScreen(product: product),
      ),
    );
  }

  void _onRestaurantTap(Restaurant restaurant) {
    // Navigate to restaurant details screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailsScreen(restaurant: restaurant),
      ),
    );
  }

  void _onAddToCart(FirebaseProduct product) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addItem(product);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart!'),
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

  // Today's Meals - show all available food items
  List<FirebaseProduct> get todayMeals {
    // Show all filtered food products (already filtered by search/category)
    return _filteredFoodProducts;
  }

  List<FirebaseProduct> get recommendedFoods =>
      _filteredFoodProducts.take(8).toList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food & Restaurant'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔍 Search Bar
                    AdvancedSearchBar(
                      hintText: "Search for food or restaurants...",
                      onSearchChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                        _filterFoods();
                      },
                      autoFocus: false,
                    ),
                    const SizedBox(height: 20),

                    // Restaurant selected indicator
                    if (_selectedRestaurant != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Text(
                              'Menu from: ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              _selectedRestaurant!.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedRestaurant = null;
                                  _filterFoods();
                                });
                              },
                              child: const Text('Show All'),
                            ),
                          ],
                        ),
                      ),

                    // 🍔 Category Title
                    const Text(
                      "Categories",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 🍕 Food Categories (Horizontal)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FoodCategoryChip(
                            title: 'All',
                            imagePath: 'assets/images/food/6.png',
                            colorScheme: colorScheme,
                            onTap: () => _onCategorySelected('All'),
                            isSelected: _selectedCategory == 'All',
                          ),
                          ...AppConstants.foodCategories.map((category) {
                            return FoodCategoryChip(
                              title: category['name']!,
                              imagePath: category['image']!,
                              colorScheme: colorScheme,
                              onTap: () => _onCategorySelected(category['name']!),
                              isSelected: _selectedCategory == category['name'],
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 🍽️ Today's Meals Section
                    SectionHeader(
                      title: "Today's Meals",
                      onSeeAllTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _buildFoodScrollSection(todayMeals, colorScheme),

                    const SizedBox(height: 25),

                    // 🏠 Nearby Restaurants
                    SectionHeader(
                      title: "Restaurants Near You",
                      onSeeAllTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _buildRestaurantScrollSection(colorScheme),

                    const SizedBox(height: 25),

                    // ⭐ Recommended Section
                    SectionHeader(
                      title: "Recommended for You",
                      onSeeAllTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _buildFoodScrollSection(recommendedFoods, colorScheme),

                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFoodScrollSection(List<FirebaseProduct> foods, ColorScheme scheme) {
    if (foods.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, color: Colors.grey[400], size: 40),
            const SizedBox(height: 8),
            Text(
              'No items available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length,
        itemBuilder: (context, index) {
          final product = foods[index];
          final foodItem = FoodItem(
            id: product.id,
            name: product.name,
            imagePath: product.imageUrl,
            price: product.price.toDouble(),
            category: product.category,
            rating: 4.5,
            preparationTime: 15,
          );
          return FoodCard(
            food: foodItem,
            onTap: () => _onFoodTap(product),
            onAddToCart: () => _onAddToCart(product),
          );
        },
      ),
    );
  }

  Widget _buildRestaurantScrollSection(ColorScheme scheme) {
    if (_restaurants.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text('No restaurants registered yet'),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _restaurants[index];
          final isSelected = _selectedRestaurant?.id == restaurant.id;

          return Opacity(
            opacity: _selectedRestaurant == null || isSelected ? 1.0 : 0.5,
            child: Container(
              decoration: isSelected ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.primary, width: 2),
              ) : null,
              child: RestaurantCard(
                restaurant: restaurant,
                onTap: () => _onRestaurantTap(restaurant),
              ),
            ),
          );
        },
      ),
    );
  }
}
