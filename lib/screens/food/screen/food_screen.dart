import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/search_bar.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = false;

  // Filtered data based on search and category
  List<FoodItem> get filteredFoods {
    if (_searchQuery.isEmpty && _selectedCategory == 'All') {
      return FoodItem.sampleFoods;
    }

    return FoodItem.sampleFoods.where((food) {
      final matchesSearch = food.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == 'All' || food.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<FoodItem> get wekaOrderFoods => filteredFoods.take(3).toList();
  List<FoodItem> get recommendedFoods => filteredFoods.take(4).toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  void _onFoodTap(FoodItem food) {
    // Navigate to food details
    print('Food tapped: ${food.name}');
  }

  void _onRestaurantTap(Restaurant restaurant) {
    // Navigate to restaurant details
    print('Restaurant tapped: ${restaurant.name}');
  }

  void _onAddToCart(FoodItem food) {
    // Add to cart functionality
    print('Added to cart: ${food.name}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${food.name} added to cart!')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔍 Search Bar
            FoodSearchBar(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
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
                  // All category
                  FoodCategoryChip(
                    title: 'All',
                    imagePath: 'assets/images/food/6.png',
                    colorScheme: colorScheme,
                    onTap: () => _onCategorySelected('All'),
                    isSelected: _selectedCategory == 'All',
                  ),
                  // Other categories
                  ...AppConstants.foodCategories.map((category) {
                    return FoodCategoryChip(
                      title: category['name']!,
                      imagePath: category['image']!,
                      colorScheme: colorScheme,
                      onTap: () => _onCategorySelected(category['name']!),
                      isSelected: _selectedCategory == category['name'],
                    );
                  }).toList(), // Added .toList() here
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 🍽️ Weka Order Section
            SectionHeader(
              title: AppConstants.wekaOrderTitle,
              onSeeAllTap: () {
                // Navigate to all foods
                print('See all foods tapped');
              },
            ),
            const SizedBox(height: 10),
            _buildFoodScrollSection(wekaOrderFoods, colorScheme),

            const SizedBox(height: 25),

            // 🏠 Mgahawa Ulio Karibu Nawe
            SectionHeader(
              title: AppConstants.nearbyRestaurantsTitle,
              onSeeAllTap: () {
                // Navigate to all restaurants
                print('See all restaurants tapped');
              },
            ),
            const SizedBox(height: 10),
            _buildRestaurantScrollSection(colorScheme),

            const SizedBox(height: 25),

            // ⭐ Recommended Section
            SectionHeader(
              title: AppConstants.recommendedTitle,
              onSeeAllTap: () {
                // Navigate to recommended foods
                print('See all recommended tapped');
              },
            ),
            const SizedBox(height: 10),
            _buildFoodScrollSection(recommendedFoods, colorScheme),

            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodScrollSection(List<FoodItem> foods, ColorScheme scheme) {
    if (foods.isEmpty) {
      return const Center(child: Text('No food items found'));
    }

    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: foods.map((food) {
          return FoodCard(
            food: food,
            onTap: () => _onFoodTap(food),
            onAddToCart: () => _onAddToCart(food),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRestaurantScrollSection(ColorScheme scheme) {
    return SizedBox(
      height: 150,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: Restaurant.sampleRestaurants.map((restaurant) {
          return RestaurantCard(
            restaurant: restaurant,
            onTap: () => _onRestaurantTap(restaurant),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
