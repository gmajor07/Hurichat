import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/cart_provider.dart';
import '../models/cart_item.dart';

class CheckoutScreen extends StatefulWidget {
  final List<String> selectedProductIds;

  const CheckoutScreen({super.key, required this.selectedProductIds});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _selectedPaymentMethod = 'Demo Payment';
  bool _isRefreshing = false;

  final List<String> _paymentMethods = [
    'Demo Payment',
    'Credit Card',
    'PayPal',
    'Bank Transfer',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAvailability();
    });
  }

  Future<void> _refreshAvailability() async {
    if (!mounted) return;
    setState(() => _isRefreshing = true);
    await context.read<CartProvider>().refreshCartAvailability(
      productIds: widget.selectedProductIds,
    );
    if (!mounted) return;
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final checkoutItems = cartProvider.items
        .where((item) => widget.selectedProductIds.contains(item.product.id))
        .toList();
    final totalsByCurrency = _totalsByCurrency(checkoutItems);
    final blockingIssues = checkoutItems
        .map(
          (item) => cartProvider.availabilityIssueForProduct(item.product.id),
        )
        .whereType<CartAvailabilityIssue>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshAvailability,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: checkoutItems.isEmpty
          ? const Center(child: Text('No selected items found in cart.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (blockingIssues.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFC107)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: blockingIssues
                            .map(
                              (issue) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '• ${issue.message}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8A5A00),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const Text(
                    'Order Summary',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${checkoutItems.length} product${checkoutItems.length > 1 ? 's' : ''} selected',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ...checkoutItems.map(_buildOrderItem),
                  const Divider(),
                  ...totalsByCurrency.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key == 'USD'
                                ? 'Total (USD):'
                                : 'Total (TSh):',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            cartProvider.formatAmountWithCurrency(
                              currency: entry.key,
                              amount: entry.value,
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._paymentMethods.map(
                    (method) => RadioListTile<String>(
                      title: Text(method),
                      value: method,
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          _placeOrder(context, cartProvider, checkoutItems),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Place Order',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    final hasImage = item.product.imageUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(item.product.imageUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey[200],
            ),
            child: hasImage
                ? null
                : const Icon(Icons.image, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Quantity: ${item.quantity}'),
                Text(item.formattedSubtotal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _totalsByCurrency(List<CartItem> items) {
    final totals = <String, double>{};
    for (final item in items) {
      final currency = item.product.currency.toUpperCase();
      totals[currency] = (totals[currency] ?? 0.0) + item.subtotal;
    }
    return totals;
  }

  void _placeOrder(
    BuildContext context,
    CartProvider cartProvider,
    List<CartItem> checkoutItems,
  ) async {
    if (checkoutItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await cartProvider.refreshCartAvailability(
        productIds: checkoutItems.map((item) => item.product.id),
      );

      final refreshedItems = cartProvider.items
          .where((item) => widget.selectedProductIds.contains(item.product.id))
          .toList();
      final blockingIssues = refreshedItems
          .map(
            (item) => cartProvider.availabilityIssueForProduct(item.product.id),
          )
          .whereType<CartAvailabilityIssue>()
          .toList();

      if (blockingIssues.isNotEmpty) {
        throw CheckoutValidationException(
          blockingIssues.map((issue) => issue.message).toList(),
        );
      }

      final totalsByCurrency = _totalsByCurrency(refreshedItems);
      final totalAmount = refreshedItems.fold<double>(
        0,
        (total, item) => total + item.subtotal,
      );

      final orderData = {
        'items': refreshedItems
            .map(
              (item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'price': item.product.price,
                'currency': item.product.currency,
                'quantity': item.quantity,
                'subtotal': item.subtotal,
              },
            )
            .toList(),
        'totalAmount': totalAmount,
        'totalsByCurrency': totalsByCurrency,
        'paymentMethod': _selectedPaymentMethod,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user',
      };

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        for (final item in refreshedItems) {
          final productRef = FirebaseFirestore.instance
              .collection('products')
              .doc(item.product.id);
          final productDoc = await transaction.get(productRef);

          if (!productDoc.exists || productDoc.data() == null) {
            throw CheckoutValidationException([
              '${item.product.name} is no longer available.',
            ]);
          }

          final data = productDoc.data()!;
          final status = (data['status'] ?? 'active').toString().toLowerCase();
          final rawQuantity = data['quantity'] ?? data['stock'] ?? 0;
          final availableQuantity = rawQuantity is num
              ? rawQuantity.toInt()
              : int.tryParse(rawQuantity.toString()) ?? 0;

          if (status != 'active' || availableQuantity <= 0) {
            throw CheckoutValidationException([
              '${item.product.name} is sold out right now.',
            ]);
          }

          if (item.quantity > availableQuantity) {
            throw CheckoutValidationException([
              'Only $availableQuantity ${availableQuantity == 1 ? 'item is' : 'items are'} left for ${item.product.name}.',
            ]);
          }

          final remainingQuantity = availableQuantity - item.quantity;
          transaction.update(productRef, {
            'quantity': remainingQuantity,
            'soldCount': FieldValue.increment(item.quantity),
            'status': remainingQuantity > 0 ? 'active' : 'sold_out',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        final orderRef = FirebaseFirestore.instance.collection('orders').doc();
        transaction.set(orderRef, orderData);
      });

      for (final item in refreshedItems) {
        cartProvider.removeItem(item.product.id);
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Placed!'),
          content: const Text('Your order has been placed successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on CheckoutValidationException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await cartProvider.refreshCartAvailability(
        productIds: widget.selectedProductIds,
      );
      _showValidationDialog(e.messages);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
    }
  }

  void _showValidationDialog(List<String> messages) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cart Updated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: messages
              .map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $message'),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Review Cart'),
          ),
        ],
      ),
    );
  }
}

class CheckoutValidationException implements Exception {
  final List<String> messages;

  CheckoutValidationException(this.messages);
}
