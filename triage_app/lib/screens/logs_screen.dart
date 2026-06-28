import 'dart:async';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import '../models/patient_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LogsScreen extends StatefulWidget {
  final UserSession session;
  const LogsScreen({super.key, required this.session});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _searchCtr = TextEditingController();
  LogsResponse? _logs;
  bool _loading = true;
  int _currentPage = 1;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _searchCtr.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtr.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _currentPage = 1;
      _fetchLogs();
    });
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getLogs(
        query: _searchCtr.text.trim(),
        page: _currentPage,
      );
      if (mounted) setState(() => _logs = result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        if (_loading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.clinicalTealLight),
            ),
          )
        else
          Expanded(child: _buildTable()),
        if (_logs != null) _buildPagination(),
      ],
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: TextField(
        controller: _searchCtr,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, ID, or complaint…',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.clinicalTealLight, size: 20),
          suffixIcon: _searchCtr.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textMuted, size: 18),
                  onPressed: () {
                    _searchCtr.clear();
                    _fetchLogs();
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ─── Table ────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    if (_logs == null || _logs!.logs.isEmpty) {
      return const Center(
        child: Text(
          'No records found',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Table header
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: _ColHeader('PATIENT')),
              Expanded(flex: 2, child: _ColHeader('TRIAGE')),
              Expanded(flex: 2, child: _ColHeader('STATUS')),
              Expanded(flex: 2, child: _ColHeader('WAIT')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _logs!.logs.length,
            itemBuilder: (context, index) =>
                _LogRow(patient: _logs!.logs[index]),
          ),
        ),
      ],
    );
  }

  // ─── Pagination ───────────────────────────────────────────────────────────
  Widget _buildPagination() {
    final logs = _logs!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: ${logs.total} records',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          Row(
            children: [
              _PageBtn(
                icon: Icons.chevron_left_rounded,
                enabled: _currentPage > 1,
                onTap: () {
                  setState(() => _currentPage--);
                  _fetchLogs();
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Page $_currentPage / ${logs.pages}',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              _PageBtn(
                icon: Icons.chevron_right_rounded,
                enabled: _currentPage < logs.pages,
                onTap: () {
                  setState(() => _currentPage++);
                  _fetchLogs();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Table helpers ────────────────────────────────────────────────────────────
class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final PatientRecord patient;
  const _LogRow({required this.patient});

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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Name + ID
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '#${patient.id}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Triage level
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _levelColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                patient.acuityLevel,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: _levelColor,
                ),
              ),
            ),
          ),
          // Status badge
          Expanded(
            flex: 2,
            child: _StatusBadge(status: patient.status),
          ),
          // Wait time or turnaround
          Expanded(
            flex: 2,
            child: Text(
              patient.turnaroundMin != null
                  ? '${patient.turnaroundMin}m'
                  : '${patient.waitMinutes}m wait',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _bgColor {
    switch (status) {
      case 'Discharged':   return const Color(0xFF22C55E);
      case 'In Treatment': return AppColors.clinicalTealLight;
      case 'Waiting':      return const Color(0xFFF59E0B);
      default:             return AppColors.textMuted;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'Discharged':   return Icons.check_circle_outline_rounded;
      case 'In Treatment': return Icons.medical_services_outlined;
      case 'Waiting':      return Icons.hourglass_top_rounded;
      default:             return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _bgColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 10, color: _bgColor),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _bgColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PageBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled ? AppColors.card : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? AppColors.clinicalTeal
                  : AppColors.cardBorder),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.clinicalTealLight : AppColors.textMuted,
        ),
      ),
    );
  }
}
