class IncidentAnalysis {
  final int? analysisId;
  final int incidentId;
  final String analysisType;
  final String modelName;
  final String modelVersion;
  final String predictedLabel;
  final double? confidenceScore;
  final double? riskScore;
  final String? explanation;
  final DateTime? createdAt;

  const IncidentAnalysis({
    this.analysisId,
    required this.incidentId,
    required this.analysisType,
    required this.modelName,
    required this.modelVersion,
    required this.predictedLabel,
    this.confidenceScore,
    this.riskScore,
    this.explanation,
    this.createdAt,
  });

  factory IncidentAnalysis.fromJson(Map<String, dynamic> json) {
    return IncidentAnalysis(
      analysisId: json['analysis_id'] as int?,
      incidentId: json['incident_id'] ?? 0,
      analysisType: (json['analysis_type'] ?? '').toString(),
      modelName: (json['model_name'] ?? '').toString(),
      modelVersion: (json['model_version'] ?? '').toString(),
      predictedLabel: (json['predicted_label'] ?? '').toString(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      riskScore: (json['risk_score'] as num?)?.toDouble(),
      explanation: json['explanation']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  String get confidenceLabel {
    if (confidenceScore == null) return '-';
    return '${(confidenceScore! * 100).toStringAsFixed(0)}%';
  }

  String get riskLabel {
    if (riskScore == null) return '-';
    return riskScore!.toStringAsFixed(1);
  }
}