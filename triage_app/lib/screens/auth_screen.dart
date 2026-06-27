import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  // ─── Controllers ──────────────────────────────────────────────────────────
  final _formKey   = GlobalKey<FormState>();
  final _idCtr     = TextEditingController();
  final _passCtr   = TextEditingController();
  bool _obscurePass = true;
  bool _loading     = false;
  String _selectedRole = 'Triage Nurse';

  static const _roles = ['Triage Nurse', 'Emergency Doctor', 'Administrator'];

  // ─── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _fadeAnim  = CurvedAnimation(parent: _fadeCtrl,  curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeCtrl.forward();
      _slideCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _idCtr.dispose();
    _passCtr.dispose();
    super.dispose();
  }

  // ─── Login ────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final session = await ApiService.login(LoginRequest(
        userId:   _idCtr.text.trim(),
        password: _passCtr.text.trim(),
        role:     _selectedRole,
      ));

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, a1, a2) => DashboardScreen(session: session),
          transitionsBuilder: (_, a1, a2, child) =>
              FadeTransition(opacity: a1, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showBiometricDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Biometric Login',
          style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Inter'),
        ),
        content: const Text(
          'Biometric authentication would be triggered here using local_auth plugin on a real device.\n\nFor this demo, use your institutional ID and password.',
          style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Inter', height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.clinicalTealLight)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.emergency.withOpacity(0.92),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ]),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(
        children: [
          // Radial glow background
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.clinicalTeal.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.emergency.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogo(),
                          const SizedBox(height: 40),
                          _buildRoleSelector(),
                          const SizedBox(height: 24),
                          _buildIdField(),
                          const SizedBox(height: 16),
                          _buildPasswordField(),
                          const SizedBox(height: 28),
                          _buildLoginButton(),
                          const SizedBox(height: 20),
                          _buildBiometricButton(),
                          const SizedBox(height: 32),
                          _buildDemoHint(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logo / Header ────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0D7280), Color(0xFF0891B2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.clinicalTeal.withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'AI TRIAGE GATEWAY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Secure Role-Based Clinical Access',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ─── Role Selector ────────────────────────────────────────────────────────
  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT ROLE', style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: _roles.map((role) {
              final selected = _selectedRole == role;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = role),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.clinicalTeal
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      role.replaceAll(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        letterSpacing: 0.3,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── ID Field ────────────────────────────────────────────────────────────
  Widget _buildIdField() {
    return TextFormField(
      controller: _idCtr,
      keyboardType: TextInputType.text,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: 'Institutional ID',
        hintText: 'e.g. nurse001 / doctor001 / admin001',
        prefixIcon: const Icon(Icons.badge_outlined,
            color: AppColors.clinicalTealLight, size: 20),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Enter your institutional ID' : null,
    );
  }

  // ─── Password Field ───────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passCtr,
      obscureText: _obscurePass,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.clinicalTealLight, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePass
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Enter your password' : null,
    );
  }

  // ─── Login Button ─────────────────────────────────────────────────────────
  Widget _buildLoginButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _loading
            ? null
            : const LinearGradient(
                colors: [Color(0xFF0D7280), Color(0xFF0891B2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: _loading
            ? []
            : [
                BoxShadow(
                  color: AppColors.clinicalTeal.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                'SECURE LOGIN',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ─── Biometric Button ─────────────────────────────────────────────────────
  Widget _buildBiometricButton() {
    return OutlinedButton.icon(
      onPressed: _showBiometricDialog,
      icon: const Icon(Icons.fingerprint_rounded, size: 20),
      label: const Text(
        'BIOMETRIC LOGIN',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 1.0,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.clinicalTealLight,
        side: const BorderSide(color: AppColors.clinicalTeal),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Demo Credentials Hint ────────────────────────────────────────────────
  Widget _buildDemoHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.clinicalTealLight, size: 15),
            const SizedBox(width: 7),
            const Text(
              'DEMO CREDENTIALS',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.clinicalTealLight,
                letterSpacing: 1.0,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          _credRow('Nurse',  'nurse001'),
          _credRow('Doctor', 'doctor001'),
          _credRow('Admin',  'admin001'),
          const SizedBox(height: 2),
          const Text('Password: pass123 (all accounts)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textMuted,
              )),
        ],
      ),
    );
  }

  Widget _credRow(String label, String id) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textSecondary,
              )),
        ),
        Text(id,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
            )),
      ]),
    );
  }
}
