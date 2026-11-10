import 'package:flutter/material.dart';

const double latestMessageDistanceThreshold = 80;

bool isNearLatestMessage(
  double pixels,
  double maxScrollExtent, {
  double threshold = latestMessageDistanceThreshold,
}) {
  return maxScrollExtent - pixels <= threshold;
}

bool shouldFollowLatestMessages({
  required bool isInitialSnapshot,
  required bool hasAddedMessages,
  required bool wasNearLatest,
}) {
  return !isInitialSnapshot && hasAddedMessages && wasNearLatest;
}

Future<void> jumpConversationToLatest(ScrollController scrollController) async {
  if (!scrollController.hasClients) return;
  await scrollController.animateTo(
    scrollController.position.maxScrollExtent,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );
}

class ConversationLatestMessages extends ChangeNotifier {
  final Set<String> _newIncomingMessageIds = {};
  bool _isNearLatest = true;
  bool _initialMessagesLoaded = false;
  bool _disposed = false;

  bool get isNearLatest => _isNearLatest;
  int get newMessageCount => _newIncomingMessageIds.length;
  bool get shouldShowButton => !_isNearLatest;
  bool get shouldShowNewMessageIndicator => newMessageCount > 0;

  void markInitialMessagesLoaded() {
    if (_initialMessagesLoaded || _disposed) return;
    _initialMessagesLoaded = true;
  }

  void updateScrollPosition({
    required double pixels,
    required double maxScrollExtent,
  }) {
    if (_disposed) return;
    final isNearLatest = isNearLatestMessage(pixels, maxScrollExtent);
    final changed = isNearLatest != _isNearLatest;
    final hadNewMessages = _newIncomingMessageIds.isNotEmpty;
    _isNearLatest = isNearLatest;
    if (isNearLatest) _newIncomingMessageIds.clear();
    if (changed || (isNearLatest && hadNewMessages)) notifyListeners();
  }

  void recordIncomingMessages(
    Iterable<MapEntry<String, String>> messageSenderIds, {
    required String? currentUserId,
  }) {
    if (_disposed || !_initialMessagesLoaded || _isNearLatest) return;
    final previousCount = _newIncomingMessageIds.length;
    _newIncomingMessageIds.addAll(
      messageSenderIds
          .where(
            (message) =>
                message.key.isNotEmpty && message.value != currentUserId,
          )
          .map((message) => message.key),
    );
    if (_newIncomingMessageIds.length != previousCount) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _newIncomingMessageIds.clear();
    super.dispose();
  }
}

class ConversationJumpToLatestButton extends StatelessWidget {
  final int newMessageCount;
  final VoidCallback onPressed;

  const ConversationJumpToLatestButton({
    super.key,
    required this.newMessageCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (newMessageCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Text(
                  newMessageCount == 1
                      ? '1 new message'
                      : '$newMessageCount new messages',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        FloatingActionButton.small(
          heroTag: 'jump-to-latest',
          tooltip: 'Jump to latest message',
          onPressed: onPressed,
          child: const Icon(Icons.arrow_downward_rounded),
        ),
      ],
    );
  }
}
