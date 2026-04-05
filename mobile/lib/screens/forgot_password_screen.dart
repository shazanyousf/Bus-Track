import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  
  int _step = 0; // 0: email, 1: code, 2: password
  bool _loading = false;
  String _error = '';
  bool _obscure = true;
  bool _obscureConfirm = true;

  Future<void> _sendResetCode() async {
    setState(() => _error = '');
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    
    setState(() => _loading = true);
    try {
      final result = await ApiService.forgotPassword(_emailCtrl.text.trim());
      setState(() {
        _step = 1;
        _loading = false;
        _error = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Reset code sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Email not found or error occurred';
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _error = '');
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the reset code');
      return;
    }
    
    setState(() => _loading = true);
    try {
      await ApiService.verifyResetCode(_emailCtrl.text.trim(), _codeCtrl.text.trim());
      setState(() {
        _step = 2;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _error = '');
    
    if (_newPassCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter a new password');
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (_newPassCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    
    setState(() => _loading = true);
    try {
      await ApiService.resetPassword(
        _emailCtrl.text.trim(),
        _codeCtrl.text.trim(),
        _newPassCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to reset password';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          child: Text('🔒', style: TextStyle(fontSize: 36))),
                    ),
                    const SizedBox(height: 16),
                    const Text('Reset Password',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Step 0: Email entry
              if (_step == 0) ...[
                _label('EMAIL ADDRESS'),
                const SizedBox(height: 8),
                _field(_emailCtrl, 'example@gmail.com',
                    type: TextInputType.emailAddress),
                const SizedBox(height: 20),
                _buildButton('Send Reset Code', _sendResetCode),
              ],
              // Step 1: Code verification
              if (_step == 1) ...[
                _label('RESET CODE'),
                const SizedBox(height: 8),
                Text(
                  'We sent a reset code to ${_emailCtrl.text}',
                  style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13),
                ),
                const SizedBox(height: 8),
                _field(_codeCtrl, 'e.g. 123456', type: TextInputType.number),
                const SizedBox(height: 20),
                _buildButton('Verify Code', _verifyCode),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _step = 0;
                      _codeCtrl.clear();
                    }),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2A3A5C)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back',
                        style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
              // Step 2: Password reset
              if (_step == 2) ...[
                _label('NEW PASSWORD'),
                const SizedBox(height: 8),
                _field(_newPassCtrl, '••••••••',
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
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
                const SizedBox(height: 20),
                _buildButton('Reset Password', _resetPassword),
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
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen())),
                  child: const Text('Back to Login',
                      style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
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

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
      ),
    );
  }
}
