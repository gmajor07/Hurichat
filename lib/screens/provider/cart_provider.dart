import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../shopping/models/cart_item.dart';
import '../shopping/models/firebase_product.dart';

enum CartScope { shopping, food }

class CartActionResult {
  final bool success;
  final String? message;

  const CartActionResult._({required this.success, this.message});

  const CartActionResult.success() : this._(success: true);

  const CartActionResult.failure(String message)
    : this._(success: false, message: message);
}

class CartAvailabilityIssue {
  final String productId;
  final String message;
  final int availableQuantity;
  final bool isUnavailable;

  const CartAvailabilityIssue({
    required this.productId,
    required this.message,
    required this.availableQuantity,
    required this.isUnavailable,
  });
}

class CartProvider with ChangeNotifier {
  static const String _cartBoxName = 'cart';
  static const String _cartItemsKey = 'items';
  static const String _selectedItemsKey = 'selectedProductIds';

  final List<CartItem> _items = [];
  final Set<String> _selectedProductIds = {};
  Map<String, CartAvailabilityIssue> _availabilityIssues = {};

  bool _isRefreshingAvailability = false;

  CartProvider() {
    _loadPersistedCart();
    unawaited(refreshCartAvailability());
  }

  List<CartItem> get items => [..._items];
  List<CartItem> get selectedItems => _items
      .where((item) => _selectedProductIds.contains(item.product.id))
      .toList();
  Set<String> get selectedProductIds => {..._selectedProductIds};
  bool get isRefreshingAvailability => _isRefreshingAvailability;

  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);
  int get uniqueItemCount => _items.length;
  int get selectedItemCount =>
      selectedItems.fold(0, (total, item) => total + item.quantity);
  int get selectedUniqueItemCount => selectedItems.length;
  bool get hasSelection => _selectedProductIds.isNotEmpty;
  bool get allItemsSelected =>
      _items.isNotEmpty && _selectedProductIds.length == _items.length;

  double get totalAmount {
    double total = 0.0;
    for (final item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  String get formattedTotalAmount =>
      '\$${_addCommas(totalAmount.toStringAsFixed(2))}';

  double get selectedTotalAmount {
    double total = 0.0;
    for (final item in selectedItems) {
      total += item.subtotal;
    }
    return total;
  }

  Map<String, double> get selectedTotalsByCurrency =>
      _buildTotalsByCurrency(selectedItems);

  Map<String, double> get totalByCurrency => _buildTotalsByCurrency(_items);

  CartAvailabilityIssue? availabilityIssueForProduct(String productId) =>
      _availabilityIssues[productId];

  List<CartAvailabilityIssue> issuesForScope(CartScope scope) =>
      itemsForScope(scope)
          .map((item) => _availabilityIssues[item.product.id])
          .whereType<CartAvailabilityIssue>()
          .toList();

  List<CartAvailabilityIssue> selectedIssuesForScope(CartScope scope) =>
      selectedItemsForScope(scope)
          .map((item) => _availabilityIssues[item.product.id])
          .whereType<CartAvailabilityIssue>()
          .toList();

  bool hasIssuesForScope(CartScope scope) => issuesForScope(scope).isNotEmpty;

  bool hasSelectedIssuesForScope(CartScope scope) =>
      selectedIssuesForScope(scope).isNotEmpty;

  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  int getQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    return index >= 0 ? _items[index].quantity : 0;
  }

  List<CartItem> itemsForScope(CartScope scope) =>
      _items.where((item) => _matchesScope(item.product, scope)).toList();

  List<CartItem> selectedItemsForScope(CartScope scope) => itemsForScope(
    scope,
  ).where((item) => _selectedProductIds.contains(item.product.id)).toList();

  Set<String> selectedProductIdsForScope(CartScope scope) =>
      selectedItemsForScope(scope).map((item) => item.product.id).toSet();

  int itemCountForScope(CartScope scope) =>
      itemsForScope(scope).fold(0, (total, item) => total + item.quantity);

  int uniqueItemCountForScope(CartScope scope) => itemsForScope(scope).length;

  int selectedItemCountForScope(CartScope scope) => selectedItemsForScope(
    scope,
  ).fold(0, (total, item) => total + item.quantity);

  int selectedUniqueItemCountForScope(CartScope scope) =>
      selectedItemsForScope(scope).length;

  bool hasSelectionInScope(CartScope scope) =>
      selectedItemsForScope(scope).isNotEmpty;

  bool allItemsSelectedForScope(CartScope scope) {
    final scopedItems = itemsForScope(scope);
    if (scopedItems.isEmpty) return false;

    return scopedItems.every(
      (item) => _selectedProductIds.contains(item.product.id),
    );
  }

  Map<String, double> selectedTotalsByCurrencyForScope(CartScope scope) =>
      _buildTotalsByCurrency(selectedItemsForScope(scope));

  bool canIncreaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index < 0) return false;

    final item = _items[index];
    final issue = _availabilityIssues[productId];
    if (issue != null && issue.isUnavailable) {
      return false;
    }

    return item.quantity < item.product.quantity;
  }

  CartActionResult addItem(FirebaseProduct product, [int quantity = 1]) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == product.id,
    );
    final currentQuantity = existingIndex >= 0
        ? _items[existingIndex].quantity
        : 0;
    final availableQuantity = product.quantity;

    if (availableQuantity <= 0) {
      _availabilityIssues = {
        ..._availabilityIssues,
        product.id: CartAvailabilityIssue(
          productId: product.id,
          message: '${product.name} is sold out right now.',
          availableQuantity: 0,
          isUnavailable: true,
        ),
      };
      notifyListeners();
      unawaited(_persistCart());
      return CartActionResult.failure('${product.name} is sold out right now.');
    }

    final requestedQuantity = currentQuantity + quantity;
    if (requestedQuantity > availableQuantity) {
      _availabilityIssues = {
        ..._availabilityIssues,
        product.id: CartAvailabilityIssue(
          productId: product.id,
          message:
              'Only $availableQuantity ${availableQuantity == 1 ? 'item is' : 'items are'} left for ${product.name}.',
          availableQuantity: availableQuantity,
          isUnavailable: false,
        ),
      };
      notifyListeners();
      unawaited(_persistCart());
      return CartActionResult.failure(
        'Only $availableQuantity ${availableQuantity == 1 ? 'item is' : 'items are'} left in stock.',
      );
    }

    if (existingIndex >= 0) {
      _items[existingIndex] = CartItem(
        product: product,
        quantity: requestedQuantity,
      );
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }

    _selectedProductIds.add(product.id);
    _availabilityIssues.remove(product.id);
    notifyListeners();
    unawaited(_persistCart());
    return const CartActionResult.success();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    _selectedProductIds.remove(productId);
    _availabilityIssues.remove(productId);
    notifyListeners();
    unawaited(_persistCart());
  }

  void removeSingleItem(String productId) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (existingIndex >= 0) {
      if (_items[existingIndex].quantity > 1) {
        _items[existingIndex].quantity -= 1;
        final availableQuantity = _items[existingIndex].product.quantity;
        if (_items[existingIndex].quantity <= availableQuantity) {
          _availabilityIssues.remove(productId);
        }
      } else {
        _selectedProductIds.remove(productId);
        _availabilityIssues.remove(productId);
        _items.removeAt(existingIndex);
      }
      notifyListeners();
      unawaited(_persistCart());
    }
  }

  CartActionResult updateQuantity(String productId, int newQuantity) {
    final existingIndex = _items.indexWhere(
      (item) => item.product.id == productId,
    );

    if (existingIndex < 0) {
      return const CartActionResult.failure('Item not found in cart.');
    }

    final item = _items[existingIndex];
    final availableQuantity = item.product.quantity;

    if (newQuantity <= 0) {
      _selectedProductIds.remove(productId);
      _availabilityIssues.remove(productId);
      _items.removeAt(existingIndex);
      notifyListeners();
      unawaited(_persistCart());
      return const CartActionResult.success();
    }

    if (availableQuantity <= 0) {
      _availabilityIssues = {
        ..._availabilityIssues,
        productId: CartAvailabilityIssue(
          productId: productId,
          message: '${item.product.name} is sold out right now.',
          availableQuantity: 0,
          isUnavailable: true,
        ),
      };
      notifyListeners();
      unawaited(_persistCart());
      return CartActionResult.failure(
        '${item.product.name} is sold out right now.',
      );
    }

    if (newQuantity > availableQuantity) {
      _availabilityIssues = {
        ..._availabilityIssues,
        productId: CartAvailabilityIssue(
          productId: productId,
          message:
              'Only $availableQuantity ${availableQuantity == 1 ? 'item is' : 'items are'} left for ${item.product.name}.',
          availableQuantity: availableQuantity,
          isUnavailable: false,
        ),
      };
      notifyListeners();
      unawaited(_persistCart());
      return CartActionResult.failure(
        'Only $availableQuantity ${availableQuantity == 1 ? 'item is' : 'items are'} left in stock.',
      );
    }

    _items[existingIndex] = CartItem(
      product: item.product,
      quantity: newQuantity,
    );
    _availabilityIssues.remove(productId);
    notifyListeners();
    unawaited(_persistCart());
    return const CartActionResult.success();
  }

  void toggleItemSelection(String productId) {
    if (_selectedProductIds.contains(productId)) {
      _selectedProductIds.remove(productId);
    } else {
      _selectedProductIds.add(productId);
    }
    notifyListeners();
    unawaited(_persistCart());
  }

  void selectAllItems() {
    _selectedProductIds
      ..clear()
      ..addAll(_items.map((item) => item.product.id));
    notifyListeners();
    unawaited(_persistCart());
  }

  void clearSelection() {
    _selectedProductIds.clear();
    notifyListeners();
    unawaited(_persistCart());
  }

  void toggleSelectAll() {
    if (allItemsSelected) {
      clearSelection();
      return;
    }
    selectAllItems();
  }

  bool isItemSelected(String productId) =>
      _selectedProductIds.contains(productId);

  void toggleSelectAllForScope(CartScope scope) {
    final scopedIds = itemsForScope(scope).map((item) => item.product.id);
    if (allItemsSelectedForScope(scope)) {
      _selectedProductIds.removeAll(scopedIds);
    } else {
      _selectedProductIds.addAll(scopedIds);
    }
    notifyListeners();
    unawaited(_persistCart());
  }

  void removeSelectedItemsForScope(CartScope scope) {
    final scopedIds = selectedProductIdsForScope(scope);
    _items.removeWhere((item) => scopedIds.contains(item.product.id));
    _selectedProductIds.removeAll(scopedIds);
    for (final productId in scopedIds) {
      _availabilityIssues.remove(productId);
    }
    notifyListeners();
    unawaited(_persistCart());
  }

  void clearCartForScope(CartScope scope) {
    final scopedIds = itemsForScope(
      scope,
    ).map((item) => item.product.id).toSet();
    _items.removeWhere((item) => scopedIds.contains(item.product.id));
    _selectedProductIds.removeAll(scopedIds);
    for (final productId in scopedIds) {
      _availabilityIssues.remove(productId);
    }
    notifyListeners();
    unawaited(_persistCart());
  }

  void removeSelectedItems() {
    final removedIds = _selectedProductIds.toSet();
    _items.removeWhere((item) => removedIds.contains(item.product.id));
    _selectedProductIds.clear();
    for (final productId in removedIds) {
      _availabilityIssues.remove(productId);
    }
    notifyListeners();
    unawaited(_persistCart());
  }

  void clearCart() {
    _items.clear();
    _selectedProductIds.clear();
    _availabilityIssues = {};
    notifyListeners();
    unawaited(_persistCart());
  }

  Future<List<CartAvailabilityIssue>> refreshCartAvailability({
    Iterable<String>? productIds,
  }) async {
    if (_items.isEmpty) {
      _availabilityIssues = {};
      notifyListeners();
      unawaited(_persistCart());
      return const [];
    }

    _isRefreshingAvailability = true;
    notifyListeners();

    final targetIds = (productIds ?? _items.map((item) => item.product.id))
        .toSet();
    final nextIssues = Map<String, CartAvailabilityIssue>.from(
      _availabilityIssues,
    );
    bool didChangeItems = false;

    for (final productId in targetIds) {
      final index = _items.indexWhere((item) => item.product.id == productId);
      if (index < 0) {
        nextIssues.remove(productId);
        continue;
      }

      final currentItem = _items[index];

      try {
        final doc = await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get();

        if (!doc.exists || doc.data() == null) {
          nextIssues[productId] = CartAvailabilityIssue(
            productId: productId,
            message: '${currentItem.product.name} is no longer available.',
            availableQuantity: 0,
            isUnavailable: true,
          );
          continue;
        }

        final data = doc.data()!;
        final latestProduct = FirebaseProduct.fromMap(doc.id, data);
        final latestQuantity = _readAvailableQuantity(data, latestProduct);
        final latestStatus = (data['status'] ?? 'active')
            .toString()
            .toLowerCase();

        if (_shouldReplaceProduct(currentItem.product, latestProduct)) {
          _items[index] = CartItem(
            product: latestProduct,
            quantity: currentItem.quantity,
          );
          didChangeItems = true;
        }

        if (latestStatus != 'active') {
          nextIssues[productId] = CartAvailabilityIssue(
            productId: productId,
            message: '${latestProduct.name} is currently unavailable.',
            availableQuantity: 0,
            isUnavailable: true,
          );
          continue;
        }

        if (latestQuantity <= 0) {
          nextIssues[productId] = CartAvailabilityIssue(
            productId: productId,
            message: '${latestProduct.name} is sold out.',
            availableQuantity: 0,
            isUnavailable: true,
          );
          continue;
        }

        if (currentItem.quantity > latestQuantity) {
          nextIssues[productId] = CartAvailabilityIssue(
            productId: productId,
            message:
                'Only $latestQuantity ${latestQuantity == 1 ? 'item is' : 'items are'} left for ${latestProduct.name}.',
            availableQuantity: latestQuantity,
            isUnavailable: false,
          );
          continue;
        }

        nextIssues.remove(productId);
      } catch (_) {
        // Keep the last known item and issue state when network refresh fails.
      }
    }

    _availabilityIssues = nextIssues;
    _isRefreshingAvailability = false;
    notifyListeners();

    if (didChangeItems || targetIds.isNotEmpty) {
      unawaited(_persistCart());
    }

    return nextIssues.values.toList();
  }

  String formatAmountWithCurrency({
    required String currency,
    required num amount,
  }) {
    final symbol = _currencySymbol(currency);
    return '$symbol${_addCommas(amount.toDouble().toStringAsFixed(2))}';
  }

  String _currencySymbol(String currency) {
    return currency.toUpperCase() == 'USD' ? '\$' : 'TSh ';
  }

  Map<String, double> _buildTotalsByCurrency(List<CartItem> source) {
    final totals = <String, double>{};
    for (final item in source) {
      final currency = item.product.currency.toUpperCase();
      totals[currency] = (totals[currency] ?? 0.0) + item.subtotal;
    }
    return totals;
  }

  String _addCommas(String price) {
    final parts = price.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : '00';

    String formatted = '';
    for (int i = integerPart.length - 1, count = 0; i >= 0; i--, count++) {
      if (count % 3 == 0 && count > 0) {
        formatted = ',$formatted';
      }
      formatted = integerPart[i] + formatted;
    }
    return '$formatted.$decimalPart';
  }

  bool _matchesScope(FirebaseProduct product, CartScope scope) {
    final sellerType = product.sellerType.trim().toLowerCase();
    switch (scope) {
      case CartScope.food:
        return sellerType == 'food';
      case CartScope.shopping:
        return sellerType != 'food';
    }
  }

  int _readAvailableQuantity(
    Map<String, dynamic> data,
    FirebaseProduct product,
  ) {
    final dynamic rawQuantity =
        data['quantity'] ?? data['stock'] ?? product.quantity;
    if (rawQuantity is num) {
      return rawQuantity.toInt();
    }
    if (rawQuantity is String) {
      return int.tryParse(rawQuantity) ?? product.quantity;
    }
    return product.quantity;
  }

  bool _shouldReplaceProduct(FirebaseProduct current, FirebaseProduct latest) {
    return current.name != latest.name ||
        current.price != latest.price ||
        current.currency != latest.currency ||
        current.imageUrl != latest.imageUrl ||
        current.quantity != latest.quantity ||
        current.status != latest.status;
  }

  void _loadPersistedCart() {
    if (!Hive.isBoxOpen(_cartBoxName)) return;

    final box = Hive.box(_cartBoxName);
    final rawItems = box.get(_cartItemsKey, defaultValue: <dynamic>[]);
    final rawSelected = box.get(_selectedItemsKey, defaultValue: <dynamic>[]);

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        if (rawItem is! Map) continue;

        final productMapRaw = rawItem['product'];
        if (productMapRaw is! Map) continue;

        final productMap = Map<String, dynamic>.from(
          productMapRaw.map((key, value) => MapEntry(key.toString(), value)),
        );
        final productId = (rawItem['productId'] ?? '').toString();
        if (productId.isEmpty) continue;

        final quantity = _parseInt(rawItem['quantity'], fallback: 1);
        _items.add(
          CartItem(
            product: FirebaseProduct.fromMap(productId, productMap),
            quantity: quantity,
          ),
        );
      }
    }

    if (rawSelected is List) {
      _selectedProductIds.addAll(rawSelected.map((item) => item.toString()));
      _selectedProductIds.removeWhere(
        (id) => !_items.any((item) => item.product.id == id),
      );
    }
  }

  Future<void> _persistCart() async {
    if (!Hive.isBoxOpen(_cartBoxName)) return;

    final box = Hive.box(_cartBoxName);
    await box.put(
      _cartItemsKey,
      _items
          .map(
            (item) => {
              'productId': item.product.id,
              'quantity': item.quantity,
              'product': _serializeProduct(item.product),
            },
          )
          .toList(),
    );
    await box.put(_selectedItemsKey, _selectedProductIds.toList());
  }

  Map<String, dynamic> _serializeProduct(FirebaseProduct product) {
    return {
      'name': product.name,
      'images': product.images,
      'category': product.category,
      'subCategory': product.subCategory,
      'price': product.price,
      'currency': product.currency,
      'condition': product.condition,
      'sellerId': product.sellerId,
      'description': product.description,
      'quantity': product.quantity,
      'location': product.location,
      'deliveryOptions': product.deliveryOptions,
      'sellerType': product.sellerType,
      'status': product.status,
      'createdAt': product.createdAt?.millisecondsSinceEpoch,
      'updatedAt': product.updatedAt?.millisecondsSinceEpoch,
      'soldCount': product.soldCount,
      'rating': product.rating,
      'discountPrice': product.discountPrice,
      'discountDescription': product.discountDescription,
    };
  }

  int _parseInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
