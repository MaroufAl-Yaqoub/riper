class ReportField {
  final String key;
  final String label;
  final String hint;
  final bool required;
  final int maxLines;

  const ReportField({
    required this.key,
    required this.label,
    required this.hint,
    this.required = true,
    this.maxLines = 1,
  });
}

class ReportCategory {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String riskLevel;
  final List<ReportField> fields;

  const ReportCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.riskLevel,
    required this.fields,
  });
}
