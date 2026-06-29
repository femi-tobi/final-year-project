// nurse_dashboard.dart
// Triage Nurse Dashboard — optimised for speed, data entry, and intake flow.

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../models/triage_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'intake_screen.dart';
import 'logs_screen.dart';
import 'diagnostics_screen.dart';
import 'results_screen.dart';
import 'shared_dashboard_widgets.dart';

class NurseDashboard extends StatefulWidget {
  final UserSession session;
  const NurseDashboard({super.key, required this.session});

  @override
  State<NurseDashboard> createState() => _NurseDashboardState();
}

class _NurseDashboardState extends State<NurseDashboard>
    with TickerProviderStateMixin {
  int _navIndex = 0;

  List<PatientRecord> _waitingQueue = [];
  QueueMetrics? _metrics;
  bool _loading = true;
  Timer? _refreshTimer;

  // Hero-button pulse animation
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroAnim;

  // Shock index of last registered patient
  double? _lastShockIndex;
  String? _lastPatientName;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _heroAnim = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeInOut));

    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData());
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getQueue(status: 'Waiting'),
        ApiService.getMetrics(),
      ]);
      if (!mounted) return;
      final queue = results[0] as List<PatientRecord>;
      final metrics = results[1] as QueueMetrics;

      // Pull shock index from the most-recently-arrived patient
      double? si;
      String? name;
      if (queue.isNotEmpty) {
        // Sort descending by arrivedAt to get latest
        final sorted = List<PatientRecord>.from(queue)
          ..sort((a, b) => b.arrivedAt.compareTo(a.arrivedAt));
        si = sorted.first.shockIndex;
        name = sorted.first.name;
      }

      setState(() {
        _waitingQueue   = queue;
        _metrics        = metrics;
        _lastShockIndex = si;
        _lastPatientName = name;
        _loading        = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _currentPage() {
    switch (_navIndex) {
      case 0: return _buildHomePage();
      case 1: return LogsScreen(session: widget.session);
      case 2: return DiagnosticsScreen(session: widget.session);
      default: return _buildHomePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Column(children: [
        RoleHeaderBar(
          session: widget.session,
          onLogout: () => performLogout(context),
        ),
        Expanded(child: _currentPage()),
      ]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: const Color(0xFF12A3BA).withOpacity(0.2),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services_rounded, color: Color(0xFF12A3BA)),
            label: 'Intake',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF12A3BA)),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed_rounded, color: Color(0xFF12A3BA)),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }

  // ─── Home Page ────────────────────────────────────────────────────────────
  Widget _buildHomePage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.clinicalTealLight));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.clinicalTealLight,
      backgroundColor: AppColors.card,
      child: CustomScrollView(
        slivers: [
          // ── Hero CTA ──────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeroCTA()),

          // ── Metrics Strip ─────────────────────────────────────────────────
          if (_metrics != null)
            SliverToBoxAdapter(child: _buildMetricsStrip()),

          // ── Last Patient Shock Index ──────────────────────────────────────
          if (_lastShockIndex != null)
            SliverToBoxAdapter(child: _buildShockIndexCard()),

          // ── Pending Patients ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: SectionHeader(
                'PENDING PATIENT QUEUE',
                count: _waitingQueue.length,
                countColor: AppColors.urgent,
              ),
            ),
          ),
          if (_waitingQueue.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No patients waiting — queue is clear ✓',
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 14, color: AppColors.textMuted,
                      )),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _NursePendingTile(patient: _waitingQueue[i]),
                  ),
                  childCount: _waitingQueue.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Hero CTA Button ─────────────────────────────────────────────────────
  Widget _buildHeroCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: AnimatedBuilder(
        animation: _heroAnim,
        builder: (_, child) => Transform.scale(scale: _heroAnim.value, child: child),
        child: GestureDetector(
          onTap: () => Navigator.of(context)
              .push(PageRouteBuilder(
                pageBuilder: (_, a1, a2) => IntakeScreen(session: widget.session),
                transitionsBuilder: (_, a1, a2, child) =>
                    FadeTransition(opacity: a1, child: child),
                transitionDuration: const Duration(milliseconds: 350),
              ))
              .then((_) => _loadData()),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D7280), Color(0xFF0891B2), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0891B2).withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 10),
                const Text(
                  'START NEW TRIAGE INTAKE',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 16,
                    fontWeight: FontWeight.w900, color: Colors.white,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to begin patient assessment',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 12,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Metrics Strip ───────────────────────────────────────────────────────
  Widget _buildMetricsStrip() {
    final m = _metrics!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        MetricTile(
          icon: Icons.people_outline_rounded,
          label: 'WAITING',
          value: '${m.totalWaiting}',
          color: AppColors.urgent,
        ),
        const SizedBox(width: 8),
        MetricTile(
          icon: Icons.timer_outlined,
          label: 'AVG WAIT',
          value: '${m.avgWaitMinutes.toStringAsFixed(0)}m',
          color: AppColors.clinicalTealLight,
        ),
        const SizedBox(width: 8),
        MetricTile(
          icon: Icons.warning_amber_rounded,
          label: 'CRITICAL',
          value: '${m.criticalCount}',
          color: m.criticalCount > 0 ? AppColors.emergency : AppColors.normalGreen,
        ),
      ]),
    );
  }

  // ─── Shock Index Card for last patient ───────────────────────────────────
  Widget _buildShockIndexCard() {
    final si = _lastShockIndex!;
    Color siColor;
    String siLabel;
    if (si >= 1.0) {
      siColor = AppColors.emergency;
      siLabel = 'CRITICAL — Haemodynamic intervention required';
    } else if (si >= 0.7) {
      siColor = AppColors.urgent;
      siLabel = 'BORDERLINE — Cardiovascular monitoring advised';
    } else {
      siColor = AppColors.normalGreen;
      siLabel = 'NORMAL — Haemodynamic stability maintained';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: siColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: siColor.withOpacity(0.35)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: siColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.monitor_heart_rounded, color: siColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('LAST PATIENT — SHOCK INDEX',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700,
                    color: AppColors.textMuted, letterSpacing: 0.8,
                  )),
              const SizedBox(height: 2),
              Text(
                _lastPatientName != null ? '$_lastPatientName · $siLabel' : siLabel,
                style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: siColor),
              ),
            ]),
          ),
          Text(
            si.toStringAsFixed(2),
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.w900,
              color: siColor, letterSpacing: -1,
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Nurse Pending Patient Tile ───────────────────────────────────────────────
class _NursePendingTile extends StatelessWidget {
  final PatientRecord patient;
  const _NursePendingTile({required this.patient});

  Color get _levelColor {
    switch (patient.acuityLevel) {
      case 'L1': return AppColors.emergency;
      case 'L2': return AppColors.urgent;
      case 'L3': return const Color(0xFFF59E0B);
      case 'L4': return AppColors.clinicalTealLight;
      default:   return AppColors.normalGreen;
    }
  }

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
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _levelColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            AcuityBadge(level: patient.acuityLevel, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(patient.name,
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 3),
                Text('${patient.age}y  ·  ${patient.chiefComplaint}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textSecondary,
                    )),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                '${patient.waitMinutes}m',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w900,
                  color: patient.waitMinutes > 20 ? AppColors.emergency : AppColors.textSecondary,
                ),
              ),
              const Text('waiting',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.textMuted)),
            ]),
          ]),
        ),
      ),
    );
  }
}
