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

  final List<String> _paymentMethods = [
    'Demo Payment',
    'Credit Card',
    'PayPal',
    'Bank Transfer',
  ];

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final checkoutItems = cartProvider.items
        .where((item) => widget.selectedProductIds.contains(item.product.id))
        .toList();
    final totalsByCurrency = _totalsByCurrency(checkoutItems);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: checkoutItems.isEmpty
          ? const Center(child: Text('No selected items found in cart.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      final totalsByCurrency = _totalsByCurrency(checkoutItems);
      final totalAmount = checkoutItems.fold<double>(
        0,
        (total, item) => total + item.subtotal,
      );

      final orderData = {
        'items': checkoutItems
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

      await FirebaseFirestore.instance.collection('orders').add(orderData);

      for (final item in checkoutItems) {
        final productRef = FirebaseFirestore.instance
            .collection('products')
            .doc(item.product.id);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final productDoc = await transaction.get(productRef);
          if (productDoc.exists) {
            final currentStock = productDoc.data()?['stock'] ?? 0;
            final newStock = (currentStock as int) - item.quantity;
            transaction.update(productRef, {
              'stock': newStock > 0 ? newStock : 0,
            });
          }
        });
      }

      for (final item in checkoutItems) {
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
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
    }
  }
}
