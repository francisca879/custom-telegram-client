import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/account_controller.dart';

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _authState = 'WAITING_PHONE';
  String _statusMessage = 'Enter your phone number to start';
  StreamSubscription? _updateSub;
  bool _isInitializingClient = false;

  @override
  void initState() {
    super.initState();
    _subscribeToTdlibUpdates();
  }

  @override
  void dispose() {
    _updateSub?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _subscribeToTdlibUpdates() {
    final accountCtrl = Provider.of<AccountController>(context, listen: false);
    _updateSub = accountCtrl.tdService.updates.listen((update) {
      final type = update['@type'];
      if (type == 'updateAuthorizationState') {
        final authState = update['authorization_state']['@type'];
        _handleAuthStateChange(authState);
      }
    });
  }

  void _handleAuthStateChange(String state) {
    setState(() {
      if (state == 'authorizationStateWaitPhoneNumber') {
        if (_isInitializingClient) {
          _isInitializingClient = false;
          _sendPhoneNumber();
        } else {
          _authState = 'WAITING_PHONE';
          _statusMessage = 'Enter your phone number to start';
        }
      } else if (state == 'authorizationStateWaitCode') {
        _authState = 'WAITING_CODE';
        _statusMessage = 'Enter the 5-digit code sent to your device';
      } else if (state == 'authorizationStateWaitPassword') {
        _authState = 'WAITING_PASSWORD';
        _statusMessage = 'Enter your Two-Step Verification cloud password';
      } else if (state == 'authorizationStateReady') {
        _authState = 'READY';
        _registerCompletedProfile();
      }
    });
  }

  Future<void> _registerCompletedProfile() async {
    final accountCtrl = Provider.of<AccountController>(context, listen: false);
    final me = await accountCtrl.tdService.send('getMe', {});
    
    await accountCtrl.registerNewAccount(
      phoneNumber: _phoneController.text.trim(),
      firstName: me['first_name'] ?? 'User',
      username: me['username'] ?? 'NoUsername',
    );

    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _submitPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _authState = 'LOADING';
      _statusMessage = 'Initializing TDLib session...';
      _isInitializingClient = true;
    });

    final accountCtrl = Provider.of<AccountController>(context, listen: false);
    await accountCtrl.tdService.initClient(phone);
  }

  Future<void> _sendPhoneNumber() async {
    final phone = _phoneController.text.trim();
    final accountCtrl = Provider.of<AccountController>(context, listen: false);

    setState(() {
      _authState = 'LOADING';
      _statusMessage = 'Requesting security code...';
    });

    await accountCtrl.tdService.send('setAuthenticationPhoneNumber', {
      'phone_number': phone,
    });
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _authState = 'LOADING';
      _statusMessage = 'Verifying security code...';
    });

    final accountCtrl = Provider.of<AccountController>(context, listen: false);
    await accountCtrl.tdService.send('checkAuthenticationCode', {
      'code': code,
    });
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    setState(() {
      _authState = 'LOADING';
      _statusMessage = 'Unlocking 2FA security database...';
    });

    final accountCtrl = Provider.of<AccountController>(context, listen: false);
    await accountCtrl.tdService.send('checkAuthenticationPassword', {
      'password': password,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FA4E7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Telegram X Custom",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Text(
                "Welcome Back",
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: GoogleFonts.outfit(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              if (_authState == 'WAITING_PHONE') ...[
                _buildTextField(
                  controller: _phoneController,
                  hintText: "+91 8718005751",
                  labelText: "Phone Number",
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 30),
                _buildSubmitButton("Send Code", _submitPhone),
              ] else if (_authState == 'WAITING_CODE') ...[
                _buildTextField(
                  controller: _codeController,
                  hintText: "12345",
                  labelText: "Security Code",
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 30),
                _buildSubmitButton("Verify Code", _submitCode),
              ] else if (_authState == 'WAITING_PASSWORD') ...[
                _buildTextField(
                  controller: _passwordController,
                  hintText: "Enter 2FA Password",
                  labelText: "Cloud Password",
                  icon: Icons.vpn_key_outlined,
                  obscureText: true,
                ),
                const SizedBox(height: 30),
                _buildSubmitButton("Unlock Session", _submitPassword),
              ] else if (_authState == 'LOADING') ...[
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF2FA4E7),
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF2FA4E7)),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2FA4E7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
