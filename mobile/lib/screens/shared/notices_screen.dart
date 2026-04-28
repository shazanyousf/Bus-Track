import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({
    super.key,
    this.adminMode = false,
  });

  final bool adminMode;

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  List _notices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    final auth = context.read<AuthService>();
    try {
      final notices = await ApiService.getNotices(auth.token!);
      if (!mounted) return;
      setState(() {
        _notices = notices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(_normalizeAttachmentUrl(url));
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to open attachment'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final attachmentCtrl = TextEditingController();

    String audience = 'all';
    String priority = 'important';
    DateTime? expiryDate;
    File? selectedFile;
    List<int>? selectedFileBytes;
    String? selectedFileName;
    bool pickingFile = false;

    Future<void> submit() async {
      final auth = context.read<AuthService>();
      if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Title and message are required'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      Navigator.pop(context);

      try {
        String? expiryIso;
        if (expiryDate != null) {
          final endOfDay = DateTime(
            expiryDate!.year,
            expiryDate!.month,
            expiryDate!.day,
            23,
            59,
            59,
          );
          expiryIso = endOfDay.toIso8601String();
        }

        await ApiService.createNotice(
          auth.token!,
          title: titleCtrl.text.trim(),
          message: messageCtrl.text.trim(),
          audience: audience,
          priority: priority,
          attachmentUrl: attachmentCtrl.text.trim(),
          expiresAt: expiryIso,
          attachmentFile: selectedFile,
          attachmentBytes: selectedFileBytes,
          attachmentName: selectedFileName,
        );

        if (!mounted) return;
        await _loadNotices();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notice published'),
          backgroundColor: Colors.green,
        ));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to publish notice: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Post Notice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _inputField(
                      controller: titleCtrl,
                      hint: 'Title',
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    _inputField(
                      controller: messageCtrl,
                      hint: 'Message',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 10),
                    _inputField(
                      controller: attachmentCtrl,
                      hint: 'Attachment URL (optional PDF/form link)',
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: pickingFile
                            ? null
                            : () async {
                              final messenger = ScaffoldMessenger.of(context);
                                FocusScope.of(context).unfocus();
                                setModalState(() => pickingFile = true);
                                try {
                                  final result = await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowMultiple: false,
                                    withData: true,
                                    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
                                  );

                                  if (result != null) {
                                    final picked = result.files.single;
                                    setModalState(() {
                                      selectedFile = picked.path != null ? File(picked.path!) : null;
                                      selectedFileBytes = picked.bytes;
                                      selectedFileName = picked.name;
                                    });
                                  }
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('File picker failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setModalState(() => pickingFile = false);
                                  }
                                }
                              },
                        icon: pickingFile
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.attach_file_rounded, color: Color(0xFFFF6B35)),
                        label: Text(
                          selectedFileName == null
                              ? (pickingFile ? 'Opening picker...' : 'Upload PDF/Image')
                              : selectedFileName!,
                          style: const TextStyle(color: Color(0xFFFF6B35)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2A3A5C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dropdown(
                            label: 'Audience',
                            value: audience,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All')),
                              DropdownMenuItem(value: 'parents', child: Text('Parents')),
                              DropdownMenuItem(value: 'drivers', child: Text('Drivers')),
                            ],
                            onChanged: (val) => setModalState(() => audience = val ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dropdown(
                            label: 'Priority',
                            value: priority,
                            items: const [
                              DropdownMenuItem(value: 'important', child: Text('Important')),
                              DropdownMenuItem(value: 'normal', child: Text('Normal')),
                            ],
                            onChanged: (val) => setModalState(() => priority = val ?? 'important'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDate: expiryDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() => expiryDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFFFF6B35)),
                      label: Text(
                        expiryDate == null
                            ? 'Set expiry (optional)'
                            : 'Expiry: ${expiryDate!.toIso8601String().substring(0, 10)}',
                        style: const TextStyle(color: Color(0xFFFF6B35)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Publish Notice'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteNotice(String id) async {
    final auth = context.read<AuthService>();
    try {
      await ApiService.deleteNotice(auth.token!, id);
      if (!mounted) return;
      await _loadNotices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to delete notice: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        elevation: 0,
        title: Text(widget.adminMode ? 'Notice Board (Admin)' : 'Notice Board'),
      ),
      floatingActionButton: widget.adminMode
          ? FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              label: const Text('Post Notice'),
              icon: const Icon(Icons.add_rounded),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            )
          : RefreshIndicator(
              onRefresh: _loadNotices,
              color: const Color(0xFFFF6B35),
              child: _notices.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(
                          child: Text(
                            'No notices available',
                            style: TextStyle(color: Color(0xFF8892A4)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notices.length,
                      itemBuilder: (_, index) {
                        final notice = _notices[index] as Map;
                        final title = notice['title']?.toString() ?? '';
                        final message = notice['message']?.toString() ?? '';
                        final audience = notice['audience']?.toString() ?? 'all';
                        final priority = notice['priority']?.toString() ?? 'normal';
                        final attachment = notice['attachmentUrl']?.toString() ?? '';
                        final id = notice['_id']?.toString() ?? '';
                        final expiresAt = notice['expiresAt']?.toString();

                        final isImportant = priority == 'important';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16213E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isImportant
                                  ? const Color(0xFFFF6B35).withValues(alpha: 0.45)
                                  : const Color(0xFF2A3A5C),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (widget.adminMode && id.isNotEmpty)
                                    IconButton(
                                      onPressed: () => _deleteNotice(id),
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          color: Colors.redAccent),
                                    ),
                                ],
                              ),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: Color(0xFFB7C1D3),
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _tag(audience.toUpperCase(), const Color(0xFF4A9EFF)),
                                  _tag(
                                    isImportant ? 'IMPORTANT' : 'NORMAL',
                                    isImportant
                                        ? const Color(0xFFFF6B35)
                                        : const Color(0xFF2ECC71),
                                  ),
                                  if (expiresAt != null && expiresAt.isNotEmpty)
                                    _tag(
                                      'EXP ${expiresAt.substring(0, 10)}',
                                      const Color(0xFFF7C948),
                                    ),
                                ],
                              ),
                              if (attachment.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                TextButton.icon(
                                  onPressed: () => _openAttachment(attachment),
                                  icon: const Icon(Icons.picture_as_pdf_rounded,
                                      color: Color(0xFFFF6B35)),
                                  label: const Text(
                                    'Open Attachment',
                                    style: TextStyle(color: Color(0xFFFF6B35)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8892A4)),
        filled: true,
        fillColor: const Color(0xFF0F0F1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF16213E),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8892A4)),
        filled: true,
        fillColor: const Color(0xFF0F0F1A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  String _normalizeAttachmentUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (!url.startsWith('/')) return url;

    final apiUri = Uri.parse(ApiService.baseUrl);
    final rootPath = apiUri.path.endsWith('/api')
        ? apiUri.path.substring(0, apiUri.path.length - 4)
        : apiUri.path;

    final root = Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: rootPath,
    ).toString();

    return '$root$url';
  }
}
