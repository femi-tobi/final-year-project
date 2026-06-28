// shared_dashboard_widgets.dart
// Widgets reused across NurseDashboard, DoctorDashboard, and AdminDashboard.

import 'dart:async';
import 'package:flutter/material.dart';

import '../models/auth_models.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

// ─── Role accent colours ──────────────────────────────────────────────────────
Color roleAccent(UserSession session) {
  if (session.isNurse)  return const Color(0xFF12A3BA); // teal
  if (session.isDoctor) return const Color(0xFF6366F1); // indigo-violet
  return const Color(0xFFF59E0B);                       // amber (admin)
}

IconData roleIcon(UserSession session) {
  if (session.isNurse)  return Icons.medical_services_rounded;
  if (session.isDoctor) return Icons.medical_information_rounded;
  return Icons.admin_panel_settings_rounded;
}

String roleTitle(UserSession session) {
  if (session.isNurse)  return 'Triage Nurse Station';
  if (session.isDoctor) return 'Emergency Physician';
  return 'ED Administration';
}

// ─── Role Header Bar ─────────────────────────────────────────────────────────
class RoleHeaderBar extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;
  const RoleHeaderBar({super.key, required this.session, required this.onLogout});

  @override
  State<RoleHeaderBar> createState() => _RoleHeaderBarState();
}

class _RoleHeaderBarState extends State<RoleHeaderBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = roleAccent(widget.session);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2A3E), Color(0xFF0D3B54), Color(0xFF0F4C5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: accent.withOpacity(0.3), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
          child: Row(children: [
            // Role icon badge
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Icon(roleIcon(widget.session), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleTitle(widget.session),
                    style: const TextStyle(
                      fontFamily: 'Inter', fontSize: 15,
                      fontWeight: FontWeight.w800, color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.session.name,
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 11, color: accent.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Live dot
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.statusGreen.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Opacity(
                    opacity: _pulseAnim.value,
                    child: Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.statusGreen,
                        boxShadow: [BoxShadow(color: AppColors.statusGreen.withOpacity(0.6), blurRadius: 6)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('LIVE',
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.statusGreen, letterSpacing: 1.0,
                      )),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.textMuted, size: 20),
              onPressed: widget.onLogout,
              tooltip: 'Logout',
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Acuity Badge ─────────────────────────────────────────────────────────────
class AcuityBadge extends StatelessWidget {
  final String level;
  final double size;
  const AcuityBadge({super.key, required this.level, this.size = 44});

  Color get color {
    switch (level) {
      case 'L1': return AppColors.emergency;
      case 'L2': return AppColors.urgent;
      case 'L3': return const Color(0xFFF59E0B);
      case 'L4': return AppColors.clinicalTealLight;
      default:   return AppColors.normalGreen;
    }
  }

  String get label {
    switch (level) {
      case 'L1': return 'LEVEL 1\nIMMEDIATE';
      case 'L2': return 'LEVEL 2\nURGENT';
      case 'L3': return 'LEVEL 3\nLESS URGENT';
      case 'L4': return 'LEVEL 4\nNON-URGENT';
      default:   return 'LEVEL 5\nMINOR';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.55), width: 1.5),
      ),
      child: Center(
        child: Text(
          level,
          style: TextStyle(
            fontFamily: 'Inter', fontSize: size * 0.27,
            fontWeight: FontWeight.w900, color: color,
          ),
        ),
      ),
    );
  }
}

// ─── Metric Strip Card ────────────────────────────────────────────────────────
class MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w900,
                  color: color, letterSpacing: -0.5,
                )),
            Text(label,
                style: const TextStyle(
                  fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.w600,
                  color: AppColors.textMuted, letterSpacing: 0.7,
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String text;
  final int? count;
  final Color? countColor;
  const SectionHeader(this.text, {super.key, this.count, this.countColor});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text,
          style: const TextStyle(
            fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 1.1,
          )),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: (countColor ?? AppColors.clinicalTeal).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700,
              color: countColor ?? AppColors.clinicalTealLight,
            ),
          ),
        ),
      ],
    ]);
  }
}

// ─── Logout helper ────────────────────────────────────────────────────────────
Future<void> performLogout(BuildContext context) async {
  await ApiService.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const AuthScreen()),
  );
}
