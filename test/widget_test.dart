import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/config/app_features.dart';
import 'package:huruchat/config/feature_routes.dart';
import 'package:huruchat/screens/home/home_bottom_nav.dart';
import 'package:huruchat/screens/huru/huru_screen.dart';
import 'package:huruchat/screens/profile/profile_actions.dart';

void main() {
  test(
    'functional messaging tabs are enabled; calls and commerce stay disabled',
    () {
      expect(AppFeatures.visibleNavigationIndices, [0, 5, 4]);
      for (final route in [
        '/calls',
        '/seller_screen',
        '/my_cart_food',
        '/my_shopping_cart',
        '/order_history',
        '/coupons',
        '/my_shopping_cart?source=link',
      ]) {
        expect(AppFeatures.canOpenRoute(route), isFalse, reason: route);
      }
      expect(AppFeatures.canOpenRoute('/account_profile'), isTrue);
      expect(AppFeatures.canOpenRoute('/home'), isTrue);
      expect(AppFeatures.canOpenRoute('/contacts'), isTrue);
      expect(AppFeatures.calls, isFalse);
    },
  );

  testWidgets('named routes and initial links never build disabled screens', (
    tester,
  ) async {
    var disabledBuilds = 0;
    final routes = guardFeatureRoutes({
      for (final name in [
        '/seller_screen',
        '/my_cart_food',
        '/my_shopping_cart',
        '/order_history',
      ])
        name: (_) {
          disabledBuilds++;
          return const Text('Disabled module');
        },
      '/account_profile': (_) => const Text('Profile route'),
    }, fallback: (_) => const Text('Messaging fallback'));
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/my_shopping_cart',
        routes: routes,
        home: const Text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Messaging fallback'), findsOneWidget);
    for (final name in ['/seller_screen', '/my_cart_food', '/order_history']) {
      Navigator.of(
        tester.element(find.text('Messaging fallback')),
      ).pushReplacementNamed(name);
      await tester.pumpAndSettle();
    }
    expect(disabledBuilds, 0);
    Navigator.of(
      tester.element(find.text('Messaging fallback')),
    ).pushNamed('/account_profile');
    await tester.pumpAndSettle();
    expect(find.text('Profile route'), findsOneWidget);
  });

  testWidgets(
    'existing bottom bar switches Chats, Contacts and Profile at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Text(switch (selected) {
                0 => 'Chat content',
                5 => 'Contacts content',
                _ => 'Profile content',
              }),
              bottomNavigationBar: buildBottomNavigationBar(
                context: context,
                currentIndex: selected,
                themeColor: const Color(0xFF4CAFAB),
                onTap: (index) => setState(() => selected = index),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Chat content'), findsOneWidget);
      expect(find.byType(InkWell), findsNWidgets(3));
      expect(find.bySemanticsLabel('Calls'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Contacts'));
      await tester.pumpAndSettle();
      expect(selected, 5);
      expect(find.text('Contacts content'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pumpAndSettle();
      expect(selected, 4);
      expect(find.text('Profile content'), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(selected, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile settings contain no disabled module shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HuruScreen()));
    expect(find.text('Profile Settings'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    for (final label in [
      'Services',
      'Food',
      'Transport',
      'Shopping Cart',
      'My Food Cart',
      'Seller Settings',
      'Seller Dashboard',
      'Coupons & Offers',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('account actions preserve update and logout, hide commerce', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileActions(
            onUpdateProfile: () {},
            onOrderHistory: () {},
            onSignOut: () {},
            onBecomeSeller: () {},
          ),
        ),
      ),
    );
    expect(find.text('Update Profile'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Order History'), findsNothing);
    expect(find.text('Become a Seller'), findsNothing);
  });
}
