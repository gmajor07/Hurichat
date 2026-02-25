import 'firebase_product.dart';

class ProductItem {
  final String id;
  final String name;
  final String price;
  final String currency; // New field: 'TSH' or 'USD'
  final String imagePath; // Kept for local fallback if needed
  final String? imageUrl;
  final String category;
  final String? subCategory;
  final String? condition;
  final String? sellerId;
  final String? description;
  final double? rating;
  final bool? isFavorite;
  final int quantity;
  final String location;
  final List<String> deliveryOptions;
  final String sellerType;
  final DateTime? createdAt;
  final int soldCount;
  final String? discountPrice;
  final String? discountDescription;
  final List<String> images;

  ProductItem({
    required this.id,
    required this.name,
    required this.price,
    this.currency = 'TSH',
    required this.imagePath,
    this.imageUrl,
    required this.category,
    this.subCategory,
    this.condition,
    this.sellerId,
    this.description,
    this.rating,
    this.isFavorite = false,
    this.quantity = 0,
    this.location = '',
    this.deliveryOptions = const [],
    this.sellerType = '',
    this.createdAt,
    this.soldCount = 0,
    this.discountPrice,
    this.discountDescription,
    this.images = const [],
  });

  // Factory constructor to create ProductItem from FirebaseProduct
  factory ProductItem.fromFirebaseProduct(FirebaseProduct firebaseProduct) {
    return ProductItem(
      id: firebaseProduct.id,
      name: firebaseProduct.name,
      price: firebaseProduct.price.toString(),
      currency: firebaseProduct.currency,
      imagePath: '',
      imageUrl: firebaseProduct.imageUrl,
      category: firebaseProduct.category,
      subCategory: firebaseProduct.subCategory,
      condition: firebaseProduct.condition,
      sellerId: firebaseProduct.sellerId,
      description: firebaseProduct.description,
      quantity: firebaseProduct.quantity,
      location: firebaseProduct.location,
      deliveryOptions: firebaseProduct.deliveryOptions,
      sellerType: firebaseProduct.sellerType,
      createdAt: firebaseProduct.createdAt,
      soldCount: firebaseProduct.soldCount,
      rating: firebaseProduct.rating,
      discountPrice: firebaseProduct.discountPrice?.toString(),
      discountDescription: firebaseProduct.discountDescription,
      images: firebaseProduct.images,
    );
  }

  // Get the appropriate image path/URL
  String get displayImage {
    return (imageUrl != null && imageUrl!.isNotEmpty) ? imageUrl! : imagePath;
  }
}
