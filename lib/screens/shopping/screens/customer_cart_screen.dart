import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../provider/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';

class CustomerCartScreen extends StatefulWidget {
  final CartScope scope;

  const CustomerCartScreen({super.key, this.scope = CartScope.shopping});

  @override
  State<CustomerCartScreen> createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  bool _hasShownAvailabilityUpdate = false;

  bool get _isFoodCart => widget.scope == CartScope.food;

  String get _title => _isFoodCart ? 'Food Cart' : 'Shopping Cart';

  String get _emptyHeadline =>
      _isFoodCart ? 'Your food cart is empty' : 'Your cart is empty';

  String get _emptySubtitle => _isFoodCart
      ? 'Add meals from food vendors to get started'
      : 'Add some products to your cart';

  String get _browseLabel => _isFoodCart ? 'Browse Meals' : 'Browse Products';

  IconData get _cartIcon => _isFoodCart
      ? Icons.shopping_basket_outlined
      : Icons.shopping_cart_outlined;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAvailability(showFeedback: false);
    });
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<void> _refreshAvailability({required bool showFeedback}) async {
    final cartProvider = context.read<CartProvider>();
    final issues = await cartProvider.refreshCartAvailability(
      productIds: cartProvider
          .itemsForScope(widget.scope)
          .map((item) => item.product.id),
    );

    if (!mounted) return;

    if (issues.isNotEmpty && (!_hasShownAvailabilityUpdate || showFeedback)) {
      _hasShownAvailabilityUpdate = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            issues.length == 1
                ? issues.first.message
                : '${issues.length} cart items need your attention before checkout.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart updated with latest availability.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final scopedItems = cartProvider.itemsForScope(widget.scope);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        automaticallyImplyLeading: true,
        actions: [
          if (scopedItems.isNotEmpty)
            IconButton(
              icon: cartProvider.isRefreshingAvailability
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: cartProvider.isRefreshingAvailability
                  ? null
                  : () => _refreshAvailability(showFeedback: true),
              tooltip: 'Refresh availability',
            ),
          if (scopedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _showClearCartDialog(context, cartProvider);
              },
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAvailability(showFeedback: true),
        child: scopedItems.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildEmptyCartView(context)],
              )
            : _buildCartWithItems(context, cartProvider, scopedItems),
      ),
      bottomNavigationBar: scopedItems.isEmpty
          ? null
          : _buildBottomBar(context, cartProvider),
    );
  }

  Widget _buildBottomBar(BuildContext context, CartProvider cartProvider) {
    final selectedTotals = cartProvider.selectedTotalsByCurrencyForScope(
      widget.scope,
    );
    final primary = AppTheme.primaryColor;
    final hasBlockingIssues = cartProvider.hasSelectedIssuesForScope(
      widget.scope,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasBlockingIssues)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC107)),
                ),
                child: const Text(
                  'Some selected items changed availability. Update your cart before checkout.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A5A00),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected (${cartProvider.selectedItemCountForScope(widget.scope)} items)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!cartProvider.hasSelectionInScope(widget.scope))
                  const Text(
                    'Please select items',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (cartProvider.hasSelectionInScope(widget.scope))
              ...selectedTotals.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        entry.key == 'USD' ? 'Total (USD): ' : 'Total (Tsh): ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          cartProvider.formatAmountWithCurrency(
                            currency: entry.key,
                            amount: entry.value,
                          ),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          cartProvider.hasSelectionInScope(widget.scope) &&
                              !hasBlockingIssues
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CheckoutScreen(
                                    selectedProductIds: cartProvider
                                        .selectedProductIdsForScope(
                                          widget.scope,
                                        )
                                        .toList(),
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Checkout',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCartView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_cartIcon, size: 80, color: primary),
              ),
              const SizedBox(height: 32),
              Text(
                _emptyHeadline,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _emptySubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(
                    _browseLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartWithItems(
    BuildContext context,
    CartProvider cartProvider,
    List<CartItem> scopedItems,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final issues = cartProvider.issuesForScope(widget.scope);

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cart Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${cartProvider.selectedUniqueItemCountForScope(widget.scope)}/${cartProvider.uniqueItemCountForScope(widget.scope)} types selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white60
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _showClearCartDialog(context, cartProvider);
                        },
                        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (issues.isNotEmpty) ...[
                    const Divider(height: 24),
                    _buildIssuesBanner(issues),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: cartProvider.allItemsSelectedForScope(
                            widget.scope,
                          ),
                          onChanged: (_) => cartProvider
                              .toggleSelectAllForScope(widget.scope),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        cartProvider.allItemsSelectedForScope(widget.scope)
                            ? 'Unselect All'
                            : 'Select All Items',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (cartProvider.hasSelectionInScope(widget.scope))
                        GestureDetector(
                          onTap: () => cartProvider.removeSelectedItemsForScope(
                            widget.scope,
                          ),
                          child: const Text(
                            'Remove Selected',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ...scopedItems.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCartItem(context, item, cartProvider),
          ),
        ),
      ],
    );
  }

  Widget _buildIssuesBanner(List<CartAvailabilityIssue> issues) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: issues
            .take(3)
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
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    CartItem item,
    CartProvider cartProvider,
  ) {
    final isSelected = cartProvider.isItemSelected(item.product.id);
    final imageUrl = item.product.imageUrl.trim();
    final primary = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final issue = cartProvider.availabilityIssueForProduct(item.product.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: issue != null
              ? const Color(0xFFFFC107)
              : isSelected
              ? primary.withValues(alpha: 0.5)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) =>
                    cartProvider.toggleItemSelection(item.product.id),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 75,
                height: 75,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _capitalize(item.product.name),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (issue != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        issue.message,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8A5A00),
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Sub: ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            item.formattedSubtotal,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Unit: ${item.formattedUnitPrice}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Available: ${item.product.quantity}',
                    style: TextStyle(
                      fontSize: 12,
                      color: issue != null
                          ? const Color(0xFF8A5A00)
                          : (isDark ? Colors.white38 : Colors.grey.shade600),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQtyBtn(
                        icon: Icons.remove,
                        onTap: () =>
                            cartProvider.removeSingleItem(item.product.id),
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        iconColor: isDark ? Colors.white70 : Colors.black87,
                      ),
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            item.quantity.toString(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      _buildQtyBtn(
                        icon: Icons.add,
                        onTap: () {
                          final result = cartProvider.addItem(item.product);
                          if (!result.success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message!),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        color: primary,
                        iconColor: Colors.white,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () =>
                            cartProvider.removeItem(item.product.id),
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade400,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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

  Widget _buildQtyBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            if (color != Colors.white10)
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF2F4F7),
      alignment: Alignment.center,
      child: Icon(
        _isFoodCart ? Icons.fastfood_rounded : Icons.shopping_bag_outlined,
        color: const Color(0xFF8B99A8),
        size: 28,
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartProvider cartProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isFoodCart ? 'Clear Food Cart' : 'Clear Cart'),
        content: Text(
          _isFoodCart
              ? 'Are you sure you want to remove all meals from your cart?'
              : 'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              cartProvider.clearCartForScope(widget.scope);
              Navigator.pop(context);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
