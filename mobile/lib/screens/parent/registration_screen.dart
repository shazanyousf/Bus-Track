import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';

class RegistrationScreen extends StatefulWidget {
  final Map? preselectedBus;
  final VoidCallback? onDone;

  const RegistrationScreen({super.key, this.preselectedBus, this.onDone});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameCtrl   = TextEditingController();
  final _idCtrl     = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  int _step = 0;

  List _buses   = [];
  List _routes  = [];
  Map? _selectedBus;
  String? _selectedDept;
  String? _selectedSemester;
  bool _loading = false;
  bool _submitted = false;

  final _departments = [
    'Computer Science', 'Software Engineering', 'Electrical Engineering',
    'Mechanical Engineering', 'Business Administration', 'Medicine',
    'Law', 'Architecture', 'Mathematics', 'Physics',
  ];

  final _semesters = ['1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.preselectedBus != null) {
      _selectedBus = widget.preselectedBus;
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getBuses(),
        ApiService.getRoutes(),
      ]);
      setState(() {
        _buses  = results[0];
        _routes = results[1];
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selectedBus == null) return;
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    try {
      await ApiService.submitRegistration(auth.token!, {
        'busId':   _selectedBus!['_id'],
        'routeId': _selectedBus!['routeId'] is Map
            ? _selectedBus!['routeId']['_id']
            : _selectedBus!['routeId'],
        'studentData': {
          'name':       _nameCtrl.text.trim(),
          'studentId':  _idCtrl.text.trim(),
          'department': _selectedDept,
          'semester':   _selectedSemester,
          'phone':      _phoneCtrl.text.trim(),
        }
      });
      setState(() { _submitted = true; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _SuccessView(onDone: () {
        if (widget.onDone != null) {
          widget.onDone!();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        title: const Text('Bus Registration',
            style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Step indicator
          Container(
            color: const Color(0xFF16213E),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: List.generate(3, (i) {
                final labels = ['Student Info', 'Select Bus', 'Confirm'];
                final done   = i < _step;
                final active = i == _step;
                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done || active
                                  ? const Color(0xFFFF6B35)
                                  : const Color(0xFF2A3A5C),
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                          color: active ? Colors.white : const Color(0xFF8892A4),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(labels[i],
                              style: TextStyle(
                                  color: active
                                      ? const Color(0xFFFF6B35)
                                      : const Color(0xFF8892A4),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (i < 2)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 20),
                            color: i < _step
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFF2A3A5C),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: [
                _StudentInfoStep(
                  nameCtrl:  _nameCtrl,
                  idCtrl:    _idCtrl,
                  phoneCtrl: _phoneCtrl,
                  selectedDept:     _selectedDept,
                  selectedSemester: _selectedSemester,
                  departments: _departments,
                  semesters:   _semesters,
                  onDeptChanged:     (v) => setState(() => _selectedDept = v),
                  onSemesterChanged: (v) => setState(() => _selectedSemester = v),
                  onNext: () => setState(() => _step = 1),
                ),
                _SelectBusStep(
                  buses:       _buses,
                  selectedBus: _selectedBus,
                  onSelect:    (b) => setState(() { _selectedBus = b; _step = 2; }),
                  onBack:      () => setState(() => _step = 0),
                ),
                _ConfirmStep(
                  nameCtrl:   _nameCtrl,
                  idCtrl:     _idCtrl,
                  dept:       _selectedDept,
                  semester:   _selectedSemester,
                  selectedBus: _selectedBus,
                  loading:    _loading,
                  onSubmit:   _submit,
                  onBack:     () => setState(() => _step = 1),
                ),
              ][_step],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentInfoStep extends StatelessWidget {
  final TextEditingController nameCtrl, idCtrl, phoneCtrl;
  final String? selectedDept, selectedSemester;
  final List departments, semesters;
  final ValueChanged<String?> onDeptChanged, onSemesterChanged;
  final VoidCallback onNext;

  const _StudentInfoStep({
    required this.nameCtrl, required this.idCtrl, required this.phoneCtrl,
    required this.selectedDept, required this.selectedSemester,
    required this.departments, required this.semesters,
    required this.onDeptChanged, required this.onSemesterChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Student Information',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        _Field(label: 'Full Name', ctrl: nameCtrl, hint: 'e.g. Ahmed Khan'),
        const SizedBox(height: 14),
        _Field(label: 'Student ID', ctrl: idCtrl, hint: 'e.g. CS-2021-001'),
        const SizedBox(height: 14),
        _Field(label: 'Phone Number', ctrl: phoneCtrl, hint: '+92-300-0000000', type: TextInputType.phone),
        const SizedBox(height: 14),
        _DropdownField(
          label: 'Department',
          value: selectedDept,
          items: departments.cast<String>(),
          hint: 'Select Department',
          onChanged: onDeptChanged,
        ),
        const SizedBox(height: 14),
        _DropdownField(
          label: 'Semester',
          value: selectedSemester,
          items: semesters.cast<String>(),
          hint: 'Select Semester',
          onChanged: onSemesterChanged,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Next: Select Bus →',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _SelectBusStep extends StatelessWidget {
  final List buses;
  final Map? selectedBus;
  final ValueChanged<Map> onSelect;
  final VoidCallback onBack;

  const _SelectBusStep({
    required this.buses, required this.selectedBus,
    required this.onSelect, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select a Bus',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Choose an available bus for your student',
            style: TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
        const SizedBox(height: 20),
        ...buses.map((bus) {
          final available = bus['availableSeats'] ?? 0;
          final route     = bus['routeId'] as Map? ?? {};
          final isSelected = selectedBus?['_id'] == bus['_id'];
          return GestureDetector(
            onTap: available > 0 ? () => onSelect(bus) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35).withOpacity(0.1)
                    : const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFF2A3A5C),
                ),
              ),
              child: Row(
                children: [
                  const Text('🚌', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(bus['busNumber'] ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(route['routeName'] ?? '',
                            style: const TextStyle(
                                color: Color(0xFF8892A4), fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$available',
                          style: TextStyle(
                              color: available == 0
                                  ? const Color(0xFFE74C3C)
                                  : const Color(0xFF2ECC71),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      const Text('seats',
                          style: TextStyle(color: Color(0xFF8892A4), fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2A3A5C)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('← Back',
                style: TextStyle(color: Color(0xFF8892A4))),
          ),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final TextEditingController nameCtrl, idCtrl;
  final String? dept, semester;
  final Map? selectedBus;
  final bool loading;
  final VoidCallback onSubmit, onBack;

  const _ConfirmStep({
    required this.nameCtrl, required this.idCtrl,
    required this.dept, required this.semester,
    required this.selectedBus, required this.loading,
    required this.onSubmit, required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final route = selectedBus?['routeId'] as Map? ?? {};
    final rows  = [
      ['Student Name', nameCtrl.text.isEmpty ? 'N/A' : nameCtrl.text],
      ['Student ID',   idCtrl.text.isEmpty ? 'N/A' : idCtrl.text],
      ['Department',   dept ?? 'N/A'],
      ['Semester',     semester != null ? '$semester Semester' : 'N/A'],
      ['Bus',          selectedBus?['busNumber'] ?? 'N/A'],
      ['Route',        route['routeName'] ?? 'N/A'],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Confirm Registration',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A3A5C)),
          ),
          child: Column(
            children: List.generate(rows.length, (i) => Padding(
              padding: EdgeInsets.only(bottom: i < rows.length - 1 ? 14 : 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i][0],
                      style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13)),
                  Text(rows[i][1],
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            )),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7C948).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF7C948).withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFFF7C948), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your request will be reviewed by admin within 24 hours.',
                  style: TextStyle(color: Color(0xFFF7C948), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: loading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Submit Registration ✓',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2A3A5C)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('← Back', style: TextStyle(color: Color(0xFF8892A4))),
          ),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2ECC71).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFF2ECC71), width: 2),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF2ECC71), size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Registration Submitted!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                  'Your request has been submitted. University admin will review and confirm within 24 hours.',
                  style: TextStyle(color: Color(0xFF8892A4), fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Back to Dashboard',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? type;

  const _Field({required this.label, required this.ctrl, required this.hint, this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF8892A4), fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label, hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label, required this.hint, required this.value,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF8892A4), fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A3A5C)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(hint, style: const TextStyle(color: Color(0xFF4A5568))),
              dropdownColor: const Color(0xFF16213E),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              isExpanded: true,
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
