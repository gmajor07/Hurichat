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
  List<Restaurant> _nearbyRestaurants = [];

  @override
  void initState() {
    super.initState();
    _loadFoodProducts();
    _loadNearbyRestaurants();
  }

  Future<void> _loadNearbyRestaurants() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("businesses")
          .where("serviceType", isEqualTo: "food")
          .get();

      final restaurants = snap.docs.map((doc) {
        final data = doc.data();
        // Use imageUrl from database if available, otherwise use default
        String imagePath = data['imageUrl'] ?? 'assets/images/food/1.png';

        return Restaurant(
          id: doc.id,
          name: data['name'] ?? 'Unknown Restaurant',
          imagePath: imagePath,
          distance:
              1.5, // Default distance (can be calculated based on user location)
          rating: 4.5, // Default rating
          cuisine: 'Various', // Default cuisine
          deliveryTime: 30, // Default delivery time in minutes
        );
      }).toList();

      setState(() {
        _nearbyRestaurants = restaurants;
      });
    } catch (e) {
      if (kDebugMode) {
        print("❌ Failed to load restaurants: $e");
      }
    }
  }

  Future<void> _loadFoodProducts() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection("products")
          .where("sellerType", isEqualTo: "food")
          .where("status", isEqualTo: "active")
          .get();

      _allFoodProducts = snap.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .toList();

      _filterFoods();
    } catch (e) {
      if (kDebugMode) {
        print("❌ Failed to load food products: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _refreshData() async {
    await Future.wait([_loadFoodProducts(), _loadNearbyRestaurants()]);
  }

  void _filterFoods() {
    setState(() {
      _filteredFoodProducts = _allFoodProducts.where((food) {
        final matchesSearch = food.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final matchesCategory =
            _selectedCategory == 'All' ||
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
    // Navigate to restaurant details
    print('Restaurant tapped: ${restaurant.name}');
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

  List<FirebaseProduct> get wekaOrderFoods =>
      _filteredFoodProducts.where((p) => p.category == 'Meals').toList();
  List<FirebaseProduct> get recommendedFoods =>
      _filteredFoodProducts.take(5).toList();

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
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔍 Search Bar
                    AdvancedSearchBar(
                      hintText: "What are you going to eat?",
                      onSearchChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                        _filterFoods();
                      },
                      autoFocus: false,
                    ),
                    const SizedBox(height: 20),

                    // 🍔 Category Title
                    Text(
                      "Choose Food",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
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
                              onTap: () =>
                                  _onCategorySelected(category['name']!),
                              isSelected: _selectedCategory == category['name'],
                            );
                          }).toList(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // 🍽️ Weka Order Section
                    SectionHeader(
                      title: AppConstants.wekaOrderTitle,
                      onSeeAllTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _buildFoodScrollSection(wekaOrderFoods, colorScheme),

                    const SizedBox(height: 25),

                    // 🏠 Mgahawa Ulio Karibu Nawe
                    SectionHeader(
                      title: AppConstants.nearbyRestaurantsTitle,
                      onSeeAllTap: () {},
                    ),
                    const SizedBox(height: 10),
                    _buildRestaurantScrollSection(colorScheme),

                    const SizedBox(height: 25),

                    // ⭐ Recommended Section
                    SectionHeader(
                      title: AppConstants.recommendedTitle,
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

  Widget _buildFoodScrollSection(
    List<FirebaseProduct> foods,
    ColorScheme scheme,
  ) {
    if (foods.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text('No food items available in this category'),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: foods.length,
        itemBuilder: (context, index) {
          final product = foods[index];
          // Convert FirebaseProduct to FoodItem for the widget
          final foodItem = FoodItem(
            id: product.id,
            name: product.name,
            imagePath: product.imageUrl,
            price: product.price.toDouble(),
            category: product.category,
            rating: 4.5, // Default rating
            preparationTime: 15, // Default time
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
    if (_nearbyRestaurants.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text(
          'No restaurants available yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _nearbyRestaurants.length,
        itemBuilder: (context, index) {
          final restaurant = _nearbyRestaurants[index];
          return RestaurantCard(
            restaurant: restaurant,
            onTap: () => _onRestaurantTap(restaurant),
          );
        },
      ),
    );
  }
}
