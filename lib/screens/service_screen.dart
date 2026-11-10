import 'package:flutter/material.dart';

import 'food/screen/food_screen.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
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
                    onTap: () => _handleServiceTap(item),
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

  void _handleServiceTap(_ServiceItem item) {
    if (item.destination != null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => item.destination!()));
      return;
    }

    _showComingSoon(item.label);
  }

  List<_ServiceSection> get _sections => [
    _ServiceSection(
      title: 'Shopping',
      items: const [
        _ServiceItem(
          'Brand Mall',
          Icons.storefront_outlined,
          Color(0xFFFF6B6B),
        ),
        _ServiceItem('Specials', Icons.local_offer_outlined, Color(0xFFE85D75)),
        _ServiceItem('Group Buying', Icons.groups_outlined, Color(0xFFF4A940)),
        _ServiceItem('Used Goods', Icons.recycling_outlined, Color(0xFFFF5A5F)),
      ],
    ),
    _ServiceSection(
      title: 'Food',
      items: const [
        _ServiceItem(
          'Restaurants',
          Icons.restaurant_outlined,
          Color(0xFFF4A940),
        ),
        _ServiceItem(
          'Food Delivery',
          Icons.delivery_dining_outlined,
          Color(0xFF2CB67D),
          destination: FoodScreen.new,
        ),
        _ServiceItem(
          'Groceries',
          Icons.local_grocery_store_outlined,
          Color(0xFF4A90E2),
        ),
      ],
    ),
    _ServiceSection(
      title: 'Entertainment',
      items: const [
        _ServiceItem(
          'Event Tickets',
          Icons.confirmation_number_outlined,
          Color(0xFFFF5A5F),
        ),
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
  final Widget Function()? destination;

  const _ServiceItem(this.label, this.icon, this.color, {this.destination});
}
