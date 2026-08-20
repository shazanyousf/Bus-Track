import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../account_screen.dart';
import '../login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.onOpenBuses,
    required this.onOpenRequests,
    required this.onOpenDrivers,
    required this.onManageNotices,
    required this.onDownloadReports,
  });

  final VoidCallback onOpenBuses;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenDrivers;
  final VoidCallback onManageNotices;
  final VoidCallback onDownloadReports;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final token = context.read<AuthService>().token;
      if (token == null) throw Exception('You are not signed in');
      final stats = await ApiService.getAdminDashboardStats(token);
      if (mounted) setState(() { _stats = stats; _loading = false; });
    } catch (error) {
      if (mounted) setState(() { _error = error.toString(); _loading = false; });
    }
  }

  int _number(String key) => (_stats?[key] as num?)?.toInt() ?? 0;
  List _list(String key) => _stats?[key] as List? ?? [];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final adminName = (auth.user?['name'] as String?)?.trim();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: _orange,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          children: [
            _Header(
              adminName: adminName == null || adminName.isEmpty ? 'Administrator' : adminName,
              onAccount: _openAccount,
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 100), child: Center(child: CircularProgressIndicator(color: _orange)))
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _load)
            else ...[
              _SectionTitle(title: 'At a glance', subtitle: 'Live transport operations overview'),
              const SizedBox(height: 12),
              _SummaryGrid(items: [
                _SummaryItem('Students', _number('students'), Icons.school_rounded, _blue),
                _SummaryItem('Buses', _number('buses'), Icons.directions_bus_rounded, _orange),
                _SummaryItem('Drivers', _number('drivers'), Icons.badge_rounded, _purple),
                _SummaryItem('Pending requests', _number('pendingRegistrations'), Icons.hourglass_top_rounded, _yellow),
                _SummaryItem('Active registrations', _number('activeRegistrations'), Icons.verified_rounded, _green),
                _SummaryItem('Tracking now', _number('trackingBuses'), Icons.location_on_rounded, _teal),
              ]),
              const SizedBox(height: 24),
              _Attention(stats: _stats!, onRequests: widget.onOpenRequests, onBuses: widget.onOpenBuses),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Registration overview', subtitle: 'Current application pipeline'),
              const SizedBox(height: 12),
              _RegistrationOverview(stats: _stats!),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Payment overview', subtitle: 'Verified Razorpay payments only'),
              const SizedBox(height: 12),
              _PaymentOverview(stats: _stats!),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Bus fleet', subtitle: 'Capacity and current availability'),
              const SizedBox(height: 12),
              _FleetOverview(stats: _stats!, onOpenBuses: widget.onOpenBuses),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Quick actions', subtitle: 'Jump to a management area'),
              const SizedBox(height: 12),
              _QuickActions(items: [
                _ActionItem('Registration Requests', Icons.assignment_rounded, _blue, widget.onOpenRequests),
                _ActionItem('Buses', Icons.directions_bus_rounded, _orange, widget.onOpenBuses),
                _ActionItem('Drivers', Icons.badge_rounded, _purple, widget.onOpenDrivers),
                _ActionItem('Reports', Icons.description_rounded, _teal, widget.onDownloadReports),
                _ActionItem('Notices', Icons.campaign_rounded, _yellow, widget.onManageNotices),
              ]),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Recent activity', subtitle: 'Latest updates from the system'),
              const SizedBox(height: 12),
              _ActivityList(items: _list('activities')),
            ],
          ],
        ),
      ),
    );
  }

  void _openAccount() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _navy,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.person_outline, color: Colors.white), title: const Text('My Account', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, 'account')),
        ListTile(leading: const Icon(Icons.logout, color: Colors.white), title: const Text('Sign Out', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(context, 'logout')),
      ])),
    );
    if (!mounted) return;
    if (choice == 'account') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
    } else if (choice == 'logout') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _navy,
          title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          content: const Text('Sign out of admin panel?', style: TextStyle(color: _muted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign Out', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await context.read<AuthService>().logout();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }
}

const _navy = Color(0xFF16213E);
const _background = Color(0xFF0F0F1A);
const _border = Color(0xFF2A3A5C);
const _muted = Color(0xFF8892A4);
const _orange = Color(0xFFFF6B35);
const _blue = Color(0xFF4A9EFF);
const _purple = Color(0xFF9B8AFB);
const _yellow = Color(0xFFF7C948);
const _green = Color(0xFF2ECC71);
const _teal = Color(0xFF45D6C8);

class _Header extends StatelessWidget {
  const _Header({required this.adminName, required this.onAccount});
  final String adminName;
  final VoidCallback onAccount;
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('BusTrack University', style: TextStyle(color: _orange, fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      const Text('Transport Management Overview', style: TextStyle(color: _muted, fontSize: 12)),
      const SizedBox(height: 4),
      Text(adminName, style: const TextStyle(color: Color(0xFFB8C2D3), fontSize: 12)),
    ])),
    IconButton(onPressed: onAccount, tooltip: 'Account menu', icon: const Icon(Icons.account_circle_outlined, color: Colors.white, size: 32)),
  ]);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
    const SizedBox(height: 3),
    Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
  ]);
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon, this.color);
  final String label; final int value; final IconData icon; final Color color;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});
  final List<_SummaryItem> items;
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55),
    itemBuilder: (_, index) { final item = items[index]; return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(item.icon, color: item.color, size: 20), Text('${item.value}', style: TextStyle(color: item.color, fontSize: 25, fontWeight: FontWeight.w800)), Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600))])); },
  );
}

class _RegistrationOverview extends StatelessWidget {
  const _RegistrationOverview({required this.stats});
  final Map<String, dynamic> stats;
  @override
  Widget build(BuildContext context) {
    final values = [('Pending', stats['pendingRegistrations'] ?? 0, _yellow), ('Approved', stats['approvedRegistrations'] ?? 0, _blue), ('Rejected', stats['rejectedRegistrations'] ?? 0, const Color(0xFFE74C3C)), ('Active', stats['activeRegistrations'] ?? 0, _green)];
    final total = values.fold<int>(0, (sum, item) => sum + (item.$2 as num).toInt());
    return _Panel(child: Column(children: values.map((item) { final value = (item.$2 as num).toInt(); final ratio = total == 0 ? 0.0 : value / total; return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [SizedBox(width: 78, child: Text(item.$1, style: const TextStyle(color: _muted, fontSize: 12))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: _background, color: item.$3))), const SizedBox(width: 10), SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))) ])); }).toList()));
  }
}

class _PaymentOverview extends StatelessWidget {
  const _PaymentOverview({required this.stats});
  final Map<String, dynamic> stats;
  @override
  Widget build(BuildContext context) => _Panel(child: Row(children: [
    _Metric(label: 'Paid', value: '${stats['paidPayments'] ?? 0}', color: _green),
    _Metric(label: 'Pending', value: '${stats['pendingPayments'] ?? 0}', color: _yellow),
    _Metric(label: 'Collected', value: '₹${_formatAmount(stats['totalCollected'])}', color: _orange),
  ]));
}

class _FleetOverview extends StatelessWidget {
  const _FleetOverview({required this.stats, required this.onOpenBuses});
  final Map<String, dynamic> stats; final VoidCallback onOpenBuses;
  @override
  Widget build(BuildContext context) {
    final buses = stats['busFleet'] as List? ?? [];
    return _Panel(child: Column(children: [
      Row(children: [_Metric(label: 'Total', value: '${stats['buses'] ?? 0}', color: Colors.white), _Metric(label: 'Active', value: '${stats['activeBuses'] ?? 0}', color: _green), _Metric(label: 'Tracking', value: '${stats['trackingBuses'] ?? 0}', color: _teal)]),
      if (buses.isNotEmpty) ...[const Divider(color: _border, height: 24), ...buses.take(4).map((bus) { final total = (bus['totalSeats'] as num?)?.toInt() ?? 0; final available = (bus['availableSeats'] as num?)?.toInt() ?? 0; final used = total - available; return Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [SizedBox(width: 68, child: Text('${bus['busNumber']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))), Expanded(child: LinearProgressIndicator(value: total == 0 ? 0 : used / total, minHeight: 6, backgroundColor: _background, color: available == 0 ? const Color(0xFFE74C3C) : _blue)), const SizedBox(width: 10), Text('$used / $total', style: const TextStyle(color: _muted, fontSize: 11))])); })],
      if (buses.isEmpty) const _EmptyText('No buses registered'),
      Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onOpenBuses, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: const Text('Manage fleet'))),
    ]));
  }
}

class _Attention extends StatelessWidget {
  const _Attention({required this.stats, required this.onRequests, required this.onBuses});
  final Map<String, dynamic> stats; final VoidCallback onRequests; final VoidCallback onBuses;
  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final pending = (stats['pendingRegistrations'] as num?)?.toInt() ?? 0;
    final payments = (stats['pendingPayments'] as num?)?.toInt() ?? 0;
    final buses = (stats['buses'] as num?)?.toInt() ?? 0;
    final activeBuses = (stats['activeBuses'] as num?)?.toInt() ?? 0;
    if (pending > 0) items.add(_AlertRow(icon: Icons.assignment_late_rounded, text: '$pending registrations pending approval', onTap: onRequests));
    if (payments > 0) items.add(_AlertRow(icon: Icons.payments_outlined, text: '$payments approved registrations awaiting payment', onTap: onRequests));
    if (buses - activeBuses > 0) items.add(_AlertRow(icon: Icons.directions_bus_outlined, text: '${buses - activeBuses} buses need attention', onTap: onBuses));
    if (items.isEmpty) return const SizedBox.shrink();
    return _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Attention required', style: TextStyle(color: _yellow, fontWeight: FontWeight.w800, fontSize: 14)), const SizedBox(height: 10), ...items]));
  }
}

class _AlertRow extends StatelessWidget { const _AlertRow({required this.icon, required this.text, required this.onTap}); final IconData icon; final String text; final VoidCallback onTap; @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(icon, color: _yellow, size: 18), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFD6DCEA), fontSize: 12))), const Icon(Icons.chevron_right_rounded, color: _muted, size: 18)]))); }
class _Metric extends StatelessWidget { const _Metric({required this.label, required this.value, required this.color}); final String label, value; final Color color; @override Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: color, fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: _muted, fontSize: 11))])); }
class _Panel extends StatelessWidget { const _Panel({required this.child}); final Widget child; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)), child: child); }
class _EmptyText extends StatelessWidget { const _EmptyText(this.text); final String text; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(text, style: const TextStyle(color: _muted, fontSize: 12))); }

class _QuickActions extends StatelessWidget { const _QuickActions({required this.items}); final List<_ActionItem> items; @override Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => ActionChip(avatar: Icon(item.icon, color: item.color, size: 17), label: Text(item.label), labelStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), backgroundColor: _navy, side: const BorderSide(color: _border), onPressed: item.onTap)).toList()); }
class _ActionItem { const _ActionItem(this.label, this.icon, this.color, this.onTap); final String label; final IconData icon; final Color color; final VoidCallback onTap; }

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items});
  final List items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _Panel(child: _EmptyText('No recent activity'));
    return _Panel(
      child: Column(
        children: items.take(8).map<Widget>((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['type']?.toString() ?? 'Activity', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(item['detail']?.toString() ?? '', style: const TextStyle(color: _muted, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget { const _ErrorState({required this.message, required this.onRetry}); final String message; final VoidCallback onRetry; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 80), child: Column(children: [const Icon(Icons.cloud_off_rounded, color: _muted, size: 40), const SizedBox(height: 12), const Text('Dashboard data unavailable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 11)), const SizedBox(height: 12), OutlinedButton(onPressed: onRetry, child: const Text('Retry'))])); }

String _formatAmount(dynamic value) {
  final amount = (value as num?)?.toDouble() ?? 0;
  return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
}
