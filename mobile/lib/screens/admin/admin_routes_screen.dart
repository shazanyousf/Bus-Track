import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AdminRoutesScreen extends StatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  State<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends State<AdminRoutesScreen> {
  List _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final routes = await ApiService.getRoutes();
      setState(() {
        _routes = routes;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddRouteDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final stopsCtrl = TextEditingController();

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
            const Text('Add New Route',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _SheetField(ctrl: nameCtrl, label: 'Route Name', hint: 'e.g. Downtown Express'),
            const SizedBox(height: 12),
            _SheetField(ctrl: codeCtrl, label: 'Route Code', hint: 'e.g. RT-001'),
            const SizedBox(height: 12),
            _SheetField(
              ctrl: descCtrl,
              label: 'Description',
              hint: 'e.g. Main downtown route',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _SheetField(
              ctrl: stopsCtrl,
              label: 'Stops',
              hint: 'Enter each stop on a new line: Name,latitude,longitude',
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final auth = context.read<AuthService>();
                  await ApiService.addRoute(auth.token!, {
                    'routeName': nameCtrl.text.trim(),
                    'routeCode': codeCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'stops': _parseStops(stopsCtrl.text),
                  });
                  Navigator.pop(ctx);
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Add Route',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseStops(String rawText) {
    return rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(',').map((p) => p.trim()).toList();
          return {
            'name': parts.isNotEmpty ? parts[0] : 'Stop',
            'latitude': parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0,
            'longitude': parts.length > 2 ? double.tryParse(parts[2]) ?? 0.0 : 0.0,
            'order':  parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0,
          };
        })
        .toList();
  }

  String _stopsTextForRoute(Map route) {
    final stops = (route['stops'] as List?) ?? [];
    return stops.map((stop) {
      final s = stop as Map;
      final lat = (s['latitude'] as num?)?.toString() ?? '0.0';
      final lng = (s['longitude'] as num?)?.toString() ?? '0.0';
      return '${s['name'] ?? 'Stop'},$lat,$lng';
    }).join('\n');
  }

  Future<void> _showEditRouteDialog(Map route) async {
    final nameCtrl = TextEditingController(text: route['routeName'] ?? '');
    final codeCtrl = TextEditingController(text: route['routeCode'] ?? '');
    final descCtrl = TextEditingController(text: route['description'] ?? '');
    final stopsCtrl = TextEditingController(text: _stopsTextForRoute(route));

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
            const Text('Edit Route',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _SheetField(ctrl: nameCtrl, label: 'Route Name'),
            const SizedBox(height: 12),
            _SheetField(ctrl: codeCtrl, label: 'Route Code'),
            const SizedBox(height: 12),
            _SheetField(ctrl: descCtrl, label: 'Description', maxLines: 3),
            const SizedBox(height: 12),
            _SheetField(
              ctrl: stopsCtrl,
              label: 'Stops',
              hint: 'Name,latitude,longitude on each line',
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final auth = context.read<AuthService>();
                  await ApiService.updateRoute(auth.token!, route['_id'], {
                    'routeName': nameCtrl.text.trim(),
                    'routeCode': codeCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'stops': _parseStops(stopsCtrl.text),
                  });
                  Navigator.pop(ctx);
                  _load();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save Changes',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRoute(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Route', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this route?',
            style: TextStyle(color: Color(0xFF8892A4))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final auth = context.read<AuthService>();
      await ApiService.deleteRoute(auth.token!, id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text('Manage Routes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Color(0xFFFF6B35)),
              onPressed: _showAddRouteDialog,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _routes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route_rounded, size: 64, color: const Color(0xFF2A3A5C)),
                      const SizedBox(height: 16),
                      const Text('No routes yet',
                          style: TextStyle(color: Color(0xFF8892A4), fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _routes.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) {
                    final route = _routes[i];
                    return Card(
                      color: const Color(0xFF16213E),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(route['routeName'] ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Code: ${route['routeCode'] ?? ''}',
                                style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
                            Text('Stops: ${(route['stops'] as List?)?.length ?? 0}',
                                style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
                            if (route['description'] != null && route['description'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(route['description'],
                                    style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          color: const Color(0xFF16213E),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              onTap: () => _showEditRouteDialog(route),
                              child: const Text('Edit', style: TextStyle(color: Colors.white)),
                            ),
                            PopupMenuItem(
                              onTap: () => _deleteRoute(route['_id']),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final TextInputType type;
  final int maxLines;

  const _SheetField({
    required this.ctrl,
    required this.label,
    this.hint = '',
    this.type = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF8892A4)),
            filled: true,
            fillColor: const Color(0xFF0F0F1A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A3A5C)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A3A5C)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}
