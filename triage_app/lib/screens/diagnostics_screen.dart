import 'dart:async';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class DiagnosticsScreen extends StatefulWidget {
  final UserSession session;
  const DiagnosticsScreen({super.key, required this.session});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen>
    with TickerProviderStateMixin {
  DiagnosticsData? _data;
  bool _loading = true;
  Timer? _refreshTimer;

  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // Animated latency counter
  double _displayedLatency = 0;
  late final AnimationController _latencyCtrl;
  late final Animation<double>   _latencyAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _latencyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _latencyAnim = CurvedAnimation(parent: _latencyCtrl, curve: Curves.easeOutCubic);
    _latencyAnim.addListener(() {
      if (_data != null && mounted) {
        setState(() => _displayedLatency =
            _latencyAnim.value * _data!.avgLatencyMs);
      }
    });

    _fetchData();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _latencyCtrl.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final data = await ApiService.getDiagnostics();
      if (!mounted) return;
      setState(() {
        _data    = data;
        _loading = false;
      });
      _latencyCtrl.forward(from: 0);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.clinicalTealLight),
      );
    }
    if (_data == null) {
      return const Center(
        child: Text('Failed to load diagnostics',
            style: TextStyle(color: AppColors.textMuted, fontFamily: 'Inter')),
      );
    }
    final d = _data!;
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppColors.clinicalTealLight,
      backgroundColor: AppColors.card,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionLabel('SYSTEM STATUS'),
            const SizedBox(height: 10),
            _buildStatusCards(d),
            const SizedBox(height: 24),
            _buildSectionLabel('RESPONSE LATENCY TRACKER'),
            const SizedBox(height: 10),
            _buildLatencyCard(d),
            const SizedBox(height: 24),
            _buildSectionLabel('DATABASE CONNECTIVITY'),
            const SizedBox(height: 10),
            _buildDbCard(d),
            const SizedBox(height: 24),
            _buildSectionLabel('API ENDPOINT STATUS'),
            const SizedBox(height: 10),
            _buildEndpointList(d),
            const SizedBox(height: 24),
            _buildSectionLabel('ML MODEL INFO'),
            const SizedBox(height: 10),
            _buildMlCard(d),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(text, style: AppTextStyles.labelLarge);

  // ─── Status Cards ─────────────────────────────────────────────────────────
  Widget _buildStatusCards(DiagnosticsData d) {
    return Row(
      children: [
        Expanded(
          child: _DiagCard(
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: _pulseAnim.value,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.statusGreen,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.statusGreen.withOpacity(0.6),
                              blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SERVER',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                        )),
                    Text(
                      d.serverStatus.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.statusGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DiagCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('UPTIME',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    )),
                const SizedBox(height: 2),
                Text(
                  d.serverUptime,
                  style: const TextStyle(
                    fontFamily: 'RobotoMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.clinicalTealLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Latency Card ─────────────────────────────────────────────────────────
  Widget _buildLatencyCard(DiagnosticsData d) {
    final bool onTarget = d.avgLatencyMs <= d.targetMs * 1.2;
    final Color latColor = onTarget ? AppColors.statusGreen : AppColors.urgent;

    return _DiagCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: latColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.speed_rounded, color: latColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AVERAGE PROCESSING LATENCY',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _latencyAnim,
                      builder: (_, __) => Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _displayedLatency.toStringAsFixed(1),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: latColor,
                              letterSpacing: -2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 4),
                            child: Text(
                              'ms',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: latColor.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar vs target
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (d.avgLatencyMs / (d.targetMs * 2)).clamp(0.0, 1.0),
              backgroundColor: AppColors.inputFill,
              valueColor: AlwaysStoppedAnimation<Color>(latColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _latencyBadge('MIN', '${d.minLatencyMs.toStringAsFixed(1)}ms', AppColors.normalGreen),
              _latencyBadge('TARGET', '${d.targetMs.toStringAsFixed(0)}ms', AppColors.clinicalTealLight),
              _latencyBadge('MAX', '${d.maxLatencyMs.toStringAsFixed(1)}ms', AppColors.urgent),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${d.requestsTracked} requests tracked this session',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latencyBadge(String label, String value, Color color) {
    return Column(children: [
      Text(label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          )),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          )),
    ]);
  }

  // ─── DB Card ──────────────────────────────────────────────────────────────
  Widget _buildDbCard(DiagnosticsData d) {
    final bool connected = d.dbStatus == 'connected';
    return _DiagCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (connected ? AppColors.statusGreen : AppColors.emergency)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storage_rounded,
                  color: connected ? AppColors.statusGreen : AppColors.emergency,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.dbType,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      connected ? 'Connection Established' : 'Disconnected',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: connected
                            ? AppColors.statusGreen
                            : AppColors.emergency,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (connected ? AppColors.statusGreen : AppColors.emergency)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  connected ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: connected
                        ? AppColors.statusGreen
                        : AppColors.emergency,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _DbStat('PING', '${d.dbPingMs.toStringAsFixed(2)}ms'),
              const SizedBox(width: 20),
              _DbStat('ACTIVE CONN.', '${d.dbActiveConnections}'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Endpoint List ────────────────────────────────────────────────────────
  Widget _buildEndpointList(DiagnosticsData d) {
    return _DiagCard(
      child: Column(
        children: d.apiEndpoints
            .map((ep) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.clinicalTealGlow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          ep.method,
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.clinicalTealLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ep.path,
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${ep.avgMs.toStringAsFixed(1)}ms',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.statusGreen,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.statusGreen,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ─── ML Card ──────────────────────────────────────────────────────────────
  Widget _buildMlCard(DiagnosticsData d) {
    return _DiagCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.clinicalTealGlow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: AppColors.clinicalTealLight, size: 22),
              ),
              const SizedBox(width: 14),
              const Text(
                'XGBoost Phase 3 Multimodal Engine',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MlStat('ACCURACY', d.mlAccuracy, AppColors.statusGreen),
              _MlStat('INFERENCE', '${d.mlInferenceMs}ms', AppColors.clinicalTealLight),
              _MlStat('PHASE', '3', AppColors.urgent),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────
class _DiagCard extends StatelessWidget {
  final Widget child;
  const _DiagCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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

class _DbStat extends StatelessWidget {
  final String label;
  final String value;
  const _DbStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 9.5,
              color: AppColors.textMuted,
              letterSpacing: 0.6,
            )),
        Text(value,
            style: const TextStyle(
              fontFamily: 'RobotoMono',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            )),
      ],
    );
  }
}

class _MlStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MlStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 9.5,
            color: AppColors.textMuted,
            letterSpacing: 0.8,
          )),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          )),
    ]);
  }
}
