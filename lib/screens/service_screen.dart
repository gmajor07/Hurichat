import 'package:flutter/material.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  static const Color _quickActionColor = Color(0xFF4DB6B3);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionCards = _sections;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF12151B)
          : const Color(0xFFF2F5F8),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Explore our wide range of services',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickActionsCard(colorScheme),
            const SizedBox(height: 12),
            if (sectionCards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'No services available.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            for (final section in sectionCards) ...[
              _buildSectionCard(section, colorScheme, isDark),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(ColorScheme scheme) {
    final quickActions = [
      (
        label: 'Scan & Pay',
        icon: Icons.qr_code_2_rounded,
        color: Color(0xFF4DB6B3),
      ),
      (
        label: 'Collect',
        icon: Icons.account_balance_wallet_rounded,
        color: Color(0xFF2CB67D),
      ),
      (
        label: 'Transfer',
        icon: Icons.swap_horiz_rounded,
        color: Color(0xFF3AA6FF),
      ),
      (
        label: 'Deposit',
        icon: Icons.download_rounded,
        color: Color(0xFFF4A940),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width < 360 ? 2 : 4;
            final tileWidth = (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: quickActions
                  .map(
                    (action) => SizedBox(
                      width: tileWidth,
                      child: _buildQuickAction(
                        label: action.label,
                        icon: action.icon,
                        color: action.color,
                        onTap: () => _showComingSoon(action.label),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    _ServiceSection section,
    ColorScheme scheme,
    bool isDark,
  ) {
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final gridWidth = constraints.maxWidth;
              final crossAxisCount = gridWidth < 320
                  ? 2
                  : gridWidth < 420
                  ? 3
                  : 4;
              final mainAxisExtent = textScaleFactor > 1.15 ? 102.0 : 94.0;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: section.items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 10,
                  mainAxisExtent: mainAxisExtent,
                ),
                itemBuilder: (_, index) {
                  final item = section.items[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showComingSoon(item.label),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: item.color.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, color: item.color, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String service) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$service service coming soon')));
  }

  List<_ServiceSection> get _sections => [
    _ServiceSection(
      title: 'Financial Services',
      items: const [
        _ServiceItem(
          'Card Repay',
          Icons.credit_card_outlined,
          Color(0xFF2CB67D),
        ),
        _ServiceItem('Wealth', Icons.pie_chart_outline, Color(0xFF3AA6FF)),
      ],
    ),
    _ServiceSection(
      title: 'Daily Services',
      items: const [
        _ServiceItem(
          'Mobile Top Up',
          Icons.phone_iphone_outlined,
          Color(0xFF4A90E2),
        ),
        _ServiceItem('Utilities', Icons.verified_outlined, Color(0xFF2CB67D)),
        _ServiceItem('QQ Coins', Icons.cloud_outlined, Color(0xFF47B8E0)),
        _ServiceItem(
          'Public Services',
          Icons.location_city_outlined,
          Color(0xFF34C38F),
        ),
        _ServiceItem(
          'Charity',
          Icons.volunteer_activism_outlined,
          Color(0xFFFF6B6B),
        ),
        _ServiceItem('Health', Icons.add_box_outlined, Color(0xFFF4A940)),
      ],
    ),
    _ServiceSection(
      title: 'Shopping & Entertainment',
      items: const [
        _ServiceItem(
          'Brand Mall',
          Icons.storefront_outlined,
          Color(0xFFFF6B6B),
        ),
        _ServiceItem('Specials', Icons.local_offer_outlined, Color(0xFFE85D75)),
        _ServiceItem(
          'Event Tickets',
          Icons.confirmation_number_outlined,
          Color(0xFFFF5A5F),
        ),
        _ServiceItem('Group Buying', Icons.groups_outlined, Color(0xFFF4A940)),
        _ServiceItem('Buy Together', Icons.favorite_border, Color(0xFFE85D75)),
        _ServiceItem('Flash Sales', Icons.flash_on_outlined, Color(0xFFD64D9D)),
        _ServiceItem('Used Goods', Icons.recycling_outlined, Color(0xFFFF5A5F)),
      ],
    ),
  ];
}

class _ServiceSection {
  final String title;
  final List<_ServiceItem> items;

  const _ServiceSection({required this.title, required this.items});
}

class _ServiceItem {
  final String label;
  final IconData icon;
  final Color color;

  const _ServiceItem(this.label, this.icon, this.color);
}
