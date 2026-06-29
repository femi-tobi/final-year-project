// admin_dashboard.dart
// ED Administration Dashboard — Control Room view.
// Tabs: Patient List (all statuses) | Bed Management | System Health

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../models/triage_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';
import 'shared_dashboard_widgets.dart';

const Color _adminAccent = Color(0xFFF59E0B);

class AdminDashboard extends StatefulWidget {
  final UserSession session;
  const AdminDashboard({super.key, required this.session});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {

  int _navIndex = 0;

  // Data
  QueueMetrics?         _metrics;
  DiagnosticsData?      _diag;
  List<PatientRecord>   _allPatients  = [];
  BedResponse?          _bedResponse;
  bool _loading = true;

  // Search/filter for patient list
  String _patientSearch = '';
  String _statusFilter  = 'All';

  Timer? _refreshTimer;

  // Animations
  late final AnimationController _arcCtrl;
  late final Animation<double>   _arcAnim;
  late final AnimationController _alertCtrl;
  late final Animation<double>   _alertAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _arcCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _arcAnim = CurvedAnimation(parent: _arcCtrl, curve: Curves.easeOutCubic);

    _alertCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
      ..repeat(reverse: true);
    _alertAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _alertCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _arcCtrl.dispose();
    _alertCtrl.dispose();
    _pulseCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getMetrics(),
        ApiService.getDiagnostics(),
        ApiService.getQueue(),   // all statuses
        ApiService.getBeds(),
      ]);
      if (!mounted) return;
      final allP = results[2] as List<PatientRecord>;
      allP.sort((a, b) => a.acuityLevel.compareTo(b.acuityLevel));
      setState(() {
        _metrics     = results[0] as QueueMetrics;
        _diag        = results[1] as DiagnosticsData;
        _allPatients = allP;
        _bedResponse = results[3] as BedResponse;
        _loading     = false;
      });
      _arcCtrl.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PatientRecord> get _filteredPatients {
    var list = _allPatients;
    if (_statusFilter != 'All') {
      list = list.where((p) => p.status == _statusFilter).toList();
    }
    if (_patientSearch.isNotEmpty) {
      final q = _patientSearch.toLowerCase();
      list = list.where((p) =>
          p.name.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          p.chiefComplaint.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<PatientRecord> get _bottleneckPatients => _allPatients
      .where((p) =>
          (p.acuityLevel == 'L1' || p.acuityLevel == 'L2') &&
          p.waitMinutes > 15 &&
          p.status == 'Waiting')
      .toList();

  Widget _currentPage() {
    switch (_navIndex) {
      case 0: return _buildPatientListPage();
      case 1: return _buildBedManagementPage();
      case 2: return _buildSystemPage();
      default: return _buildPatientListPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Column(children: [
        RoleHeaderBar(session: widget.session, onLogout: () => performLogout(context)),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: _adminAccent))
            : _currentPage()),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: _adminAccent.withOpacity(0.2),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: _adminAccent),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bed_outlined),
            selectedIcon: Icon(Icons.bed_rounded, color: _adminAccent),
            label: 'Beds',
          ),
          NavigationDestination(
            icon: const Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed_rounded, color: _adminAccent),
            label: 'System',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PAGE 1 — ALL PATIENTS LIST (like doctor, but full status view)
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildPatientListPage() {
    return Column(children: [
      // ── Fleet Metrics Strip ──────────────────────────────────────────────
      if (_metrics != null) _buildMetricsStrip(),

      // ── Search + Filter ──────────────────────────────────────────────────
      _buildSearchFilter(),

      // ── Patient List ─────────────────────────────────────────────────────
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _adminAccent,
          backgroundColor: AppColors.card,
          child: _filteredPatients.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('No patients match the current filter',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: _filteredPatients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _AdminPatientTile(
                    patient: _filteredPatients[i],
                    pulseAnim: _pulseAnim,
                  ),
                ),
        ),
      ),
    ]);
  }

  Widget _buildMetricsStrip() {
    final m = _metrics!;
    final int inTreatment = _allPatients.where((p) => p.status == 'In Treatment').length;
    final int discharged  = _allPatients.where((p) => p.status == 'Discharged').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        MetricTile(icon: Icons.hourglass_empty_rounded, label: 'WAITING',
            value: '${m.totalWaiting}', color: AppColors.urgent),
        const SizedBox(width: 8),
        MetricTile(icon: Icons.healing_rounded, label: 'IN TREATMENT',
            value: '$inTreatment', color: AppColors.clinicalTealLight),
        const SizedBox(width: 8),
        MetricTile(icon: Icons.check_circle_outline_rounded, label: 'DISCHARGED',
            value: '$discharged', color: AppColors.normalGreen),
      ]),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search box
        TextField(
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary),
          onChanged: (v) => setState(() => _patientSearch = v),
          decoration: InputDecoration(
            hintText: 'Search by name, ID or complaint…',
            hintStyle: const TextStyle(fontFamily: 'Inter', color: AppColors.textMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Waiting', 'In Treatment', 'Discharged'].map((status) {
              final isSelected = _statusFilter == status;
              final chipColor = status == 'Waiting'      ? AppColors.urgent
                  : status == 'In Treatment' ? AppColors.clinicalTealLight
                  : status == 'Discharged'   ? AppColors.normalGreen
                  : _adminAccent;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = status),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? chipColor.withOpacity(0.2) : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? chipColor : AppColors.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(status,
                        style: TextStyle(
                          fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600,
                          color: isSelected ? chipColor : AppColors.textSecondary,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PAGE 2 — BED MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildBedManagementPage() {
    final bedResp = _bedResponse;
    if (bedResp == null) {
      return const Center(child: CircularProgressIndicator(color: _adminAccent));
    }

    final available = bedResp.beds.where((b) => b.isAvailable).toList();
    final occupied  = bedResp.beds.where((b) => !b.isAvailable).toList();
    final double pct = bedResp.total > 0 ? (bedResp.occupiedCount / bedResp.total) : 0;
    final Color arcColor = pct > 0.9
        ? AppColors.emergency
        : pct > 0.75 ? AppColors.urgent : AppColors.normalGreen;

    // Group by ward
    final Map<String, List<BedInfo>> byWard = {};
    for (final b in bedResp.beds) {
      byWard.putIfAbsent(b.ward, () => []).add(b);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _adminAccent,
      backgroundColor: AppColors.card,
      child: CustomScrollView(
        slivers: [
          // ── Occupancy Summary ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _buildBedSummaryCard(bedResp, pct, arcColor, available.length, occupied.length),
            ),
          ),

          // ── Bottleneck Alerts ────────────────────────────────────────────
          if (_bottleneckPatients.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildBottleneckAlerts(),
              ),
            ),

          // ── Ward-by-Ward bed grids ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: SectionHeader('BED STATUS BY WARD',
                  count: bedResp.total, countColor: _adminAccent),
            ),
          ),
          ...byWard.entries.map((entry) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildWardSection(entry.key, entry.value),
            ),
          )),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildBedSummaryCard(BedResponse bedResp, double pct, Color arcColor,
      int availCount, int occCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: arcColor.withOpacity(0.3)),
      ),
      child: LayoutBuilder(builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('BED OCCUPANCY',
              style: TextStyle(fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: AppColors.textMuted, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          isNarrow
              ? Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  _arcGauge(bedResp, pct, arcColor),
                  const SizedBox(height: 16),
                  _bedOccupancyStats(bedResp, pct, arcColor, availCount, occCount),
                ])
              : Row(children: [
                  _arcGauge(bedResp, pct, arcColor),
                  const SizedBox(width: 24),
                  Expanded(child: _bedOccupancyStats(bedResp, pct, arcColor, availCount, occCount)),
                ]),
        ]);
      }),
    );
  }

  Widget _arcGauge(BedResponse bedResp, double pct, Color arcColor) {
    return SizedBox(
      width: 100, height: 100,
      child: AnimatedBuilder(
        animation: _arcAnim,
        builder: (_, __) => CustomPaint(
          painter: _ArcGaugePainter(fraction: pct * _arcAnim.value, color: arcColor),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${bedResp.occupiedCount}',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w900, color: arcColor)),
              Text('/ ${bedResp.total}',
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: AppColors.textMuted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bedOccupancyStats(BedResponse bedResp, double pct, Color arcColor,
      int availCount, int occCount) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: arcColor)),
        const SizedBox(width: 8),
        Text('Occupied: $occCount',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: arcColor)),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.normalGreen)),
        const SizedBox(width: 8),
        Text('Available: $availCount',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.normalGreen)),
      ]),
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
      Text('${(pct * 100).toStringAsFixed(1)}% capacity utilised',
          style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: arcColor)),
    ]);
  }

  Widget _buildWardSection(String ward, List<BedInfo> beds) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _adminAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _adminAccent.withOpacity(0.3)),
          ),
          child: Text(ward.toUpperCase(),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 10,
                  fontWeight: FontWeight.w700, color: _adminAccent, letterSpacing: 0.8)),
        ),
        const SizedBox(width: 10),
        Text('${beds.where((b) => b.isAvailable).length}/${beds.length} available',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted)),
      ]),
      const SizedBox(height: 10),
      // Responsive grid of bed cards
      LayoutBuilder(builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth > 500 ? 4
            : constraints.maxWidth > 360 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 8, mainAxisSpacing: 8,
            childAspectRatio: 1.6,
          ),
          itemCount: beds.length,
          itemBuilder: (ctx, i) => _BedCard(
            bed: beds[i],
            onRelease: () async {
              final released = beds[i];
              try {
                await ApiService.releaseBed(released.id);
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${released.name} released — now available'),
                    backgroundColor: AppColors.normalGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.emergency));
              }
            },
          ),
        );
      }),
    ]);
  }

  Widget _buildBottleneckAlerts() {
    final pts = _bottleneckPatients;
    return AnimatedBuilder(
      animation: _alertAnim,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.emergency.withOpacity(0.08 * _alertAnim.value + 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.emergency.withOpacity(0.5 * _alertAnim.value + 0.2), width: 1.5),
        ),
        child: child,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_rounded, color: AppColors.emergency, size: 18),
          SizedBox(width: 8),
          Text('BOTTLENECK ALERT',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w800,
                  color: AppColors.emergency, letterSpacing: 0.8)),
        ]),
        const SizedBox(height: 8),
        ...pts.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.emergency)),
            const SizedBox(width: 8),
            Expanded(child: Text('${p.name}  ·  ${p.acuityLevel}  ·  ${p.waitMinutes} min waiting',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textPrimary))),
          ]),
        )),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PAGE 3 — SYSTEM HEALTH
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSystemPage() {
    final d = _diag;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: _adminAccent,
      backgroundColor: AppColors.card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_adminAccent.withOpacity(0.12), _adminAccent.withOpacity(0.04)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _adminAccent.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.monitor_heart_outlined, color: _adminAccent, size: 22),
              SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('System Telemetry', style: TextStyle(fontFamily: 'Inter', fontSize: 15,
                    fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Real-time API & ML model monitoring',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          if (d != null) ...[
            // Flask latency
            _SystemCard(
              title: 'Flask Backend',
              subtitle: 'Avg ${d.avgLatencyMs.toStringAsFixed(1)}ms',
              icon: Icons.speed_rounded,
              color: d.avgLatencyMs <= d.targetMs * 1.2 ? AppColors.normalGreen : AppColors.urgent,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(d.avgLatencyMs.toStringAsFixed(1),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 36, fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          color: d.avgLatencyMs <= d.targetMs * 1.2 ? AppColors.normalGreen : AppColors.urgent)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 3),
                    child: Text('ms', style: TextStyle(fontFamily: 'Inter', fontSize: 14,
                        color: AppColors.textSecondary)),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Target: ${d.targetMs.toStringAsFixed(0)}ms',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted)),
                  ]),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _Badge('MIN', '${d.minLatencyMs.toStringAsFixed(0)}ms', AppColors.normalGreen),
                  const SizedBox(width: 10),
                  _Badge('MAX', '${d.maxLatencyMs.toStringAsFixed(0)}ms', AppColors.urgent),
                  const SizedBox(width: 10),
                  _Badge('ML INFER.', '${d.mlInferenceMs}ms', AppColors.clinicalTealLight),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            // Database
            _SystemCard(
              title: '${d.dbType}',
              subtitle: d.dbStatus == 'connected' ? 'Connected' : 'Disconnected',
              icon: Icons.storage_rounded,
              color: d.dbStatus == 'connected' ? AppColors.statusGreen : AppColors.emergency,
              child: Row(children: [
                _Badge('STATUS', d.dbStatus.toUpperCase(),
                    d.dbStatus == 'connected' ? AppColors.statusGreen : AppColors.emergency),
                const SizedBox(width: 10),
                _Badge('PING', '${d.dbPingMs.toStringAsFixed(2)}ms', AppColors.clinicalTealLight),
                const SizedBox(width: 10),
                _Badge('CONN.', '${d.dbActiveConnections}', _adminAccent),
              ]),
            ),
          ] else
            const Center(child: Text('Loading telemetry…',
                style: TextStyle(fontFamily: 'Inter', color: AppColors.textMuted))),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Admin Patient Tile — full status view
// ──────────────────────────────────────────────────────────────────────────────
class _AdminPatientTile extends StatelessWidget {
  final PatientRecord patient;
  final Animation<double> pulseAnim;
  const _AdminPatientTile({required this.patient, required this.pulseAnim});

  Color get _levelColor {
    switch (patient.acuityLevel) {
      case 'L1': return AppColors.emergency;
      case 'L2': return AppColors.urgent;
      case 'L3': return const Color(0xFFF59E0B);
      case 'L4': return AppColors.clinicalTealLight;
      default:   return AppColors.normalGreen;
    }
  }

  Color get _statusColor {
    switch (patient.status) {
      case 'Waiting':      return AppColors.urgent;
      case 'In Treatment': return AppColors.clinicalTealLight;
      case 'Discharged':   return AppColors.normalGreen;
      default:             return AppColors.textMuted;
    }
  }

  bool get _isCritical =>
      (patient.acuityLevel == 'L1' || patient.acuityLevel == 'L2') &&
      patient.status == 'Waiting';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResultsScreen(
                result: TriageResult.fromPatient(patient),
                isViewOnly: true,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, child) {
            final glow = _isCritical ? pulseAnim.value * 0.15 : 0.05;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _levelColor.withOpacity(_isCritical ? 0.5 : 0.25)),
                boxShadow: [BoxShadow(color: _levelColor.withOpacity(glow), blurRadius: _isCritical ? 16 : 6)],
              ),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              AcuityBadge(level: patient.acuityLevel, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(patient.name,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14,
                              fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(width: 6),
                    Text('${patient.age}y',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted)),
                  ]),
                  const SizedBox(height: 4),
                  Text(patient.chiefComplaint,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 5),
                  Row(children: [
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor.withOpacity(0.4)),
                      ),
                      child: Text(patient.status,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 9.5,
                              fontWeight: FontWeight.w700, color: _statusColor)),
                    ),
                    // Bed name if assigned
                    if (patient.bedName != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.normalGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.normalGreen.withOpacity(0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.bed_rounded, size: 10, color: AppColors.normalGreen),
                          const SizedBox(width: 4),
                          Text(patient.bedName!,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 9.5,
                                  fontWeight: FontWeight.w700, color: AppColors.normalGreen)),
                        ]),
                      ),
                    ],
                  ]),
                ]),
              ),
              // Wait time / confidence
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (patient.status == 'Waiting')
                  Text('${patient.waitMinutes}m',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800,
                          color: patient.waitMinutes > 15 ? AppColors.emergency : AppColors.textSecondary)),
                Text('${patient.confidence.toStringAsFixed(0)}%',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted)),
                const Text('conf.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.textMuted)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Bed Card — shows one bed with status
// ──────────────────────────────────────────────────────────────────────────────
class _BedCard extends StatelessWidget {
  final BedInfo bed;
  final VoidCallback onRelease;
  const _BedCard({required this.bed, required this.onRelease});

  @override
  Widget build(BuildContext context) {
    final color = bed.isAvailable ? AppColors.normalGreen : AppColors.urgent;
    return GestureDetector(
      onLongPress: bed.isAvailable ? null : () => _confirmRelease(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [
            Icon(Icons.bed_rounded, size: 13, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(bed.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            bed.isAvailable ? 'Available' : bed.patientName ?? 'Occupied',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                color: bed.isAvailable ? AppColors.textSecondary : AppColors.textPrimary),
          ),
          if (!bed.isAvailable)
            const Text('Hold to release',
                style: TextStyle(fontFamily: 'Inter', fontSize: 8.5, color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  void _confirmRelease(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Release ${bed.name}?',
            style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800, color: Colors.white)),
        content: Text(
          '${bed.patientName} will be marked as Discharged and ${bed.name} will become available.',
          style: const TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.normalGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () { Navigator.pop(ctx); onRelease(); },
            child: const Text('Release Bed',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// System Card
// ──────────────────────────────────────────────────────────────────────────────
class _SystemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;
  const _SystemCard({required this.title, required this.subtitle, required this.icon,
      required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 13,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: color)),
          ]),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// Badge / label chip
class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Badge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 9,
          fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
          fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Arc Gauge Painter
// ──────────────────────────────────────────────────────────────────────────────
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
    final bgPaint = Paint()
      ..color = AppColors.inputFill
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, bgPaint);
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
