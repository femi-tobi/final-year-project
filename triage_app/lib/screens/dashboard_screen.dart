// dashboard_screen.dart
// Role-aware routing shell.
// Reads session.role and delegates to the appropriate purpose-built dashboard.

import 'package:flutter/material.dart';

import '../models/auth_models.dart';
import 'nurse_dashboard.dart';
import 'doctor_dashboard.dart';
import 'admin_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  final UserSession session;
  const DashboardScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.isNurse)  return NurseDashboard(session: session);
    if (session.isDoctor) return DoctorDashboard(session: session);
    if (session.isAdmin)  return AdminDashboard(session: session);

    // Fallback: unknown role — show nurse dashboard as safe default
    return NurseDashboard(session: session);
  }
}
