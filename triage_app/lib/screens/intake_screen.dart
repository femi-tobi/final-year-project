import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/triage_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen>
    with SingleTickerProviderStateMixin {
  // ─── Controllers ─────────────────────────────────────────────────────────
  final _formKey      = GlobalKey<FormState>();
  final _ageCtr       = TextEditingController();
  final _hrCtr        = TextEditingController();
  final _sbpCtr       = TextEditingController();
  final _tempCtr      = TextEditingController();
  final _o2Ctr        = TextEditingController();
  final _symptomCtr   = TextEditingController();

  // ─── State ────────────────────────────────────────────────────────────────
  bool _loading        = false;
  bool _serverOnline   = false;
  Timer? _healthTimer;

  // ─── Animation ───────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _checkServer();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkServer(),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _healthTimer?.cancel();
    for (final c in [_ageCtr, _hrCtr, _sbpCtr, _tempCtr, _o2Ctr, _symptomCtr]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkServer() async {
    final ok = await ApiService.checkHealth();
    if (mounted) setState(() => _serverOnline = ok);
  }

  // ─── Submit ───────────────────────────────────────────────────────────────
  Future<void> _dispatch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final result = await ApiService.predict(
        age:         double.parse(_ageCtr.text.trim()),
        heartRate:   double.parse(_hrCtr.text.trim()),
        systolicBp:  double.parse(_sbpCtr.text.trim()),
        temperature: double.parse(_tempCtr.text.trim()),
        o2Sat:       double.parse(_o2Ctr.text.trim()),
        symptomText: _symptomCtr.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, a1, a2) => ResultsScreen(result: result),
          transitionsBuilder: (_, a1, a2, child) => FadeTransition(
            opacity: a1,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 450),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.emergency.withOpacity(0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDemographicsRow(),
                    const SizedBox(height: 24),
                    _buildVitalsGrid(),
                    const SizedBox(height: 24),
                    _buildSymptomsField(),
                    const SizedBox(height: 28),
                    _buildDispatchButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2A3E), Color(0xFF0D3B54), Color(0xFF0F4C5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.clinicalTeal.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.clinicalTealGlow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.clinicalTealLight.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: AppColors.clinicalTealLight,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI-Driven Multimodal\nTriage Gateway',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Server status
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _serverOnline
                          ? AppColors.statusGreen.withOpacity(0.4)
                          : AppColors.emergency.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _serverOnline ? _pulseAnim.value : 1.0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _serverOnline
                                ? AppColors.statusGreen
                                : AppColors.emergency,
                            boxShadow: [
                              BoxShadow(
                                color: (_serverOnline
                                        ? AppColors.statusGreen
                                        : AppColors.emergency)
                                    .withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _serverOnline
                            ? 'Server Connection: Active (XGBoost Phase 3)'
                            : 'Server Connection: Offline',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _serverOnline
                              ? AppColors.statusGreen
                              : AppColors.emergency,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Demographics ─────────────────────────────────────────────────────────
  Widget _buildDemographicsRow() {
    return _SectionCard(
      label: 'PATIENT DEMOGRAPHICS',
      child: _VitalInput(
        controller: _ageCtr,
        label: 'Age',
        hint: 'e.g. 45',
        icon: Icons.person_outline_rounded,
        unit: 'yrs',
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          final n = int.tryParse(v);
          if (n == null || n < 1 || n > 120) return '1–120';
          return null;
        },
      ),
    );
  }

  // ─── Vitals 2×2 Grid ──────────────────────────────────────────────────────
  Widget _buildVitalsGrid() {
    return _SectionCard(
      label: 'PHYSIOLOGICAL VITALS',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.4,
        children: [
          _VitalInput(
            controller: _hrCtr,
            label: 'Heart Rate',
            hint: 'BPM',
            icon: Icons.favorite_outline_rounded,
            unit: 'bpm',
            iconColor: const Color(0xFFFF6B8A),
            validator: _numValidator('10–300'),
            allowDecimal: false,
          ),
          _VitalInput(
            controller: _sbpCtr,
            label: 'Systolic BP',
            hint: 'mmHg',
            icon: Icons.monitor_heart_outlined,
            unit: 'mmHg',
            iconColor: const Color(0xFF60A5FA),
            validator: _numValidator('40–300'),
            allowDecimal: false,
          ),
          _VitalInput(
            controller: _tempCtr,
            label: 'Temperature',
            hint: '°C',
            icon: Icons.thermostat_rounded,
            unit: '°C',
            iconColor: const Color(0xFFFBBF24),
            validator: _decimalValidator('30–45'),
            allowDecimal: true,
          ),
          _VitalInput(
            controller: _o2Ctr,
            label: 'O₂ Saturation',
            hint: '%',
            icon: Icons.air_rounded,
            unit: '%',
            iconColor: const Color(0xFF34D399),
            validator: _numValidator('50–100'),
            allowDecimal: false,
          ),
        ],
      ),
    );
  }

  String? Function(String?) _numValidator(String range) {
    return (v) {
      if (v == null || v.isEmpty) return 'Required';
      if (double.tryParse(v) == null) return 'Invalid';
      return null;
    };
  }

  String? Function(String?) _decimalValidator(String range) {
    return (v) {
      if (v == null || v.isEmpty) return 'Required';
      if (double.tryParse(v) == null) return 'Invalid';
      return null;
    };
  }

  // ─── Symptoms ─────────────────────────────────────────────────────────────
  Widget _buildSymptomsField() {
    return _SectionCard(
      label: 'CHIEF COMPLAINT / UNSTRUCTURED CLINICAL NOTES',
      child: TextFormField(
        controller: _symptomCtr,
        maxLines: 5,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.55,
        ),
        decoration: InputDecoration(
          hintText:
              'e.g. "severe crushing chest pressure, shortness of breath, diaphoresis…"',
          hintMaxLines: 3,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8, top: 12),
            child: Icon(
              Icons.notes_rounded,
              color: AppColors.clinicalTealLight.withOpacity(0.7),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 0,
          ),
          alignLabelWithHint: true,
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter clinical notes' : null,
      ),
    );
  }

  // ─── Dispatch Button ──────────────────────────────────────────────────────
  Widget _buildDispatchButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
        onPressed: _loading ? null : _dispatch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.rocket_launch_rounded, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'DISPATCH FOR INFUSED INFERENCE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Reusable Section Card ───────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _SectionCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ─── Individual Vital Input ───────────────────────────────────────────────────
class _VitalInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String unit;
  final Color iconColor;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final bool allowDecimal;

  const _VitalInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.unit,
    this.iconColor = AppColors.clinicalTealLight,
    this.validator,
    this.inputFormatters,
    this.allowDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
          inputFormatters: inputFormatters ??
              [
                FilteringTextInputFormatter.allow(
                  allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
                ),
              ],
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: unit,
            suffixStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
