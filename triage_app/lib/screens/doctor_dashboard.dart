// doctor_dashboard.dart
// Emergency Doctor Dashboard — priority queue, XAI reason blocks, action toggles.

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'logs_screen.dart';
import 'shared_dashboard_widgets.dart';

class DoctorDashboard extends StatefulWidget {
  final UserSession session;
  const DoctorDashboard({super.key, required this.session});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with TickerProviderStateMixin {
  int _navIndex = 0;

  List<PatientRecord> _queue = [];
  QueueMetrics? _metrics;
  bool _loading = true;
  Timer? _refreshTimer;

  // Pulsing animation for L1 critical cards
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadData());
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
      final rawQueue = results[0] as List<PatientRecord>;
      // Sort strictly by acuity: L1 → L5
      rawQueue.sort((a, b) => a.acuityLevel.compareTo(b.acuityLevel));
      setState(() {
        _queue   = rawQueue;
        _metrics = results[1] as QueueMetrics;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _currentPage() {
    switch (_navIndex) {
      case 0: return _buildQueuePage();
      case 1: return LogsScreen(session: widget.session);
      default: return _buildQueuePage();
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
        indicatorColor: const Color(0xFF6366F1).withOpacity(0.2),
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart_rounded, color: Color(0xFF6366F1)),
            label: 'Priority Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: Color(0xFF6366F1)),
            label: 'Case Logs',
          ),
        ],
      ),
    );
  }

  // ─── Queue Page ──────────────────────────────────────────────────────────
  Widget _buildQueuePage() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6366F1),
      backgroundColor: AppColors.card,
      child: CustomScrollView(
        slivers: [
          // Metrics strip
          if (_metrics != null)
            SliverToBoxAdapter(child: _buildMetricsStrip()),

          // Queue header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: SectionHeader(
                'PRIORITY PATIENT QUEUE',
                count: _queue.length,
                countColor: const Color(0xFF6366F1),
              ),
            ),
          ),

          // Sublabel
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Sorted by acuity severity (L1 Critical → L5 Minor) · Tap a patient to review',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted,
                ),
              ),
            ),
          ),

          if (_queue.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: Text('No patients currently in queue',
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DoctorPatientCard(
                      patient: _queue[i],
                      pulseAnim: _pulseAnim,
                      session: widget.session,
                      onActionTaken: _loadData,
                    ),
                  ),
                  childCount: _queue.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Metrics Strip ───────────────────────────────────────────────────────
  Widget _buildMetricsStrip() {
    final m = _metrics!;
    final int critical = _queue.where((p) => p.acuityLevel == 'L1' || p.acuityLevel == 'L2').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(children: [
        MetricTile(
          icon: Icons.people_outline_rounded,
          label: 'WAITING',
          value: '${m.totalWaiting}',
          color: const Color(0xFF6366F1),
        ),
        const SizedBox(width: 8),
        MetricTile(
          icon: Icons.warning_rounded,
          label: 'CRITICAL (L1–L2)',
          value: '$critical',
          color: critical > 0 ? AppColors.emergency : AppColors.normalGreen,
        ),
        const SizedBox(width: 8),
        MetricTile(
          icon: Icons.timer_outlined,
          label: 'AVG WAIT',
          value: '${m.avgWaitMinutes.toStringAsFixed(0)}m',
          color: AppColors.textSecondary,
        ),
      ]),
    );
  }
}

// ─── Doctor Patient Card ──────────────────────────────────────────────────────
class _DoctorPatientCard extends StatefulWidget {
  final PatientRecord patient;
  final Animation<double> pulseAnim;
  final UserSession session;
  final VoidCallback onActionTaken;

  const _DoctorPatientCard({
    required this.patient,
    required this.pulseAnim,
    required this.session,
    required this.onActionTaken,
  });

  @override
  State<_DoctorPatientCard> createState() => _DoctorPatientCardState();
}

class _DoctorPatientCardState extends State<_DoctorPatientCard> {
  bool _expanded = false;
  bool _actionLoading = false;

  Color get _levelColor {
    switch (widget.patient.acuityLevel) {
      case 'L1': return AppColors.emergency;
      case 'L2': return AppColors.urgent;
      case 'L3': return const Color(0xFFF59E0B);
      case 'L4': return AppColors.clinicalTealLight;
      default:   return AppColors.normalGreen;
    }
  }

  String get _levelFull {
    switch (widget.patient.acuityLevel) {
      case 'L1': return 'LEVEL 1 · RESUSCITATION';
      case 'L2': return 'LEVEL 2 · URGENT';
      case 'L3': return 'LEVEL 3 · LESS URGENT';
      case 'L4': return 'LEVEL 4 · NON-URGENT';
      default:   return 'LEVEL 5 · MINOR';
    }
  }

  bool get _isCritical =>
      widget.patient.acuityLevel == 'L1' || widget.patient.acuityLevel == 'L2';

  // Reconstruct XAI explanation from flags on the patient record
  String _buildXaiExplanation() {
    final p = widget.patient;
    final reasons = <String>[];
    if (p.shockIndex >= 1.0)  reasons.add('Critical Shock Index (${p.shockIndex.toStringAsFixed(2)})');
    if (p.shockIndex >= 0.7 && p.shockIndex < 1.0) reasons.add('Elevated Shock Index (${p.shockIndex.toStringAsFixed(2)})');
    if (p.o2Sat < 94)         reasons.add('Low O₂ Saturation (${p.o2Sat.toStringAsFixed(0)}%)');
    if (p.heartRate > 100)    reasons.add('Tachycardia (${p.heartRate.toStringAsFixed(0)} bpm)');
    if (p.heartRate < 50)     reasons.add('Bradycardia (${p.heartRate.toStringAsFixed(0)} bpm)');
    if (p.systolicBp < 90)    reasons.add('Hypotension (SBP ${p.systolicBp.toStringAsFixed(0)} mmHg)');
    if (p.temperature > 38.5) reasons.add('Fever (${p.temperature.toStringAsFixed(1)} °C)');
    if (p.temperature < 36.0) reasons.add('Hypothermia (${p.temperature.toStringAsFixed(1)} °C)');
    if (p.age >= 65)          reasons.add('Elderly high-risk patient (${p.age}y)');
    if (p.chiefComplaint.toLowerCase().contains('chest'))
      reasons.add('"Chest pain" keyword in clinical narrative');
    if (p.chiefComplaint.toLowerCase().contains('breath'))
      reasons.add('"Shortness of breath" keyword in clinical narrative');
    if (p.chiefComplaint.toLowerCase().contains('stroke') ||
        p.chiefComplaint.toLowerCase().contains('weakness') ||
        p.chiefComplaint.toLowerCase().contains('slurred'))
      reasons.add('Neurological deficit keywords detected');

    if (reasons.isEmpty) {
      return 'Model Prediction: ${widget.patient.acuityLevel} — '
          'Multimodal XGBoost model classified this patient based on combined vital signs '
          'and clinical narrative. Confidence: ${widget.patient.confidence.toStringAsFixed(1)}%.';
    }
    return 'Model Prediction: ${widget.patient.acuityLevel} due to combined effect of: '
        '${reasons.join('; ')}. '
        'Confidence: ${widget.patient.confidence.toStringAsFixed(1)}%.';
  }

  Future<void> _acceptScore() async {
    setState(() => _actionLoading = true);
    try {
      await ApiService.confirmAllocation(widget.patient.id, widget.session.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI score accepted for ${widget.patient.name}'),
            backgroundColor: AppColors.normalGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        widget.onActionTaken();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.emergency),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _showOverrideDialog() async {
    String? selectedLevel;
    final reasonCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Manual Override',
            style: TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w800, color: Colors.white,
            )),
        content: StatefulBuilder(
          builder: (ctx, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Override Acuity Level',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: ['L1', 'L2', 'L3', 'L4', 'L5'].map((lvl) {
                  final isSelected = selectedLevel == lvl;
                  final colors = {
                    'L1': AppColors.emergency,
                    'L2': AppColors.urgent,
                    'L3': const Color(0xFFF59E0B),
                    'L4': AppColors.clinicalTealLight,
                    'L5': AppColors.normalGreen,
                  };
                  final c = colors[lvl]!;
                  return GestureDetector(
                    onTap: () => setInner(() => selectedLevel = lvl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? c.withOpacity(0.25) : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? c : AppColors.cardBorder, width: 1.5),
                      ),
                      child: Text(lvl, style: TextStyle(
                        fontFamily: 'Inter', fontWeight: FontWeight.w700,
                        color: isSelected ? c : AppColors.textSecondary,
                      )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Clinical Reason (required)',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 12, color: AppColors.textSecondary,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 13, color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Clinical signs suggest lower acuity than model predicted…',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.urgent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (selectedLevel == null || reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Select a level and provide a reason'),
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(ctx);
              setState(() => _actionLoading = true);
              try {
                final catMap = {
                  'L1': 'Emergency', 'L2': 'Urgent',
                  'L3': 'Normal',   'L4': 'Normal', 'L5': 'Normal',
                };
                await ApiService.overrideAllocation(
                  patientId: widget.patient.id,
                  acuityLevel: selectedLevel!,
                  triageCategory: catMap[selectedLevel!]!,
                  reason: reasonCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Override applied: ${widget.patient.name} → $selectedLevel'),
                      backgroundColor: AppColors.urgent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  widget.onActionTaken();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.emergency),
                  );
                }
              } finally {
                if (mounted) setState(() => _actionLoading = false);
                reasonCtrl.dispose();
              }
            },
            child: const Text('Apply Override', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return AnimatedBuilder(
      animation: widget.pulseAnim,
      builder: (_, child) {
        final glowOpacity = _isCritical ? widget.pulseAnim.value * 0.18 : 0.06;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _levelColor.withOpacity(0.4), width: _isCritical ? 1.5 : 1.0),
            boxShadow: [
              BoxShadow(
                color: _levelColor.withOpacity(glowOpacity),
                blurRadius: _isCritical ? 20 : 8,
                spreadRadius: _isCritical ? 2 : 0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(children: [
        // ── Main Row ──────────────────────────────────────────────────────
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Acuity badge
              Stack(
                alignment: Alignment.topRight,
                children: [
                  AcuityBadge(level: p.acuityLevel, size: 48),
                  if (_isCritical)
                    AnimatedBuilder(
                      animation: widget.pulseAnim,
                      builder: (_, __) => Opacity(
                        opacity: widget.pulseAnim.value,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.emergency,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.emergency.withOpacity(0.7), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(p.name,
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(width: 8),
                    Text('${p.age}y',
                        style: const TextStyle(
                          fontFamily: 'Inter', fontSize: 11, color: AppColors.textMuted,
                        )),
                  ]),
                  const SizedBox(height: 3),
                  Text(_levelFull,
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700,
                        color: _levelColor, letterSpacing: 0.7,
                      )),
                  const SizedBox(height: 4),
                  Text(p.chiefComplaint,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 11.5, color: AppColors.textSecondary,
                      )),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${p.waitMinutes}m',
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w800,
                      color: p.waitMinutes > 15 ? AppColors.emergency : AppColors.textSecondary,
                    )),
                const Text('waiting',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: AppColors.textMuted)),
                const SizedBox(height: 4),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted, size: 18,
                ),
              ]),
            ]),
          ),
        ),

        // ── Expanded Clinical Panel ───────────────────────────────────────
        if (_expanded) _buildClinicalPanel(p),
      ]),
    );
  }

  Widget _buildClinicalPanel(PatientRecord p) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _levelColor.withOpacity(0.2))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Vitals Strip ─────────────────────────────────────────────────
        const Text('VITAL SIGNS',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 1.0,
            )),
        const SizedBox(height: 8),
        Row(children: [
          _VitalChip(label: 'HR', value: '${p.heartRate.toStringAsFixed(0)}', unit: 'bpm',
              color: p.heartRate > 100 || p.heartRate < 50 ? AppColors.urgent : AppColors.normalGreen),
          const SizedBox(width: 8),
          _VitalChip(label: 'SBP', value: '${p.systolicBp.toStringAsFixed(0)}', unit: 'mmHg',
              color: p.systolicBp < 90 ? AppColors.emergency : AppColors.normalGreen),
          const SizedBox(width: 8),
          _VitalChip(label: 'O₂', value: '${p.o2Sat.toStringAsFixed(0)}', unit: '%',
              color: p.o2Sat < 94 ? AppColors.emergency : p.o2Sat < 97 ? AppColors.urgent : AppColors.normalGreen),
          const SizedBox(width: 8),
          _VitalChip(label: 'Temp', value: '${p.temperature.toStringAsFixed(1)}', unit: '°C',
              color: p.temperature > 38.5 || p.temperature < 36.0 ? AppColors.urgent : AppColors.normalGreen),
          const SizedBox(width: 8),
          _VitalChip(label: 'SI', value: p.shockIndex.toStringAsFixed(2), unit: '',
              color: p.shockIndex >= 1.0 ? AppColors.emergency : p.shockIndex >= 0.7 ? AppColors.urgent : AppColors.normalGreen),
        ]),

        const SizedBox(height: 14),

        // ── Nurse Narrative ───────────────────────────────────────────────
        const Text('CLINICAL NARRATIVE (NURSE)',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 9.5, fontWeight: FontWeight.w700,
              color: AppColors.textMuted, letterSpacing: 1.0,
            )),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            '"${p.chiefComplaint}"',
            style: const TextStyle(
              fontFamily: 'Inter', fontSize: 13, fontStyle: FontStyle.italic,
              color: AppColors.textPrimary, height: 1.55,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── XAI Reason Block ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('XAI · MODEL REASONING',
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w800,
                    color: Color(0xFF6366F1), letterSpacing: 1.0,
                  )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${p.confidence.toStringAsFixed(1)}% conf.',
                  style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              _buildXaiExplanation(),
              style: const TextStyle(
                fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // ── Action Buttons ────────────────────────────────────────────────
        if (_actionLoading)
          const Center(child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF6366F1)),
          ))
        else
          Row(children: [
            Expanded(
              child: _ActionButton(
                label: '✓  Accept AI Score',
                color: AppColors.normalGreen,
                onTap: _acceptScore,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: '⚡  Manual Override',
                color: AppColors.urgent,
                onTap: _showOverrideDialog,
              ),
            ),
          ]),
      ]),
    );
  }
}

// ─── Vital Chip ───────────────────────────────────────────────────────────────
class _VitalChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _VitalChip({
    required this.label, required this.value,
    required this.unit,  required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 8.5, fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.8), letterSpacing: 0.5,
                )),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w900, color: color,
                )),
            if (unit.isNotEmpty)
              Text(unit,
                  style: TextStyle(
                    fontFamily: 'Inter', fontSize: 8, color: color.withOpacity(0.6),
                  )),
          ],
        ),
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: color,
            ),
          ),
        ),
      ),
    );
  }
}
