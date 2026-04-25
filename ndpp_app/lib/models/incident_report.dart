class IncidentReport {
  final int incidentId;
  final int reporterUserId;
  final String title;
  final String description;
  final String? suspiciousUrl;
  final int? riskLevelId;
  final String statusKey;
  final int? reportTypeId;
  final DateTime? incidentDate;

  const IncidentReport({
    required this.incidentId,
    required this.reporterUserId,
    required this.title,
    required this.description,
    required this.statusKey,
    this.suspiciousUrl,
    this.riskLevelId,
    this.reportTypeId,
    this.incidentDate,
  });

  factory IncidentReport.fromJson(Map<String, dynamic> json) {
    return IncidentReport(
      incidentId: json['incident_id'] ?? 0,
      reporterUserId: json['reporter_user_id'] ?? 0,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      suspiciousUrl: json['suspicious_url']?.toString(),
      riskLevelId: json['risk_level_id'],
      statusKey: (json['status_key'] ?? 'SUBMITTED').toString(),
      reportTypeId: json['report_type_id'],
      incidentDate: json['incident_date'] != null
          ? DateTime.tryParse(json['incident_date'].toString())
          : null,
    );
  }

  String get displayId => 'INC-$incidentId';

  String get categoryTitle => title;

  String get summary => description;

  String get createdAtLabel {
    if (incidentDate == null) return '-';
    final d = incidentDate!;
    return '${d.day}/${d.month}/${d.year}';
    }
}