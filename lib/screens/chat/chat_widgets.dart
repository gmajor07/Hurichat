// lib/screens/chat/chat_widgets.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'chat_controller.dart';
import 'chat_theme.dart';

/// ─── Message bubble tile ──────────────────────────────────────────────────
class MessageTile extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback? onLongPress;
  final String? senderPhotoUrl;
  final String? receiverPhotoUrl;

  const MessageTile({
    super.key,
    required this.message,
    this.onLongPress,
    this.senderPhotoUrl,
    this.receiverPhotoUrl,
  });

  String _formatTimeFromMillis(int? ms) {
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'sending':
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white70),
        );
      case 'failed':
        return const Icon(Icons.error_outline_rounded, size: 13, color: Colors.white70);
      case 'sent':
        return const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = message['senderId'] == currentUid;
    final text = message['text'] ?? '';
    final status = message['status'] ?? 'sent';
    final timestamp =
        message['timestamp'] is int ? message['timestamp'] as int : null;
    final time = _formatTimeFromMillis(timestamp);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFailed = status == 'failed';

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Receiver avatar
            if (!isMe) ...[
              CircleAvatar(
                radius: 15,
                backgroundImage:
                    receiverPhotoUrl != null && receiverPhotoUrl!.isNotEmpty
                        ? NetworkImage(receiverPhotoUrl!)
                        : null,
                backgroundColor: Colors.grey.shade400,
                child: (receiverPhotoUrl == null || receiverPhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 15, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
            ],

            // Bubble + timestamp
            Flexible(
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe && !isFailed
                          ? LinearGradient(
                              colors: ChatTheme.getSenderGradient(context),
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isFailed
                          ? Colors.red.shade400
                          : (!isMe ? ChatTheme.getReceiverBubble(context) : null),
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
                              : Colors.black
                                  .withValues(alpha: isDark ? 0.25 : 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        color: isMe
                            ? Colors.white
                            : (isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        _statusIcon(status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.showEmojiPicker,
    required this.onToggleEmoji,
    required this.onSendPressed,
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

          // Text field
          Expanded(
            child: Container(
              constraints:
                  const BoxConstraints(minHeight: 46, maxHeight: 120),
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller.messageController,
                textInputAction: TextInputAction.newline,
                maxLines: null,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white.withValues(alpha: 0.87) : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                ),
                onSubmitted: (_) => onSendPressed(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Animated send / mic button
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.messageController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? onSendPressed : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasText
                          ? [ChatTheme.primary, ChatTheme.primaryDark]
                          : [Colors.grey.shade400, Colors.grey.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (hasText ? ChatTheme.primary : Colors.grey)
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
                      child: Icon(
                        hasText ? Icons.send_rounded : Icons.mic_rounded,
                        key: ValueKey(hasText),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ─── Small icon button ─────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

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
          final start =
              selection.start >= 0 ? selection.start : old.length;
          final end = selection.end >= 0 ? selection.end : old.length;
          final newText = old.replaceRange(start, end, emoji.emoji);
          textController.text = newText;
          final cursorPos = start + emoji.emoji.length;
          textController.selection =
              TextSelection.fromPosition(TextPosition(offset: cursorPos));
        },
        onBackspacePressed: () {
          final text = textController.text;
          if (text.isNotEmpty) {
            textController.text = text.characters.skipLast(1).toString();
            textController.selection = TextSelection.fromPosition(
                TextPosition(offset: textController.text.length));
          }
        },
      ),
    );
  }
}
