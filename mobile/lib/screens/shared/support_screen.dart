import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

const _supportNavy = Color(0xFF16213E);
const _supportBackground = Color(0xFF0F0F1A);
const _supportBorder = Color(0xFF2A3A5C);
const _supportMuted = Color(0xFF8892A4);
const _supportOrange = Color(0xFFFF6B35);

class ParentSupportScreen extends StatefulWidget {
  const ParentSupportScreen({super.key});
  @override
  State<ParentSupportScreen> createState() => _ParentSupportScreenState();
}

class _ParentSupportScreenState extends State<ParentSupportScreen> {
  List _queries = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final token = context.read<AuthService>().token!;
      final queries = await ApiService.getSupportQueries(token);
      if (mounted) setState(() { _queries = queries; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _raiseQuery() async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => const _RaiseQueryDialog(),
    );
    if (submitted == true && mounted) { await _load(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Query sent to admin'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _supportBackground,
    appBar: AppBar(title: const Text('Support'), backgroundColor: _supportNavy, foregroundColor: Colors.white, actions: [IconButton(onPressed: _raiseQuery, icon: const Icon(Icons.add_comment_rounded), tooltip: 'Raise query')]),
    body: _loading ? const Center(child: CircularProgressIndicator(color: _supportOrange)) : RefreshIndicator(
      onRefresh: _load, child: _queries.isEmpty ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No queries yet', style: TextStyle(color: _supportMuted)))]) : ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: _queries.length, itemBuilder: (_, index) => _QueryCard(query: _queries[index], admin: false)),
    ),
    floatingActionButton: FloatingActionButton.extended(onPressed: _raiseQuery, backgroundColor: _supportOrange, icon: const Icon(Icons.add_comment_rounded), label: const Text('Raise query')),
  );
}

class _RaiseQueryDialog extends StatefulWidget {
  const _RaiseQueryDialog();

  @override
  State<_RaiseQueryDialog> createState() => _RaiseQueryDialogState();
}

class _RaiseQueryDialogState extends State<_RaiseQueryDialog> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  PlatformFile? _attachment;
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
    );
    if (!mounted || result == null || result.files.single.bytes == null) return;
    setState(() => _attachment = result.files.single);
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ApiService.createSupportQuery(
        context.read<AuthService>().token!,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        attachmentBytes: _attachment?.bytes,
        attachmentName: _attachment?.name,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _supportNavy,
    title: const Text('Raise a query', style: TextStyle(color: Colors.white)),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      _field(_subject, 'Subject'),
      const SizedBox(height: 12),
      _field(_message, 'Describe the problem', maxLines: 5),
      const SizedBox(height: 10),
      Align(alignment: Alignment.centerLeft, child: TextButton.icon(
        onPressed: _submitting ? null : _pickAttachment,
        icon: const Icon(Icons.attach_file_rounded),
        label: Text(_attachment?.name ?? 'Add screenshot (optional)'),
      )),
    ])),
    actions: [
      TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
      FilledButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
        label: Text(_submitting ? 'Sending...' : 'Submit'),
      ),
    ],
  );
}

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  List _queries = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final data = await ApiService.getSupportQueries(context.read<AuthService>().token!); if (mounted) setState(() { _queries = data; _loading = false; }); }
    catch (_) { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _reply(Map query) async {
    final response = await showDialog<String>(
      context: context,
      builder: (_) => _ReplyDialog(initialResponse: query['adminResponse'] ?? ''),
    );
    if (response == null || response.isEmpty) return;
    try { await ApiService.replyToSupportQuery(context.read<AuthService>().token!, query['_id'].toString(), response); await _load(); }
    catch (error) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _supportBackground,
    appBar: AppBar(title: const Text('Parent Queries'), backgroundColor: _supportNavy, foregroundColor: Colors.white, leading: widget.onBack == null ? null : IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back))),
    body: _loading ? const Center(child: CircularProgressIndicator(color: _supportOrange)) : RefreshIndicator(onRefresh: _load, child: _queries.isEmpty ? ListView(children: const [SizedBox(height: 180), Center(child: Text('No parent queries', style: TextStyle(color: _supportMuted)))]) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _queries.length, itemBuilder: (_, index) => _QueryCard(query: _queries[index], admin: true, onReply: () => _reply(_queries[index])))),
  );
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog({required this.initialResponse});

  final String initialResponse;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialResponse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _supportNavy,
    title: const Text('Respond to query', style: TextStyle(color: Colors.white)),
    content: _field(_controller, 'Response', maxLines: 5),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton.icon(
        onPressed: () {
          final response = _controller.text.trim();
          if (response.isNotEmpty) Navigator.of(context).pop(response);
        },
        icon: const Icon(Icons.send_rounded),
        label: const Text('Send response'),
      ),
    ],
  );
}

Widget _field(TextEditingController controller, String label, {int maxLines = 1}) => TextField(
  controller: controller, maxLines: maxLines, style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: _supportMuted), filled: true, fillColor: _supportBackground, border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(10))),
);

class _QueryCard extends StatelessWidget {
  const _QueryCard({required this.query, required this.admin, this.onReply});
  final Map query; final bool admin; final VoidCallback? onReply;
  @override
  Widget build(BuildContext context) {
    final parent = query['parentId'] is Map ? query['parentId']['name'] : null;
    final resolved = query['status'] == 'resolved';
    return Card(color: _supportNavy, margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(query['subject'] ?? 'Query', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))), Chip(label: Text(resolved ? 'Resolved' : 'Open'), backgroundColor: (resolved ? Colors.green : _supportOrange).withValues(alpha: .2), labelStyle: TextStyle(color: resolved ? Colors.greenAccent : Colors.orangeAccent))]),
      if (parent != null) Text('From $parent', style: const TextStyle(color: _supportMuted, fontSize: 12)),
      const SizedBox(height: 10), Text(query['message'] ?? '', style: const TextStyle(color: Colors.white70)),
      if ((query['attachmentUrl'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: TextButton.icon(onPressed: () => launchUrl(Uri.parse(query['attachmentUrl'].toString()), mode: LaunchMode.externalApplication), icon: const Icon(Icons.image_rounded), label: const Text('View attachment'))),
      if ((query['adminResponse'] ?? '').toString().isNotEmpty) ...[const Divider(color: _supportBorder, height: 24), const Text('Admin response', style: TextStyle(color: _supportOrange, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(query['adminResponse'], style: const TextStyle(color: Colors.white70))],
      if (admin) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onReply, icon: const Icon(Icons.reply_rounded), label: Text(resolved ? 'Update response' : 'Respond'))),
    ])));
  }
}