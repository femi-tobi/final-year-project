import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/triage_result.dart';

class ApiService {
  // Change this to your machine's IP when running on a physical mobile device.
  // For Windows desktop / emulator use 127.0.0.1.
  static const String _baseUrl = 'http://127.0.0.1:5000';

  /// Sends patient vitals + symptom text to the Flask XGBoost endpoint and
  /// returns a strongly-typed [TriageResult].
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
          headers: {'Content-Type': 'application/json'},
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

  /// Simple health-check against GET /health.
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
}
