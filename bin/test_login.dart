import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:tdlib/tdlib.dart';

void main() async {
  TdNativePlugin.registerWith();
  print("Initializing TDLib dynamic engine...");
  String libPath = '/opt/homebrew/lib/libtdjson.dylib';
  await TdPlugin.initialize(libPath);
  
  final clientId = TdPlugin.instance.tdJsonClientCreate();
  print("Created TDLib client with ID: $clientId");
  
  final sessionDir = '${Directory.systemTemp.path}/tdlib_test_session_${DateTime.now().millisecondsSinceEpoch}';
  await Directory(sessionDir).create(recursive: true);
  
  final parameters = {
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
    'device_model': 'MacBook',
    'system_version': 'macOS',
    'application_version': '1.0.0',
    'enable_storage_optimizer': true,
  };
  
  TdPlugin.instance.tdJsonClientSend(clientId, jsonEncode(parameters));
  
  bool hasSentPhone = false;
  print("Starting event update loop...");
  
  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    final res = TdPlugin.instance.tdJsonClientReceive(clientId, 0.1);
    if (res != null) {
      if (res.contains('authorizationStateWaitEncryptionKey')) {
        print("\n[TEST] Auth state is WAIT_ENCRYPTION. Unlocking database with empty key...");
        final sendKey = {
          '@type': 'checkDatabaseEncryptionKey',
          'encryption_key': ''
        };
        TdPlugin.instance.tdJsonClientSend(clientId, jsonEncode(sendKey));
      }
      
      if (res.contains('authorizationStateWaitPhoneNumber') && !hasSentPhone) {
        hasSentPhone = true;
        print("\n[TEST] Auth state is WAITING_PHONE. Sending phone number: +918718005751...");
        final sendPhone = {
          '@type': 'setAuthenticationPhoneNumber',
          'phone_number': '+918718005751'
        };
        TdPlugin.instance.tdJsonClientSend(clientId, jsonEncode(sendPhone));
      }
      
      if (res.contains('authorizationStateWaitCode')) {
        print("\n🏆 SUCCESS! TDLib successfully transitioned to WAITING_CODE!");
        print("OTP code has been sent by Telegram's server to the user.");
        timer.cancel();
        exit(0);
      }
      
      if (res.contains('error')) {
        print("\n⚠️ Received Error update: $res");
      }
    }
  });
}
