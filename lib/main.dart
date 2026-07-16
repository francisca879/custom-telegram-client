import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdlib/tdlib.dart';
import 'services/tdlib_service.dart';
import 'controllers/account_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/session_controller.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';
import 'views/sessions_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isMacOS) {
    String libPath = 'libtdjson.dylib';
    if (File('/opt/homebrew/lib/libtdjson.dylib').existsSync()) {
      libPath = '/opt/homebrew/lib/libtdjson.dylib';
    } else if (File('/usr/local/lib/libtdjson.dylib').existsSync()) {
      libPath = '/usr/local/lib/libtdjson.dylib';
    }
    
    try {
      await TdPlugin.initialize(libPath);
      debugPrint("TDLib initialized successfully with: $libPath");
    } catch (e) {
      debugPrint("Failed to initialize TDLib with $libPath: $e");
    }
  } else if (Platform.isWindows) {
    try {
      await TdPlugin.initialize('tdjson.dll');
    } catch (e) {
      debugPrint("Failed to initialize TDLib on Windows: $e");
    }
  }

  // Pre-load SharedPreferences to determine correct initial route
  final prefs = await SharedPreferences.getInstance();
  final List<String>? savedList = prefs.getStringList('hosted_accounts');
  final String? activePhone = prefs.getString('active_account_phone');
  final bool hasSession = savedList != null && savedList.isNotEmpty && activePhone != null && activePhone.isNotEmpty;

  final tdService = TdLibService();

  runApp(
    MultiProvider(
      providers: [
        Provider<TdLibService>.value(value: tdService),
        ChangeNotifierProvider<AccountController>(
          create: (_) => AccountController(tdService),
        ),
        ChangeNotifierProvider<ChatController>(
          create: (context) => ChatController(tdService),
        ),
        ChangeNotifierProvider<SessionController>(
          create: (context) => SessionController(tdService),
        ),
      ],
      child: MyApp(hasSession: hasSession),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool hasSession;
  const MyApp({Key? key, required this.hasSession}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountController>(
      builder: (context, accountCtrl, child) {
        final String initialRoute = hasSession ? '/home' : '/login';
        
        return MaterialApp(

          title: 'Telegram X Custom',
          debugShowCheckedModeBanner: false,
          
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF2FA4E7),
            scaffoldBackgroundColor: const Color(0xFF000000),
            
            textTheme: GoogleFonts.outfitTextTheme(
              ThemeData.dark().textTheme,
            ),
            
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2FA4E7),
              secondary: Color(0xFF2FA4E7),
              background: Color(0xFF000000),
              surface: Color(0xFF161618),
            ),
            
            useMaterial3: true,
          ),
          
          initialRoute: initialRoute,
          routes: {
            '/login': (context) => const LoginView(),
            '/home': (context) => const HomeView(),
            '/sessions': (context) => const SessionsView(),
          },
        );
      },
    );
  }
}
