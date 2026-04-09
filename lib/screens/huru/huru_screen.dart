import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:huruchat/screens/transport_screen.dart';
import '../food/screen/food_screen.dart';
import '../theme/app_theme.dart';
import '../shopping/screens/seller_dashboard_screen.dart';

class HuruScreen extends StatelessWidget {
  const HuruScreen({super.key});

  // --- Helpers ---
  Widget _buildSectionTitle(String title, bool isDark) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    ),
  );

  Widget _buildModernSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    String? routeName,
    bool isLogout = false,
    bool isSellerDashboard = false,
    bool isSellerSettings = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDark ? Colors.white24 : Colors.black12,
          size: 20,
        ),
        onTap: () async {
          final user = FirebaseAuth.instance.currentUser;

          if (isLogout) {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
            return;
          }

          if (isSellerDashboard || isSellerSettings) {
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Login required.")),
              );
              return;
            }

            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final userData = userDoc.data();
              if (userData?['role'] != 'seller' ||
                  userData?['sellerStatus'] != 'active') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Access restricted to active sellers.")),
                );
                return;
              }

              if (isSellerDashboard) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellerProductsScreen(sellerId: user.uid),
                  ),
                );
              } else {
                Navigator.pushNamed(context, '/seller_screen');
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: $e")),
              );
            }
            return;
          }

          if (routeName != null) {
            Navigator.pushNamed(context, routeName);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12151B)
          : const Color(0xFFF2F5F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Huruchati Huru',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Manage your account and settings',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Services Section
                _buildSectionTitle('Services', isDark),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    _ActionButton(
                      icon: Icons.car_rental_rounded,
                      label: 'Transport',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransportScreen())),
                    ),
                    _ActionButton(
                      icon: Icons.fastfood_rounded,
                      label: 'Food',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodScreen())),
                    ),
                    const _ActionButton(icon: Icons.confirmation_number_rounded, label: 'Ticket'),
                    const _ActionButton(icon: Icons.receipt_long_rounded, label: 'Bills'),
                  ],
                ),
                const SizedBox(height: 20),

                // Account & Settings Section
                _buildSectionTitle('Account & Settings', isDark),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.shopping_basket_rounded,
                  title: 'My Food Cart',
                  color: Colors.orange,
                  routeName: '/my_cart_food',
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.shopping_bag_rounded,
                  title: 'Shopping Cart',
                  color: Colors.blue,
                  routeName: '/my_shopping_cart',
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.headset_mic_rounded,
                  title: 'Customer Support',
                  color: Colors.teal,
                  routeName: '/customer_support',
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.local_activity_rounded,
                  title: 'Coupons & Offers',
                  color: Colors.pink,
                  routeName: '/coupons',
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.person_rounded,
                  title: 'Profile Settings',
                  color: primary,
                  routeName: '/account_profile',
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.storefront_rounded,
                  title: 'Seller Settings',
                  color: Colors.indigo,
                  isSellerSettings: true,
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.dashboard_customize_rounded,
                  title: 'Seller Dashboard',
                  color: const Color(0xFF4CAFAB),
                  isSellerDashboard: true,
                  isDark: isDark,
                ),
                _buildModernSettingsTile(
                  context,
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  color: Colors.red,
                  isLogout: true,
                  isDark: isDark,
                ),
                // Safe area padding at bottom to ensure logout is not hidden by nav
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E222D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary, size: 24),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
