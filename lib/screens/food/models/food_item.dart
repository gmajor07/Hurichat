class FoodItem {
  final String id;
  final String name;
  final String imagePath;
  final double price;
  final String category;
  final String? description;
  final double? rating;
  final int? preparationTime;

  FoodItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.price,
    required this.category,
    this.description,
    this.rating,
    this.preparationTime,
  });

  String get formattedPrice {
    final priceStr = price.toStringAsFixed(0);
    final parts = <String>[];
    var remaining = priceStr;
    
    while (remaining.length > 3) {
      parts.insert(0, remaining.substring(remaining.length - 3));
      remaining = remaining.substring(0, remaining.length - 3);
    }
    parts.insert(0, remaining);
    
    return 'TZS ${parts.join(',')}';
  }

  // Sample data
  static List<FoodItem> sampleFoods = [
    FoodItem(
      id: '1',
      name: 'Rice & Beans',
      imagePath: 'assets/images/food/1.png',
      price: 5000,
      category: 'Wali',
      rating: 4.5,
      preparationTime: 15,
    ),
    FoodItem(
      id: '2',
      name: 'Burger Combo',
      imagePath: 'assets/images/food/2.png',
      price: 7500,
      category: 'Burger',
      rating: 4.2,
      preparationTime: 10,
    ),
    FoodItem(
      id: '3',
      name: 'Chips Kuku',
      imagePath: 'assets/images/food/3.png',
      price: 6000,
      category: 'Chips',
      rating: 4.3,
      preparationTime: 12,
    ),
    FoodItem(
      id: '4',
      name: 'Pizza Deluxe',
      imagePath: 'assets/images/food/4.png',
      price: 9000,
      category: 'Piza',
      rating: 4.7,
      preparationTime: 20,
    ),
    FoodItem(
      id: '5',
      name: 'Kuku Special',
      imagePath: 'assets/images/food/5.png',
      price: 8500,
      category: 'Kuku',
      rating: 4.4,
      preparationTime: 18,
    ),
  ];
}
