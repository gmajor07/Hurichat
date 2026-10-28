/// Product visibility only; backend authorization remains unchanged.
abstract final class AppFeatures {
  static const messaging = true;
  static const contacts = true;
  // No calling implementation or history exists yet; preserve chat buttons.
  static const calls = false;
  static const services = false;
  static const shopping = false;
  static const discover = false;
  static const profile = true;

  // Original indices are retained for screen, icon, app bar and FAB selection.
  static List<int> get visibleNavigationIndices => [
    if (messaging) 0,
    if (contacts) 5,
    if (services) 1,
    if (shopping) 2,
    if (discover) 3,
    if (profile) 4,
  ];

  static bool get commerce => services || shopping;

  static bool canOpenRoute(String route) => switch (Uri.parse(route).path) {
    '/contacts' => contacts,
    '/calls' => calls,
    '/my_cart_food' => services,
    '/my_shopping_cart' => shopping,
    '/seller_screen' || '/order_history' || '/coupons' => commerce,
    _ => true,
  };
}
