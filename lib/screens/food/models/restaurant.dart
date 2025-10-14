class Restaurant {
  final String id;
  final String name;
  final String imagePath;
  final double distance;
  final double rating;
  final String cuisine;
  final int deliveryTime;

  Restaurant({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.distance,
    this.rating = 0.0,
    this.cuisine = 'Various',
    this.deliveryTime = 30,
  });

  String get formattedDistance => '${distance.toStringAsFixed(1)} km';

  // Sample data
  static List<Restaurant> sampleRestaurants = [
    Restaurant(
      id: '1',
      name: 'Mama Ntilie',
      imagePath: 'assets/images/food/7.png',
      distance: 1.2,
      rating: 4.5,
      cuisine: 'Local',
      deliveryTime: 25,
    ),
    Restaurant(
      id: '2',
      name: 'Urban Tastes',
      imagePath: 'assets/images/food/8.png',
      distance: 2.5,
      rating: 4.3,
      cuisine: 'International',
      deliveryTime: 30,
    ),
    Restaurant(
      id: '3',
      name: 'Food Corner',
      imagePath: 'assets/images/food/6.png',
      distance: 1.8,
      rating: 4.6,
      cuisine: 'Fast Food',
      deliveryTime: 20,
    ),
  ];
}
