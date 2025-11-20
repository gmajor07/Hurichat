import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

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
            // ✅ Account & Settings Section
            _buildSectionTitle('Discover'),
            const SizedBox(height: 12),

            _buildSettingsTile(
              context,
              icon: Icons.fastfood_outlined,
              title: 'Status',
              color: primary,
              routeName: '/my_cart_food',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.shopping_cart_outlined,
              title: 'Video and channel',
              color: primary,
              routeName: '/my_shopping_cart',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.support_agent,
              title: 'Search',
              color: primary,
              routeName: '/customer_support',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.card_giftcard,
              title: 'Scan',
              color: primary,
              routeName: '/coupons',
            ),
            const Divider(),
            _buildSettingsTile(
              context,
              icon: Icons.settings,
              title: 'Programs',
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
            // ignore: use_build_context_synchronously
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
