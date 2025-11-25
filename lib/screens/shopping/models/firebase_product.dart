class FirebaseProduct {
  final String id;
  final String name;
  final String imageUrl; // Holds the first image URL for display
  final String category;
  final String subCategory;
  final String price;
  final String condition;
  final String sellerId;
  final String? description;

  FirebaseProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.subCategory,
    required this.price,
    required this.condition,
    required this.sellerId,
    this.description,
  });

  /// Factory constructor to create a FirebaseProduct from a Firestore map.
  /// It extracts the first image URL from the 'images' array.
  factory FirebaseProduct.fromMap(String id, Map<String, dynamic> data) {
    // FIX: Safely extract the first image URL from the 'images' array
    String firstImageUrl = '';
    final dynamic imagesData = data["images"];

    if (imagesData is List && imagesData.isNotEmpty) {
      // Assuming the list contains strings (image URLs)
      firstImageUrl = imagesData.first.toString();
    }

    return FirebaseProduct(
      id: id,
      name: data["name"] ?? '',
      imageUrl: firstImageUrl, // Correctly extracted first image URL
      category: data["category"] ?? '',
      subCategory: data["subCategory"] ?? '',
      // Ensure price is converted to a string, handling both number and string types from Firestore
      price: data["price"]?.toString() ?? '0',
      condition: data["condition"] ?? '',
      sellerId: data["sellerId"] ?? '',
      description: data["description"],
    );
  }

  /// Converts the FirebaseProduct object back into a map suitable for Firestore.
  /// It packages the single 'imageUrl' into an 'images' array.
  Map<String, dynamic> toMap() {
    return {
      "name": name,
      // ✅ FIX: Store the single imageUrl as the first item in the 'images' list
      "images": imageUrl.isNotEmpty ? [imageUrl] : [],
      "category": category,
      "subCategory": subCategory,
      "price": price,
      "condition": condition,
      "sellerId": sellerId,
      "description": description,
    };
  }
}
