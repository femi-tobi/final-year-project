import 'patient_models.dart';

class ClassProbabilities {
  final double normal;
  final double urgent;
  final double emergency;

  const ClassProbabilities({
    required this.normal,
    required this.urgent,
    required this.emergency,
  });

  factory ClassProbabilities.fromJson(Map<String, dynamic> json) {
    double _parse(String? val) =>
        double.tryParse((val ?? '0').replaceAll('%', '')) ?? 0.0;
    return ClassProbabilities(
      normal: _parse(json['Normal']?.toString()),
      urgent: _parse(json['Urgent']?.toString()),
      emergency: _parse(json['Emergency']?.toString()),
    );
  }
}

class MetricsAnalyzed {
  final double shockIndex;
  final double pulsePressureProxy;
  final bool hypoxiaFlag;
  final bool tachycardiaFlag;
  final bool hypotensionFlag;
  final bool elderlyRiskFlag;
  final double age;
  final String engine;

  const MetricsAnalyzed({
    required this.shockIndex,
    required this.pulsePressureProxy,
    required this.hypoxiaFlag,
    required this.tachycardiaFlag,
    required this.hypotensionFlag,
    required this.elderlyRiskFlag,
    required this.age,
    required this.engine,
  });

  factory MetricsAnalyzed.fromJson(Map<String, dynamic> json) {
    return MetricsAnalyzed(
      shockIndex: (json['shock_index'] as num?)?.toDouble() ?? 0.0,
      pulsePressureProxy: (json['pulse_pressure_proxy'] as num?)?.toDouble() ?? 0.0,
      hypoxiaFlag: json['hypoxia_flag'] as bool? ?? false,
      tachycardiaFlag: json['tachycardia_flag'] as bool? ?? false,
      hypotensionFlag: json['hypotension_flag'] as bool? ?? false,
      elderlyRiskFlag: json['elderly_risk_flag'] as bool? ?? false,
      age: (json['age'] as num?)?.toDouble() ?? 0.0,
      engine: json['engine'] as String? ?? 'Phase 3 XGBoost Multimodal',
    );
  }
}

class TriageResult {
  final String triageCategory;
  final double confidenceScore;
  final ClassProbabilities classProbabilities;
  final String clinicalExplanation;
  final MetricsAnalyzed metricsAnalyzed;
  /// Patient name entered during intake (not from API JSON — injected locally)
  final String patientName;

  const TriageResult({
    required this.triageCategory,
    required this.confidenceScore,
    required this.classProbabilities,
    required this.clinicalExplanation,
    required this.metricsAnalyzed,
    this.patientName = '',
  });

  TriageResult copyWith({String? patientName}) => TriageResult(
        triageCategory:      triageCategory,
        confidenceScore:     confidenceScore,
        classProbabilities:  classProbabilities,
        clinicalExplanation: clinicalExplanation,
        metricsAnalyzed:     metricsAnalyzed,
        patientName:         patientName ?? this.patientName,
      );

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    double _parseScore(String? val) =>
        double.tryParse((val ?? '0').replaceAll('%', '')) ?? 0.0;

    return TriageResult(
      triageCategory: json['triage_category'] as String? ?? 'Unknown',
      confidenceScore: _parseScore(json['confidence_score']?.toString()),
      classProbabilities: ClassProbabilities.fromJson(
        json['class_probabilities'] as Map<String, dynamic>? ?? {},
      ),
      clinicalExplanation: json['clinical_explanation'] as String? ?? '',
      metricsAnalyzed: MetricsAnalyzed.fromJson(
        json['metrics_analyzed'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  factory TriageResult.fromPatient(PatientRecord p) {
    double normal = 0.0;
    double urgent = 0.0;
    double emergency = 0.0;
    
    if (p.triageCategory == 'Emergency') {
      emergency = p.confidence;
      urgent = (100 - p.confidence) * 0.7;
      normal = (100 - p.confidence) * 0.3;
    } else if (p.triageCategory == 'Urgent') {
      urgent = p.confidence;
      emergency = (100 - p.confidence) * 0.4;
      normal = (100 - p.confidence) * 0.6;
    } else {
      normal = p.confidence;
      urgent = (100 - p.confidence) * 0.8;
      emergency = (100 - p.confidence) * 0.2;
    }
    
    String explanation = 'Baseline vital indicators and clinical narrative analysed.';
    if (p.shockIndex >= 1.0) explanation += ' | Critical shock index observed.';
    if (p.o2Sat < 94) explanation += ' | Low oxygen saturation detected.';
    if (p.heartRate > 100) explanation += ' | Tachycardia detected.';
    if (p.systolicBp < 90) explanation += ' | Hypotension detected.';
    
    return TriageResult(
      triageCategory: p.triageCategory,
      confidenceScore: p.confidence,
      classProbabilities: ClassProbabilities(
        normal: normal,
        urgent: urgent,
        emergency: emergency,
      ),
      clinicalExplanation: explanation,
      metricsAnalyzed: MetricsAnalyzed(
        shockIndex: p.shockIndex,
        pulsePressureProxy: p.systolicBp * 0.4,
        hypoxiaFlag: p.o2Sat <= 94,
        tachycardiaFlag: p.heartRate > 100,
        hypotensionFlag: p.systolicBp < 90,
        elderlyRiskFlag: p.age > 65,
        age: p.age.toDouble(),
        engine: 'Phase 3 XGBoost Multimodal',
      ),
      patientName: p.name,
    );
  }
}
