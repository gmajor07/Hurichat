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
              'Huruchati Discover',
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
            _buildModernTile(
              context,
              icon: Icons.auto_awesome_mosaic_rounded,
              title: 'Status',
              color: Colors.orange,
              routeName: '/my_cart_food',
              isDark: isDark,
            ),
            _buildModernTile(
              context,
              icon: Icons.video_library_rounded,
              title: 'Video and channel',
              color: Colors.redAccent,
              routeName: '/my_shopping_cart',
              isDark: isDark,
            ),
            _buildModernTile(
              context,
              icon: Icons.search_rounded,
              title: 'Search',
              color: primary,
              routeName: '/customer_support',
              isDark: isDark,
            ),
            _buildModernTile(
              context,
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan',
              color: Colors.blue,
              routeName: '/coupons',
              isDark: isDark,
            ),
            _buildModernTile(
              context,
              icon: Icons.grid_view_rounded,
              title: 'Programs',
              color: Colors.teal,
              routeName: '/account_settings',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildModernTile(
              context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              color: Colors.red,
              isLogout: true,
              isDark: isDark,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
    String? routeName,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDark ? Colors.white38 : Colors.black26,
        ),
        onTap: () async {
          if (isLogout) {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
}
