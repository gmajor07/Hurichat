// 'providers/cart_provider.dart'
import 'package:flutter/foundation.dart';
import '../shopping/models/cart_item.dart';
import '../shopping/models/firebase_product.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => [..._items]; // Return a copy for immutability

  int get itemCount {
    return _items.fold(0, (total, item) => total + item.quantity);
  }

  int get uniqueItemCount => _items.length;

  double get totalAmount {
    double total = 0.0;
    for (var item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  String get formattedTotalAmount =>
      "\$${_addCommas(totalAmount.toStringAsFixed(2))}";

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

  // Check if product is in cart
  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  // Get quantity of a specific product
  int getQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    return index >= 0 ? _items[index].quantity : 0;
  }

  // --- Core Logic ---

  void addItem(FirebaseProduct product, [int quantity = 1]) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      // Product already in cart: Increase quantity
      _items[existingIndex].quantity += quantity;
    } else {
      // Product not in cart: Add new item
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity -= 1;
      } else {
        _items.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void updateQuantity(String productId, int newQuantity) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (existingIndex >= 0) {
      if (newQuantity > 0) {
        _items[existingIndex].quantity = newQuantity;
      } else {
        _items.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
