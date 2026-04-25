import 'package:flutter/material.dart';

import '../../core/constants/report_type_ids.dart';
import '../../models/report_category.dart';
import '../../services/incidents_api_service.dart';
import 'report_submit_success_screen.dart';

class ReportFormScreen extends StatefulWidget {
  final ReportCategory category;

  const ReportFormScreen({super.key, required this.category});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final IncidentsApiService _apiService = IncidentsApiService();

  late final Map<String, TextEditingController> _controllers;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.category.fields)
        field.key: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _valueOf(String key) {
    return _controllers[key]?.text.trim() ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final reportTypeId =
        ReportTypeIds.fromCategoryId(widget.category.id);

    final title = _valueOf('title').isNotEmpty
        ? _valueOf('title')
        : widget.category.title;

    String description = '';

    switch (widget.category.id) {
      case 'phishing_sms':
        description = _valueOf('message');
        break;
      case 'email_phishing':
      case 'bank_impersonation':
      case 'suspicious_links':
      case 'account_hacking':
      case 'identity_theft':
      case 'shopping_fraud':
      case 'blackmail':
      case 'fake_gov':
      case 'qr_scam':
      case 'deepfake':
        description = _valueOf('details');
        break;
      case 'whatsapp_scams':
        description = _valueOf('content');
        break;
      default:
        description = _valueOf('details');
    }

    if (description.isEmpty) {
      description =
          'تم تقديم بلاغ من نوع: ${widget.category.title}';
    }

    final suspiciousUrl = _valueOf('link');
    final suspiciousMessage = _valueOf('message').isNotEmpty
        ? _valueOf('message')
        : _valueOf('content');
    final platform = _valueOf('platform').isNotEmpty
        ? _valueOf('platform')
        : _valueOf('source');
    final note = _valueOf('details');

    setState(() => _isSubmitting = true);

    try {
      final created = await _apiService.createIncident(
        title: title,
        description: description,
        reportTypeId: reportTypeId,
        suspiciousUrl:
            suspiciousUrl.isEmpty ? null : suspiciousUrl,
        suspiciousMessage:
            suspiciousMessage.isEmpty ? null : suspiciousMessage,
        platform: platform.isEmpty ? null : platform,
        note: note.isEmpty ? null : note,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReportSubmitSuccessScreen(
            categoryTitle: widget.category.title,
            incidentId: created.displayId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إرسال البلاغ:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.subtitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.category.description),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            ...widget.category.fields.map(
              (field) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: _controllers[field.key],
                  maxLines: field.maxLines,
                  validator: (value) {
                    if (field.required &&
                        (value == null ||
                            value.trim().isEmpty)) {
                      return 'هذا الحقل مطلوب';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: field.label,
                    hintText: field.hint,
                  ),
                ),
              ),
            ),

            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                        'رفع المرفقات سيُفعّل لاحقًا عند ربط endpoint الأدلة.'),
                  ),
                );
              },
              icon: const Icon(Icons.attach_file),
              label: const Text('إضافة مرفق'),
            ),

            const SizedBox(height: 20),

            FilledButton(
              onPressed:
                  _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('إرسال البلاغ'),
            ),
          ],
        ),
      ),
    );
  }
}