import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class SessionController extends ChangeNotifier {
  final TdLibService _tdService;
  List<dynamic> _sessions = [];
  bool _isLoading = false;

  SessionController(this._tdService);

  List<dynamic> get sessions => _sessions;
  bool get isLoading => _isLoading;

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _tdService.getActiveSessions();
      _sessions = result['sessions'] ?? [];
    } catch (e) {
      debugPrint("Failed to load active sessions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> terminateSession(int sessionId) async {
    try {
      await _tdService.terminateSession(sessionId);
      _sessions.removeWhere((s) => s['id'] == sessionId);
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to terminate session $sessionId: $e");
    }
  }

  Future<void> terminateAllOtherSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _tdService.terminateAllOtherSessions();
      _sessions.removeWhere((s) => !(s['is_current'] ?? false));
    } catch (e) {
      debugPrint("Failed to terminate all other sessions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
