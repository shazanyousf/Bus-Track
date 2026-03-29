import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  List<String> _departments = [];
  List<String> _semesters = [];
  bool _loading = true;
  bool _saving = false;
  final _deptCtrl = TextEditingController();
  final _semCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final data = await ApiService.getSettings(auth.token!);
      setState(() {
        _departments = List<String>.from(data['departments'] ?? []);
        _semesters = List<String>.from(data['semesters'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final auth = context.read<AuthService>();
    try {
      await ApiService.updateSettings(auth.token!, {
        'departments': _departments,
        'semesters': _semesters,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save settings'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  void _addDepartment() {
    final value = _deptCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _departments.add(value);
      _deptCtrl.clear();
    });
  }

  void _addSemester() {
    final value = _semCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _semesters.add(value);
      _semCtrl.clear();
    });
  }

  void _removeDepartment(int index) {
    setState(() => _departments.removeAt(index));
  }

  void _removeSemester(int index) {
    setState(() => _semesters.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Manage Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Departments', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _buildInputRow(_deptCtrl, 'Add department', _addDepartment),
                  const SizedBox(height: 12),
                  ..._departments.asMap().entries.map((entry) {
                    final i = entry.key;
                    final value = entry.value;
                    return _buildChip(value, () => _removeDepartment(i));
                  }).toList(),
                  const SizedBox(height: 28),
                  const Text('Semesters', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _buildInputRow(_semCtrl, 'Add semester', _addSemester),
                  const SizedBox(height: 12),
                  ..._semesters.asMap().entries.map((entry) {
                    final i = entry.key;
                    final value = entry.value;
                    return _buildChip(value, () => _removeSemester(i));
                  }).toList(),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildInputRow(TextEditingController ctrl, String hint, VoidCallback onAdd) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF8892A4)),
              filled: true,
              fillColor: const Color(0xFF16213E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A3A5C)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onAdd,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A9EFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildChip(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 20, color: Color(0xFFE74C3C)),
          ),
        ],
      ),
    );
  }
}
