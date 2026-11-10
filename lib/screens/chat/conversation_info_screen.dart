import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../user_account/receiver_details_screen.dart';
import 'shared_media_screen.dart';

class ConversationInfoScreen extends StatelessWidget {
  final String chatId;
  final String participantId;
  final Stream<Map<String, dynamic>?>? profileStream;
  final VoidCallback? onOpenSharedMedia;
  final VoidCallback? onViewProfile;

  const ConversationInfoScreen({
    super.key,
    required this.chatId,
    required this.participantId,
    this.profileStream,
    this.onOpenSharedMedia,
    this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conversation info')),
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
            participantId: participantId,
            profile: snapshot.data!,
            onOpenSharedMedia: onOpenSharedMedia,
            onViewProfile: onViewProfile,
          );
        },
      ),
    );
  }
}

class ConversationInfoContent extends StatelessWidget {
  final String chatId;
  final String participantId;
  final Map<String, dynamic> profile;
  final VoidCallback? onOpenSharedMedia;
  final VoidCallback? onViewProfile;

  const ConversationInfoContent({
    super.key,
    required this.chatId,
    required this.participantId,
    required this.profile,
    this.onOpenSharedMedia,
    this.onViewProfile,
  });

  String _availableString(String key, {String fallback = 'Unavailable'}) {
    final value = profile[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num) return value.toString();
    return fallback;
  }

  String _presenceLabel() {
    final status = _availableString('status', fallback: '');
    final normalizedStatus = status.toLowerCase();
    final isOnline = const {
      'online',
      'active',
      'available',
    }.contains(normalizedStatus);
    if (isOnline) return 'Online';

    final lastSeen = _formatLastSeen(profile['lastSeen']);
    if (lastSeen == null) return 'Offline · last seen unavailable';
    return 'Offline · last seen $lastSeen';
  }

  String? _formatLastSeen(Object? value) {
    final date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      _ => null,
    };
    if (date == null) return null;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final name = _availableString('name', fallback: 'Unknown user');
    final photoUrl = _availableString('photoUrl', fallback: '');
    final fields = <({String label, String key})>[
      (label: 'Phone', key: 'phone'),
      (label: 'Email', key: 'email'),
      (label: 'Location', key: 'location'),
      (label: 'Gender', key: 'gender'),
      (label: 'Age', key: 'age'),
      (label: 'Bio', key: 'bio'),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
            child: photoUrl.isEmpty ? const Icon(Icons.person, size: 48) : null,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            _presenceLabel(),
            key: const ValueKey('conversation-info-presence'),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          key: const ValueKey('conversation-info-shared-media'),
          onPressed:
              onOpenSharedMedia ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SharedMediaScreen(chatId: chatId),
                ),
              ),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Shared Media'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('conversation-info-view-profile'),
          onPressed:
              onViewProfile ??
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceiverDetailsScreen(userId: participantId),
                ),
              ),
          icon: const Icon(Icons.person_outline),
          label: const Text('View Profile'),
        ),
        const SizedBox(height: 20),
        for (final field in fields)
          if (_availableString(field.key, fallback: '').isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(field.label),
              subtitle: Text(_availableString(field.key)),
            ),
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
