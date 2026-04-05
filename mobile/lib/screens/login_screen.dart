import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'parent/parent_home.dart';
import 'admin/admin_home.dart';
import 'driver/driver_home.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool   _obscure  = true;
  String _error    = '';

  Future<void> _login() async {
    setState(() => _error = '');
    final auth   = context.read<AuthService>();
    final result = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (result['success']) {
      final role = auth.user?['role'] ?? 'parent';
      Widget dest;
      if (role == 'admin')       dest = const AdminHome();
      else if (role == 'driver') dest = const DriverHome();
      else                       dest = const ParentHome();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => dest));
    } else {
      setState(() => _error = result['message'] ?? 'Login failed');
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
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFF8C55)]),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            blurRadius: 20)],
                      ),
                      child: const Center(
                          child: Text('🚌', style: TextStyle(fontSize: 36))),
                    ),
                    const SizedBox(height: 16),
                    const Text('BusTrack',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900)),
                    const Text('University Transport System',
                        style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // Role chips (decorative — role comes from DB)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoleChip(emoji: '👨‍👩‍👧', label: 'Parent'),
                  const SizedBox(width: 8),
                  _RoleChip(emoji: '🛡', label: 'Admin'),
                  const SizedBox(width: 8),
                  _RoleChip(emoji: '🚌', label: 'Driver'),
                ],
              ),
              const SizedBox(height: 30),
              _label('EMAIL'),
              const SizedBox(height: 8),
              _field(_emailCtrl, 'example@gmail.com', type: TextInputType.emailAddress),
              const SizedBox(height: 18),
              _label('PASSWORD'),
              const SizedBox(height: 8),
              _field(_passCtrl, '••••••••', obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF8892A4), size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen())),
                  child: const Text('Forgot Password?',
                      style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ),
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
                    Expanded(child: Text(_error,
                        style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: auth.isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In →',
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Your role (Parent / Admin / Driver) is set by the admin.\nContact admin if you cannot log in.',
                      style: TextStyle(color: Color(0xFF8892A4), fontSize: 12, height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Don\'t have an account? ',
                            style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen())),
                          child: const Text('Create one',
                              style: TextStyle(
                                  color: Color(0xFFFF6B35),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                        ),
                      ],
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

  Widget _label(String t) => Text(t,
      style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11,
          fontWeight: FontWeight.w700, letterSpacing: 0.5));

  Widget _field(TextEditingController ctrl, String hint,
      {bool obscure = false, TextInputType? type, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: TextField(
        controller: ctrl, obscureText: obscure, keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF4A5568)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String emoji, label;
  const _RoleChip({required this.emoji, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF16213E),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF2A3A5C)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 13)),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(
          color: Color(0xFF8892A4), fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}
