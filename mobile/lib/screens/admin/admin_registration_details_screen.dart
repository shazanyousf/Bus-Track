import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'package:provider/provider.dart';

class AdminRegistrationDetailsScreen extends StatefulWidget {
  const AdminRegistrationDetailsScreen({super.key, required this.registration});
  final Map registration;

  @override
  State<AdminRegistrationDetailsScreen> createState() => _AdminRegistrationDetailsScreenState();
}

class _AdminRegistrationDetailsScreenState extends State<AdminRegistrationDetailsScreen> {
  List _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final payments = await ApiService.getMonthlyPayments(context.read<AuthService>().token!);
      final id = widget.registration['_id']?.toString();
      if (mounted) setState(() {
        _payments = payments.where((payment) {
          final linked = payment['registrationId'];
          final linkedId = linked is Map ? linked['_id'] : linked;
          return linkedId?.toString() == id;
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map _map(dynamic value) => value is Map ? value : {};

  @override
  Widget build(BuildContext context) {
    final registration = widget.registration;
    final student = _map(registration['studentId']);
    final parent = _map(registration['parentId']);
    final bus = _map(registration['busId']);
    final route = _map(registration['routeId']).isNotEmpty ? _map(registration['routeId']) : _map(bus['routeId']);
    final stop = _map(registration['stop']);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text('Registration Details', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Student', [
            _row('Name', student['name']),
            _row('Student ID', student['studentId']),
            _row('Phone', student['phone']),
            _row('Class', student['class']),
          ]),
          _section('Parent', [_row('Name', parent['name']), _row('Email', parent['email'])]),
          _section('Transport', [
            _row('Bus', bus['busNumber'] ?? 'Not Assigned'),
            _row('Route', route['routeName']),
            _row('Stop', stop['name']),
            _row('Monthly Fee', '₹${stop['monthlyFee'] ?? registration['paymentAmount'] ?? 0}'),
          ]),
          _section('Status', [
            _row('Registration', registration['status']),
            _row('Payment', registration['paymentStatus']),
            _row('Registration Date', registration['requestDate']),
            _row('Approved At', registration['reviewedAt']),
            _row('Remarks', registration['remarks']),
          ]),
          _section('Payment History', _loading
              ? [const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))]
              : _payments.isEmpty
                  ? [_row('Payments', 'No monthly payments')]
                  : _payments.map((payment) => _row(payment['billingMonth'], '₹${payment['amount']} · ${payment['status']}')).toList()),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2A3A5C))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)), const SizedBox(height: 10), ...children],),
  );

  Widget _row(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12))), Expanded(flex: 2, child: Text(value?.toString().isNotEmpty == true ? value.toString() : 'N/A', style: const TextStyle(color: Colors.white, fontSize: 13)))],),
  );
}
