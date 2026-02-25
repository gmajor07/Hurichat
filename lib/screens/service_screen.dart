import 'package:flutter/material.dart';
import 'advanced_search_bar.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionCards = _filteredSections;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdvancedSearchBar(
              hintText: "Search services",
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              autoFocus: false,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
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
                  'No services found for "$_searchQuery".',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickAction(
              label: 'Money',
              icon: Icons.qr_code_scanner_rounded,
              onTap: () => _showComingSoon('Money'),
            ),
          ),
          Expanded(
            child: _buildQuickAction(
              label: 'Wallet',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => _showComingSoon('Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: section.items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
              childAspectRatio: 0.9,
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

  List<_ServiceSection> get _filteredSections {
    final sections = _sections;
    if (_searchQuery.isEmpty) return sections;

    final query = _searchQuery;
    return sections
        .map((section) {
          final matchedItems = section.items
              .where((item) => item.label.toLowerCase().contains(query))
              .toList();
          if (section.title.toLowerCase().contains(query)) {
            return section;
          }
          return _ServiceSection(title: section.title, items: matchedItems);
        })
        .where((section) => section.items.isNotEmpty)
        .toList();
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
