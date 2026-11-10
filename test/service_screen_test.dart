import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/service_screen.dart';

void main() {
  testWidgets('shows only Shopping, Food, and Entertainment categories', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ServiceScreen()));

    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Entertainment'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);
    expect(find.text('Financial Services'), findsNothing);
    expect(find.text('Daily Services'), findsNothing);
  });
}
