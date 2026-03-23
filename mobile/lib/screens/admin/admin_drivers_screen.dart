import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  List _drivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final data = await ApiService.getDrivers(auth.token!);
      setState(() { _drivers = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddDriverDialog() async {
    final nameCtrl    = TextEditingController();
    final phoneCtrl   = TextEditingController();
    final licenseCtrl = TextEditingController();
    final expCtrl     = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Driver',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _buildField(nameCtrl,    'Full Name',      'e.g. Ahmed Ali'),
            const SizedBox(height: 12),
            _buildField(phoneCtrl,   'Phone Number',   '+92-300-0000000', type: TextInputType.phone),
            const SizedBox(height: 12),
            _buildField(licenseCtrl, 'License Number', 'e.g. LHR-2021-001'),
            const SizedBox(height: 12),
            _buildField(expCtrl,     'Experience (years)', 'e.g. 5', type: TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final auth = context.read<AuthService>();
                  await ApiService.addDriver(auth.token!, {
                    'name':       nameCtrl.text.trim(),
                    'phone':      phoneCtrl.text.trim(),
                    'licenseNo':  licenseCtrl.text.trim(),
                    'experience': int.tryParse(expCtrl.text) ?? 0,
                  });
                  Navigator.pop(ctx);
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Add Driver',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, String hint,
      {TextInputType? type}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A3A5C)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF4A5568)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteDriver(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Driver',
            style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this driver?',
            style: TextStyle(color: Color(0xFF8892A4))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final auth = context.read<AuthService>();
      await ApiService.deleteDriver(auth.token!, id);
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Manage Drivers',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                    Text('${_drivers.length} drivers registered',
                        style: const TextStyle(
                            color: Color(0xFF8892A4), fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDriverDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF6B35)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFFFF6B35),
                    child: _drivers.isEmpty
                        ? const Center(
                            child: Text('No drivers added yet',
                                style:
                                    TextStyle(color: Color(0xFF8892A4))))
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _drivers.length,
                            itemBuilder: (_, i) {
                              final d = _drivers[i] as Map;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16213E),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFF2A3A5C)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          const Color(0xFF4A9EFF)
                                              .withOpacity(0.15),
                                      child: Text(
                                        (d['name'] as String? ?? 'D')
                                                .isNotEmpty
                                            ? (d['name'] as String)[0]
                                                .toUpperCase()
                                            : 'D',
                                        style: const TextStyle(
                                            color: Color(0xFF4A9EFF),
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(d['name'] ?? '',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15)),
                                          Text(d['phone'] ?? '',
                                              style: const TextStyle(
                                                  color: Color(0xFF8892A4),
                                                  fontSize: 12)),
                                          Text(
                                              '${d['experience'] ?? 0} yrs exp • License: ${d['licenseNo'] ?? 'N/A'}',
                                              style: const TextStyle(
                                                  color: Color(0xFF8892A4),
                                                  fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _deleteDriver(
                                          d['_id'] as String),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFE74C3C),
                                          size: 20),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
