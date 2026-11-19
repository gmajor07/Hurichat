import 'package:flutter/material.dart';

class ChatTheme {
  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0E7C7B);
  static const Color primaryDark = Color(0xFF0C6665);
  static const Color accent = Color(0xFF149E9D);

  // ── Sender bubble gradients ────────────────────────────────────────
  static const List<Color> senderGradientLight = [
    Color(0xFF0E7C7B),
    Color(0xFF0C6665),
  ];
  static const List<Color> senderGradientDark = [
    Color(0xFF0D5C5B),
    Color(0xFF0C6665),
  ];

  // ── Receiver bubbles ───────────────────────────────────────────────
  static const Color receiverBubbleLight = Colors.white;
  static const Color receiverBubbleDark = Color(0xFF1E2A2E);

  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color chatBackgroundLight = Color(0xFFF7F9FA);
  static const Color chatBackgroundDark = Color(0xFF0B1116);
  static const Color cardSurfaceLight = Colors.white;
  static const Color cardSurfaceDark = Color(0xFF131B20);

  // ── Composer ─────────────────────────────────────────────────────────
  static const Color composerBackgroundLight = Colors.white;
  static const Color composerBackgroundDark = Color(0xFF131B20);

  // ── Helpers ────────────────────────────────────────────────────────
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color getChatBackground(BuildContext context) =>
      _isDark(context) ? chatBackgroundDark : chatBackgroundLight;

  static List<Color> getSenderGradient(BuildContext context) =>
      _isDark(context) ? senderGradientDark : senderGradientLight;

  static Color getReceiverBubble(BuildContext context) =>
      _isDark(context) ? receiverBubbleDark : receiverBubbleLight;

  static Color getCardSurface(BuildContext context) =>
      _isDark(context) ? cardSurfaceDark : cardSurfaceLight;

  static Color getDividerColor(BuildContext context) =>
      _isDark(context) ? Colors.white12 : Colors.black12;

  static Color getComposerBackground(BuildContext context) =>
      _isDark(context) ? composerBackgroundDark : composerBackgroundLight;

  static Color getComposerShadowColor(BuildContext context) => _isDark(context)
      ? Colors.black.withValues(alpha: 0.45)
      : Colors.black.withValues(alpha: 0.08);

  // ── Text colors ──────────────────────────────────────────────────────
  static Color getPrimaryText(BuildContext context) =>
      _isDark(context) ? Colors.white.withValues(alpha: 0.87) : Colors.black87;

  static Color getSecondaryText(BuildContext context) =>
      _isDark(context) ? Colors.white.withValues(alpha: 0.60) : Colors.black54;

  static Color getHintText(BuildContext context) => _isDark(context)
      ? Colors.white.withValues(alpha: 0.45)
      : Colors.grey.shade500;

  static Color getBodyText(BuildContext context, bool isMe) => isMe
      ? Colors.white
      : (_isDark(context)
            ? Colors.white.withValues(alpha: 0.90)
            : Colors.black87);

  static Color getTimeColor(BuildContext context, bool isMe) => isMe
      ? Colors.white70
      : (_isDark(context)
            ? Colors.white.withValues(alpha: 0.50)
            : Colors.black45);

  // ── Avatar placeholder ───────────────────────────────────────────────
  static Color getAvatarPlaceholderColor(BuildContext context) =>
      _isDark(context) ? Colors.white10 : Colors.grey.shade300;
}
