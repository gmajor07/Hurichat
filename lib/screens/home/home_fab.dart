import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../connection/discovery_connection_screen.dart';

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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ConnectionsDiscoveryScreen(),
            ),
          );
        },
        child: SvgPicture.asset(
          'assets/icon/chat.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      );
    default:
      return null;
  }
}
