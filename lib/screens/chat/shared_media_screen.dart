import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'shared_media_logic.dart';

class SharedMediaScreen extends StatefulWidget {
  final String chatId;

  const SharedMediaScreen({super.key, required this.chatId});

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<SharedMediaScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 30;

  late final TabController _tabController;
  final List<SharedMediaItem> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  CollectionReference<Map<String, dynamic>> get _messages => FirebaseFirestore
      .instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNextMediaPage(initial: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNextMediaPage({bool initial = false}) async {
    if (_isLoadingMore || (!_hasMore && !initial)) return;
    setState(() {
      _isLoadingMore = true;
      _error = null;
      if (initial) _isLoading = true;
    });

    try {
      Query<Map<String, dynamic>> query = _messages
          .orderBy('timestamp', descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(_pageSize);
      final cursor = _cursor;
      if (cursor != null) query = query.startAfterDocument(cursor);

      final page = await query.get();
      if (page.docs.isEmpty) {
        _hasMore = false;
        return;
      }

      _cursor = page.docs.last;
      _hasMore = hasMoreSharedMediaPage(page.docs.length, pageSize: _pageSize);
      final mediaItems = page.docs.map(
        (document) => SharedMediaItem(
          id: document.id,
          data: {...document.data(), 'firestoreId': document.id},
        ),
      );
      final filteredItems = filterSharedMediaItems(mediaItems);
      _items
        ..clear()
        ..addAll(
          mergeSharedMediaPage(current: _items, nextPage: filteredItems),
        );
    } catch (error, stackTrace) {
      debugPrint(
        'Could not load shared media in ${widget.chatId}: '
        '$error\n$stackTrace',
      );
      _error = 'Could not load shared media. Tap to retry.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _openImage(SharedMediaItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedImageViewer(imageUrl: item.mediaUrl),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () => _loadNextMediaPage(initial: true),
          child: Text(_error!),
        ),
      );
    }

    final images = filterSharedMediaItems(_items, type: 'image');
    final voices = filterSharedMediaItems(_items, type: 'voice');
    return TabBarView(
      controller: _tabController,
      children: [_buildImagesTab(images), _buildVoicesTab(voices)],
    );
  }

  Widget _buildImagesTab(List<SharedMediaItem> images) {
    if (images.isEmpty) {
      return SharedMediaEmptyState(
        label: 'No shared images yet.',
        onLoadMore: _hasMore ? () => _loadNextMediaPage() : null,
        isLoading: _isLoadingMore,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240 &&
            _hasMore &&
            !_isLoadingMore) {
          _loadNextMediaPage();
        }
        return false;
      },
      child: GridView.builder(
        key: const PageStorageKey<String>('shared-images-grid'),
        padding: const EdgeInsets.all(8),
        itemCount: images.length + (_isLoadingMore ? 1 : 0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (context, index) {
          if (index >= images.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = images[index];
          return InkWell(
            onTap: () => _openImage(item),
            child: Image.network(
              item.mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVoicesTab(List<SharedMediaItem> voices) {
    if (voices.isEmpty) {
      return SharedMediaEmptyState(
        label: 'No shared voice messages yet.',
        onLoadMore: _hasMore ? () => _loadNextMediaPage() : null,
        isLoading: _isLoadingMore,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240 &&
            _hasMore &&
            !_isLoadingMore) {
          _loadNextMediaPage();
        }
        return false;
      },
      child: ListView.builder(
        key: const PageStorageKey<String>('shared-voices-list'),
        itemCount: voices.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= voices.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = voices[index];
          return SharedVoiceMediaTile(
            item: item,
            onTap: (messageId) => Navigator.pop(context, messageId),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared media'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Images'),
            Tab(text: 'Voice'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          if (_error != null && _items.isNotEmpty)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: () => _loadNextMediaPage(),
                  child: const Text('Retry'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class SharedMediaEmptyState extends StatelessWidget {
  final String label;
  final VoidCallback? onLoadMore;
  final bool isLoading;

  const SharedMediaEmptyState({
    super.key,
    required this.label,
    this.onLoadMore,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          if (isLoading) ...[
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ] else if (onLoadMore != null)
            TextButton(
              onPressed: onLoadMore,
              child: const Text('Load older media'),
            ),
        ],
      ),
    );
  }
}

class SharedVoiceMediaTile extends StatelessWidget {
  final SharedMediaItem item;
  final ValueChanged<String> onTap;

  const SharedVoiceMediaTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.mic_none_rounded)),
      title: Text(
        'Voice message · ${formatSharedMediaDuration(item.durationMillis)}',
      ),
      subtitle: const Text('Tap to open in conversation'),
      onTap: () => onTap(item.id),
    );
  }
}

class SharedImageViewer extends StatelessWidget {
  final String imageUrl;

  const SharedImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Image'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
