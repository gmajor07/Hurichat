import 'firebase_product.dart';

class CartItem {
  final FirebaseProduct product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  // The price is already a number (num) from the FirebaseProduct model,
  // so we don't need to parse it from a string.

  double get subtotal {
    // 1. Get the price as a double. Since product.price is 'num', .toDouble() is safe.
    final priceValue = product.price.toDouble();

    // 2. Perform the calculation.
    return priceValue * quantity;
  }

  String get formattedSubtotal => _formatPrice(subtotal);

  String _formatPrice(double price) {
    return '\$${_addCommas(price.toStringAsFixed(2))}';
  }

  String _addCommas(String price) {
    // Simple comma formatting
    List<String> parts = price.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '00';

    String formatted = '';
    for (int i = integerPart.length - 1, count = 0; i >= 0; i--, count++) {
      if (count % 3 == 0 && count > 0) {
        formatted = ',' + formatted;
      }
      formatted = integerPart[i] + formatted;
    }
    return '$formatted.$decimalPart';
  }

  // Method to check if two CartItems represent the same product
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          product.id == other.product.id;

  @override
  int get hashCode => product.id.hashCode;
}
