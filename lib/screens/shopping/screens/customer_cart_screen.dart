import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../provider/cart_provider.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';

class CustomerCartScreen extends StatelessWidget {
  const CustomerCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          if (cartProvider.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _showClearCartDialog(context, cartProvider);
              },
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: cartProvider.items.isEmpty
          ? _buildEmptyCartView(context)
          : _buildCartWithItems(context, cartProvider),
      bottomNavigationBar: cartProvider.items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).canvasColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cartProvider.formattedTotalAmount,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CheckoutScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text(
                        'Proceed to Checkout',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back
                    },
                    child: const Text('Continue Shopping'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyCartView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'Your cart is empty',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add some products to your cart',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Go back to product screen
            },
            child: const Text('Browse Products'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartWithItems(BuildContext context, CartProvider cartProvider) {
    return Column(
      children: [
        // Cart summary
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cartProvider.itemCount} item${cartProvider.itemCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${cartProvider.formattedTotalAmount}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _showClearCartDialog(context, cartProvider);
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Clear All'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Cart items list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cartProvider.items.length,
            itemBuilder: (context, index) {
              final item = cartProvider.items[index];
              return _buildCartItem(context, item, cartProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem item,
    CartProvider cartProvider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(item.product.imageUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(item.product.price.toDouble()),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quantity controls
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          cartProvider.removeSingleItem(item.product.id);
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 20,
                        color: Colors.red,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          item.quantity.toString(),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          cartProvider.addItem(item.product);
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 20,
                        color: Colors.green,
                      ),
                      const Spacer(),
                      Text(
                        item.formattedSubtotal,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cartProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartProvider.clearCart();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
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
}
