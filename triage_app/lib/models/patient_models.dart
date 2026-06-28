// patient_models.dart
// Models for patient queue, metrics counters, and diagnostics data.

// ─── Patient Record ───────────────────────────────────────────────────────────
class PatientRecord {
  final String id;
  final String name;
  final int age;
  final String triageCategory;
  final String acuityLevel;
  final String chiefComplaint;
  final String status;
  final String arrivedAt;
  final int waitMinutes;
  final double confidence;
  final double heartRate;
  final double systolicBp;
  final double o2Sat;
  final double temperature;
  final double shockIndex;
  final String? outcome;
  final int? turnaroundMin;
  final String? bedId;
  final String? bedName;

  const PatientRecord({
    required this.id,
    required this.name,
    required this.age,
    required this.triageCategory,
    required this.acuityLevel,
    required this.chiefComplaint,
    required this.status,
    required this.arrivedAt,
    required this.waitMinutes,
    required this.confidence,
    required this.heartRate,
    required this.systolicBp,
    required this.o2Sat,
    required this.temperature,
    required this.shockIndex,
    this.outcome,
    this.turnaroundMin,
    this.bedId,
    this.bedName,
  });

  factory PatientRecord.fromJson(Map<String, dynamic> json) {
    return PatientRecord(
      id:             json['id']               as String? ?? '',
      name:           json['name']             as String? ?? '',
      age:            (json['age'] as num?)?.toInt() ?? 0,
      triageCategory: json['triage_category']  as String? ?? 'Normal',
      acuityLevel:    json['acuity_level']     as String? ?? 'L5',
      chiefComplaint: json['chief_complaint']  as String? ?? '',
      status:         json['status']           as String? ?? 'Waiting',
      arrivedAt:      json['arrived_at']       as String? ?? '',
      waitMinutes:    (json['wait_minutes'] as num?)?.toInt() ?? 0,
      confidence:     (json['confidence'] as num?)?.toDouble() ?? 0,
      heartRate:      (json['heart_rate'] as num?)?.toDouble() ?? 0,
      systolicBp:     (json['systolic_bp'] as num?)?.toDouble() ?? 0,
      o2Sat:          (json['o2_sat'] as num?)?.toDouble() ?? 0,
      temperature:    (json['temperature'] as num?)?.toDouble() ?? 0,
      shockIndex:     (json['shock_index'] as num?)?.toDouble() ?? 0,
      outcome:        json['outcome']          as String?,
      turnaroundMin:  (json['turnaround_min'] as num?)?.toInt(),
      bedId:          json['bed_id']           as String?,
      bedName:        json['bed_name']         as String?,
    );
  }
}

// ─── Queue Metrics ────────────────────────────────────────────────────────────
class QueueMetrics {
  final int totalWaiting;
  final double avgWaitMinutes;
  final int bedOccupancy;
  final int totalBeds;
  final double occupancyPct;
  final int criticalCount;

  const QueueMetrics({
    required this.totalWaiting,
    required this.avgWaitMinutes,
    required this.bedOccupancy,
    required this.totalBeds,
    required this.occupancyPct,
    required this.criticalCount,
  });

  factory QueueMetrics.fromJson(Map<String, dynamic> json) {
    return QueueMetrics(
      totalWaiting:   (json['total_waiting']    as num?)?.toInt()    ?? 0,
      avgWaitMinutes: (json['avg_wait_minutes'] as num?)?.toDouble() ?? 0,
      bedOccupancy:   (json['bed_occupancy']    as num?)?.toInt()    ?? 0,
      totalBeds:      (json['total_beds']       as num?)?.toInt()    ?? 30,
      occupancyPct:   (json['occupancy_pct']    as num?)?.toDouble() ?? 0,
      criticalCount:  (json['critical_count']   as num?)?.toInt()    ?? 0,
    );
  }
}

// ─── Diagnostics Data ─────────────────────────────────────────────────────────
class EndpointStat {
  final String path;
  final String method;
  final String status;
  final double avgMs;

  const EndpointStat({
    required this.path,
    required this.method,
    required this.status,
    required this.avgMs,
  });

  factory EndpointStat.fromJson(Map<String, dynamic> json) {
    return EndpointStat(
      path:   json['path']   as String? ?? '',
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      avgMs:  (json['avg_ms'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DiagnosticsData {
  final String serverStatus;
  final String serverUptime;
  final double avgLatencyMs;
  final double minLatencyMs;
  final double maxLatencyMs;
  final double targetMs;
  final int requestsTracked;
  final String dbType;
  final String dbStatus;
  final double dbPingMs;
  final int dbActiveConnections;
  final List<EndpointStat> apiEndpoints;
  final String mlAccuracy;
  final int mlInferenceMs;

  const DiagnosticsData({
    required this.serverStatus,
    required this.serverUptime,
    required this.avgLatencyMs,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.targetMs,
    required this.requestsTracked,
    required this.dbType,
    required this.dbStatus,
    required this.dbPingMs,
    required this.dbActiveConnections,
    required this.apiEndpoints,
    required this.mlAccuracy,
    required this.mlInferenceMs,
  });

  factory DiagnosticsData.fromJson(Map<String, dynamic> json) {
    final perf = json['performance'] as Map<String, dynamic>? ?? {};
    final db   = json['database']    as Map<String, dynamic>? ?? {};
    final srv  = json['server']      as Map<String, dynamic>? ?? {};
    final ml   = json['ml_model']    as Map<String, dynamic>? ?? {};

    final rawEps = json['api_endpoints'] as List<dynamic>? ?? [];
    final eps = rawEps
        .map((e) => EndpointStat.fromJson(e as Map<String, dynamic>))
        .toList();

    return DiagnosticsData(
      serverStatus:        srv['status']    as String? ?? 'unknown',
      serverUptime:        srv['uptime']    as String? ?? '00h 00m 00s',
      avgLatencyMs:        (perf['avg_latency_ms'] as num?)?.toDouble() ?? 115,
      minLatencyMs:        (perf['min_latency_ms'] as num?)?.toDouble() ?? 0,
      maxLatencyMs:        (perf['max_latency_ms'] as num?)?.toDouble() ?? 0,
      targetMs:            (perf['target_ms']       as num?)?.toDouble() ?? 115,
      requestsTracked:     (perf['requests_tracked'] as num?)?.toInt() ?? 0,
      dbType:              db['type']    as String? ?? 'MySQL',
      dbStatus:            db['status']  as String? ?? 'unknown',
      dbPingMs:            (db['ping_ms'] as num?)?.toDouble() ?? 0,
      dbActiveConnections: (db['active_connections'] as num?)?.toInt() ?? 0,
      apiEndpoints:        eps,
      mlAccuracy:          ml['accuracy']         as String? ?? '0%',
      mlInferenceMs:       (ml['inference_ms_avg'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Logs Response ────────────────────────────────────────────────────────────
class LogsResponse {
  final List<PatientRecord> logs;
  final int total;
  final int page;
  final int pages;

  const LogsResponse({
    required this.logs,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory LogsResponse.fromJson(Map<String, dynamic> json) {
    final rawLogs = json['logs'] as List<dynamic>? ?? [];
    return LogsResponse(
      logs:  rawLogs.map((l) => PatientRecord.fromJson(l as Map<String, dynamic>)).toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page:  (json['page']  as num?)?.toInt() ?? 1,
      pages: (json['pages'] as num?)?.toInt() ?? 1,
    );
  }
}

// ─── Bed Info ─────────────────────────────────────────────────────────────────
class BedInfo {
  final String id;
  final String name;
  final String ward;
  final String status;        // "Available" | "Occupied"
  final String? patientId;
  final String? patientName;

  bool get isAvailable => status == 'Available';

  const BedInfo({
    required this.id,
    required this.name,
    required this.ward,
    required this.status,
    this.patientId,
    this.patientName,
  });

  factory BedInfo.fromJson(Map<String, dynamic> json) {
    return BedInfo(
      id:          json['id']           as String? ?? '',
      name:        json['name']         as String? ?? '',
      ward:        json['ward']         as String? ?? '',
      status:      json['status']       as String? ?? 'Available',
      patientId:   json['patient_id']   as String?,
      patientName: json['patient_name'] as String?,
    );
  }
}

// ─── Bed Response ─────────────────────────────────────────────────────────────
class BedResponse {
  final List<BedInfo> beds;
  final int total;
  final int availableCount;
  final int occupiedCount;

  const BedResponse({
    required this.beds,
    required this.total,
    required this.availableCount,
    required this.occupiedCount,
  });

  factory BedResponse.fromJson(Map<String, dynamic> json) {
    final rawBeds = json['beds'] as List<dynamic>? ?? [];
    return BedResponse(
      beds:           rawBeds.map((b) => BedInfo.fromJson(b as Map<String, dynamic>)).toList(),
      total:          (json['total']           as num?)?.toInt() ?? 0,
      availableCount: (json['available_count'] as num?)?.toInt() ?? 0,
      occupiedCount:  (json['occupied_count']  as num?)?.toInt() ?? 0,
    );
  }
}
