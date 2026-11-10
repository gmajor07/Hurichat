import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../connection/discovery_connection_screen.dart';

Widget buildDiscoveryScreen() => const ConnectionsDiscoveryScreen();

Route<void> buildDiscoveryRoute() => MaterialPageRoute<void>(
  builder: (_) => buildDiscoveryScreen(),
);

Widget? buildFAB({
  required int currentIndex,
  required Color themeColor,
  required BuildContext context,
}) {
  switch (currentIndex) {
    case 0:
      return FloatingActionButton(
        backgroundColor: themeColor,
        elevation: 4,
        tooltip: 'New Chat',
        onPressed: () {
          Navigator.push(context, buildDiscoveryRoute());
        },
        child: SvgPicture.asset(
          'assets/icon/chat.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      );
    case 5:
      return FloatingActionButton(
        backgroundColor: themeColor,
        elevation: 4,
        tooltip: 'Discover people',
        onPressed: () {
          Navigator.push(context, buildDiscoveryRoute());
        },
        child: const Icon(Icons.person_add_alt_1, color: Colors.white),
      );
    default:
      return null;
  }
}
