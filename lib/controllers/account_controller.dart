import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tdlib_service.dart';

class TelegramAccount {
  final String phoneNumber;
  final String firstName;
  final String username;
  final String photoPath;
  final bool isPremium;

  TelegramAccount({
    required this.phoneNumber,
    required this.firstName,
    required this.username,
    required this.photoPath,
    this.isPremium = false,
  });

  Map<String, String> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'firstName': firstName,
      'username': username,
      'photoPath': photoPath,
      'isPremium': isPremium.toString(),
    };
  }

  factory TelegramAccount.fromMap(Map<String, dynamic> map) {
    return TelegramAccount(
      phoneNumber: map['phoneNumber'] ?? '',
      firstName: map['firstName'] ?? '',
      username: map['username'] ?? '',
      photoPath: map['photoPath'] ?? '',
      isPremium: map['isPremium'] == 'true',
    );
  }
}

class AccountController extends ChangeNotifier {
  final TdLibService _tdService;
  final List<TelegramAccount> _accounts = [];
  TelegramAccount? _currentAccount;
  bool _isLoading = false;

  AccountController(this._tdService) {
    _loadAccountsFromStorage();
  }

  List<TelegramAccount> get accounts => _accounts;
  TelegramAccount? get currentAccount => _currentAccount;
  bool get isLoading => _isLoading;
  TdLibService get tdService => _tdService;

  // Load registered profiles from SharedPreferences cache
  Future<void> _loadAccountsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedList = prefs.getStringList('hosted_accounts');
    if (savedList != null) {
      _accounts.clear();
      for (final item in savedList) {
        final parts = item.split('::');
        if (parts.length >= 4) {
          final bool isPrem = parts.length >= 5 ? parts[4] == 'true' : false;
          _accounts.add(TelegramAccount(
            phoneNumber: parts[0],
            firstName: parts[1],
            username: parts[2],
            photoPath: parts[3],
            isPremium: isPrem,
          ));
        }
      }
    }
    
    // Auto-select last active account if available
    final activePhone = prefs.getString('active_account_phone');
    if (activePhone != null && _accounts.any((a) => a.phoneNumber == activePhone)) {
      _currentAccount = _accounts.firstWhere((a) => a.phoneNumber == activePhone);
      await _tdService.initClient(_currentAccount!.phoneNumber);
    }
    notifyListeners();
  }

  // Sync premium status from Telegram server
  Future<void> syncPremiumStatus() async {
    if (_currentAccount == null) return;
    try {
      final me = await _tdService.send('getMe', {});
      final bool isPrem = me['is_premium'] ?? false;
      
      // Update account field
      final idx = _accounts.indexWhere((a) => a.phoneNumber == _currentAccount!.phoneNumber);
      if (idx != -1) {
        final updated = TelegramAccount(
          phoneNumber: _accounts[idx].phoneNumber,
          firstName: _accounts[idx].firstName,
          username: _accounts[idx].username,
          photoPath: _accounts[idx].photoPath,
          isPremium: isPrem,
        );
        _accounts[idx] = updated;
        _currentAccount = updated;
        
        final prefs = await SharedPreferences.getInstance();
        final savedList = _accounts.map((a) => '${a.phoneNumber}::${a.firstName}::${a.username}::${a.photoPath}::${a.isPremium}').toList();
        await prefs.setStringList('hosted_accounts', savedList);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to sync premium status: $e");
    }
  }

  // Switch between up to 50 concurrent logged-in accounts
  Future<void> switchAccount(TelegramAccount target) async {
    if (_currentAccount?.phoneNumber == target.phoneNumber) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      _currentAccount = target;
      // Re-initialize library to isolate state folder for target phone number
      await _tdService.initClient(target.phoneNumber);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('active_account_phone', target.phoneNumber);
    } catch (e) {
      debugPrint("Failed to switch account: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register a new logged-in account profile
  Future<void> registerNewAccount({
    required String phoneNumber,
    required String firstName,
    required String username,
    String photoPath = '',
    bool isPremium = false,
  }) async {
    // Prevent duplicate profiles
    _accounts.removeWhere((a) => a.phoneNumber == phoneNumber);
    
    final newAccount = TelegramAccount(
      phoneNumber: phoneNumber,
      firstName: firstName,
      username: username,
      photoPath: photoPath,
      isPremium: isPremium,
    );
    
    _accounts.add(newAccount);
    _currentAccount = newAccount;
    
    // Cache profiles list in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedList = _accounts.map((a) => '${a.phoneNumber}::${a.firstName}::${a.username}::${a.photoPath}::${a.isPremium}').toList();
    await prefs.setStringList('hosted_accounts', savedList);
    await prefs.setString('active_account_phone', phoneNumber);
    
    notifyListeners();
  }

  // Delete an account profile
  Future<void> deleteAccount(String phoneNumber) async {
    _accounts.removeWhere((a) => a.phoneNumber == phoneNumber);
    if (_currentAccount?.phoneNumber == phoneNumber) {
      if (_accounts.isNotEmpty) {
        await switchAccount(_accounts.first);
      } else {
        _currentAccount = null;
        await _tdService.destroyClient();
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    final savedList = _accounts.map((a) => '${a.phoneNumber}::${a.firstName}::${a.username}::${a.photoPath}::${a.isPremium}').toList();
    await prefs.setStringList('hosted_accounts', savedList);
    if (_currentAccount == null) {
      await prefs.remove('active_account_phone');
    }
    notifyListeners();
  }
}
