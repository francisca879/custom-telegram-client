import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/account_controller.dart';

// ─── Telegram brand colours ────────────────────────────────────────────────
const _bg    = Color(0xFF17212B);
const _surf  = Color(0xFF1C2733);
const _blue  = Color(0xFF2AABEE);
const _dim   = Color(0xFF8A9DB0);
// ──────────────────────────────────────────────────────────────────────────

class LoginView extends StatefulWidget {
  const LoginView({Key? key}) : super(key: key);
  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> with SingleTickerProviderStateMixin {
  final _phoneCtrl    = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneFocus   = FocusNode();

  String _step          = 'PHONE';   // PHONE | CODE | PASSWORD | LOADING
  String _errorMsg      = '';
  bool   _obscurePwd    = true;
  StreamSubscription? _sub;
  bool _isInitializingClient = false;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _subscribeToTdlibUpdates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_phoneFocus);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _subscribeToTdlibUpdates() {
    final ctrl = Provider.of<AccountController>(context, listen: false);
    _sub = ctrl.tdService.updates.listen((update) {
      if (update['@type'] == 'updateAuthorizationState') {
        _handleAuth(update['authorization_state']['@type']);
      }
    });
  }

  void _handleAuth(String state) {
    if (!mounted) return;
    setState(() => _errorMsg = '');
    if (state == 'authorizationStateWaitPhoneNumber') {
      if (_isInitializingClient) {
        _isInitializingClient = false;
        _doSendPhone();
      } else {
        _transition('PHONE');
      }
    } else if (state == 'authorizationStateWaitCode') {
      _transition('CODE');
    } else if (state == 'authorizationStateWaitPassword') {
      _transition('PASSWORD');
    } else if (state == 'authorizationStateReady') {
      _completeLogin();
    } else if (state == 'authorizationStateWaitTdlibParameters') {
      // ignore
    }
  }

  void _transition(String step) {
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _step = step);
      _fadeCtrl.forward();
    });
  }

  Future<void> _completeLogin() async {
    final ctrl = Provider.of<AccountController>(context, listen: false);
    final me = await ctrl.tdService.send('getMe', {});
    await ctrl.registerNewAccount(
      phoneNumber: _phoneCtrl.text.trim(),
      firstName: me['first_name'] ?? 'User',
      username: me['username'] ?? '',
    );
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  Future<void> _onNext() async {
    setState(() => _errorMsg = '');
    if (_step == 'PHONE') {
      final phone = _phoneCtrl.text.trim();
      if (phone.length < 7) {
        setState(() => _errorMsg = 'Enter a valid phone number');
        return;
      }
      setState(() { _step = 'LOADING'; _isInitializingClient = true; });
      final ctrl = Provider.of<AccountController>(context, listen: false);
      try {
        await ctrl.tdService.initClient(phone);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _step = 'PHONE';
          _isInitializingClient = false;
          _errorMsg = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } else if (_step == 'CODE') {
      final code = _codeCtrl.text.trim();
      if (code.length != 5) {
        setState(() => _errorMsg = 'Code must be 5 digits');
        return;
      }
      setState(() => _step = 'LOADING');
      final ctrl = Provider.of<AccountController>(context, listen: false);
      try {
        await ctrl.tdService.send('checkAuthenticationCode', {'code': code});
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _step = 'CODE';
          _errorMsg = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    } else if (_step == 'PASSWORD') {
      final pwd = _passwordCtrl.text;
      if (pwd.isEmpty) {
        setState(() => _errorMsg = 'Password cannot be empty');
        return;
      }
      setState(() => _step = 'LOADING');
      final ctrl = Provider.of<AccountController>(context, listen: false);
      try {
        await ctrl.tdService.send('checkAuthenticationPassword', {'password': pwd});
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _step = 'PASSWORD';
          _errorMsg = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Future<void> _doSendPhone() async {
    setState(() => _step = 'LOADING');
    final ctrl = Provider.of<AccountController>(context, listen: false);
    try {
      await ctrl.tdService.send('setAuthenticationPhoneNumber', {
        'phone_number': _phoneCtrl.text.trim(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = 'PHONE';
        _errorMsg = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }


  void _goBack() {
    if (_step == 'CODE') _transition('PHONE');
    else if (_step == 'PASSWORD') _transition('CODE');
    else Navigator.maybePop(context);
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLoading = _step == 'LOADING';
    return Scaffold(
      backgroundColor: _bg,
      appBar: _step != 'PHONE'
          ? AppBar(
              backgroundColor: _bg,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: isLoading ? null : _goBack,
              ),
              systemOverlayStyle: SystemUiOverlayStyle.light,
            )
          : null,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      _buildLogo(),
                      const SizedBox(height: 32),
                      _buildTitle(),
                      const SizedBox(height: 12),
                      _buildSubtitle(),
                      const SizedBox(height: 36),
                      _buildInput(),
                      if (_errorMsg.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMsg,
                          style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildNextButton(isLoading),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2AABEE), Color(0xFF229ED9)],
        ),
      ),
      child: const Icon(Icons.send_rounded, color: Colors.white, size: 44),
    );
  }

  Widget _buildTitle() {
    final titles = {
      'PHONE': 'Your Phone',
      'CODE': 'Enter Code',
      'PASSWORD': 'Two-Step Verification',
      'LOADING': 'Please Wait...',
    };
    return Text(
      titles[_step] ?? '',
      style: GoogleFonts.roboto(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle() {
    final subs = {
      'PHONE':    'Enter your phone number to sign in.',
      'CODE':     'We sent a code to ${_phoneCtrl.text.trim()}.\nCheck Telegram or your SMS.',
      'PASSWORD': 'Your account has Two-Step Verification\nenabled. Enter your cloud password.',
      'LOADING':  '',
    };
    return Text(
      subs[_step] ?? '',
      style: GoogleFonts.roboto(color: _dim, fontSize: 14.5, height: 1.5),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildInput() {
    if (_step == 'LOADING') {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5)),
      );
    }
    if (_step == 'PHONE') {
      return _TgTextField(
        controller: _phoneCtrl,
        focusNode: _phoneFocus,
        hint: '+91 XXXXX XXXXX',
        label: 'Phone Number',
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
        onSubmitted: (_) => _onNext(),
      );
    }
    if (_step == 'CODE') {
      return _TgTextField(
        controller: _codeCtrl,
        hint: '- - - - -',
        label: '5-digit Code',
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
        textAlign: TextAlign.center,
        letterSpacing: 12,
        onSubmitted: (_) => _onNext(),
      );
    }
    if (_step == 'PASSWORD') {
      return _TgTextField(
        controller: _passwordCtrl,
        hint: 'Cloud Password',
        label: 'Password',
        obscureText: _obscurePwd,
        suffixIcon: IconButton(
          icon: Icon(_obscurePwd ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: _dim, size: 20),
          onPressed: () => setState(() => _obscurePwd = !_obscurePwd),
        ),
        onSubmitted: (_) => _onNext(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildNextButton(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isLoading ? null : _onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            disabledBackgroundColor: _blue.withOpacity(0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          child: Text(
            _step == 'PHONE' ? 'NEXT' : _step == 'CODE' ? 'VERIFY' : 'CONTINUE',
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared text-field widget ─────────────────────────────────────────────────
class _TgTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign textAlign;
  final double? letterSpacing;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  const _TgTextField({
    required this.controller,
    required this.hint,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.textAlign = TextAlign.start,
    this.letterSpacing,
    this.suffixIcon,
    this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: textAlign,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: Colors.white,
        fontSize: 17,
        letterSpacing: letterSpacing,
      ),
      cursorColor: const Color(0xFF2AABEE),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8A9DB0), fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF4A6175), fontSize: 17),
        suffixIcon: suffixIcon,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2C3E50), width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF2AABEE), width: 2),
        ),
      ),
    );
  }
}
