import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class ChatController extends ChangeNotifier {
  final TdLibService _tdService;
  final List<Map<String, dynamic>> _chats = [];
  final Map<int, List<Map<String, dynamic>>> _messages = {};
  StreamSubscription? _updateSub;
  bool _isLoadingChats = false;
  bool _isLoadingMessages = false;

  ChatController(this._tdService) {
    _subscribeToUpdates();
  }

  List<Map<String, dynamic>> get chats => _chats;
  bool get isLoadingChats    => _isLoadingChats;
  bool get isLoadingMessages => _isLoadingMessages;

  List<Map<String, dynamic>> getMessagesForChat(int chatId) {
    return _messages[chatId] ?? [];
  }

  void _subscribeToUpdates() {
    _updateSub = _tdService.updates.listen((update) {
      final type = update['@type'];

      // Auto-load chats when TDLib becomes authorized
      if (type == 'updateAuthorizationState') {
        final state = update['authorization_state']?['@type'];
        if (state == 'authorizationStateReady') {
          debugPrint('ChatController: auth ready → loading chats');
          loadChats();
        }
        return;
      }

      if (type == 'updateNewMessage') {
        final message = update['message'];
        final int chatId = message['chat_id'];
        if (!_messages.containsKey(chatId)) _messages[chatId] = [];
        _messages[chatId]!.insert(0, message);
        final chatIndex = _chats.indexWhere((c) => c['id'] == chatId);
        if (chatIndex != -1) {
          _chats[chatIndex]['last_message'] = message;
          final chat = _chats.removeAt(chatIndex);
          _chats.insert(0, chat);
        }
        notifyListeners();
      } else if (type == 'updateChatLastMessage') {
        final int chatId = update['chat_id'];
        final lastMessage = update['last_message'];
        final chatIndex = _chats.indexWhere((c) => c['id'] == chatId);
        if (chatIndex != -1) {
          _chats[chatIndex]['last_message'] = lastMessage;
          notifyListeners();
        }
      } else if (type == 'updateChatUnreadCount') {
        final int chatId = update['chat_id'];
        final int count = update['unread_count'] ?? 0;
        final chatIndex = _chats.indexWhere((c) => c['id'] == chatId);
        if (chatIndex != -1) {
          _chats[chatIndex]['unread_count'] = count;
          notifyListeners();
        }
      }
    });
  }


  Future<void> loadChats() async {
    _isLoadingChats = true;
    notifyListeners();

    try {
      final result = await _tdService.getChats(limit: 100);
      final List<dynamic> chatIds = result['chat_ids'] ?? [];

      _chats.clear();
      for (final dynamic id in chatIds) {
        try {
          final chat = await _tdService.getChat(id as int);
          _chats.add(chat);
        } catch (e) {
          debugPrint('Failed to load chat $id: $e');
        }
      }

      // Sort by position order (TDLib 1.8+: positions array)
      _chats.sort((a, b) {
        int orderOf(Map<String, dynamic> chat) {
          final positions = chat['positions'] as List?;
          if (positions != null && positions.isNotEmpty) {
            final pos = positions.first;
            final order = pos['order'];
            if (order is int) return order;
            if (order is String) return int.tryParse(order) ?? 0;
          }
          return 0;
        }
        return orderOf(b).compareTo(orderOf(a));
      });
    } catch (e) {
      debugPrint('loadChats error: $e');
    } finally {
      _isLoadingChats = false;
      notifyListeners();
    }
  }




  Future<void> loadMessages(int chatId) async {
    _isLoadingMessages = true;
    notifyListeners();
    try {
      final result = await _tdService.getChatHistory(chatId, limit: 40);
      final List<dynamic> msgs = result['messages'] ?? [];
      _messages[chatId] = List<Map<String, dynamic>>.from(msgs);
    } catch (e) {
      debugPrint("Error loading messages for chat $chatId: $e");
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(int chatId, String text) async {
    try {
      await _tdService.sendMessage(chatId, text);
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    super.dispose();
  }
}
