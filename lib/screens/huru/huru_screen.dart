import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../food/screen/food_screen.dart';
import '../shopping/screens/shopping_screen.dart';
import '../theme/app_theme.dart';

class HuruScreen extends StatelessWidget {
  const HuruScreen({super.key});

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
            // ✅ Top Row
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

            // ✅ Quick Actions
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

            // ✅ Services
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
                  icon: Icons.fastfood,
                  label: 'Food',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FoodScreen(),
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

            // ✅ Account & Settings Section
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
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () async {
        if (isLogout) {
          await FirebaseAuth.instance.signOut();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
          return;
        }

        if (routeName != null) {
          Navigator.pushNamed(context, routeName);
        }
      },
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
