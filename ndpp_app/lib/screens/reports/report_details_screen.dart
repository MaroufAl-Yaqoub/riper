import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/mock_data.dart';
import '../../models/incident_analysis.dart';
import '../../models/incident_report.dart';
import '../../models/incident_update.dart';
import '../../services/incidents_api_service.dart';

class ReportDetailsScreen extends StatefulWidget {
  final IncidentReport report;

  const ReportDetailsScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final IncidentsApiService _apiService = IncidentsApiService();

  late Future<_ReportDetailsData> _future;
  bool _isAnalyzing = false;
  bool _isUploadingEvidence = false;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ReportDetailsData> _loadData() async {
    final details = await _apiService.getIncidentById(widget.report.incidentId);
    final updates =
        await _apiService.getIncidentUpdates(widget.report.incidentId);
    final analysis =
        await _apiService.getLatestAnalysis(widget.report.incidentId);

    return _ReportDetailsData(
      report: details,
      updates: updates,
      analysis: analysis,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  Future<void> _uploadEvidence() async {
    setState(() => _isUploadingEvidence = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;

      if (file.bytes == null) {
        throw Exception('تعذر قراءة الملف');
      }

      await _apiService.uploadEvidence(
        incidentId: widget.report.incidentId,
        bytes: file.bytes!,
        fileName: file.name,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الدليل بنجاح')),
      );

      await _refresh();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفع الدليل:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingEvidence = false);
      }
    }
  }

  Future<void> _analyzeIncident() async {
    setState(() => _isAnalyzing = true);

    try {
      await _apiService.analyzeIncident(widget.report.incidentId);
      await _refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحليل البلاغ بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تحليل البلاغ:\n$e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  int _statusStep(String statusKey) {
    switch (statusKey) {
      case 'SUBMITTED':
        return 0;
      case 'UNDER_REVIEW':
        return 1;
      case 'IN_ANALYSIS':
        return 2;
      case 'RESOLVED':
      case 'REJECTED':
      case 'CLOSED':
        return 3;
      default:
        return 0;
    }
  }

  List<Step> _buildSteps(String statusKey) {
    final lastTitle = statusKey == 'REJECTED'
        ? 'مرفوض'
        : statusKey == 'CLOSED'
            ? 'مغلق'
            : 'تم الحل';

    final currentStep = _statusStep(statusKey);

    final titles = [
      'تم الإرسال',
      'قيد المراجعة',
      'قيد التحليل',
      lastTitle,
    ];

    return List.generate(
      titles.length,
      (index) => Step(
        title: Text(titles[index]),
        content: const SizedBox.shrink(),
        isActive: index <= currentStep,
        state: index < currentStep
            ? StepState.complete
            : index == currentStep
                ? StepState.indexed
                : StepState.disabled,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(IncidentAnalysis? analysis) {
    if (analysis == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لا توجد نتيجة تحليل حتى الآن',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeIncident,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _isAnalyzing
                      ? 'جاري التحليل...'
                      : 'تحليل البلاغ بالذكاء الاصطناعي',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نتيجة تحليل الذكاء الاصطناعي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _infoRow('التصنيف', analysis.predictedLabel),
            _infoRow('الثقة', analysis.confidenceLabel),
            _infoRow('درجة الخطورة', analysis.riskLabel),
            _infoRow('النموذج', analysis.modelName),
            _infoRow('الإصدار', analysis.modelVersion),
            if (analysis.explanation != null &&
                analysis.explanation!.trim().isNotEmpty)
              _infoRow('التفسير', analysis.explanation!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeIncident,
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isAnalyzing ? 'جاري التحليل...' : 'إعادة التحليل'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesList(List<IncidentUpdate> updates) {
    if (updates.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد تحديثات متاحة لهذا البلاغ حتى الآن'),
        ),
      );
    }

    return Column(
      children: updates.map((update) {
        final label = update.statusKey != null
            ? MockData.statusLabel(update.statusKey!)
            : 'تحديث';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.update)),
              title: Text(label),
              subtitle: Text(
                (update.note != null && update.note!.trim().isNotEmpty)
                    ? update.note!
                    : 'لا توجد ملاحظة',
              ),
              trailing: Text(
                update.createdAtLabel,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل البلاغ'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<_ReportDetailsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر تحميل تفاصيل البلاغ:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final report = data.report;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _infoRow('رقم البلاغ', report.displayId),
                        _infoRow(
                          'الحالة',
                          MockData.statusLabel(report.statusKey),
                        ),
                        _infoRow('التاريخ', report.createdAtLabel),
                        if (report.suspiciousUrl != null &&
                            report.suspiciousUrl!.trim().isNotEmpty)
                          _infoRow('الرابط', report.suspiciousUrl!),
                        const SizedBox(height: 12),
                        const Text(
                          'وصف البلاغ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(report.description),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed:
                              _isUploadingEvidence ? null : _uploadEvidence,
                          icon: _isUploadingEvidence
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.attach_file),
                          label: Text(
                            _isUploadingEvidence
                                ? 'جاري رفع الدليل...'
                                : 'رفع دليل (صورة / ملف)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'تحليل البلاغ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildAnalysisCard(data.analysis),
                const SizedBox(height: 20),
                const Text(
                  'متابعة البلاغ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Stepper(
                    currentStep: _statusStep(report.statusKey),
                    controlsBuilder: (context, details) =>
                        const SizedBox.shrink(),
                    steps: _buildSteps(report.statusKey),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'سجل التحديثات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildUpdatesList(data.updates),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportDetailsData {
  final IncidentReport report;
  final List<IncidentUpdate> updates;
  final IncidentAnalysis? analysis;

  const _ReportDetailsData({
    required this.report,
    required this.updates,
    required this.analysis,
  });
}