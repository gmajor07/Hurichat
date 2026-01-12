import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:huruchat/screens/transport_screen.dart';
import '../shopping/screens/shopping_screen.dart';
import '../theme/app_theme.dart';
// ✅ IMPORTANT: Import the SellerProductsScreen for direct navigation
import '../shopping/screens/seller_dashboard_screen.dart';

class HuruScreen extends StatelessWidget {
  const HuruScreen({super.key});

  // --- Helpers ---
  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  );

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    String? routeName,
    bool isLogout = false,
    bool isSellerDashboard = false, // ✅ NEW FLAG for Seller Dashboard
    bool isSellerSettings = false, // ✅ NEW FLAG for Seller Settings
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;

        if (isLogout) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }

        // 🔑 FIX LOGIC: Direct navigation to Seller Dashboard with UID
        if (isSellerDashboard) {
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Login required to view dashboard."),
              ),
            );
            return;
          }

          // Check if user is an active seller
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            final userData = userDoc.data();
            if (userData?['role'] != 'seller' || userData?['sellerStatus'] != 'active') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("You must be an active seller to access the dashboard."),
                ),
              );
              return;
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error checking seller status: $e")),
            );
            return;
          }

          // Use direct navigation and pass the authenticated user's ID
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SellerProductsScreen(sellerId: user.uid),
            ),
          );
          return;
        }

        // 🔑 CHECK for Seller Settings
        if (isSellerSettings) {
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Login required to access seller settings."),
              ),
            );
            return;
          }

          // Check if user is an active seller
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            final userData = userDoc.data();
            if (userData?['role'] != 'seller' || userData?['sellerStatus'] != 'active') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("You must be an active seller to access seller settings."),
                ),
              );
              return;
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error checking seller status: $e")),
            );
            return;
          }

          // Proceed to seller screen
          Navigator.pushNamed(context, '/seller_screen');
          return;
        }

        if (routeName != null) {
          Navigator.pushNamed(context, routeName);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = AppTheme.accentBlue;
    final Color primary = AppTheme.primaryColor;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Check Balance',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions
            _buildSectionTitle('Quick Actions'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: const [
                _ActionButton(icon: Icons.qr_code, label: 'Scan & Pay'),
                _ActionButton(
                  icon: Icons.account_balance_wallet,
                  label: 'Collect',
                ),
                _ActionButton(icon: Icons.sync_alt, label: 'Transfer'),
                _ActionButton(icon: Icons.download, label: 'Deposit'),
              ],
            ),
            const SizedBox(height: 24),

            // Services
            _buildSectionTitle('Services'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _ActionButton(
                  icon: Icons.car_rental_outlined,
                  label: 'Transport',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TransportScreen(),
                      ),
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.shopping_bag,
                  label: 'Shopping',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ShoppingScreen(),
                      ),
                    );
                  },
                ),
                const _ActionButton(
                  icon: Icons.confirmation_number,
                  label: 'Ticket',
                ),
                const _ActionButton(icon: Icons.receipt, label: 'Bill Payment'),
              ],
            ),
            const SizedBox(height: 24),

            // Account & Settings Section
            _buildSectionTitle('Account & Settings'),
            const SizedBox(height: 12),

            _buildSettingsTile(
              context,
              icon: Icons.fastfood_outlined,
              title: 'My Cart Food',
              color: primary,
              routeName: '/my_cart_food',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'My Shopping Cart',
              color: primary,
              routeName: '/my_shopping_cart',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.support_agent,
              title: 'Customer Support',
              color: primary,
              routeName: '/customer_support',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.card_giftcard,
              title: 'Coupon & Offer',
              color: primary,
              routeName: '/coupons',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.settings,
              title: 'Settings',
              color: primary,
              routeName: '/account_settings',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.shop,
              title: 'Seller Settings',
              color: primary,
              isSellerSettings: true,
            ),
            const Divider(),
            // ✅ FIXED NAVIGATION: Using flag and direct push
            _buildSettingsTile(
              context,
              icon: Icons.store_mall_directory, // Updated icon
              title: 'My Seller Dashboard',
              color: primary,
              isSellerDashboard: true, // 🔑 Trigger the fix logic
              // routeName: '/seller_dashboard_screen', // ❌ DEPRECATED ROUTE
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.logout,
              title: 'Logout',
              color: Colors.redAccent,
              isLogout: true,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// --- Reusable action button ---
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color accent = AppTheme.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
