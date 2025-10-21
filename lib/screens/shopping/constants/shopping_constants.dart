import 'package:flutter/material.dart';

class ShoppingConstants {
  static const double defaultPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;

  static const double cardBorderRadius = 12.0;
  static const double chipBorderRadius = 20.0;

  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color accentColor = Colors.redAccent;

  // Categories
  static const List<String> categories = [
    "All",
    "Women",
    "Men",
    "Bags",
    "Shoes",
    "Electronics",
    "Kitchen",
    "Grocery",
  ];

  // Section titles
  static const String topDealsTitle = "Top Deals";
  static const String groceryKitchenTitle = "Grocery and Kitchen";
  static const String viewMoreTitle = "View More";
  static const String seeMoreText = "See More";
}
