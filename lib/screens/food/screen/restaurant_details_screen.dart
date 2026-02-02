import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../advanced_search_bar.dart';
import '../../provider/cart_provider.dart';
import '../../shopping/models/firebase_product.dart';
import '../../shopping/screens/customer_cart_screen.dart';
import '../../shopping/screens/customer_product_details_screen.dart';
import '../models/restaurant.dart';
import '../widgets/food_card.dart';
import '../widgets/food_category_chip.dart';
import '../models/food_item.dart';
import '../constants/app_constants.dart';

class RestaurantDetailsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailsScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsScreen> createState() => _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends State<RestaurantDetailsScreen> {
  late List<FirebaseProduct> _allMenuItems = [];
  late List<FirebaseProduct> _filteredMenuItems = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRestaurantMenu();
  }

  Future<void> _loadRestaurantMenu() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Load all food products from this restaurant
      final snapshot = await FirebaseFirestore.instance
          .collection("products")
          .where("sellerType", isEqualTo: "food")
          .where("sellerId", isEqualTo: widget.restaurant.id)
          .where("status", isEqualTo: "active")
          .get();

      _allMenuItems = snapshot.docs
          .map((doc) => FirebaseProduct.fromMap(doc.id, doc.data()))
          .toList();

      _filterMenuItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading menu: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _filterMenuItems() {
    setState(() {
      _filteredMenuItems = _allMenuItems.where((product) {
        // Search filter
        final matchesSearch = product.name.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        ) || (product.description?.toLowerCase().contains(
          _searchQuery.toLowerCase(),
        ) ?? false);

        // Category filter
        final matchesCategory = _selectedCategory == 'All' ||
            product.category.toLowerCase() == _selectedCategory.toLowerCase();

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _filterMenuItems();
  }

  void _onFoodTap(FirebaseProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerProductDetailsScreen(product: product),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Menu'),
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
              onRefresh: _loadRestaurantMenu,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant Header Card
                    _buildRestaurantHeader(colorScheme),
                    const SizedBox(height: 20),

                    // Search Bar
                    AdvancedSearchBar(
                      hintText: "Search menu...",
                      onSearchChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                        _filterMenuItems();
                      },
                      autoFocus: false,
                    ),
                    const SizedBox(height: 20),

                    // Category Pills
                    const Text(
                      "Categories",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 20),

                    // Menu Items Grid
                    _buildMenuGrid(colorScheme),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRestaurantHeader(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.asset(
              widget.restaurant.imagePath,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant name
                Text(
                  widget.restaurant.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Rating and delivery info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.restaurant.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.delivery_dining, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.restaurant.deliveryTime} min',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.restaurant.distance} km',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Cuisine type
                Text(
                  widget.restaurant.cuisine,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(ColorScheme colorScheme) {
    if (_filteredMenuItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.restaurant_menu, color: Colors.grey[400], size: 50),
              const SizedBox(height: 16),
              Text(
                'No items available',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredMenuItems.length,
      itemBuilder: (context, index) {
        final product = _filteredMenuItems[index];
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
    );
  }
}
