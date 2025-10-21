import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'advanced_search_bar.dart';

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            AdvancedSearchBar(
              hintText: "Where are you going? || Enter your route",
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
              autoFocus: false,
            ),
            const SizedBox(height: 20),

            // Category title
            Text(
              "Choose Transport",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // Transport options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCategoryCard(
                  'Taxi',
                  'assets/images/taxi.png',
                  colorScheme,
                ),
                _buildCategoryCard(
                  'Boda',
                  'assets/images/boda.png',
                  colorScheme,
                ),
                _buildCategoryCard(
                  'Bajaji',
                  'assets/images/bajaji.png',
                  colorScheme,
                ),
                _buildCategoryCard('VIP', 'assets/images/vip.png', colorScheme),
              ],
            ),

            const SizedBox(height: 25),

            // Let’s Go Section
            Text(
              "Let's Go",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // Featured ride
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.primary, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Image.asset(
                    'assets/images/boda_promo.png',
                    fit: BoxFit.cover,
                    height: 180,
                    width: double.infinity,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.surface,
                        foregroundColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text("Bodaboda →"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    String imagePath,
    ColorScheme scheme,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.asset(
                imagePath,
                height: 55,
                width: 55,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
