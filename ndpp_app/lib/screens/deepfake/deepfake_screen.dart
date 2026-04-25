import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/deepfake_api_service.dart';

class DeepfakeScreen extends StatefulWidget {
  const DeepfakeScreen({super.key});

  @override
  State<DeepfakeScreen> createState() => _DeepfakeScreenState();
}

class _DeepfakeScreenState extends State<DeepfakeScreen> {
  final DeepfakeApiService _apiService = DeepfakeApiService();

  static const int _userId = 1;

  bool _isAnalyzing = false;
  bool _isLoadingHistory = true;
  DeepfakeApiResult? _latestResult;
  String? _errorMessage;

  List<DeepfakeApiResult> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _apiService.getHistory(userId: _userId);

      if (!mounted) return;

      setState(() {
        _history = history;
        _latestResult = history.isNotEmpty ? history.first : null;
        _isLoadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    try {
      await _apiService.clearHistory(userId: _userId);

      if (!mounted) return;

      setState(() {
        _history = [];
        _latestResult = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickAndAnalyzeImage() async {
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: false,
        type: FileType.image,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isAnalyzing = false);
        return;
      }

      final file = result.files.first;

      if (file.bytes == null) {
        throw Exception('تعذر قراءة الصورة');
      }

      final analysis = await _apiService.analyzeImage(
        bytes: file.bytes!,
        fileName: file.name,
      );

      final saved = await _apiService.saveScan(
        userId: _userId,
        result: analysis,
      );

      if (!mounted) return;

      setState(() {
        _latestResult = saved;
        _history.insert(0, saved);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  bool _isSuspicious(String result) {
    final value = result.toLowerCase();
    return value.contains('fake') ||
        value.contains('ai') ||
        value.contains('generated') ||
        value.contains('phishing') ||
        value.contains('scam') ||
        value.contains('suspicious');
  }

  Color _resultColor(String result) {
    return _isSuspicious(result)
        ? const Color(0xFFB91C1C)
        : const Color(0xFF166534);
  }

  IconData _resultIcon(String result) {
    return _isSuspicious(result)
        ? Icons.warning_amber_rounded
        : Icons.verified;
  }

  String _resultLabel(String result) {
    final value = result.toUpperCase();

    if (value.contains('PHISHING')) return 'محتوى مشبوه';
    if (value.contains('FAKE')) return 'Fake';
    if (value.contains('REAL')) return 'Real';

    return result;
  }

  String _confidenceLabel(double confidence) {
    return '${(confidence * 100).toStringAsFixed(0)}%';
  }

  Widget _buildLatestResult() {
    final latest = _latestResult;

    if (latest == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('لم يتم إجراء تحليل بعد'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _resultIcon(latest.result),
              size: 52,
              color: _resultColor(latest.result),
            ),
            const SizedBox(height: 12),
            Text(
              _resultLabel(latest.result),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _resultColor(latest.result),
              ),
            ),
            const SizedBox(height: 8),
            Text('Confidence: ${_confidenceLabel(latest.confidence)}'),
            const SizedBox(height: 8),
            Text(
              latest.fileName,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Text(
              'تاريخ الفحص: ${latest.createdAtLabel}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_isLoadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا يوجد سجل فحوصات بعد'),
        ),
      );
    }

    return Column(
      children: _history.map((scan) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _isSuspicious(scan.result)
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFDCFCE7),
                child: Icon(
                  _isSuspicious(scan.result) ? Icons.close : Icons.check,
                  color: _resultColor(scan.result),
                ),
              ),
              title: Text(scan.fileName),
              subtitle: Text(
                'النتيجة: ${_resultLabel(scan.result)} • ${_confidenceLabel(scan.confidence)}',
              ),
              trailing: Text(
                scan.createdAtLabel,
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
        title: const Text('فحص Deepfake'),
        actions: [
          IconButton(
            onPressed: _history.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'مسح السجل',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ارفع صورة لفحصها',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اختر صورة وسيتم تحليلها وحفظ النتيجة في سجل الفحوصات.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isAnalyzing ? null : _pickAndAnalyzeImage,
                      icon: _isAnalyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        _isAnalyzing
                            ? 'جاري التحليل...'
                            : 'اختيار صورة وتحليلها',
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'آخر نتيجة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildLatestResult(),
            const SizedBox(height: 20),
            const Text(
              'سجل الفحوصات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildHistory(),
          ],
        ),
      ),
    );
  }
}