class IncidentUpdate {
  final int? updateId;
  final int? incidentId;
  final int? actorUserId;
  final String? statusKey;
  final String? note;
  final DateTime? createdAt;

  const IncidentUpdate({
    this.updateId,
    this.incidentId,
    this.actorUserId,
    this.statusKey,
    this.note,
    this.createdAt,
  });

  factory IncidentUpdate.fromJson(Map<String, dynamic> json) {
    return IncidentUpdate(
      updateId: json['update_id'] as int?,
      incidentId: json['incident_id'] as int?,
      actorUserId: json['actor_user_id'] as int?,
      statusKey: json['status_key']?.toString(),
      note: json['note']?.toString() ??
          json['comment']?.toString() ??
          json['description']?.toString(),
      createdAt: _parseDate(
        json['created_at'] ??
            json['update_date'] ??
            json['timestamp'],
      ),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String get createdAtLabel {
    if (createdAt == null) return '-';
    final d = createdAt!;
    return '${d.day}/${d.month}/${d.year}';
  }
}