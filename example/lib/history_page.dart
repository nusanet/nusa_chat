import 'package:flutter/material.dart';
import 'package:nusa_chat/nusa_chat.dart';
import 'package:url_launcher/url_launcher.dart';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatTime(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year} ${_formatTime(local)}';
}

/// The visitor's past and open conversations, built on [NusaChatClient].
/// Owns [client] and disposes it with the page.
class ConversationHistoryPage extends StatefulWidget {
  final NusaChatClient client;

  /// Location previews; a drawn placeholder when null.
  final NusaChatGoogleMap? googleMap;

  const ConversationHistoryPage({super.key, required this.client, this.googleMap});

  @override
  State<ConversationHistoryPage> createState() => _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  final _conversations = <ChatConversation>[];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.client.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.client.getConversations(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _conversations.addAll(result.conversations);
        _page = result.page;
        _hasMore = result.hasMore;
      });
    } on NusaChatException catch (error) {
      if (!mounted) return;
      // The bridge answers 404 for a visitor who has never chatted: no history yet.
      if (error.statusCode != 404) setState(() => _error = error.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat percakapan')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (_conversations.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return _CenteredMessage(message: error ?? 'Belum ada riwayat percakapan.', onRetry: error == null ? null : _load);
    }
    return ListView.separated(
      itemCount: _conversations.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == _conversations.length) return _buildFooter(error);
        final conversation = _conversations[index];
        final open = conversation.status == ChatConversationStatus.open;
        return ListTile(
          leading: Icon(open ? Icons.chat_bubble_outline : Icons.history),
          title: Text(_formatDate(conversation.lastActivityAt)),
          subtitle: Text('${open ? 'Aktif' : 'Selesai'} · dibuka ${_formatDate(conversation.openedAt)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ConversationThreadPage(
                client: widget.client,
                conversation: conversation,
                googleMap: widget.googleMap,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(String? error) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) return _CenteredMessage(message: error, onRetry: _load);
    if (!_hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton(onPressed: _load, child: const Text('Muat lebih banyak')),
    );
  }
}

/// The messages of one conversation, read-only.
class ConversationThreadPage extends StatefulWidget {
  final NusaChatClient client;
  final ChatConversation conversation;
  final NusaChatGoogleMap? googleMap;

  const ConversationThreadPage({super.key, required this.client, required this.conversation, this.googleMap});

  @override
  State<ConversationThreadPage> createState() => _ConversationThreadPageState();
}

class _ConversationThreadPageState extends State<ConversationThreadPage> {
  static const _strings = NusaChatStrings();

  late Future<List<ChatMessage>> _messages = _fetch();

  Future<List<ChatMessage>> _fetch() => widget.client.getConversationMessages(widget.conversation.id);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_formatDate(widget.conversation.openedAt))),
      backgroundColor: NusaChatThemeScope.of(context).backgroundColor,
      body: FutureBuilder<List<ChatMessage>>(
        future: _messages,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = snapshot.error;
          if (error != null) {
            return _CenteredMessage(
              message: error is NusaChatException ? error.message : error.toString(),
              onRetry: () => setState(() => _messages = _fetch()),
            );
          }
          final messages = snapshot.requireData;
          if (messages.isEmpty) return const _CenteredMessage(message: 'Percakapan ini belum berisi pesan.');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildMessage(messages[index]),
          );
        },
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final media = _buildMedia(message);
    return NusaChatMessageRow(
      key: ValueKey(message.localId),
      isMine: message.isMine,
      senderName: _strings.agentName,
      avatar: const NusaChatAvatar(),
      bubble: NusaChatBubble(
        text: media == null ? _strings.displayText(message) : message.text,
        media: media,
        time: _formatTime(message.createdAt),
        isMine: message.isMine,
        status: message.isMine ? message.status : null,
      ),
      // No onTap: buttons of a past conversation are shown, but cannot be sent.
      footer: message.buttons.isEmpty ? null : NusaChatMessageButtons(buttons: message.buttons),
    );
  }

  /// The same content `NusaChatPage` shows; null for a message without media.
  Widget? _buildMedia(ChatMessage message) {
    final media = message.media;
    switch (message.type) {
      case ChatMessageType.image:
        final heroTag = 'history_image_${message.localId}';
        return NusaChatImageContent(
          media: media,
          heroTag: heroTag,
          onTap: media == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NusaChatImageViewerPage(media: media, caption: message.text, heroTag: heroTag),
                  ),
                ),
        );
      case ChatMessageType.document:
        final url = media?.url;
        return NusaChatDocumentContent(
          media: media,
          isMine: message.isMine,
          onTap: url == null ? null : () => _open(Uri.tryParse(url)),
        );
      case ChatMessageType.audio:
        return NusaChatAudioContent(
          media: media,
          isMine: message.isMine,
          onError: () => _notice(_strings.mediaLoadFailed),
        );
      case ChatMessageType.location:
        final location = message.location;
        if (location == null) return null;
        return NusaChatLocationContent(
          location: location,
          isMine: message.isMine,
          openLabel: _strings.openInMaps,
          googleMap: widget.googleMap,
          onTap: () => _open(location.mapsUri),
        );
      case ChatMessageType.text || ChatMessageType.interactive || ChatMessageType.unknown:
        return null;
    }
  }

  Future<void> _open(Uri? uri) async {
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) _notice(_strings.openFailed);
  }

  void _notice(String message) {
    if (mounted) showNusaChatSnackBar(context, message);
  }
}

class _CenteredMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _CenteredMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ],
        ),
      ),
    );
  }
}
