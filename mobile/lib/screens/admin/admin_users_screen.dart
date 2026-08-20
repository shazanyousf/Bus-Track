import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/auth_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final SocketService _socket = SocketService();
  List _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _socket.connect();
    _socket.listenToProfileUpdates((_) {
      if (mounted) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _socket.stopListeningToProfileUpdates();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final data = await ApiService.getUsers(auth.token!);
      setState(() { _users = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showEditDialog(Map user) async {
    final nameCtrl = TextEditingController(text: user['name'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    String role = user['role'] ?? 'parent';
    bool emailVerified = user['emailVerified'] == true;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20,20,20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit User', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _buildField(nameCtrl, 'Full Name', 'e.g. Ali Khan'),
            const SizedBox(height: 8),
            _buildField(emailCtrl, 'Email', 'user@example.com'),
            const SizedBox(height: 8),
            _buildField(phoneCtrl, 'Phone', '+92-300-0000000'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: role,
              dropdownColor: const Color(0xFF16213E),
              items: const [
                DropdownMenuItem(value: 'parent', child: Text('Parent')),
                DropdownMenuItem(value: 'driver', child: Text('Driver')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (v) { if (v != null) role = v; },
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Email verified', style: TextStyle(color: Colors.white)),
              const Spacer(),
              StatefulBuilder(builder: (c, s) {
                return Switch(value: emailVerified, onChanged: (v) => s(() => emailVerified = v));
              })
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final auth = context.read<AuthService>();
                  await ApiService.updateUser(auth.token!, user['_id'] as String, {
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'role': role,
                    'emailVerified': emailVerified,
                  });
                  Navigator.pop(ctx);
                  _load();
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A9EFF)),
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8892A4))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF0F0F1A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2A3A5C))),
          child: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10))),
        ),
      ],
    );
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete User', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this user?', style: TextStyle(color: Color(0xFF8892A4))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final auth = context.read<AuthService>();
      await ApiService.deleteUser(auth.token!, id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20,20,20,16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.onBack != null)
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Back to dashboard',
                  ),
                const Text('Manage Users', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${_users.length} users', style: const TextStyle(color: Color(0xFF8892A4)))
              ],
            ),
          ),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35))) : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFFF6B35),
              child: _users.isEmpty ? const Center(child: Text('No users', style: TextStyle(color: Color(0xFF8892A4)))) : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _users.length,
                itemBuilder: (_, i) {
                  final u = _users[i] as Map;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A3A5C))),
                    child: Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: const Color(0xFF4A9EFF).withOpacity(0.15), child: Text(((u['name'] as String?)?.isNotEmpty ?? false) ? (u['name'] as String)[0].toUpperCase() : 'U', style: const TextStyle(color: Color(0xFF4A9EFF), fontWeight: FontWeight.w800))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), Text(u['email'] ?? '', style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)), Text(u['role'] ?? '', style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11))])),
                      IconButton(onPressed: () => _showEditDialog(u), icon: const Icon(Icons.edit_outlined, color: Color(0xFF4A9EFF))),
                      IconButton(onPressed: () => _deleteUser(u['_id'] as String), icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE74C3C))),
                    ]),
                  );
                }
              ),
            ),
          ),
        ],
      ),
    );
  }
}
