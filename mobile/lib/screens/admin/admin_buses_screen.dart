import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class AdminBusesScreen extends StatefulWidget {
  const AdminBusesScreen({super.key});

  @override
  State<AdminBusesScreen> createState() => _AdminBusesScreenState();
}

class _AdminBusesScreenState extends State<AdminBusesScreen> {
  List _buses   = [];
  List _routes  = [];
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
      final results = await Future.wait([
        ApiService.getBuses(),
        ApiService.getRoutes(),
        ApiService.getDrivers(auth.token!),
      ]);
      setState(() {
        _buses   = results[0];
        _routes  = results[1];
        _drivers = results[2];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddBusDialog() async {
    final numCtrl   = TextEditingController();
    final seatsCtrl = TextEditingController();
    String? selectedRouteId;
    String? selectedDriverId;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Bus',
                  style: TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              _SheetField(ctrl: numCtrl, label: 'Bus Number', hint: 'e.g. BUS-005'),
              const SizedBox(height: 12),
              _SheetField(ctrl: seatsCtrl, label: 'Total Seats', hint: 'e.g. 40', type: TextInputType.number),
              const SizedBox(height: 12),
              _SheetDropdown(
                label: 'Route',
                value: selectedRouteId,
                items: _routes.map((r) => DropdownMenuItem(
                  value: r['_id'] as String,
                  child: Text(r['routeName'] ?? '', style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (v) => setLocal(() => selectedRouteId = v),
              ),
              const SizedBox(height: 12),
              _SheetDropdown(
                label: 'Driver',
                value: selectedDriverId,
                items: _drivers.map((d) => DropdownMenuItem(
                  value: d['_id'] as String,
                  child: Text(d['name'] ?? '', style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (v) => setLocal(() => selectedDriverId = v),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final auth = context.read<AuthService>();
                    final seats = int.tryParse(seatsCtrl.text) ?? 40;
                    await ApiService.addBus(auth.token!, {
                      'busNumber':      numCtrl.text.trim(),
                      'totalSeats':     seats,
                      'availableSeats': seats,
                      'routeId':        selectedRouteId,
                      'driverId':       selectedDriverId,
                    });
                    Navigator.pop(ctx);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Add Bus',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBus(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Delete Bus', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this bus?',
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
      await ApiService.deleteBus(auth.token!, id);
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
                    const Text('Manage Buses',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    Text('${_buses.length} buses registered',
                        style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddBusDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Bus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFFFF6B35),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _buses.length,
                      itemBuilder: (_, i) {
                        final bus    = _buses[i] as Map;
                        final driver = bus['driverId'] as Map? ?? {};
                        final route  = bus['routeId']  as Map? ?? {};
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF2A3A5C)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Text('🚌', style: TextStyle(fontSize: 28)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(bus['busNumber'] ?? '',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15)),
                                        Text(route['routeName'] ?? 'No route',
                                            style: const TextStyle(
                                                color: Color(0xFF8892A4), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteBus(bus['_id'] as String),
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: Color(0xFFE74C3C), size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _BusStat(label: 'Total', value: '${bus['totalSeats']}', color: Colors.white),
                                  const SizedBox(width: 8),
                                  _BusStat(label: 'Available', value: '${bus['availableSeats']}', color: const Color(0xFF2ECC71)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F0F1A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        driver['name'] ?? 'No driver',
                                        style: const TextStyle(
                                            color: Color(0xFF8892A4), fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
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

class _BusStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BusStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(color: Color(0xFF8892A4), fontSize: 10)),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType? type;
  const _SheetField({required this.ctrl, required this.label, required this.hint, this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _SheetDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  const _SheetDropdown({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A3A5C)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF16213E),
              hint: Text('Select $label', style: const TextStyle(color: Color(0xFF4A5568))),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
