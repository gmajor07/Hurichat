import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/cart_provider.dart';
import '../models/cart_item.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...cartProvider.items.map((item) => _buildOrderItem(item)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatPrice(cartProvider.totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Payment Method
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

            // Place Order Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _placeOrder(context, cartProvider),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Product image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: item.product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(item.product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: Colors.grey[200],
            ),
            child: item.product.imageUrl == null
                ? const Icon(Icons.image, color: Colors.grey)
                : null,
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
                Text(_formatPrice(item.subtotal)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  void _placeOrder(BuildContext context, CartProvider cartProvider) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Create order data
      final orderData = {
        'items': cartProvider.items
            .map(
              (item) => {
                'productId': item.product.id,
                'productName': item.product.name,
                'price': item.product.price,
                'quantity': item.quantity,
                'subtotal': item.subtotal,
              },
            )
            .toList(),
        'totalAmount': cartProvider.totalAmount,
        'paymentMethod': _selectedPaymentMethod,
        'status': 'completed', // or 'pending' for real payment
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user',
      };

      // Save to Firebase
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      // Update stock for each item
      for (final item in cartProvider.items) {
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

      // Clear cart
      cartProvider.clearCart();

      // Hide loading
      Navigator.of(context).pop();

      // Show success
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Placed!'),
          content: const Text('Your order has been placed successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to cart
                Navigator.of(
                  context,
                ).pop(); // Go back to shopping/product details
                // If came from product details, one more pop might be needed
                // but let's keep it simple for now
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Hide loading
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
    }
  }
}
