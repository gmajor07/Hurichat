import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseProduct {
  final String id;
  final String name;
  final List<String> images; // Changed from single imageUrl to list
  final String category;
  final String subCategory;
  final num price;
  final String currency; // New field: 'TSH' or 'USD'
  final String condition;
  final String sellerId;
  final String? description;
  final int quantity;
  final String location;
  final List<String> deliveryOptions;
  final String sellerType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int soldCount; // New field for tracking sales
  final num? discountPrice; // New field for discount pricing
  final String? discountDescription; // New field for discount info

  FirebaseProduct({
    required this.id,
    required this.name,
    required this.images,
    required this.category,
    required this.subCategory,
    required this.price,
    this.currency = 'TSH',
    required this.condition,
    required this.sellerId,
    this.description,
    this.quantity = 0,
    this.location = '',
    this.deliveryOptions = const [],
    this.sellerType = '',
    this.createdAt,
    this.updatedAt,
    this.soldCount = 0,
    this.discountPrice,
    this.discountDescription,
  });

  // Backward compatibility getter
  String get imageUrl => images.isNotEmpty ? images.first : '';

  // Backward compatibility getter
  String get displayImage => imageUrl;

  /// Factory constructor to create a FirebaseProduct from a Firestore map.
  factory FirebaseProduct.fromMap(String id, Map<String, dynamic> data) {
    // Handle images - can be List<String> or single String for backward compatibility
    List<String> imagesList = [];
    final dynamic imagesData = data["images"] ?? data["imageUrl"];

    if (imagesData is List && imagesData.isNotEmpty) {
      imagesList = imagesData.map((img) => img.toString()).toList();
    } else if (imagesData is String && imagesData.isNotEmpty) {
      imagesList = [imagesData];
    }

    // 💰 FIX: Safely parse the price from any possible type (String, int, double)
    num priceValue = 0;
    final rawPrice = data["price"];

    if (rawPrice is num) {
      priceValue = rawPrice;
    } else if (rawPrice is String) {
      // Use double.tryParse to handle strings like "5000" or "50.0"
      priceValue = double.tryParse(rawPrice) ?? 0;
    }

    // Parse timestamps
    DateTime? createdAt;
    DateTime? updatedAt;
    if (data["createdAt"] is Timestamp) {
      createdAt = (data["createdAt"] as Timestamp).toDate();
    }
    if (data["updatedAt"] is Timestamp) {
      updatedAt = (data["updatedAt"] as Timestamp).toDate();
    }

    // Handle delivery options
    List<String> deliveryOpts = [];
    if (data["deliveryOptions"] is List) {
      deliveryOpts = (data["deliveryOptions"] as List)
          .map((opt) => opt.toString())
          .toList();
    }

    return FirebaseProduct(
      id: id,
      name: data["name"] ?? '',
      images: imagesList,
      category: data["category"] ?? '',
      subCategory: data["subCategory"] ?? '',
      price: priceValue,
      currency: data["currency"] ?? 'TSH',
      condition: data["condition"] ?? '',
      sellerId: data["sellerId"] ?? '',
      description: data["description"],
      quantity: data["quantity"] ?? 0,
      location: data["location"] ?? '',
      deliveryOptions: deliveryOpts,
      sellerType: data["sellerType"] ?? '',
      createdAt: createdAt,
      updatedAt: updatedAt,
      soldCount: data["soldCount"] ?? 0,
      discountPrice: data["discountPrice"] is num
          ? data["discountPrice"]
          : null,
      discountDescription: data["discountDescription"],
    );
  }

  /// Converts the FirebaseProduct object back into a map suitable for Firestore.
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "images": images,
      "category": category,
      "subCategory": subCategory,
      "price": price,
      "currency": currency,
      "condition": condition,
      "sellerId": sellerId,
      "description": description,
      "quantity": quantity,
      "location": location,
      "deliveryOptions": deliveryOptions,
      "sellerType": sellerType,
      "createdAt": createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
      "soldCount": soldCount,
      "discountPrice": discountPrice,
      "discountDescription": discountDescription,
    };
  }
}
