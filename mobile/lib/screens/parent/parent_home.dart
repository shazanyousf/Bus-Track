import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../services/notification_service.dart';
import '../login_screen.dart';
import 'bus_list_screen.dart';
import 'registration_screen.dart';
import 'my_registrations_screen.dart';
import 'live_tracking_screen.dart';
import '../account_screen.dart';
import '../shared/notices_screen.dart';
import '../shared/support_screen.dart';

class ParentHome extends StatefulWidget {
  const ParentHome({super.key});

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
    final SocketService _socket = SocketService();
  int _currentIndex = 0;
  List _registrations = [];
  List _monthlyPayments = [];
  List _activeTrips = [];
  final Map<String, Map<String, dynamic>> _liveLocations = {};
  final Set<String> _completedBusIds = {};
  final Set<String> _listeningBusIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final parentId = (context.read<AuthService>().user?['_id'] ?? context.read<AuthService>().user?['id'])?.toString();
    _socket.connect(token: context.read<AuthService>().token);
    _socket.listenToProfileUpdates((_) {
      if (mounted) _loadData();
    });
    _socket.listenToRegistrationUpdates((update) {
      if (update['parentId']?.toString() != parentId) return;
      final isPayment = update['event'] == 'payment';
      final status = update['status']?.toString() ?? 'updated';
      final studentName = update['studentName']?.toString() ?? 'Student';
      NotificationService.instance.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: isPayment ? 'Payment Successful' : 'Registration $status',
        body: isPayment ? 'Your transport fee payment was received.' : '$studentName\'s bus registration was $status.',
      );
      if (mounted) _loadData();
    });
    _socket.listenToTripStarted((_) {
      _completedBusIds.clear();
      if (mounted) _loadData();
    });
    _socket.listenToTripCompleted((update) {
      if (mounted) {
        final busId = update['busId']?.toString();
        if (busId != null) {
          _completedBusIds.add(busId);
          _liveLocations.remove(busId);
        }
        _loadData();
        NotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Trip completed',
          body: 'The bus trip has ended. Live location is unavailable.',
        );
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _socket.stopListeningToProfileUpdates();
    _socket.stopListeningToRegistrationUpdates();
    _socket.stopListeningToTripEvents();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    debugPrint('[PARENT AUTH] Current user ID = ${auth.user?['_id'] ?? auth.user?['id']}');
    debugPrint('[PARENT AUTH] Current role = ${auth.user?['role']}');
    debugPrint('[PARENT AUTH] JWT exists = ${auth.token != null && auth.token!.isNotEmpty}');
    debugPrint('Flutter API BASE URL = ${ApiService.baseUrl}');
    debugPrint('Flutter Socket URL = ${_socket.socketUrl}');
    try {
      final regs = await ApiService.getRegistrations(auth.token!);
      List monthlyPayments = [];
      try {
        monthlyPayments = await ApiService.getMonthlyPayments(auth.token!);
      } catch (error) {
        debugPrint('[PARENT PAYMENTS FETCH] error = $error');
      }
      final assignedBusIds = regs
          .where((registration) => registration['status'] == 'active')
          .map((registration) => registration['busId']?['_id']?.toString())
          .whereType<String>()
          .toSet();
      for (final busId in assignedBusIds) {
        if (_listeningBusIds.add(busId)) {
          _socket.listenToBus(busId, (location) {
            if (!mounted) return;
            setState(() => _liveLocations[busId] = location);
          });
        }
      }
      setState(() {
        _registrations = regs;
        _monthlyPayments = monthlyPayments;
        _loading = false;
      });
      debugPrint('[PARENT REGISTRATION STATE] count=${_registrations.length}');
      for (final registration in _registrations) {
        final bus = registration['busId'];
        debugPrint('[PARENT ASSIGNMENT] registrationId=${registration['_id']} assignedBusId=${bus is Map ? bus['_id'] : bus}');
      }

      try {
        final trips = await ApiService.getActiveTrips(auth.token!);
        if (mounted) {
          setState(() {
            _activeTrips = trips.where((trip) => assignedBusIds.contains(trip['busId']?.toString())).toList();
          });
        }
      } catch (error) {
        debugPrint('[PARENT ACTIVE TRIPS FETCH] error = $error');
      }
    } catch (error) {
      debugPrint('[PARENT REGISTRATIONS FETCH] error = $error');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final approved = _registrations.where((r) => r['status'] == 'active').toList();
    debugPrint('[PARENT HOME BUILD] loading=$_loading registrations=${_registrations.length} approved=${approved.length}');

    final pages = [
      _DashboardTab(
        userName: auth.user?['name'] ?? 'Parent',
        approved: approved,
        monthlyPayments: _monthlyPayments,
        activeTrips: _activeTrips,
        liveLocations: _liveLocations,
        completedBusIds: _completedBusIds,
        loading: _loading,
        onRefresh: _loadData,
        onRegister: () => setState(() => _currentIndex = 2),
        onViewBuses: () => setState(() => _currentIndex = 1),
        onOpenPending: () => setState(() => _currentIndex = 3),
        onOpenNotices: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoticesScreen()),
          );
        },
        onOpenSupport: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentSupportScreen())),
      ),
      approved.isNotEmpty
          ? _AssignedBusPage(
              registrations: approved,
              monthlyPayments: _monthlyPayments,
              activeTrips: _activeTrips,
              liveLocations: _liveLocations,
              completedBusIds: _completedBusIds,
              onBack: () => setState(() => _currentIndex = 0),
            )
          : BusListScreen(onBack: () => setState(() => _currentIndex = 0)),
      RegistrationScreen(
        onDone: () => setState(() => _currentIndex = 0),
        onBack: () => setState(() => _currentIndex = 0),
      ),
      MyRegistrationsScreen(onBack: () => setState(() => _currentIndex = 0)),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16213E),
          border: Border(top: BorderSide(color: Color(0xFF2A3A5C))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            if (i == _currentIndex) return;
            setState(() => _currentIndex = i);
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: const Color(0xFF8892A4),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Buses'),
            BottomNavigationBarItem(icon: Icon(Icons.app_registration_rounded), label: 'Register'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'My Requests'),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final String userName;
  final List approved;
  final List monthlyPayments;
  final List activeTrips;
  final Map<String, Map<String, dynamic>> liveLocations;
  final Set<String> completedBusIds;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onRegister;
  final VoidCallback onViewBuses;
  final VoidCallback onOpenPending;
  final VoidCallback onOpenNotices;
  final VoidCallback onOpenSupport;

  const _DashboardTab({
    required this.userName,
    required this.approved,
    required this.monthlyPayments,
    required this.activeTrips,
    required this.liveLocations,
    required this.completedBusIds,
    required this.loading,
    required this.onRefresh,
    required this.onRegister,
    required this.onViewBuses,
    required this.onOpenPending,
    required this.onOpenNotices,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    final greetingName = userName.trim().isEmpty ? 'Parent' : userName.trim();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        color: const Color(0xFFFF6B35),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_graph_rounded, color: Color(0xFFFFA15F), size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Dashboard Overview',
                          style: TextStyle(
                            color: Color(0xFFFFB582),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                ],
              ),
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF16213E), Color(0xFF132742)],
                  ),
                  border: Border.all(color: const Color(0xFF2A3A5C)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Good Day,',
                              style: TextStyle(color: Color(0xFF8892A4), fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(greetingName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    _Avatar(name: greetingName),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (approved.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Assigned Bus',
                  subtitle: 'Your approved bus and driver details',
                ),
                const SizedBox(height: 12),
                ...approved.map((registration) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AssignedBusCard(
                    registration: registration,
                    monthlyPayments: monthlyPayments,
                    activeTrips: activeTrips,
                    liveLocations: liveLocations,
                    completedBusIds: completedBusIds,
                  ),
                )),
                const SizedBox(height: 24),
              ],

              // Quick actions
              const _SectionHeader(
                title: 'Quick Actions',
                subtitle: 'Common tasks for faster access',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.app_registration_rounded,
                      label: 'Register Bus',
                      color: const Color(0xFFFF6B35),
                      onTap: onRegister,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.directions_bus_rounded,
                      label: approved.isNotEmpty ? 'My Bus' : 'View Buses',
                      color: const Color(0xFF4A9EFF),
                      onTap: onViewBuses,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.receipt_long_rounded,
                      label: 'My Requests',
                      color: const Color(0xFF7B52FF),
                      onTap: onOpenPending,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.campaign_rounded,
                      label: 'Notice Board',
                      color: const Color(0xFFF7C948),
                      onTap: onOpenNotices,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.support_agent_rounded,
                label: 'Raise a Query',
                color: const Color(0xFF45D6C8),
                onTap: onOpenSupport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Show menu: Account / Sign Out
        final choice = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF16213E),
          builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(leading: const Icon(Icons.person), title: const Text('My Account'), onTap: () => Navigator.pop(context, 'account')),
            ListTile(leading: const Icon(Icons.logout), title: const Text('Sign Out'), onTap: () => Navigator.pop(context, 'logout')),
          ])),
        );
        if (choice == 'account' && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
          return;
        }
        if (choice == 'logout') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF16213E),
              title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
              content: const Text('Are you sure you want to sign out?',
                  style: TextStyle(color: Color(0xFF8892A4))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign Out',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (confirm == true && context.mounted) {
            await context.read<AuthService>().logout();
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          }
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8C55)]),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF8892A4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _AssignedBusCard extends StatelessWidget {
  final Map registration;
  final List monthlyPayments;
  final List activeTrips;
  final Map<String, Map<String, dynamic>> liveLocations;
  final Set<String> completedBusIds;

  const _AssignedBusCard({
    required this.registration,
    required this.monthlyPayments,
    required this.activeTrips,
    required this.liveLocations,
    required this.completedBusIds,
  });

  Map _safeMap(dynamic value) {
    if (value is Map) return value as Map;
    return {};
  }

  Future<void> _makeCall(String? phone, BuildContext context) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Phone number not available'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitizedPhone);
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not launch dialer'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _trackBus(Map bus, BuildContext context) {
    final busId = bus['_id'] ?? bus['busNumber'];
    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bus ID unavailable for tracking'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveTrackingScreen(bus: bus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus    = _safeMap(registration['busId']);
    final driver = _safeMap(bus['driverId']);
    final route  = _safeMap(registration['routeId']).isNotEmpty
        ? _safeMap(registration['routeId'])
        : _safeMap(bus['routeId']);
    final busId = bus['_id']?.toString();
    final matchingTrips = activeTrips.cast<Map>().where(
      (trip) => trip['busId']?.toString() == busId,
    ).toList();
    final activeTrip = matchingTrips.isEmpty ? null : matchingTrips.first;
    final registrationId = registration['_id']?.toString();
    final currentMonth = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
    final monthlyPayment = monthlyPayments.cast<Map>().where((payment) {
      final paymentRegistration = payment['registrationId'];
      final paymentRegistrationId = paymentRegistration is Map
        ? paymentRegistration['_id']
        : paymentRegistration;
      return paymentRegistrationId?.toString() == registrationId &&
        payment['billingMonth']?.toString() == currentMonth;
    }).firstOrNull;
    final location = busId == null ? null : liveLocations[busId];
    final hasLocation = location != null &&
      (location['lat'] is num || location['latitude'] is num) &&
      (location['lng'] is num || location['longitude'] is num);
    final status = completedBusIds.contains(busId) || bus['tripStatus'] == 'COMPLETED'
      ? 'TRIP COMPLETED'
      : activeTrip != null && activeTrip['status'] == 'ACTIVE' && activeTrip['trackingStatus'] == 'LIVE'
        ? hasLocation ? 'LIVE' : 'WAITING'
        : 'NOT TRACKING';
    final statusColor = status == 'LIVE'
      ? const Color(0xFF2ECC71)
      : status == 'WAITING'
        ? const Color(0xFFF7C948)
        : const Color(0xFF8892A4);
    debugPrint('[PARENT RENDER] buses.length=not_loaded_in_parent_home assignedBus=$bus assignedBusId=$busId busNumber=${bus['busNumber']} shouldRender=${bus.isNotEmpty && busId != null}');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16213E), Color(0xFF1A2A4D)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3A5C)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                    child: Icon(Icons.directions_bus_rounded, color: Color(0xFFFFA15F), size: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bus['busNumber'] ?? 'N/A',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    Text(route['routeName'] ?? 'Route not assigned',
                        style: const TextStyle(
                            color: Color(0xFF8892A4), fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.4)),
                ),
                  child: Text(status,
                    style: TextStyle(
                      color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF2A3A5C)),
          const SizedBox(height: 10),
          if (monthlyPayment != null) ...[
            Row(
              children: [
                const Icon(Icons.payments_rounded, color: Color(0xFFF7C948), size: 18),
                const SizedBox(width: 8),
                Text('Fee: ₹${monthlyPayment['amount'] ?? 0}', style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
                const Spacer(),
                Text(
                  monthlyPayment['status'] == 'PAID' ? 'PAID' : monthlyPayment['status'] == 'OVERDUE' ? 'OVERDUE' : 'PENDING',
                  style: TextStyle(
                    color: monthlyPayment['status'] == 'PAID' ? const Color(0xFF2ECC71) : monthlyPayment['status'] == 'OVERDUE' ? const Color(0xFFE74C3C) : const Color(0xFFF7C948),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A9EFF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_rounded, color: Color(0xFF4A9EFF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver['name'] ?? 'Not assigned',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(driver['phone'] ?? '',
                        style: const TextStyle(
                            color: Color(0xFF8892A4), fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _makeCall(driver['phone'] as String?, context),
                icon: const Icon(Icons.phone_rounded,
                    color: Color(0xFF2ECC71), size: 22),
              ),
              IconButton(
                onPressed: () => _trackBus(bus, context),
                icon: const Icon(Icons.location_on_rounded,
                    color: Color(0xFF4A9EFF), size: 22),
                tooltip: 'Track bus',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignedBusPage extends StatelessWidget {
  final List registrations;
  final List monthlyPayments;
  final List activeTrips;
  final Map<String, Map<String, dynamic>> liveLocations;
  final Set<String> completedBusIds;
  final VoidCallback? onBack;
  const _AssignedBusPage({
    required this.registrations,
    required this.monthlyPayments,
    required this.activeTrips,
    required this.liveLocations,
    required this.completedBusIds,
    this.onBack,
  });

  Map _safeMap(dynamic value) {
    if (value is Map) return value as Map;
    return {};
  }

  void _trackBus(Map bus, BuildContext context) {
    final busId = bus['_id'] ?? bus['busNumber'];
    if (busId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bus ID unavailable for tracking'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveTrackingScreen(bus: bus)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  tooltip: 'Back to home',
                ),
              const SizedBox(width: 8),
              const Text('My Buses', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          ...registrations.map((registration) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _AssignedBusCard(
              registration: registration,
              monthlyPayments: monthlyPayments,
              activeTrips: activeTrips,
              liveLocations: liveLocations,
              completedBusIds: completedBusIds,
            ),
          )),
        ],
        /*
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Back to home',
                  ),
                if (onBack != null) const SizedBox(width: 4),
                const Icon(Icons.directions_bus_rounded, color: Color(0xFFFF6B35), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bus['busNumber'] ?? 'My Bus',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Route: ${route['routeName'] ?? 'N/A'}',
                          style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                      Text('Bus Code: ${bus['busNumber'] ?? 'N/A'}',
                          style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                      if (route['routeCode'] != null && route['routeCode'].toString().isNotEmpty)
                        Text('Route Code: ${route['routeCode']}',
                            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2A3A5C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Driver', style: TextStyle(color: Color(0xFF8892A4), fontSize: 12)),
                  const SizedBox(height: 10),
                  Text(driver['name'] ?? 'Not assigned', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (driver['phone'] != null && driver['phone'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(driver['phone'], style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (stops.isNotEmpty) ...[
              const Text('Route Stops', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...List.generate(stops.length, (i) {
                final stop = stops[i] as Map;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3A5C)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF4A9EFF).withOpacity(0.2),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(stop['name'] ?? 'Stop', style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF2A3A5C)),
                ),
                child: const Text('Route stops are not configured yet. Please contact the admin.',
                    style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _trackBus(bus, context),
                icon: const Icon(Icons.location_on_rounded),
                label: const Text('Track Assigned Bus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A9EFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),*/
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF16213E),
                color.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.8), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
