import 'package:flutter/material.dart';

class ChatTheme {
  static const Color primary = Color(0xFF497A72); // match login/register button
  static const Color accent = Color(0xFF60A89B); // lighter variant

  static Color getBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF121212)
      : Colors.grey.shade50;

  static Color getBubbleColor(BuildContext context, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isMe) {
      // Sender (current user) bubble color
      return isDark ? const Color(0xFF60A89B) : primary;
    } else {
      // Receiver bubble color
      return isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade200;
    }
  }

  static Color getTextColor(bool isMe) {
    return isMe ? Colors.white : Colors.black87;
  }

  static Color getTimeColor(bool isMe) {
    return isMe ? Colors.white70 : Colors.black45;
  }
}
