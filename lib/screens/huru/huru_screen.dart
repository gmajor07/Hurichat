import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class HuruScreen extends StatelessWidget {
  const HuruScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Color accent = AppTheme.accentBlue;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Greeting + Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Check balance',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick actions grid
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
              children: const [
                _ActionButton(icon: Icons.fastfood, label: 'Food'),
                _ActionButton(icon: Icons.shopping_bag, label: 'Shopping'),
                _ActionButton(icon: Icons.confirmation_number, label: 'Ticket'),
                _ActionButton(icon: Icons.receipt, label: 'Bill Payment'),
              ],
            ),
            const SizedBox(height: 24),

            // Promo section
            _buildSectionHeader('Promo and Discount', 'See all', accent),
            const SizedBox(height: 12),
            _PromoCard(image: 'assets/images/promo1.png', title: 'Buy and Pay'),
            const SizedBox(height: 24),

            // Shopping section
            _buildSectionHeader('Shop on Huru', 'See all', accent),
            const SizedBox(height: 12),
            _PromoCard(
              image: 'assets/images/promo2.png',
              title: 'Online Shopping',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
  );

  Widget _buildSectionHeader(String title, String action, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        Text(
          action,
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final Color accent = AppTheme.primaryColor;
    return Container(
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
    );
  }
}

class _PromoCard extends StatelessWidget {
  final String image;
  final String title;

  const _PromoCard({required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    final Color accent = AppTheme.accentBlue;
    return Container(
      height: 140,
      decoration: BoxDecoration(
        border: Border.all(color: accent, width: 1.2),
        borderRadius: BorderRadius.circular(14),
        image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
