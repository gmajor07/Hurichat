import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/config/app_features.dart';
import 'package:huruchat/screens/status_screen.dart';

void main() {
  test('home navigation exposes the requested five destinations in order', () {
    expect(AppFeatures.visibleNavigationIndices, [0, 6, 1, 5, 4]);
  });

  testWidgets('status shows an empty placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StatusScreen()));

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('No status updates yet'), findsOneWidget);
  });
}
