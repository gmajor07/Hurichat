class ProductItem {
  final String id;
  final String name;
  final String price;
  final String imagePath;
  final String category;
  final double? rating;
  final bool? isFavorite;

  ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imagePath,
    required this.category,
    this.rating,
    this.isFavorite = false,
  });

  // Sample data
  static List<ProductItem> sampleProducts = [
    ProductItem(
      id: '1',
      name: "Casual Wear",
      price: "Tsh 15,000",
      imagePath: 'assets/images/shopping/casual_wear.png',
      category: "Men",
      rating: 4.5,
    ),
    ProductItem(
      id: '2',
      name: "Home Appliance",
      price: "Tsh 70,000",
      imagePath: 'assets/images/shopping/home_appliance.png',
      category: "Electronics",
      rating: 4.2,
    ),
    ProductItem(
      id: '3',
      name: "T-Shirt",
      price: "Tsh 12,000",
      imagePath: 'assets/images/shopping/tshirt.png',
      category: "Men",
      rating: 4.3,
    ),
    ProductItem(
      id: '4',
      name: "Snacks",
      price: "Tsh 5,000",
      imagePath: 'assets/images/shopping/snacks.png',
      category: "Grocery",
      rating: 4.1,
    ),
    ProductItem(
      id: '5',
      name: "Juice & Drinks",
      price: "Tsh 7,500",
      imagePath: 'assets/images/shopping/juice.png',
      category: "Grocery",
      rating: 4.4,
    ),
    ProductItem(
      id: '6',
      name: "Fresh Vegetables",
      price: "Tsh 9,000",
      imagePath: 'assets/images/shopping/vegetables.png',
      category: "Grocery",
      rating: 4.6,
    ),
    ProductItem(
      id: '7',
      name: "Shoes",
      price: "Tsh 25,000",
      imagePath: 'assets/images/shopping/shoes.png',
      category: "Shoes",
      rating: 4.7,
    ),
    ProductItem(
      id: '8',
      name: "Smartphone",
      price: "Tsh 250,000",
      imagePath: 'assets/images/shopping/smartphone.png',
      category: "Electronics",
      rating: 4.8,
    ),
  ];

  // Filter products by category
  static List<ProductItem> getProductsByCategory(String category) {
    if (category == "All") return sampleProducts;
    return sampleProducts
        .where((product) => product.category == category)
        .toList();
  }

  // Get featured products for different sections
  static List<ProductItem> get topDeals => sampleProducts.take(3).toList();
  static List<ProductItem> get groceryKitchen => sampleProducts
      .where((product) => product.category == "Grocery")
      .take(3)
      .toList();
  static List<ProductItem> get viewMore =>
      sampleProducts.skip(6).take(2).toList();
}
