import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tdlib/tdlib.dart';
import 'package:path_provider/path_provider.dart';

// Bridge class to map TDLib package JSON functions to the client wrapper
class TdClient {
  static Future<int> create() async {
    return TdPlugin.instance.tdJsonClientCreate();
  }

  static Future<Map<String, dynamic>> send(int clientId, Map<String, dynamic> event) async {
    final String req = json.encode(event);
    TdPlugin.instance.tdJsonClientSend(clientId, req);
    return {};
  }

  static Future<Map<String, dynamic>?> receive(int clientId, double timeout) async {
    final String? res = TdPlugin.instance.tdJsonClientReceive(clientId, timeout);
    if (res != null) {
      try {
        return json.decode(res) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("JSON Decode Error: $e");
      }
    }
    return null;
  }
}

class TdLibService {
  int? _clientId;
  final StreamController<Map<String, dynamic>> _updateController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get updates => _updateController.stream;
  int? get clientId => _clientId;

  Future<void> initClient(String phoneNumber) async {
    if (_clientId != null) {
      await destroyClient();
    }

    _clientId = await TdClient.create();
    
    final appDir = await getApplicationDocumentsDirectory();
    final String sessionDir = '${appDir.path}/sessions/account_$phoneNumber';
    await Directory(sessionDir).create(recursive: true);

    _startUpdateLoop();

    await send('setTdlibParameters', {
      'parameters': {
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
        'device_model': Platform.isAndroid ? 'Android Device' : 'iOS Device',
        'system_version': Platform.operatingSystemVersion,
        'application_version': '1.0.0',
        'enable_storage_optimizer': true,
      }
    });
  }

  Future<Map<String, dynamic>> send(String method, Map<String, dynamic> parameters) async {
    if (_clientId == null) throw Exception("TDLib Client not initialized");
    final response = await TdClient.send(_clientId!, {
      '@type': method,
      ...parameters,
    });
    return response;
  }

  Future<Map<String, dynamic>> getChats({int limit = 50}) async {
    return await send('getChats', {
      'chat_list': {'@type': 'chatListMain'},
      'limit': limit,
    });
  }

  Future<Map<String, dynamic>> getChatHistory(int chatId, {int fromMessageId = 0, int offset = 0, int limit = 30}) async {
    return await send('getChatHistory', {
      'chat_id': chatId,
      'from_message_id': fromMessageId,
      'offset': offset,
      'limit': limit,
      'only_local': false,
    });
  }

  Future<Map<String, dynamic>> sendMessage(int chatId, String text) async {
    return await send('sendMessage', {
      'chat_id': chatId,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {
          '@type': 'formattedText',
          'text': text,
        },
        'disable_web_page_preview': false,
        'clear_draft': true,
      }
    });
  }

  Future<Map<String, dynamic>> searchPublicChat(String username) async {
    return await send('searchPublicChat', {
      'username': username,
    });
  }

  Future<Map<String, dynamic>> getActiveSessions() async {
    return await send('getActiveSessions', {});
  }

  Future<Map<String, dynamic>> terminateSession(int sessionId) async {
    return await send('terminateSession', {
      'session_id': sessionId,
    });
  }

  Future<Map<String, dynamic>> terminateAllOtherSessions() async {
    return await send('terminateAllOtherSessions', {});
  }

  void _startUpdateLoop() {
    Future.sync(() async {
      while (_clientId != null) {
        try {
          final update = await TdClient.receive(_clientId!, 1.0);
          if (update != null) {
            _updateController.add(update);
            _handleInternalUpdate(update);
          }
        } catch (e) {
          debugPrint("TDLib Receive Error: $e");
        }
      }
    });
  }

  void _handleInternalUpdate(Map<String, dynamic> update) {
    final type = update['@type'];
    if (type == 'updateAuthorizationState') {
      final state = update['authorization_state']['@type'];
      debugPrint("Auth State Updated: $state");
      
      if (state == 'authorizationStateWaitEncryptionKey') {
        send('checkDatabaseEncryptionKey', {
          'encryption_key': '',
        }).catchError((err) {
          debugPrint("Failed to send encryption key: $err");
        });
      }
    }
  }

  Future<void> destroyClient() async {
    if (_clientId != null) {
      await send('close', {});
      _clientId = null;
    }
  }
}
