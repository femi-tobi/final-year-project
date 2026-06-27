import 'dart:async';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'intake_screen.dart';
import 'logs_screen.dart';
import 'diagnostics_screen.dart';
import 'auth_screen.dart';

class DashboardScreen extends StatefulWidget {
  final UserSession session;
  const DashboardScreen({super.key, required this.session});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _navIndex = 0;

  List<PatientRecord> _queue = [];
  QueueMetrics? _metrics;
  bool _loading = true;
  Timer? _refreshTimer;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _loadData();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _loadData());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
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
      setState(() {
        _queue   = results[0] as List<PatientRecord>;
        _metrics = results[1] as QueueMetrics;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  // ─── Navigation pages ─────────────────────────────────────────────────────
  Widget _currentPage() {
    switch (_navIndex) {
      case 0: return _buildQueuePage();
      case 1: return LogsScreen(session: widget.session);
      case 2: return DiagnosticsScreen(session: widget.session);
      default: return _buildQueuePage();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _currentPage()),
        ],
      ),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'new_triage',
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, a1, a2) =>
                      IntakeScreen(session: widget.session),
                  transitionsBuilder: (_, a1, a2, child) =>
                      FadeTransition(opacity: a1, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              ).then((_) => _loadData()),
              backgroundColor: AppColors.clinicalTeal,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'NEW TRIAGE INTAKE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.clinicalTealGlow,
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart_rounded, color: AppColors.clinicalTealLight),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppColors.clinicalTealLight),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed_rounded, color: AppColors.clinicalTealLight),
            label: 'Diagnostics',
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2A3E), Color(0xFF0D3B54), Color(0xFF0F4C5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3312A3BA),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.clinicalTealGlow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.clinicalTealLight.withOpacity(0.3)),
                ),
                child: const Icon(Icons.local_hospital_rounded,
                    color: AppColors.clinicalTealLight, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emergency Department',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.session.role}  ·  ${widget.session.name}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Live indicator
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.statusGreen.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Opacity(
                      opacity: _pulseAnim.value,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.statusGreen,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.statusGreen.withOpacity(0.6),
                                blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('LIVE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusGreen,
                          letterSpacing: 1.0,
                        )),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.textMuted, size: 20),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Queue Page ───────────────────────────────────────────────────────────
  Widget _buildQueuePage() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.clinicalTealLight),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.clinicalTealLight,
      backgroundColor: AppColors.card,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: _buildMetricCards(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(children: [
                const Text('PATIENT QUEUE',
                    style: AppTextStyles.labelLarge),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.clinicalTealGlow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_queue.length} waiting',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.clinicalTealLight,
                    ),
                  ),
                ),
              ]),
            ),
          ),
          if (_queue.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text(
                    'No patients currently waiting',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PatientQueueCard(patient: _queue[index]),
                  ),
                  childCount: _queue.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Metric Cards Row ─────────────────────────────────────────────────────
  Widget _buildMetricCards() {
    if (_metrics == null) return const SizedBox.shrink();
    return Row(
      children: [
        _MetricCard(
          icon: Icons.people_outline_rounded,
          label: 'WAITING',
          value: '${_metrics!.totalWaiting}',
          color: AppColors.urgent,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          icon: Icons.timer_outlined,
          label: 'AVG WAIT',
          value: '${_metrics!.avgWaitMinutes.toStringAsFixed(0)}m',
          color: AppColors.clinicalTealLight,
        ),
        const SizedBox(width: 10),
        _MetricCard(
          icon: Icons.bed_outlined,
          label: 'BEDS USED',
          value: '${_metrics!.bedOccupancy}/${_metrics!.totalBeds}',
          color: _metrics!.occupancyPct > 80
              ? AppColors.emergency
              : AppColors.normalGreen,
        ),
      ],
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Patient Queue Card ───────────────────────────────────────────────────────
class _PatientQueueCard extends StatelessWidget {
  final PatientRecord patient;

  const _PatientQueueCard({required this.patient});

  Color get _levelColor {
    switch (patient.acuityLevel) {
      case 'L1': return AppColors.emergency;
      case 'L2': return AppColors.urgent;
      case 'L3': return const Color(0xFFF59E0B);
      case 'L4': return AppColors.clinicalTealLight;
      default:   return AppColors.normalGreen;
    }
  }

  String get _levelLabel {
    switch (patient.acuityLevel) {
      case 'L1': return 'LEVEL 1 · IMMEDIATE';
      case 'L2': return 'LEVEL 2 · URGENT';
      case 'L3': return 'LEVEL 3 · LESS URGENT';
      case 'L4': return 'LEVEL 4 · NON-URGENT';
      default:   return 'LEVEL 5 · MINOR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _levelColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _levelColor.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Acuity badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _levelColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _levelColor.withOpacity(0.5), width: 1.5),
            ),
            child: Center(
              child: Text(
                patient.acuityLevel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: _levelColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Patient info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${patient.age}y',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _levelLabel,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _levelColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  patient.chiefComplaint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Wait time
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${patient.waitMinutes}m',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: patient.waitMinutes > 30
                      ? AppColors.urgent
                      : AppColors.textSecondary,
                ),
              ),
              const Text(
                'waiting',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
