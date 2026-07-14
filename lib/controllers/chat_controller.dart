import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class ChatController extends ChangeNotifier {
  final TdLibService _tdService;
  final List<Map<String, dynamic>> _chats = [];
  final Map<int, List<Map<String, dynamic>>> _messages = {};
  StreamSubscription? _updateSub;
  bool _isLoadingChats = false;

  ChatController(this._tdService) {
    _subscribeToUpdates();
  }

  List<Map<String, dynamic>> get chats => _chats;
  bool get isLoadingChats => _isLoadingChats;

  List<Map<String, dynamic>> getMessagesForChat(int chatId) {
    return _messages[chatId] ?? [];
  }

  void _subscribeToUpdates() {
    _updateSub = _tdService.updates.listen((update) {
      final type = update['@type'];
      
      if (type == 'updateNewMessage') {
        final message = update['message'];
        final int chatId = message['chat_id'];
        
        if (!_messages.containsKey(chatId)) {
          _messages[chatId] = [];
        }
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
      }
    });
  }

  Future<void> loadChats() async {
    _isLoadingChats = true;
    notifyListeners();

    try {
      final result = await _tdService.getChats();
      final List<dynamic> chatIds = result['chat_ids'] ?? [];
      
      _chats.clear();
      for (final int id in chatIds) {
        final chat = await _tdService.send('getChat', {'chat_id': id});
        _chats.add(chat);
      }
      
      _chats.sort((a, b) {
        final int orderA = a['order'] ?? 0;
        final int orderB = b['order'] ?? 0;
        return orderB.compareTo(orderA);
      });
    } catch (e) {
      debugPrint("Error loading chats: $e");
    } finally {
      _isLoadingChats = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(int chatId) async {
    try {
      final result = await _tdService.getChatHistory(chatId, limit: 40);
      final List<dynamic> msgs = result['messages'] ?? [];
      
      _messages[chatId] = List<Map<String, dynamic>>.from(msgs);
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading messages for chat $chatId: $e");
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
