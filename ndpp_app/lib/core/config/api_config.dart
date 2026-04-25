class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';

  static const int reporterUserId = 1;

  static String incidents() =>
      '$baseUrl/incidents?actor_user_id=$reporterUserId';

  static String incidentById(int incidentId) =>
      '$baseUrl/incidents/$incidentId?actor_user_id=$reporterUserId';
}