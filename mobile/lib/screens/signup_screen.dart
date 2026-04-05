import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'parent/parent_home.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String _error = '';
  int _step = 0; // 0 = account details, 1 = email verification

  Future<void> _signup() async {
    setState(() { _error = ''; });

    // Validation
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (!_emailCtrl.text.contains('@')) {
      setState(() => _error = 'Please enter a valid email');
      return;
    }
    if (_passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    final auth = context.read<AuthService>();
    final result = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      _phoneCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] && result['verificationRequired'] == true) {
      setState(() {
        _step = 1;
        _error = result['message'] ?? 'Verification code sent to email';
      });
      return;
    }

    if (result['success']) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ParentHome()));
    } else {
      setState(() => _error = result['message'] ?? 'Signup failed');
    }
  }

  Future<void> _verifyCode() async {
    setState(() { _error = ''; });
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the verification code');
      return;
    }

    final auth = context.read<AuthService>();
    final result = await auth.verifyRegistrationCode(
      _emailCtrl.text.trim(),
      _codeCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result['success']) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const ParentHome()));
    } else {
      setState(() => _error = result['message'] ?? 'Verification failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C55)]),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFFF6B35).withOpacity(0.3),
                              blurRadius: 20)
                        ],
                      ),
                      child: const Center(
                          child: Text('🚌', style: TextStyle(fontSize: 36))),
                    ),
                    const SizedBox(height: 16),
                    const Text('Create Account',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    const Text('Join BusTrack as a Parent',
                        style:
                            TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (_step == 0) ...[
                _label('FULL NAME'),
                const SizedBox(height: 8),
                _field(_nameCtrl, 'e.g. John Smith'),
                const SizedBox(height: 14),
                _label('EMAIL'),
                const SizedBox(height: 8),
                _field(_emailCtrl, 'example@gmail.com',
                    type: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _label('PHONE (OPTIONAL)'),
                const SizedBox(height: 8),
                _field(_phoneCtrl, '+91 98765 43210',
                    type: TextInputType.phone),
                const SizedBox(height: 14),
                _label('PASSWORD'),
                const SizedBox(height: 8),
                _field(_passCtrl, '••••••••',
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF8892A4),
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    )),
                const SizedBox(height: 14),
                _label('CONFIRM PASSWORD'),
                const SizedBox(height: 8),
                _field(_confirmCtrl, '••••••••',
                    obscure: _obscureConfirm,
                    suffix: IconButton(
                      icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF8892A4),
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Create Account →',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
              ] else ...[
                _label('EMAIL VERIFICATION'),
                const SizedBox(height: 8),
                Text(
                  'Enter the code sent to ${_emailCtrl.text}',
                  style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13),
                ),
                const SizedBox(height: 12),
                _field(_codeCtrl, 'e.g. 123456', type: TextInputType.number),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Verify Email →',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _step = 0;
                      _codeCtrl.clear();
                      _error = '';
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2A3A5C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Edit Details',
                        style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: Color(0xFF8892A4))),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      child: const Text('Sign In',
                          style: TextStyle(
                              color: Color(0xFFFF6B35),
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12));

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType type = TextInputType.text,
      bool obscure = false,
      Widget? suffix}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8892A4)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A5C)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A3A5C)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
