import 'package:flutter/material.dart';

class ChatTheme {
  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF4CAFaa);
  static const Color primaryDark = Color(0xFF3D8A84);
  static const Color accent      = Color(0xFF60A89B);

  // ── Sender bubble gradients ────────────────────────────────────────
  static const List<Color> senderGradientLight = [
    Color(0xFF4CAFaa),
    Color(0xFF3D8A84),
  ];
  static const List<Color> senderGradientDark = [
    Color(0xFF5ABEB7),
    Color(0xFF2E7D68),
  ];

  // ── Receiver bubbles ───────────────────────────────────────────────
  static const Color receiverBubbleLight = Colors.white;
  static const Color receiverBubbleDark  = Color(0xFF2A2A2A);

  // ── Helpers ────────────────────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF0F1115) : const Color(0xFFF0F8F7);

  static List<Color> getSenderGradient(BuildContext context) =>
      _isDark(context) ? senderGradientDark : senderGradientLight;

  static Color getReceiverBubble(BuildContext context) =>
      _isDark(context) ? receiverBubbleDark : receiverBubbleLight;

  static Color getBubbleColor(BuildContext context, bool isMe) =>
      isMe ? primary : getReceiverBubble(context);

  static Color getTextColor(bool isMe) =>
      isMe ? Colors.white : Colors.black87;

  static Color getTimeColor(bool isMe) =>
      isMe ? Colors.white70 : Colors.black45;
}
