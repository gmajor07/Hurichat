import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

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
              'Discover',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Discover new things and stay updated',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
