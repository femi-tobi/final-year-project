// auth_screen.dart
// Premium split-panel login — dark illustrated left side + clean form right side.
// Responsive: stacked on mobile, side-by-side on wide screens.

import 'dart:math' as math;
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

  final _formKey  = GlobalKey<FormState>();
  final _idCtr    = TextEditingController();
  final _passCtr  = TextEditingController();
  bool _obscurePass    = true;
  bool _loading        = false;
  String _selectedRole = 'Triage Nurse';

  static const _roles = ['Triage Nurse', 'Emergency Doctor', 'Administrator'];

  // ─── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _floatCtrl;   // floating stethoscope bob
  late final AnimationController _shimmerCtrl; // shimmer on left panel
  late final AnimationController _pulseCtrl;   // heartbeat pulse

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _floatAnim;
  late final Animation<double> _shimmerAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _floatAnim = Tween<double>(begin: -8, end: 8)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _shimmerCtrl.dispose();
    _pulseCtrl.dispose();
    _idCtr.dispose();
    _passCtr.dispose();
    super.dispose();
  }

  // ─── Login ──────────────────────────────────────────────────────────────────
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
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, a1, a2) => DashboardScreen(session: session),
        transitionsBuilder: (_, a1, a2, child) =>
            FadeTransition(opacity: a1, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.emergency,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 13))),
      ]),
    ));
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Scaffold(
      backgroundColor: const Color(0xFF060D1A),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDE — side-by-side
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildWideLayout() {
    return Row(children: [
      // Left illustrated panel
      Expanded(flex: 5, child: _buildIllustrationPanel()),
      // Right form panel
      Expanded(flex: 4, child: _buildFormPanel(isWide: true)),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NARROW — stacked (mobile / tablet portrait)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      child: Column(children: [
        // Compact banner on mobile
        _buildCompactBanner(),
        _buildFormPanel(isWide: false),
      ]),
    );
  }

  // ── Compact top banner (mobile) ───────────────────────────────────────────
  Widget _buildCompactBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF040C1C), Color(0xFF0B2040), Color(0xFF0D3B70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.4),
                      blurRadius: 16, spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TRIAGE AI',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 18,
                      fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              Text('Clinical Decision System',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                      color: Colors.white.withOpacity(0.55))),
            ]),
          ]),
          const SizedBox(height: 24),
          // Triage queuing illustration/image
          Center(child: _buildTriageImage(compact: true)),
        ],
      ),
    );
  }

  // ── Left Illustration Panel (wide) ────────────────────────────────────────
  Widget _buildIllustrationPanel() {
    return Stack(
      children: [
        // Background image
        Positioned.fill(
          child: Image.asset(
            'assets/triage_waiting_room.png',
            fit: BoxFit.cover,
          ),
        ),
        // Dark gradient overlay for text readability and sleek clinical look
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF030A16).withOpacity(0.92),
                  const Color(0xFF081A35).withOpacity(0.82),
                  const Color(0xFF0C244C).withOpacity(0.55),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        // Animated shimmer orb
        Positioned(
          top: -100, left: -100,
          child: AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, __) {
              final angle = _shimmerAnim.value * math.pi * 2;
              return Transform.translate(
                offset: Offset(math.sin(angle) * 30, math.cos(angle) * 20),
                child: Container(
                  width: 400, height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF0EA5E9).withOpacity(0.12),
                      Colors.transparent,
                    ]),
                  ),
                ),
              );
            },
          ),
        ),

        // Second orb bottom right
        Positioned(
          bottom: -80, right: -60,
          child: Container(
            width: 320, height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF6366F1).withOpacity(0.14),
                Colors.transparent,
              ]),
            ),
          ),
        ),

        // Decorative circles ring
        ..._buildDecorativeCircles(),

        // Grid dot pattern
        Positioned.fill(child: _buildDotGrid()),

        // Main content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo / brand
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.45),
                          blurRadius: 22, spreadRadius: 3),
                    ],
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TRIAGE AI',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 22,
                          fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.5)),
                  Text('Clinical Decision System',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12,
                          color: Colors.white.withOpacity(0.5))),
                ]),
              ]),

              const SizedBox(height: 60),

              // Headline
              const Text(
                'Intelligent\nEmergency\nTriage.',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 44,
                  fontWeight: FontWeight.w900, color: Colors.white,
                  height: 1.1, letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AI-powered multimodal triage assessment\n'
                'with XGBoost clinical decision support.',
                style: TextStyle(
                  fontFamily: 'Inter', fontSize: 14.5,
                  color: Colors.white.withOpacity(0.5), height: 1.7,
                ),
              ),

              const Spacer(),

              // Stats row
              _buildStatsPills(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  // ── Triage Waiting Room Image ─────────────────────────────────────────────
  Widget _buildTriageImage({required bool compact}) {
    final double width = compact ? 220.0 : 360.0;
    final double height = compact ? 120.0 : 220.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0EA5E9).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.2),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/triage_waiting_room.png',
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (!compact)
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emergency_outlined,
                          color: const Color(0xFF0EA5E9).withOpacity(0.9),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Waiting Area Live Monitor',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.5),
                          width: 0.8,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: Color(0xFF22C55E),
                            size: 6,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF22C55E),
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
      ),
    );
  }

  // ── Decorative background circles ────────────────────────────────────────
  List<Widget> _buildDecorativeCircles() {
    const specs = [
      (top: 40.0,  left: 80.0,  r: 120.0, op: 0.04),
      (top: 180.0, left: -30.0, r: 90.0,  op: 0.06),
      (top: -30.0, left: 260.0, r: 70.0,  op: 0.05),
    ];
    return specs.map((s) => Positioned(
      top: s.top, left: s.left,
      child: Container(
        width: s.r, height: s.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(s.op), width: 1),
        ),
      ),
    )).toList();
  }

  // ── Dot grid texture ─────────────────────────────────────────────────────
  Widget _buildDotGrid() {
    return CustomPaint(painter: _DotGridPainter());
  }

  // ── Stats pills row ───────────────────────────────────────────────────────
  Widget _buildStatsPills() {
    return Row(children: [
      _StatPill(icon: Icons.people_outline_rounded, label: '3 Roles', color: const Color(0xFF0EA5E9)),
      const SizedBox(width: 10),
      _StatPill(icon: Icons.security_rounded, label: 'End-to-End Secure', color: const Color(0xFF22C55E)),
      const SizedBox(width: 10),
      _StatPill(icon: Icons.bolt_rounded, label: 'Real-Time AI', color: const Color(0xFF8B5CF6)),
    ]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RIGHT / BOTTOM — Form Panel
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFormPanel({required bool isWide}) {
    return Container(
      constraints: isWide ? null : const BoxConstraints(minHeight: 600),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        boxShadow: isWide
            ? [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(-10, 0))]
            : null,
      ),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 44 : 28, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Form header
                        _buildFormHeader(),
                        const SizedBox(height: 36),

                        // Role selector
                        _buildRoleSelector(),
                        const SizedBox(height: 26),

                        // ID field
                        _buildIdField(),
                        const SizedBox(height: 16),

                        // Password field
                        _buildPasswordField(),
                        const SizedBox(height: 28),

                        // Login button
                        _buildLoginButton(),
                        const SizedBox(height: 16),

                        // Biometric button
                        _buildBiometricButton(),
                        const SizedBox(height: 32),

                        // Divider
                        Row(children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text('DEMO ACCOUNTS',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 9.5,
                                    color: Colors.white.withOpacity(0.3), letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.08), thickness: 1)),
                        ]),
                        const SizedBox(height: 16),

                        // Demo hint
                        _buildDemoHint(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Form Header ───────────────────────────────────────────────────────────
  Widget _buildFormHeader() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Welcome back',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: const Color(0xFF0EA5E9).withOpacity(0.85),
              fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 6),
      const Text('Sign in to\nyour dashboard',
          style: TextStyle(fontFamily: 'Inter', fontSize: 30,
              fontWeight: FontWeight.w900, color: Colors.white,
              height: 1.15, letterSpacing: -0.8)),
      const SizedBox(height: 10),
      Text('Enter your institutional credentials below.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13,
              color: Colors.white.withOpacity(0.4), height: 1.5)),
    ]);
  }

  // ── Role Selector ─────────────────────────────────────────────────────────
  Widget _buildRoleSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SELECT ROLE',
          style: TextStyle(fontFamily: 'Inter', fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.2,
              color: Colors.white.withOpacity(0.4))),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E36),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: _roles.map((role) {
            final selected = _selectedRole == role;
            final roleIcon = role == 'Triage Nurse'
                ? Icons.medical_services_rounded
                : role == 'Emergency Doctor'
                    ? Icons.medical_information_rounded
                    : Icons.admin_panel_settings_rounded;
            final roleColor = role == 'Triage Nurse'
                ? const Color(0xFF0EA5E9)
                : role == 'Emergency Doctor'
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFF59E0B);

            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedRole = role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: selected ? roleColor.withOpacity(0.2) : Colors.transparent,
                    border: selected
                        ? Border.all(color: roleColor.withOpacity(0.5), width: 1.2)
                        : null,
                    boxShadow: selected
                        ? [BoxShadow(color: roleColor.withOpacity(0.2), blurRadius: 12)]
                        : null,
                  ),
                  child: Column(children: [
                    Icon(roleIcon,
                        size: 18,
                        color: selected ? roleColor : Colors.white.withOpacity(0.25)),
                    const SizedBox(height: 5),
                    Text(
                      role.replaceAll(' ', '\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter', fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected ? roleColor : Colors.white.withOpacity(0.35),
                        height: 1.4, letterSpacing: 0.2,
                      ),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ── ID Field ──────────────────────────────────────────────────────────────
  Widget _buildIdField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('INSTITUTIONAL ID',
          style: TextStyle(fontFamily: 'Inter', fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.2,
              color: Colors.white.withOpacity(0.4))),
      const SizedBox(height: 8),
      TextFormField(
        controller: _idCtr,
        keyboardType: TextInputType.text,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'nurse001  /  doctor001  /  admin001',
          hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 12,
              color: Colors.white.withOpacity(0.2)),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.badge_outlined, color: const Color(0xFF0EA5E9).withOpacity(0.7), size: 20),
          ),
          filled: true,
          fillColor: const Color(0xFF0F1E36),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.emergency, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter your institutional ID' : null,
      ),
    ]);
  }

  // ── Password Field ────────────────────────────────────────────────────────
  Widget _buildPasswordField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('PASSWORD',
            style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 1.2,
                color: Colors.white.withOpacity(0.4))),
        const Spacer(),
        Text('pass123 (demo)',
            style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                color: const Color(0xFF0EA5E9).withOpacity(0.55))),
      ]),
      const SizedBox(height: 8),
      TextFormField(
        controller: _passCtr,
        obscureText: _obscurePass,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: Colors.white),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 14,
              color: Colors.white.withOpacity(0.2)),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.lock_outline_rounded, color: const Color(0xFF0EA5E9).withOpacity(0.7), size: 20),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white.withOpacity(0.3), size: 19,
            ),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
          filled: true,
          fillColor: const Color(0xFF0F1E36),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.emergency, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter your password' : null,
      ),
    ]);
  }

  // ── Login Button ──────────────────────────────────────────────────────────
  Widget _buildLoginButton() {
    // Pick gradient colour based on selected role
    final roleGrad = _selectedRole == 'Emergency Doctor'
        ? const [Color(0xFF4F46E5), Color(0xFF7C3AED)]
        : _selectedRole == 'Administrator'
            ? const [Color(0xFFD97706), Color(0xFFF59E0B)]
            : const [Color(0xFF0284C7), Color(0xFF0EA5E9)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _loading ? null : LinearGradient(
          colors: roleGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: _loading ? [] : [
          BoxShadow(color: roleGrad[0].withOpacity(0.45), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.login_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                const Text('SIGN IN',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w800,
                        fontSize: 14, letterSpacing: 1.8, color: Colors.white)),
              ]),
      ),
    );
  }

  // ── Biometric / Secondary ─────────────────────────────────────────────────
  Widget _buildBiometricButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(Icons.fingerprint_rounded, size: 18,
            color: Colors.white.withOpacity(0.4)),
        label: Text('BIOMETRIC LOGIN',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700,
                fontSize: 12, letterSpacing: 1.2, color: Colors.white.withOpacity(0.4))),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // ── Demo credentials ──────────────────────────────────────────────────────
  Widget _buildDemoHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E36),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        _DemoCredRow(icon: Icons.medical_services_rounded,
            color: const Color(0xFF0EA5E9), role: 'Triage Nurse', id: 'nurse001'),
        const SizedBox(height: 8),
        _DemoCredRow(icon: Icons.medical_information_rounded,
            color: const Color(0xFF6366F1), role: 'Emergency Doctor', id: 'doctor001'),
        const SizedBox(height: 8),
        _DemoCredRow(icon: Icons.admin_panel_settings_rounded,
            color: const Color(0xFFF59E0B), role: 'Admin', id: 'admin001'),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            const Icon(Icons.key_rounded, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text('All accounts use password: pass123',
                style: TextStyle(fontFamily: 'Inter', fontSize: 10.5,
                    color: Colors.white.withOpacity(0.25))),
          ]),
        ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Stats pill widget
// ──────────────────────────────────────────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label,
              style: TextStyle(fontFamily: 'Inter', fontSize: 10,
                  fontWeight: FontWeight.w600, color: color.withOpacity(0.9)),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Demo credential row
// ──────────────────────────────────────────────────────────────────────────────
class _DemoCredRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String role;
  final String id;
  const _DemoCredRow({required this.icon, required this.color,
      required this.role, required this.id});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 12, color: color),
      ),
      const SizedBox(width: 10),
      Text(role,
          style: TextStyle(fontFamily: 'Inter', fontSize: 11.5,
              color: Colors.white.withOpacity(0.4))),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(id,
            style: TextStyle(fontFamily: 'Inter', fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color.withOpacity(0.85),
                fontStyle: FontStyle.italic)),
      ),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Dot Grid Painter
// ──────────────────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter _) => false;
}
