import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_theme.dart';
import 'shared_media_screen.dart';

class ConversationInfoScreen extends StatelessWidget {
  final String chatId;
  final String participantId;
  final Stream<Map<String, dynamic>?>? profileStream;
  final VoidCallback? onOpenSharedMedia;

  const ConversationInfoScreen({
    super.key,
    required this.chatId,
    required this.participantId,
    this.profileStream,
    this.onOpenSharedMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ChatTheme.getChatBackground(context),
        foregroundColor: ChatTheme.getPrimaryText(context),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream:
            profileStream ??
            FirebaseFirestore.instance
                .collection('users')
                .doc(participantId)
                .snapshots()
                .map((snapshot) => snapshot.exists ? snapshot.data() : null),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ConversationInfoUnavailable(
              message: 'Profile information is unavailable.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const ConversationInfoUnavailable(
              message: 'This profile is no longer available.',
            );
          }

          return ConversationInfoContent(
            chatId: chatId,
            profile: snapshot.data!,
            onOpenSharedMedia: onOpenSharedMedia,
          );
        },
      ),
    );
  }
}

class ConversationInfoContent extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> profile;
  final VoidCallback? onOpenSharedMedia;

  const ConversationInfoContent({
    super.key,
    required this.chatId,
    required this.profile,
    this.onOpenSharedMedia,
  });

  String _availableString(String key, {String fallback = 'Unavailable'}) {
    final value = profile[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  String _formatName(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  bool get _isOnline => const {
    'online',
    'active',
    'available',
  }.contains(_availableString('status', fallback: '').toLowerCase());

  Future<void> _callPhone(BuildContext context, String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return;

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app.')),
        );
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Failed to open phone app: $error\n$stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone app.')),
        );
      }
    }
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _infoCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _formatName(
      _availableString('name', fallback: 'Unknown user'),
    );
    final photoUrl = _availableString('photoUrl', fallback: '');
    final phone = _availableString('phone', fallback: '');
    final isOnline = _isOnline;

    final fields = <({String label, String key, IconData icon, Color color})>[
      (
        label: 'Phone',
        key: 'phone',
        icon: Icons.phone_iphone_outlined,
        color: const Color(0xFFF2B705),
      ),
      (
        label: 'Email',
        key: 'email',
        icon: Icons.email_outlined,
        color: const Color(0xFF4CAFaa),
      ),
      (
        label: 'Location',
        key: 'location',
        icon: Icons.location_on_outlined,
        color: const Color(0xFF9CCC65),
      ),
      (
        label: 'Gender',
        key: 'gender',
        icon: Icons.transgender,
        color: const Color(0xFFBA68C8),
      ),
      (
        label: 'Age',
        key: 'age',
        icon: Icons.cake_outlined,
        color: const Color(0xFFEF5350),
      ),
      (
        label: 'Bio',
        key: 'bio',
        icon: Icons.description_outlined,
        color: const Color(0xFF5C6BC0),
      ),
    ];

    final infoCards = <Widget>[];
    for (final field in fields) {
      final value = _availableString(field.key, fallback: '');
      if (value.isEmpty) continue;
      infoCards.add(
        _infoCard(
          context: context,
          isDark: isDark,
          icon: field.icon,
          iconColor: field.color,
          label: field.label,
          value: value,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                backgroundImage: photoUrl.isEmpty
                    ? null
                    : NetworkImage(photoUrl),
                child: photoUrl.isEmpty
                    ? const Icon(Icons.person, size: 52)
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                key: const ValueKey('conversation-info-status'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOnline) ...[
                    Container(
                      key: const ValueKey('conversation-info-online-indicator'),
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 13,
                      color: isOnline
                          ? const Color(0xFF22C55E)
                          : (isDark ? Colors.white60 : Colors.black54),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('conversation-info-call'),
                      onPressed: phone.isEmpty
                          ? null
                          : () => _callPhone(context, phone),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Call'),
                      style: FilledButton.styleFrom(
                        backgroundColor: ChatTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('conversation-info-message'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ChatTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeader(context, 'Conversation'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('conversation-info-shared-media'),
          onPressed:
              onOpenSharedMedia ??
              () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SharedMediaScreen(chatId: chatId),
                ),
              ),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Shared Media'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: ChatTheme.primary,
            side: BorderSide(color: ChatTheme.primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (infoCards.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionHeader(context, 'Profile info'),
          const SizedBox(height: 12),
          ...infoCards,
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class ConversationInfoUnavailable extends StatelessWidget {
  final String message;

  const ConversationInfoUnavailable({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
