// lib/screens/chat/chat_widgets.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'chat_controller.dart';
import 'chat_theme.dart';
import 'message_read_state.dart';
import 'voice_message_logic.dart';
import 'reply_message.dart';
import 'message_reactions.dart';

class MessageEditBanner extends StatelessWidget {
  final VoidCallback onCancel;

  const MessageEditBanner({super.key, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Editing message', style: TextStyle(fontSize: 13)),
          ),
          IconButton(
            tooltip: 'Cancel edit',
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class PinnedMessageBanner extends StatelessWidget {
  final String preview;
  final VoidCallback onTap;

  const PinnedMessageBanner({
    super.key,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        key: const ValueKey('pinned-message-banner'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Icon(
                Icons.push_pin_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pinned message',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class ReplyMessagePreview extends StatelessWidget {
  final String text;
  final String type;
  final bool isOutgoing;
  final bool isComposer;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const ReplyMessagePreview({
    super.key,
    required this.text,
    required this.type,
    this.isOutgoing = false,
    this.isComposer = false,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOutgoing
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isComposer
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.black.withValues(alpha: isOutgoing ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            switch (type) {
              'image' => Icons.image_outlined,
              'voice' => Icons.mic_none_rounded,
              _ => Icons.reply_rounded,
            },
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isComposer ? 'Replying to' : 'Reply',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isComposer
                        ? Theme.of(context).colorScheme.onSurface
                        : (isOutgoing ? Colors.white : Colors.black87),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              tooltip: 'Cancel reply',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              onPressed: onCancel,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isComposer ? 0 : 8),
      child: GestureDetector(onTap: onTap, child: content),
    );
  }
}

/// ─── Message bubble tile ──────────────────────────────────────────────────
class MessageTile extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset>? onTextLongPressStart;
  final String? senderPhotoUrl;
  final String? receiverPhotoUrl;
  final bool isHighlighted;
  final String? currentUserId;
  final ValueChanged<String>? onReplyTap;
  final ValueChanged<String>? onReactionTap;

  const MessageTile({
    super.key,
    required this.message,
    this.onLongPress,
    this.onTextLongPressStart,
    this.senderPhotoUrl,
    this.receiverPhotoUrl,
    this.isHighlighted = false,
    this.currentUserId,
    this.onReplyTap,
    this.onReactionTap,
  });

  String _formatTimeFromMillis(int? ms) {
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _statusIcon(String status, {required bool isRead}) {
    switch (status) {
      case 'sending':
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: Colors.white70,
          ),
        );
      case 'failed':
        return const Icon(
          Icons.error_outline_rounded,
          size: 13,
          color: Colors.white70,
        );
      case 'sent':
        return Tooltip(
          message: isRead ? 'Read' : 'Sent',
          child: Icon(
            Icons.done_all_rounded,
            size: 13,
            color: isRead ? Colors.lightBlueAccent : Colors.white70,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = currentUserId ?? FirebaseAuth.instance.currentUser?.uid;
    final isMe = message['senderId'] == currentUid;
    final text = message['text'] ?? '';
    final status = message['status'] ?? 'sent';
    final timestamp = message['timestamp'] is int
        ? message['timestamp'] as int
        : null;
    final time = timestamp == null || timestamp <= 0
        ? ''
        : _formatTimeFromMillis(timestamp);
    final isRead = hasReadReceipt(message);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFailed = status == 'failed';
    final reactions = normalizeMessageReactions(message['reactions']);
    final reactionCounts = countMessageReactions(message['reactions']);

    return GestureDetector(
      onLongPress: onLongPress,
      onLongPressStart: (details) {
        final type = message['type'];
        if ((type == null || type == 'text') && message['text'] is String) {
          onTextLongPressStart?.call(details.globalPosition);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxBubbleWidth = constraints.maxWidth * 0.7;
            return Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  CircleAvatar(
                    radius: 15,
                    backgroundImage:
                        receiverPhotoUrl != null && receiverPhotoUrl!.isNotEmpty
                        ? NetworkImage(receiverPhotoUrl!)
                        : null,
                    backgroundColor: Colors.grey.shade400,
                    child:
                        (receiverPhotoUrl == null || receiverPhotoUrl!.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 15,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Container(
                          key: const ValueKey('message-bubble'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isMe && !isFailed
                                ? LinearGradient(
                                    colors: ChatTheme.getSenderGradient(
                                      context,
                                    ),
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isFailed
                                ? Colors.red.shade400
                                : (!isMe
                                      ? ChatTheme.getReceiverBubble(context)
                                      : null),
                            border: isHighlighted
                                ? Border.all(color: ChatTheme.primary, width: 2)
                                : null,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isMe
                                    ? ChatTheme.primary.withValues(alpha: 0.28)
                                    : Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.07,
                                      ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message['isForwarded'] == true)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    'Forwarded',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              if (hasReplyMetadata(message))
                                ReplyMessagePreview(
                                  text: replyPreviewText(message),
                                  type: replyPreviewType(message),
                                  isOutgoing: isMe,
                                  onTap:
                                      message[replyToMessageIdField] is String
                                      ? () => onReplyTap?.call(
                                          message[replyToMessageIdField]
                                              as String,
                                        )
                                      : null,
                                ),
                              switch (message['type']) {
                                'image' => _buildImageContent(
                                  message['imageUrl'],
                                ),
                                'voice' => VoiceMessagePlayer(
                                  audioUrl:
                                      message['audioUrl'] as String? ?? '',
                                  duration: Duration(
                                    milliseconds:
                                        message['durationMillis'] is int
                                        ? message['durationMillis'] as int
                                        : 0,
                                  ),
                                  isOutgoing: isMe,
                                ),
                                _ => Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                    color: isMe
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.87,
                                                )
                                              : Colors.black87),
                                  ),
                                ),
                              },
                            ],
                          ),
                        ),
                        if (reactionCounts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final entry in reactionCounts.entries)
                                  _ReactionCountChip(
                                    emoji: entry.key,
                                    count: entry.value,
                                    isSelected:
                                        reactions[currentUid] == entry.key,
                                    onTap: onReactionTap == null
                                        ? null
                                        : () => onReactionTap!(entry.key),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (message['editedAt'] != null) ...[
                              const Text(
                                'Edited',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              _statusIcon(status, isRead: isRead),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageContent(dynamic imageUrl) {
    final parsedUrl = imageUrl is String ? Uri.tryParse(imageUrl) : null;
    if (parsedUrl == null ||
        !parsedUrl.hasScheme ||
        (parsedUrl.scheme != 'http' && parsedUrl.scheme != 'https')) {
      return const SizedBox(
        width: 220,
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined),
              SizedBox(height: 4),
              Text('Image unavailable'),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 220,
        height: 220,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined),
                SizedBox(height: 4),
                Text('Image unavailable'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionCountChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ReactionCountChip({
    required this.emoji,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.16)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showMessageReactionPicker(
  BuildContext context, {
  required ValueChanged<String> onSelected,
}) async {
  final emoji = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'React with',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final reaction in messageReactionEmojis)
                  IconButton(
                    key: ValueKey('reaction-picker-$reaction'),
                    tooltip: reaction,
                    onPressed: () => Navigator.pop(context, reaction),
                    icon: Text(reaction, style: const TextStyle(fontSize: 24)),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (emoji != null && context.mounted) onSelected(emoji);
}

Future<void> showTextMessageCopyMenu(
  BuildContext context, {
  required Offset globalPosition,
  required String text,
  VoidCallback? onReply,
  VoidCallback? onReact,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onForward,
  VoidCallback? onPin,
  String pinActionLabel = 'Pin Message',
}) async {
  final screenSize = MediaQuery.sizeOf(context);
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      screenSize.width - globalPosition.dx,
      screenSize.height - globalPosition.dy,
    ),
    items: [
      const PopupMenuItem<String>(
        value: 'copy',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy_rounded, size: 18),
            SizedBox(width: 10),
            Text('Copy Message'),
          ],
        ),
      ),
      if (onReply != null)
        const PopupMenuItem<String>(
          value: 'reply',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.reply_rounded, size: 18),
              SizedBox(width: 10),
              Text('Reply'),
            ],
          ),
        ),
      if (onReact != null)
        const PopupMenuItem<String>(
          value: 'react',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_reaction_outlined, size: 18),
              SizedBox(width: 10),
              Text('React'),
            ],
          ),
        ),
      if (onEdit != null)
        const PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 10),
              Text('Edit'),
            ],
          ),
        ),
      if (onDelete != null)
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, size: 18),
              SizedBox(width: 10),
              Text('Delete'),
            ],
          ),
        ),
      if (onForward != null)
        const PopupMenuItem<String>(
          value: 'forward',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forward_rounded, size: 18),
              SizedBox(width: 10),
              Text('Forward'),
            ],
          ),
        ),
      if (onPin != null)
        PopupMenuItem<String>(
          value: 'pin',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.push_pin_outlined, size: 18),
              const SizedBox(width: 10),
              Text(pinActionLabel),
            ],
          ),
        ),
    ],
  );
  if (action == 'react' && context.mounted) {
    onReact?.call();
    return;
  }
  if (action == 'reply' && context.mounted) {
    onReply?.call();
    return;
  }
  if (action == 'edit' && context.mounted) {
    onEdit?.call();
    return;
  }
  if (action == 'delete' && context.mounted) {
    onDelete?.call();
    return;
  }
  if (action == 'forward' && context.mounted) {
    onForward?.call();
    return;
  }
  if (action == 'pin' && context.mounted) {
    onPin?.call();
    return;
  }
  if (action != 'copy' || !context.mounted) return;

  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('Message copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

Future<bool> confirmMessageDeletion(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete message?'),
      content: const Text(
        'This message will be removed from the conversation.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final Duration duration;
  final bool isOutgoing;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isOutgoing,
  });

  static Future<void> stopActivePlayback() =>
      _VoiceMessagePlayerState.stopActivePlayback();

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  static _VoiceMessagePlayerState? _activePlayerState;
  static int _playbackRequest = 0;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isLoading = false;
  bool _isPlaying = false;
  String? _error;
  int _playbackGeneration = 0;

  static Future<void> stopActivePlayback() async {
    final activeState = _activePlayerState;
    if (activeState == null) return;
    _playbackRequest++;
    _activePlayerState = null;
    await activeState._stopPlayer();
  }

  Future<void> _togglePlayback() async {
    final player = _player;
    if (player != null && _isPlaying) {
      try {
        await player.pause();
      } catch (error, stackTrace) {
        debugPrint('Could not pause voice playback: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _error = 'Could not play voice message';
          });
        }
      }
      return;
    }
    if (_isLoading) return;

    final uri = Uri.tryParse(widget.audioUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _error = 'Voice message unavailable');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    final request = ++_playbackRequest;
    final generation = ++_playbackGeneration;
    final previousState = _activePlayerState;
    _activePlayerState = this;
    try {
      if (previousState != null && previousState != this) {
        await previousState._stopPlayer();
      }
      if (!_isCurrentPlayback(request, generation)) return;

      final nextPlayer = _player ??= AudioPlayer();
      _playerStateSubscription ??= nextPlayer.playerStateStream.listen(
        (state) {
          if (!mounted) return;
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
            }
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Voice playback state failed: $error\n$stackTrace');
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _error = 'Could not play voice message';
            });
          }
        },
      );
      await nextPlayer.setUrl(widget.audioUrl);
      if (!_isCurrentPlayback(request, generation)) return;
      setState(() => _isPlaying = true);
      unawaited(
        nextPlayer.play().catchError((Object error, StackTrace stackTrace) {
          debugPrint('Voice playback failed: $error\n$stackTrace');
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _error = 'Could not play voice message';
            });
          }
        }),
      );
    } catch (error, stackTrace) {
      debugPrint('Could not start voice playback: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _error = 'Could not play voice message';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCurrentPlayback(int request, int generation) {
    return mounted &&
        request == _playbackRequest &&
        generation == _playbackGeneration &&
        identical(_activePlayerState, this);
  }

  Future<void> _stopPlayer() async {
    _playbackGeneration++;
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (error, stackTrace) {
        debugPrint('Could not stop voice playback: $error\n$stackTrace');
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });
    }
  }

  @override
  void dispose() {
    if (identical(_activePlayerState, this)) {
      _activePlayerState = null;
      _playbackRequest++;
    }
    _playerStateSubscription?.cancel();
    final player = _player;
    if (player != null) {
      unawaited(_disposePlayer(player));
    }
    super.dispose();
  }

  Future<void> _disposePlayer(AudioPlayer player) async {
    try {
      await player.stop();
      await player.dispose();
    } catch (error, stackTrace) {
      debugPrint('Could not dispose voice playback: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.isOutgoing
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 184,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: _isPlaying ? 'Pause voice message' : 'Play voice message',
            onPressed: _isLoading ? null : _togglePlayback,
            icon: _isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: foreground,
                  ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatVoiceDuration(widget.duration),
                  style: TextStyle(color: foreground, fontSize: 13),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: widget.isOutgoing
                          ? Colors.white70
                          : Theme.of(context).colorScheme.error,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Chat input bar ────────────────────────────────────────────────────────
class ChatInputBar extends StatelessWidget {
  final ChatController controller;
  final bool showEmojiPicker;
  final VoidCallback onToggleEmoji;
  final VoidCallback onSendPressed;
  final VoidCallback onAttachImage;
  final bool isPickingImage;
  final bool isEditingMessage;
  final bool isSavingEdit;
  final VoiceRecordingState voiceRecordingState;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final ValueChanged<String>? onTextChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.showEmojiPicker,
    required this.onToggleEmoji,
    required this.onSendPressed,
    required this.onAttachImage,
    required this.voiceRecordingState,
    required this.onStartRecording,
    required this.onStopRecording,
    this.onTextChanged,
    this.isPickingImage = false,
    this.isEditingMessage = false,
    this.isSavingEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Emoji toggle
          _IconBtn(
            icon: showEmojiPicker
                ? Icons.keyboard_rounded
                : Icons.emoji_emotions_outlined,
            color: showEmojiPicker
                ? ChatTheme.primary
                : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            onTap: onToggleEmoji,
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: Listenable.merge([
              controller.sendGuard,
              voiceRecordingState,
            ]),
            builder: (context, _) => _IconBtn(
              icon: Icons.attach_file_rounded,
              color:
                  controller.sendGuard.isSending ||
                      isPickingImage ||
                      isEditingMessage ||
                      voiceRecordingState.status != VoiceRecordingStatus.idle
                  ? Colors.grey.shade500
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              onTap:
                  controller.sendGuard.isSending ||
                      isPickingImage ||
                      isEditingMessage ||
                      voiceRecordingState.status != VoiceRecordingStatus.idle
                  ? null
                  : onAttachImage,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: Listenable.merge([
              voiceRecordingState,
              controller.sendGuard,
            ]),
            builder: (context, _) => _IconBtn(
              icon: voiceRecordingState.isRecording
                  ? Icons.stop_circle_rounded
                  : Icons.mic_none_rounded,
              color:
                  voiceRecordingState.status ==
                          VoiceRecordingStatus.uploading ||
                      voiceRecordingState.status ==
                          VoiceRecordingStatus.finalizing ||
                      controller.sendGuard.isSending ||
                      isPickingImage ||
                      isEditingMessage
                  ? Colors.grey.shade500
                  : voiceRecordingState.isRecording
                  ? Colors.red.shade400
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              onTap: switch (voiceRecordingState.status) {
                VoiceRecordingStatus.idle
                    when !controller.sendGuard.isSending &&
                        !isPickingImage &&
                        !isEditingMessage =>
                  onStartRecording,
                VoiceRecordingStatus.recording => onStopRecording,
                _ => null,
              },
            ),
          ),
          const SizedBox(width: 4),

          // Text field
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                controller.sendGuard,
                voiceRecordingState,
              ]),
              builder: (context, _) => MessageTextField(
                controller: controller.messageController,
                enabled:
                    !controller.sendGuard.isSending &&
                    !isSavingEdit &&
                    voiceRecordingState.status == VoiceRecordingStatus.idle,
                onSubmitted: (_) => onSendPressed(),
                onChanged: onTextChanged,
                backgroundColor: fieldBg,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Animated send button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return AnimatedBuilder(
                animation: Listenable.merge([
                  controller.sendGuard,
                  voiceRecordingState,
                ]),
                builder: (context, _) {
                  final isSending =
                      controller.sendGuard.isSending || isSavingEdit;
                  final isBusy =
                      voiceRecordingState.status ==
                          VoiceRecordingStatus.finalizing ||
                      voiceRecordingState.status ==
                          VoiceRecordingStatus.uploading;
                  final voiceIsIdle =
                      voiceRecordingState.status == VoiceRecordingStatus.idle;
                  return GestureDetector(
                    onTap: hasText && !isSending && voiceIsIdle
                        ? onSendPressed
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: hasText && !isSending && voiceIsIdle
                              ? [ChatTheme.primary, ChatTheme.primaryDark]
                              : [Colors.grey.shade400, Colors.grey.shade500],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                (hasText && !isSending && voiceIsIdle
                                        ? ChatTheme.primary
                                        : Colors.grey)
                                    .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: isSending || isBusy
                              ? const SizedBox(
                                  key: ValueKey('sending'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  key: ValueKey(hasText),
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class MessageTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final Color backgroundColor;

  const MessageTextField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
    required this.backgroundColor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.newline,
        maxLines: null,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Message...',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

/// ─── Small icon button ─────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

/// ─── Emoji picker ──────────────────────────────────────────────────────────
class ChatEmojiPicker extends StatelessWidget {
  final TextEditingController textController;

  const ChatEmojiPicker({super.key, required this.textController});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          final old = textController.text;
          final selection = textController.selection;
          final start = selection.start >= 0 ? selection.start : old.length;
          final end = selection.end >= 0 ? selection.end : old.length;
          final newText = old.replaceRange(start, end, emoji.emoji);
          textController.text = newText;
          final cursorPos = start + emoji.emoji.length;
          textController.selection = TextSelection.fromPosition(
            TextPosition(offset: cursorPos),
          );
        },
        onBackspacePressed: () {
          final text = textController.text;
          if (text.isNotEmpty) {
            textController.text = text.characters.skipLast(1).toString();
            textController.selection = TextSelection.fromPosition(
              TextPosition(offset: textController.text.length),
            );
          }
        },
      ),
    );
  }
}
