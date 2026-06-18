import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/triage_result.dart';
import '../theme/app_theme.dart';

class ResultsScreen extends StatefulWidget {
  final TriageResult result;
  const ResultsScreen({super.key, required this.result});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bannerCtrl;
  late final AnimationController _gaugeCtrl;
  late final AnimationController _barsCtrl;
  late final AnimationController _blinkCtrl;

  late final Animation<double> _bannerScale;
  late final Animation<double> _gaugeArc;
  late final Animation<double> _barsSlide;
  late final Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();

    _bannerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _gaugeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    );
    _barsCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    );
    _blinkCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bannerScale = CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOutBack);
    _gaugeArc    = CurvedAnimation(parent: _gaugeCtrl,  curve: Curves.easeOutCubic);
    _barsSlide   = CurvedAnimation(parent: _barsCtrl,   curve: Curves.easeOutCubic);
    _blinkAnim   = Tween<double>(begin: 0.3, end: 1.0).animate(_blinkCtrl);

    Future.delayed(const Duration(milliseconds: 100), () {
      _bannerCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _gaugeCtrl.forward();
      _barsCtrl.forward();
    });
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    _gaugeCtrl.dispose();
    _barsCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  // ─── Severity helpers ────────────────────────────────────────────────────
  bool get _isEmergency => widget.result.triageCategory == 'Emergency';
  bool get _isUrgent    => widget.result.triageCategory == 'Urgent';

  Color get _severityColor {
    if (_isEmergency) return AppColors.emergency;
    if (_isUrgent)    return AppColors.urgent;
    return AppColors.normalGreen;
  }

  Color get _severityGlow {
    if (_isEmergency) return AppColors.emergencyGlow;
    if (_isUrgent)    return AppColors.urgentGlow;
    return AppColors.normalGlow;
  }

  IconData get _severityIcon {
    if (_isEmergency) return Icons.crisis_alert_rounded;
    if (_isUrgent)    return Icons.warning_amber_rounded;
    return Icons.check_circle_rounded;
  }

  String get _severityLabel {
    if (_isEmergency) return '🚨 EMERGENCY';
    if (_isUrgent)    return '⚠️ URGENT';
    return '✅ NORMAL';
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Column(
        children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBanner(),
                  const SizedBox(height: 24),
                  _buildGaugeRow(),
                  const SizedBox(height: 24),
                  _buildProbabilityBars(),
                  const SizedBox(height: 24),
                  _buildMetricsRow(),
                  const SizedBox(height: 24),
                  _buildXaiCard(),
                  const SizedBox(height: 24),
                  _buildBackButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2A3E), Color(0xFF0D3B54)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 14),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  'Clinical Evaluation Dashboard',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.clinicalTealGlow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.clinicalTealLight.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  widget.result.metricsAnalyzed.engine,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.clinicalTealLight,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Dynamic Triage Banner ────────────────────────────────────────────────
  Widget _buildBanner() {
    return ScaleTransition(
      scale: _bannerScale,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: _severityColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _severityColor.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _severityGlow,
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _blinkAnim,
              builder: (_, __) => Opacity(
                opacity: _isEmergency ? _blinkAnim.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _severityColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _severityIcon,
                    color: _severityColor,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRIAGE CLASSIFICATION',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _severityColor.withOpacity(0.8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _severityLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _severityColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Confidence Gauge ─────────────────────────────────────────────────────
  Widget _buildGaugeRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _ResultCard(
            child: Column(
              children: [
                const Text(
                  'CONFIDENCE SCORE',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _gaugeArc,
                  builder: (_, __) => SizedBox(
                    width: 140,
                    height: 140,
                    child: CustomPaint(
                      painter: _GaugePainter(
                        progress: _gaugeArc.value *
                            (widget.result.confidenceScore / 100),
                        color: _severityColor,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(widget.result.confidenceScore * _gaugeArc.value).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: _severityColor,
                                letterSpacing: -1,
                              ),
                            ),
                            const Text(
                              'confidence',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 3,
          child: _ResultCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DERIVED METRICS', style: AppTextStyles.labelLarge),
                const SizedBox(height: 14),
                _MetricTile(
                  label: 'Shock Index',
                  value: widget.result.metricsAnalyzed.shockIndex
                      .toStringAsFixed(3),
                  color: widget.result.metricsAnalyzed.shockIndex >= 1.0
                      ? AppColors.emergency
                      : widget.result.metricsAnalyzed.shockIndex >= 0.7
                          ? AppColors.urgent
                          : AppColors.normalGreen,
                ),
                _MetricTile(
                  label: 'Pulse Pressure',
                  value:
                      '${widget.result.metricsAnalyzed.pulsePressureProxy.toStringAsFixed(1)} mmHg',
                  color: AppColors.clinicalTealLight,
                ),
                _FlagTile(
                  label: 'Hypoxia',
                  active: widget.result.metricsAnalyzed.hypoxiaFlag,
                ),
                _FlagTile(
                  label: 'Tachycardia',
                  active: widget.result.metricsAnalyzed.tachycardiaFlag,
                ),
                _FlagTile(
                  label: 'Hypotension',
                  active: widget.result.metricsAnalyzed.hypotensionFlag,
                ),
                _FlagTile(
                  label: 'Elderly Risk',
                  active: widget.result.metricsAnalyzed.elderlyRiskFlag,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Probability Distribution Bars ───────────────────────────────────────
  Widget _buildProbabilityBars() {
    final probs = widget.result.classProbabilities;
    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PROBABILITY DISTRIBUTION', style: AppTextStyles.labelLarge),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _barsSlide,
            builder: (_, __) => Column(
              children: [
                _ProbBar(
                  label: 'Emergency',
                  value: probs.emergency,
                  color: AppColors.emergency,
                  animProgress: _barsSlide.value,
                ),
                const SizedBox(height: 10),
                _ProbBar(
                  label: 'Urgent',
                  value: probs.urgent,
                  color: AppColors.urgent,
                  animProgress: _barsSlide.value,
                ),
                const SizedBox(height: 10),
                _ProbBar(
                  label: 'Normal',
                  value: probs.normal,
                  color: AppColors.normalGreen,
                  animProgress: _barsSlide.value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Metrics Flag Row ──────────────────────────────────────────────────────
  Widget _buildMetricsRow() {
    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PATIENT PARAMETERS', style: AppTextStyles.labelLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ParamChip(
                icon: Icons.person_outline_rounded,
                label: 'Age',
                value:
                    '${widget.result.metricsAnalyzed.age.toStringAsFixed(0)} yrs',
              ),
              _ParamChip(
                icon: Icons.monitor_heart_outlined,
                label: 'Shock Idx',
                value:
                    widget.result.metricsAnalyzed.shockIndex.toStringAsFixed(2),
                danger: widget.result.metricsAnalyzed.shockIndex >= 1.0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── XAI Narrative ───────────────────────────────────────────────────────
  Widget _buildXaiCard() {
    final bullets = widget.result.clinicalExplanation
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return _ResultCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.clinicalTealGlow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.clinicalTealLight,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'EXPLAINABLE AI NARRATIVE',
                style: AppTextStyles.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bullets
                  .map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '•',
                              style: TextStyle(
                                fontSize: 16,
                                color: _severityColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Back Button ──────────────────────────────────────────────────────────
  Widget _buildBackButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).pop(),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text(
        'NEW PATIENT ASSESSMENT',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.clinicalTealLight,
        side: const BorderSide(color: AppColors.clinicalTeal),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ─── Result Card wrapper ─────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final Widget child;
  const _ResultCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
  }
}

// ─── Probability Bar ─────────────────────────────────────────────────────────
class _ProbBar extends StatelessWidget {
  final String label;
  final double value;      // 0–100
  final Color  color;
  final double animProgress;

  const _ProbBar({
    required this.label,
    required this.value,
    required this.color,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * animProgress).clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )),
            Text(
              '${value.toStringAsFixed(2)}%',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AppColors.inputFill,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ─── Metric Tile ──────────────────────────────────────────────────────────────
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
              )),
          Text(value,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ─── Flag Tile ────────────────────────────────────────────────────────────────
class _FlagTile extends StatelessWidget {
  final String label;
  final bool   active;

  const _FlagTile({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
              )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.emergency.withOpacity(0.15)
                  : AppColors.normalGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              active ? 'YES' : 'NO',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.emergency : AppColors.normalGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Param Chip ───────────────────────────────────────────────────────────────
class _ParamChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     danger;

  const _ParamChip({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger
              ? AppColors.emergency.withOpacity(0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: danger
                  ? AppColors.emergency
                  : AppColors.clinicalTealLight),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: AppColors.textMuted,
                  )),
              Text(value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: danger
                        ? AppColors.emergency
                        : AppColors.textPrimary,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Custom Gauge Painter ─────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color  color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 8;

    const startAngle = math.pi * 0.75;
    const sweepMax   = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..color  = AppColors.inputFill
      ..strokeWidth = 10
      ..style  = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepMax,
      false,
      trackPaint,
    );

    // Progress arc
    final arcPaint = Paint()
      ..color  = color
      ..strokeWidth = 10
      ..style  = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Glow
    final glowPaint = Paint()
      ..color  = color.withOpacity(0.3)
      ..strokeWidth = 18
      ..style  = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final sweep = sweepMax * progress;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweep,
      false,
      glowPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress || old.color != color;
}
