import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_service.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final SocketService _socket = SocketService();
  List _requests = [];
  bool _loading  = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _socket.connect(token: context.read<AuthService>().token);
    _socket.listenToProfileUpdates((_) {
      if (mounted) _load();
    });
    _socket.listenToPaymentReceived((_) {
      NotificationService.instance.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Payment Received',
        body: 'A parent completed a transport fee payment.',
      );
      if (mounted) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _socket.stopListeningToProfileUpdates();
    _socket.stopListeningToPaymentReceived();
    super.dispose();
  }

  Future<void> _assignBus(Map registration) async {
    final buses = await ApiService.getBuses();
    if (!mounted) return;
    final selectedBusId = await showDialog<String>(
      context: context,
      builder: (_) {
        String? selected;
        return StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          title: const Text('Assign Bus', style: TextStyle(color: Colors.white)),
          content: DropdownButtonFormField<String>(
            value: selected,
            dropdownColor: const Color(0xFF16213E),
            decoration: const InputDecoration(labelText: 'Bus', labelStyle: TextStyle(color: Color(0xFF8892A4))),
            items: buses.map((bus) => DropdownMenuItem<String>(
              value: bus['_id']?.toString(),
              child: Text('${bus['busNumber']} (${bus['availableSeats']} seats)', style: const TextStyle(color: Colors.white)),
            )).toList(),
            onChanged: (value) => setDialogState(() => selected = value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: selected == null ? null : () => Navigator.pop(context, selected), child: const Text('Assign Bus')),
          ],
        ));
      },
    );
    if (selectedBusId == null || !mounted) return;
    try {
      await ApiService.assignRegistration(context.read<AuthService>().token!, registration['_id'].toString(), selectedBusId,
          routeId: registration['routeId']?['_id']?.toString());
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus assigned successfully')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Assignment failed: $error')));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      final data = await ApiService.getRegistrations(auth.token!);
      setState(() { _requests = data; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to load requests: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _updateStatus(String id, String status, {String remarks = ''}) async {
    final auth = context.read<AuthService>();
    try {
      await ApiService.updateRegistrationStatus(auth.token!, id, status, remarks: remarks);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request $status successfully'),
          backgroundColor: status == 'approved'
              ? const Color(0xFF2ECC71)
              : status == 'cancelled'
                  ? const Color(0xFFF7C948)
                  : const Color(0xFFE74C3C),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _showRejectDialog(String id) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Reject Request', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason (optional):',
                style: TextStyle(color: Color(0xFF8892A4))),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A3A5C)),
              ),
              child: TextField(
                controller: ctrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Bus full, wrong route...',
                  hintStyle: TextStyle(color: Color(0xFF4A5568)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reject',
                  style: TextStyle(color: Color(0xFFE74C3C)))),
        ],
      ),
    );
    if (confirmed == true) {
      await _updateStatus(id, 'rejected', remarks: ctrl.text.trim());
    }
  }

  List get _filtered {
    if (_filter == 'all') return _requests;
    return _requests.where((r) => r['status'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: 'Back to dashboard',
                    ),
                  ),
                const Text('Registration Requests',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(
                    '${_requests.where((r) => r['status'] == 'pending').length} pending approval',
                    style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ['all', 'pending', 'approved', 'active', 'rejected', 'cancelled']
                        .map((f) => GestureDetector(
                              onTap: () => setState(() => _filter = f),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _filter == f
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF16213E),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _filter == f
                                          ? const Color(0xFFFF6B35)
                                          : const Color(0xFF2A3A5C)),
                                ),
                                child: Text(
                                  f[0].toUpperCase() + f.substring(1),
                                  style: TextStyle(
                                      color: _filter == f
                                          ? Colors.white
                                          : const Color(0xFF8892A4),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: const Color(0xFFFF6B35),
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text('No requests found',
                                style: TextStyle(color: Color(0xFF8892A4))))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final reg    = _filtered[i] as Map;
                              Map _safeMap(dynamic v) => v is Map ? v as Map : {};
                              final bus    = _safeMap(reg['busId']);
                              final route = _safeMap(reg['routeId']).isNotEmpty
                                  ? _safeMap(reg['routeId'])
                                  : _safeMap(bus['routeId']);
                              final parent = _safeMap(reg['parentId']);
                              final student = _safeMap(reg['studentId']);
                              final status = reg['status']  as String? ?? 'pending';
                              final paymentStatus = reg['paymentStatus'] as String? ?? 'PENDING';

                              Color sc = status == 'approved'
                                  ? const Color(0xFF2ECC71)
                                  : status == 'rejected'
                                      ? const Color(0xFFE74C3C)
                                      : const Color(0xFFF7C948);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16213E),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: const Color(0xFF2A3A5C)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(parent['name'] ?? 'Unknown Parent',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15)),
                                            Text(parent['email'] ?? '',
                                                style: const TextStyle(
                                                    color: Color(0xFF8892A4),
                                                    fontSize: 12)),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: sc.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(16),
                                            border:
                                                Border.all(color: sc.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            status[0].toUpperCase() +
                                                status.substring(1),
                                            style: TextStyle(
                                                color: sc,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F0F1A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF2A3A5C)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Student Details',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12)),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 16,
                                            runSpacing: 6,
                                            children: [
                                              _StudentDetail(
                                                  label: 'Name',
                                                  value: student['name']?.toString() ?? 'N/A'),
                                              _StudentDetail(
                                                  label: 'Roll No.',
                                                  value: student['studentId']?.toString() ?? 'N/A'),
                                              _StudentDetail(
                                                  label: 'Class',
                                                  value: student['class']?.toString() ?? 'N/A'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _Tag(
                                            icon: Icons.directions_bus_rounded,
                                            text: bus['busNumber'] ?? 'N/A'),
                                        const SizedBox(width: 8),
                                        _Tag(
                                            icon: Icons.route_rounded,
                                            text: route['routeName'] ?? 'N/A'),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Text(paymentStatus == 'PAID' ? 'Payment: PAID ✓' : 'Payment: PENDING',
                                            style: TextStyle(color: paymentStatus == 'PAID' ? const Color(0xFF2ECC71) : const Color(0xFFF7C948), fontSize: 12, fontWeight: FontWeight.w700)),
                                        const Spacer(),
                                        if (status == 'approved' && paymentStatus == 'PAID')
                                          TextButton.icon(onPressed: () => _assignBus(reg), icon: const Icon(Icons.directions_bus, size: 16), label: const Text('Assign Bus')),
                                      ],
                                    ),
                                    if (status == 'pending' || status == 'approved') ...[
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          if (status == 'pending') ...[
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _updateStatus(
                                                    reg['_id'] as String, 'approved'),
                                                icon: const Icon(Icons.check_rounded,
                                                    size: 16),
                                                label: const Text('Approve'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2ECC71)
                                                      .withOpacity(0.15),
                                                  foregroundColor:
                                                      const Color(0xFF2ECC71),
                                                  elevation: 0,
                                                  side: const BorderSide(
                                                      color: Color(0xFF2ECC71),
                                                      width: 0.5),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showRejectDialog(reg['_id'] as String),
                                                icon: const Icon(Icons.close_rounded,
                                                    size: 16),
                                                label: const Text('Reject'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFE74C3C)
                                                      .withOpacity(0.1),
                                                  foregroundColor:
                                                      const Color(0xFFE74C3C),
                                                  elevation: 0,
                                                  side: const BorderSide(
                                                      color: Color(0xFFE74C3C),
                                                      width: 0.5),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _updateStatus(
                                                    reg['_id'] as String, 'cancelled'),
                                                icon: const Icon(Icons.cancel_rounded,
                                                    size: 16),
                                                label: const Text('Cancel'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFF7C948)
                                                      .withOpacity(0.15),
                                                  foregroundColor:
                                                      const Color(0xFFF7C948),
                                                  elevation: 0,
                                                  side: const BorderSide(
                                                      color: Color(0xFFF7C948),
                                                      width: 0.5),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ],
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

class _StudentDetail extends StatelessWidget {
  final String label;
  final String value;

  const _StudentDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF8892A4)),
          const SizedBox(width: 5),
          Text(text,
              style: const TextStyle(color: Color(0xFF8892A4), fontSize: 11)),
        ],
      ),
    );
  }
}
