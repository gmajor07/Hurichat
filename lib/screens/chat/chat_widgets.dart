// lib/screens/chat/chat_widgets.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'chat_controller.dart';

/// Message bubble tile (reusable)
class MessageTile extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback? onLongPress;

  const MessageTile({super.key, required this.message, this.onLongPress});

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
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        );
      case 'failed':
        return const Icon(Icons.error_outline, size: 12, color: Colors.white);
      case 'sent':
        return const Icon(Icons.done_all, size: 12, color: Colors.white70);
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
    final timestamp = message['timestamp'] is int
        ? message['timestamp'] as int
        : null;
    final time = _formatTimeFromMillis(timestamp);

    final sentColor = Theme.of(context).brightness == Brightness.dark
        ? const Color.fromARGB(255, 8, 107, 138)
        : Colors.blue.shade500;
    final failedColor = Colors.redAccent.shade400;
    final receivedColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : Colors.grey.shade200;

    final bubbleColor = isMe
        ? (status == 'failed' ? failedColor : sentColor)
        : receivedColor;
    final textColor = isMe
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : Colors.black87);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe)
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade400,
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                if (!isMe) const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMe
                            ? const Radius.circular(18)
                            : const Radius.circular(6),
                        bottomRight: isMe
                            ? const Radius.circular(6)
                            : const Radius.circular(18),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(
                left: isMe ? 0 : 48,
                right: isMe ? 48 : 0,
                top: 6,
              ),
              child: Row(
                mainAxisAlignment: isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMe ? Colors.blue.shade200 : Colors.grey.shade600,
                    ),
                  ),
                  if (isMe) const SizedBox(width: 6),
                  if (isMe) _statusIcon(status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Input bar used at the bottom of the chat (emoji toggle + text field + send)
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
    final fieldBg = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[850]
        : Colors.white;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? Colors.tealAccent
        : const Color(0xFF4CAFAB);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.orangeAccent
                  : Colors.orange,
            ),
            onPressed: onToggleEmoji,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: fieldBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller.messageController,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => onSendPressed(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSendPressed,
            child: Container(
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.25),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.send, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emoji picker widget (wraps emoji_picker_flutter)
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
            // basic removal of last character
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
