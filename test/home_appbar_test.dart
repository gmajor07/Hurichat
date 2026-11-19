import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huruchat/screens/home/home_appbar.dart';

void main() {
  testWidgets('home menu excludes Scan and Money options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: buildHomeAppBar(
              context: context,
              themeColor: const Color(0xFF4CAFAB),
              onSelectMenu: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Connection Requests'), findsOneWidget);
    expect(find.text('Add Contacts'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Scan'), findsNothing);
    expect(find.text('Money'), findsNothing);
  });
}
