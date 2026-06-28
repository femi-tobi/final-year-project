import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/triage_result.dart';
import '../models/auth_models.dart';
import '../models/patient_models.dart'; // includes PatientRecord, QueueMetrics, BedResponse

class ApiService {
  // Change this to your machine's IP when running on a physical mobile device.
  // For Windows desktop / emulator use 127.0.0.1.
  static const String _baseUrl = 'http://127.0.0.1:5000';

  // ─── Auth token holder (set after login) ──────────────────────────────────
  static String? _token;
  static UserSession? currentSession;

  static Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ─── Authentication ────────────────────────────────────────────────────────
  static Future<UserSession> login(LoginRequest req) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(req.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final session = UserSession.fromJson(json);
      _token = session.token;
      currentSession = session;
      return session;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Login failed');
    }
  }

  static Future<void> logout() async {
    try {
      await http
          .post(
            Uri.parse('$_baseUrl/auth/logout'),
            headers: _authHeaders,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
    _token = null;
    currentSession = null;
  }

  // ─── ML Prediction (unchanged) ────────────────────────────────────────────
  static Future<TriageResult> predict({
    required double age,
    required double heartRate,
    required double systolicBp,
    required double temperature,
    required double o2Sat,
    required String symptomText,
  }) async {
    final uri = Uri.parse('$_baseUrl/predict');

    final payload = {
      'age': age,
      'heart_rate': heartRate,
      'systolic_bp': systolicBp,
      'temperature': temperature,
      'o2_sat': o2Sat,
      'symptom_text': symptomText,
    };

    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TriageResult.fromJson(json);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Server error ${response.statusCode}');
    }
  }

  // ─── Patient Queue ─────────────────────────────────────────────────────────
  static Future<List<PatientRecord>> getQueue({String status = ''}) async {
    final uri = Uri.parse(
      '$_baseUrl/patients${status.isNotEmpty ? '?status=${Uri.encodeComponent(status)}' : ''}',
    );
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rawList = json['patients'] as List<dynamic>? ?? [];
      return rawList
          .map((e) => PatientRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load patient queue');
  }

  static Future<Map<String, dynamic>> createPatient(
      Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/patients'),
          headers: _authHeaders,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to register patient');
  }

  static Future<void> confirmAllocation(
      String patientId, String confirmedBy) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/patients/$patientId/confirm'),
          headers: _authHeaders,
          body: jsonEncode({'confirmed_by': confirmedBy}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to confirm allocation');
    }
  }

  static Future<void> overrideAllocation({
    required String patientId,
    required String acuityLevel,
    required String triageCategory,
    required String reason,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/patients/$patientId/override'),
          headers: _authHeaders,
          body: jsonEncode({
            'acuity_level':    acuityLevel,
            'triage_category': triageCategory,
            'reason':          reason,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Failed to apply override');
    }
  }

  // ─── Dashboard Metrics ─────────────────────────────────────────────────────
  static Future<QueueMetrics> getMetrics() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/metrics'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return QueueMetrics.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load metrics');
  }

  // ─── Analytics / Logs ──────────────────────────────────────────────────────
  static Future<LogsResponse> getLogs({
    String query = '',
    String date = '',
    int page = 1,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': '12',
      if (query.isNotEmpty) 'q': query,
      if (date.isNotEmpty) 'date': date,
    };
    final uri = Uri.parse('$_baseUrl/analytics/logs')
        .replace(queryParameters: params);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return LogsResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load logs');
  }

  // ─── Diagnostics ───────────────────────────────────────────────────────────
  static Future<DiagnosticsData> getDiagnostics() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/diagnostics'), headers: _authHeaders)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return DiagnosticsData.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load diagnostics');
  }

  // ─── Health Check ──────────────────────────────────────────────────────────
  static Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Bed Management ────────────────────────────────────────────────────────
  static Future<BedResponse> getBeds() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/beds'), headers: _authHeaders)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      return BedResponse.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to load bed data');
  }

  static Future<void> assignBed({
    required String patientId,
    required String bedId,
    required String assignedBy,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/patients/$patientId/assign-bed'),
          headers: _authHeaders,
          body: jsonEncode({'bed_id': bedId, 'assigned_by': assignedBy}),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error'] ?? 'Failed to assign bed');
    }
  }

  static Future<void> releaseBed(String bedId) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/beds/$bedId/release'),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to release bed');
    }
  }
}
