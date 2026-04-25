import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/incident_report.dart';
import '../../services/incidents_api_service.dart';
import 'report_details_screen.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  final IncidentsApiService _apiService = IncidentsApiService();
  late Future<List<IncidentReport>> _futureReports;

  @override
  void initState() {
    super.initState();
    _futureReports = _apiService.getIncidents();
  }

  Future<void> _reload() async {
    setState(() {
      _futureReports = _apiService.getIncidents();
    });
    await _futureReports;
  }

  Color _statusColor(String key) {
    switch (key) {
      case 'RESOLVED':
        return const Color(0xFF166534);
      case 'UNDER_REVIEW':
      case 'IN_ANALYSIS':
        return const Color(0xFF854D0E);
      case 'REJECTED':
      case 'CLOSED':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF0F766E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بلاغاتي'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<List<IncidentReport>>(
        future: _futureReports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تعذر تحميل البلاغات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'لا يوجد بلاغات حتى الآن',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                final statusLabel = MockData.statusLabel(report.statusKey);
                final color = _statusColor(report.statusKey);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportDetailsScreen(report: report),
                        ),
                      );
                    },
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.categoryTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(report.summary),
                            if (report.suspiciousUrl != null &&
                                report.suspiciousUrl!.trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                report.suspiciousUrl!,
                                style: const TextStyle(
                                  color: Color(0xFF0F766E),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  report.displayId,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  report.createdAtLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}