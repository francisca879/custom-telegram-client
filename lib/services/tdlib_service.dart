import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tdlib/tdlib.dart';
import 'package:path_provider/path_provider.dart';

/// TDLib bridge — properly correlates async requests via @extra
class TdLibService {
  int? _clientId;
  int _reqId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final StreamController<Map<String, dynamic>> _updateCtrl =
      StreamController.broadcast();
  Timer? _timer;

  Stream<Map<String, dynamic>> get updates => _updateCtrl.stream;
  int? get clientId => _clientId;
  bool get isReady => _clientId != null;

  // ── Init / Destroy ──────────────────────────────────────────────────────
  Future<void> initClient(String phoneNumber) async {
    if (_clientId != null) await destroyClient();

    _clientId = TdPlugin.instance.tdJsonClientCreate();
    debugPrint('TDLib client created: $_clientId');

    final appDir = await getApplicationSupportDirectory();
    final sessionDir = '${appDir.path}/sessions/account_$phoneNumber';
    await Directory(sessionDir).create(recursive: true);
    debugPrint('Session dir: $sessionDir');

    _startLoop();

    _rawSend({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': sessionDir,
      'files_directory': '$sessionDir/files',
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': 39624542,
      'api_hash': 'aeec5e61d5e8fc87fe7e5b63a7b5e17c',
      'system_language_code': 'en',
      'device_model': Platform.isMacOS ? 'Mac' : 'Desktop',
      'system_version': Platform.operatingSystemVersion,
      'application_version': '1.0.0',
      'enable_storage_optimizer': true,
    });
  }

  Future<void> destroyClient() async {
    _timer?.cancel();
    _timer = null;
    final id = _clientId;
    _clientId = null;
    // Cancel all pending requests
    for (final c in _pending.values) {
      c.completeError('Client destroyed');
    }
    _pending.clear();
    if (id != null) {
      TdPlugin.instance.tdJsonClientSend(id, json.encode({'@type': 'close'}));
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Send a TDLib request and await its response.
  Future<Map<String, dynamic>> send(String method, Map<String, dynamic> params,
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (_clientId == null) throw Exception('TDLib not initialized');
    final id = (_reqId++).toString();
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    TdPlugin.instance.tdJsonClientSend(
        _clientId!, json.encode({'@type': method, '@extra': id, ...params}));
    return c.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('TDLib request timed out: $method');
    });
  }

  Future<Map<String, dynamic>> getChats({int limit = 100}) =>
      send('getChats', {'chat_list': {'@type': 'chatListMain'}, 'limit': limit});

  Future<Map<String, dynamic>> getChat(int chatId) =>
      send('getChat', {'chat_id': chatId});

  Future<Map<String, dynamic>> getChatHistory(int chatId,
          {int fromMessageId = 0, int offset = 0, int limit = 50}) =>
      send('getChatHistory', {
        'chat_id': chatId,
        'from_message_id': fromMessageId,
        'offset': offset,
        'limit': limit,
        'only_local': false,
      });

  Future<Map<String, dynamic>> sendMessage(int chatId, String text) =>
      send('sendMessage', {
        'chat_id': chatId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {'@type': 'formattedText', 'text': text},
          'disable_web_page_preview': false,
          'clear_draft': true,
        },
      });

  Future<Map<String, dynamic>> searchPublicChat(String username) =>
      send('searchPublicChat', {'username': username});

  /// Search contacts + public chats by query
  Future<Map<String, dynamic>> searchChatsAndUsers(String query) =>
      send('searchChatsOnServer', {'query': query, 'limit': 20});

  Future<Map<String, dynamic>> searchContacts(String query, {int limit = 20}) =>
      send('searchContacts', {'query': query, 'limit': limit});

  Future<Map<String, dynamic>> getMe() => send('getMe', {});

  Future<Map<String, dynamic>> getActiveSessions() =>
      send('getActiveSessions', {});

  Future<Map<String, dynamic>> terminateSession(int sessionId) =>
      send('terminateSession', {'session_id': sessionId});

  Future<Map<String, dynamic>> terminateAllOtherSessions() =>
      send('terminateAllOtherSessions', {});

  // ── Internal loop ───────────────────────────────────────────────────────
  void _startLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final id = _clientId;
      if (id == null) { _timer?.cancel(); return; }
      try {
        final raw = TdPlugin.instance.tdJsonClientReceive(id, 0.0);
        if (raw != null && raw.isNotEmpty) {
          final Map<String, dynamic> upd = json.decode(raw);
          _dispatch(upd);
        }
      } catch (e) {
        debugPrint('TDLib recv error: $e');
      }
    });
  }

  void _rawSend(Map<String, dynamic> data) {
    if (_clientId == null) return;
    TdPlugin.instance.tdJsonClientSend(_clientId!, json.encode(data));
  }

  void _dispatch(Map<String, dynamic> upd) {
    // Route response to pending completer if @extra present
    final extra = upd['@extra'];
    if (extra != null) {
      final key = extra.toString();
      final c = _pending.remove(key);
      if (c != null && !c.isCompleted) {
        if (upd['@type'] == 'error') {
          c.completeError('TDLib error ${upd['code']}: ${upd['message']}');
        } else {
          c.complete(upd);
        }
        return;
      }
    }

    // Broadcast to listeners
    _updateCtrl.add(upd);

    // Internal handlers
    final type = upd['@type'];
    if (type == 'updateAuthorizationState') {
      final state = upd['authorization_state']['@type'];
      debugPrint('Auth: $state');
      if (state == 'authorizationStateWaitEncryptionKey') {
        _rawSend({'@type': 'checkDatabaseEncryptionKey', 'encryption_key': ''});
      }
    }
  }
}
