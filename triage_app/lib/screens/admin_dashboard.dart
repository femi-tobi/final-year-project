// admin_dashboard.dart
// Emergency Department / Admin Dashboard — Control Room view.
// Focuses on logistics, capacity, system health, and bottleneck alerts.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'shared_dashboard_widgets.dart';

// Amber accent for admin
const Color _adminAccent = Color(0xFFF59E0B);

class AdminDashboard extends StatefulWidget {
  final UserSession session;
  const AdminDashboard({super.key, required this.session});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {

  QueueMetrics? _metrics;
  DiagnosticsData? _diag;
  List<PatientRecord> _allPatients = [];
  bool _loading = true;
  Timer? _refreshTimer;

  // Animated latency counter
  late final AnimationController _latencyCtrl;
  late final Animation<double> _latencyAnim;
  double _displayedLatency = 0;

  // Bed occupancy arc animation
  late final AnimationController _arcCtrl;
  late final Animation<double> _arcAnim;

  // Alert pulse
  late final AnimationController _alertCtrl;
  late final Animation<double> _alertAnim;

  @override
  void initState() {
    super.initState();

    _latencyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _latencyAnim = CurvedAnimation(parent: _latencyCtrl, curve: Curves.easeOutCubic);
    _latencyAnim.addListener(() {
      if (_diag != null && mounted) {
        setState(() => _displayedLatency = _latencyAnim.value * _diag!.avgLatencyMs);
      }
    });

    _arcCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _arcAnim = CurvedAnimation(parent: _arcCtrl, curve: Curves.easeOutCubic);

    _alertCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
    _alertAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _alertCtrl, curve: Curves.easeInOut));

    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _latencyCtrl.dispose();
    _arcCtrl.dispose();
    _alertCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getMetrics(),
        ApiService.getDiagnostics(),
        ApiService.getQueue(),          // all statuses
      ]);
      if (!mounted) return;
      setState(() {
        _metrics     = results[0] as QueueMetrics;
        _diag        = results[1] as DiagnosticsData;
        _allPatients = results[2] as List<PatientRecord>;
        _loading     = false;
      });
      _latencyCtrl.forward(from: 0);
      _arcCtrl.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Compute bottleneck patients: L1 or L2 waiting > 15 min
  List<PatientRecord> get _bottleneckPatients => _allPatients
      .where((p) =>
          (p.acuityLevel == 'L1' || p.acuityLevel == 'L2') &&
          p.waitMinutes > 15 &&
          p.status == 'Waiting')
      .toList();

  int get _inTreatment =>
      _allPatients.where((p) => p.status == 'In Treatment').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Column(children: [
        RoleHeaderBar(
          session: widget.session,
          onLogout: () => performLogout(context),
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _adminAccent))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: _adminAccent,
                  backgroundColor: AppColors.card,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildControlRoomBanner(),
                        const SizedBox(height: 20),
                        _buildFleetMetrics(),
                        const SizedBox(height: 20),
                        _buildBedOccupancyCard(),
                        const SizedBox(height: 20),
                        if (_bottleneckPatients.isNotEmpty) ...[
                          _buildBottleneckAlerts(),
                          const SizedBox(height: 20),
                        ],
                        _buildSystemHealthSection(),
                        const SizedBox(height: 20),
                        _buildStaffPanel(),
                      ],
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  // ─── Control Room Banner ─────────────────────────────────────────────────
  Widget _buildControlRoomBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _adminAccent.withOpacity(0.12),
            _adminAccent.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _adminAccent.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _adminAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.dashboard_rounded, color: _adminAccent, size: 24),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ED Control Room',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
            Text('Real-time department overview and system telemetry',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary,
                )),
          ]),
        ),
      ]),
    );
  }

  // ─── Fleet Metrics ────────────────────────────────────────────────────────
  Widget _buildFleetMetrics() {
    final m = _metrics;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('PATIENT FLEET OVERVIEW'),
      const SizedBox(height: 10),
      Row(children: [
        MetricTile(
          icon: Icons.people_outline_rounded,
          label: 'WAITING',
          value: '${m?.totalWaiting ?? 0}',
          color: AppColors.urgent,
        ),
        const SizedBox(width: 8),
        MetricTile(
          icon: Icons.local_hospital_outlined,
          label: 'IN TREATMENT',
          value: '$_inTreatment',
          color: AppColors.clinicalTealLight,
        ),
        const SizedBox(width: 8),
        MetricTile(
          icon: Icons.timer_outlined,
          label: 'AVG WAIT',
          value: '${m?.avgWaitMinutes.toStringAsFixed(0) ?? '--'}m',
          color: _adminAccent,
        ),
      ]),
    ]);
  }

  // ─── Bed Occupancy Arc Card ───────────────────────────────────────────────
  Widget _buildBedOccupancyCard() {
    final m = _metrics;
    final int occupied = m?.bedOccupancy ?? 0;
    final int total = m?.totalBeds ?? 40;
    final double pct = total > 0 ? (occupied / total) : 0;
    final Color arcColor = pct > 0.9
        ? AppColors.emergency
        : pct > 0.75
            ? AppColors.urgent
            : AppColors.normalGreen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: arcColor.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('BED OCCUPANCY',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 1.0,
            )),
        const SizedBox(height: 16),
        Row(children: [
          // Arc gauge
          SizedBox(
            width: 100, height: 100,
            child: AnimatedBuilder(
              animation: _arcAnim,
              builder: (_, __) => CustomPaint(
                painter: _ArcGaugePainter(
                  fraction: pct * _arcAnim.value,
                  color: arcColor,
                ),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      '$occupied',
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.w900,
                        color: arcColor,
                      ),
                    ),
                    Text('/ $total beds',
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 10, color: AppColors.textMuted,
                        )),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _OccupancyRow(label: 'Occupied', value: occupied, color: arcColor),
              const SizedBox(height: 8),
              _OccupancyRow(label: 'Available', value: total - occupied, color: AppColors.normalGreen),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedBuilder(
                  animation: _arcAnim,
                  builder: (_, __) => LinearProgressIndicator(
                    value: pct * _arcAnim.value,
                    backgroundColor: AppColors.inputFill,
                    valueColor: AlwaysStoppedAnimation<Color>(arcColor),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(pct * 100).toStringAsFixed(1)}% capacity utilised',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600,
                  color: arcColor,
                ),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ─── Bottleneck Alerts ────────────────────────────────────────────────────
  Widget _buildBottleneckAlerts() {
    final pts = _bottleneckPatients;
    final l1 = pts.where((p) => p.acuityLevel == 'L1').length;
    final l2 = pts.where((p) => p.acuityLevel == 'L2').length;

    return AnimatedBuilder(
      animation: _alertAnim,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.emergency.withOpacity(0.08 * _alertAnim.value + 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.emergency.withOpacity(0.5 * _alertAnim.value + 0.2),
            width: 1.5,
          ),
        ),
        child: child,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_rounded, color: AppColors.emergency, size: 20),
          const SizedBox(width: 8),
          const Text('BOTTLENECK ALERT',
              style: TextStyle(
                fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800,
                color: AppColors.emergency, letterSpacing: 0.8,
              )),
        ]),
        const SizedBox(height: 8),
        if (l1 > 0)
          _AlertLine('$l1 Level-1 (Resuscitation) patient${l1 > 1 ? 's' : ''} waiting > 15 minutes'),
        if (l2 > 0)
          _AlertLine('$l2 Level-2 (Urgent) patient${l2 > 1 ? 's' : ''} waiting > 15 minutes'),
        const SizedBox(height: 8),
        ...pts.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            const SizedBox(width: 6),
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.emergency,
              ),
            ),
            const SizedBox(width: 8),
            Text('${p.name}  ·  ${p.acuityLevel}  ·  ${p.waitMinutes} min',
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 12, color: AppColors.textPrimary,
                )),
          ]),
        )),
      ]),
    );
  }

  // ─── System Health ────────────────────────────────────────────────────────
  Widget _buildSystemHealthSection() {
    final d = _diag;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('SYSTEM HEALTH TELEMETRY'),
      const SizedBox(height: 10),
      // Flask latency card
      _HealthCard(
        title: 'Flask Backend Latency',
        subtitle: 'Average response time across all API endpoints',
        icon: Icons.speed_rounded,
        iconColor: d == null
            ? AppColors.textMuted
            : d.avgLatencyMs <= d.targetMs * 1.2
                ? AppColors.normalGreen
                : AppColors.urgent,
        child: Column(children: [
          if (d != null) ...[
            AnimatedBuilder(
              animation: _latencyAnim,
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _displayedLatency.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 42, fontWeight: FontWeight.w900,
                      color: d.avgLatencyMs <= d.targetMs * 1.2
                          ? AppColors.normalGreen
                          : AppColors.urgent,
                      letterSpacing: -2,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
                    child: Text('ms',
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Target: ${d.targetMs.toStringAsFixed(0)}ms',
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted,
                        )),
                    Text('${d.requestsTracked} requests tracked',
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted,
                        )),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              _SystemBadge('MIN', '${d.minLatencyMs.toStringAsFixed(0)}ms', AppColors.normalGreen),
              const SizedBox(width: 10),
              _SystemBadge('MAX', '${d.maxLatencyMs.toStringAsFixed(0)}ms', AppColors.urgent),
              const SizedBox(width: 10),
              _SystemBadge('ML INFER.', '${d.mlInferenceMs}ms', AppColors.clinicalTealLight),
            ]),
          ] else
            const Text('Loading telemetry...',
                style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted)),
        ]),
      ),
      const SizedBox(height: 10),
      // Database card
      if (d != null)
        _HealthCard(
          title: '${d.dbType} Database',
          subtitle: d.dbStatus == 'connected' ? 'Connection established' : 'Disconnected',
          icon: Icons.storage_rounded,
          iconColor: d.dbStatus == 'connected' ? AppColors.statusGreen : AppColors.emergency,
          child: Row(children: [
            _SystemBadge(
              'STATUS',
              d.dbStatus.toUpperCase(),
              d.dbStatus == 'connected' ? AppColors.statusGreen : AppColors.emergency,
            ),
            const SizedBox(width: 12),
            _SystemBadge('PING', '${d.dbPingMs.toStringAsFixed(2)}ms', AppColors.clinicalTealLight),
            const SizedBox(width: 12),
            _SystemBadge('CONN.', '${d.dbActiveConnections}', _adminAccent),
          ]),
        ),
    ]);
  }

  // ─── Staff Panel ──────────────────────────────────────────────────────────
  Widget _buildStaffPanel() {
    // Placeholder: real-time assignment data pending /staff API endpoint
    final m = _metrics;
    final int criticalCount = m?.criticalCount ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('STAFF ON DUTY'),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Placeholder notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _adminAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _adminAccent.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _adminAccent),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Real-time assignment data pending /staff API endpoint. Displaying sample roster.',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 10.5, color: _adminAccent,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // Sample roster rows
          _StaffRow(
            role: 'Emergency Doctor', name: 'Dr. Adaobi Okafor',
            icon: Icons.medical_information_rounded,
            color: const Color(0xFF6366F1),
            patients: criticalCount > 0 ? criticalCount : 2,
          ),
          const SizedBox(height: 8),
          _StaffRow(
            role: 'Emergency Doctor', name: 'Dr. Emeka Nwosu',
            icon: Icons.medical_information_rounded,
            color: const Color(0xFF6366F1),
            patients: 1,
          ),
          const SizedBox(height: 8),
          _StaffRow(
            role: 'Triage Nurse', name: 'Nurse Fatima Ibrahim',
            icon: Icons.medical_services_rounded,
            color: AppColors.clinicalTealLight,
            patients: m?.totalWaiting ?? 3,
          ),
          const SizedBox(height: 8),
          _StaffRow(
            role: 'Triage Nurse', name: 'Nurse Chukwuemeka Eze',
            icon: Icons.medical_services_rounded,
            color: AppColors.clinicalTealLight,
            patients: 2,
          ),
        ]),
      ),
    ]);
  }
}

// ─── Health Card ──────────────────────────────────────────────────────────────
class _HealthCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _HealthCard({
    required this.title, required this.subtitle,
    required this.icon,  required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            Text(subtitle,
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 11, color: iconColor,
                )),
          ]),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ─── System Badge ─────────────────────────────────────────────────────────────
class _SystemBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SystemBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
            fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w700,
            color: AppColors.textMuted, letterSpacing: 0.8,
          )),
      const SizedBox(height: 3),
      Text(value,
          style: TextStyle(
            fontFamily: 'RobotoMono', fontSize: 13, fontWeight: FontWeight.w700, color: color,
          )),
    ]);
  }
}

// ─── Alert Line ───────────────────────────────────────────────────────────────
class _AlertLine extends StatelessWidget {
  final String text;
  const _AlertLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('⚠ $text',
          style: const TextStyle(
            fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600,
            color: AppColors.emergency,
          )),
    );
  }
}

// ─── Occupancy Row ────────────────────────────────────────────────────────────
class _OccupancyRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _OccupancyRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(
            fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary,
          )),
      Text('$value',
          style: TextStyle(
            fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w800, color: color,
          )),
    ]);
  }
}

// ─── Staff Row ────────────────────────────────────────────────────────────────
class _StaffRow extends StatelessWidget {
  final String role;
  final String name;
  final IconData icon;
  final Color color;
  final int patients;

  const _StaffRow({
    required this.role, required this.name, required this.icon,
    required this.color, required this.patients,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          Text(role,
              style: TextStyle(fontFamily: 'Inter', fontSize: 10.5, color: color.withOpacity(0.7))),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          '$patients pts',
          style: TextStyle(
            fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: color,
          ),
        ),
      ),
    ]);
  }
}

// ─── Arc Gauge Painter ────────────────────────────────────────────────────────
class _ArcGaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _ArcGaugePainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width * 0.44;
    const strokeWidth = 10.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.inputFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, bgPaint);

    // Filled arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5 * fraction, false, fgPaint);
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.fraction != fraction || old.color != color;
}
