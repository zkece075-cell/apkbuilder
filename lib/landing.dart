import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  // ── Dark Navy colour palette ──────────────────────────────────────────────
  static const Color _bg       = Color(0xFF020617);
  static const Color _card     = Color(0xFF0A1124);
  static const Color _line     = Color(0xFF1B2A41);
  static const Color _primary  = Color(0xFF1E3A8A);
  static const Color _primarySoft = Color(0xFF3B82F6);
  static const Color _text     = Color(0xFFE6EDF7);
  static const Color _muted    = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) { _showSnack('Link tidak valid.'); return; }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) _showSnack('Tidak dapat membuka link.');
    } catch (_) {
      _showSnack('Terjadi kesalahan saat membuka link.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF020617), Color(0xFF01030A), Color(0xFF020617)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: _StarDust()),

            // Glow
            Positioned(
              top: -60,
              left: size.width * 0.15,
              child: _glow(size.width * 0.55, _primary.withOpacity(0.12)),
            ),
            Positioned(
              top: size.height * 0.38,
              right: -50,
              child: _glow(size.width * 0.30, Colors.blueAccent.withOpacity(0.08)),
            ),
            Positioned(
              bottom: 0,
              left: -40,
              child: _glow(size.width * 0.28, _primary.withOpacity(0.06)),
            ),

            SafeArea(
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          children: [
                            _buildTopLogo(),
                            const SizedBox(height: 20),
                            _buildMainTitle(),
                            const SizedBox(height: 28),
                            _buildInfoCard(),
                            const SizedBox(height: 28),
                            _buildLoginButton(),
                            const SizedBox(height: 14),
                            _buildContactSupportButton(),
                            const SizedBox(height: 28),
                            _buildBottomContactCard(),
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
      ),
    );
  }

  // ── LOGO ─────────────────────────────────────────────
  Widget _buildTopLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _primary.withOpacity(0.25),
                Colors.transparent,
              ],
            ),
          ),
        ),
        SizedBox(
          width: 110,
          height: 110,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    colors: [
                      _primary.withOpacity(0.3),
                      _primarySoft.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(color: _primary.withOpacity(0.4)),
                ),
                child: Icon(Icons.flash_on, color: _primarySoft, size: 54),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── TITLE ─────────────────────────────────────────────
  Widget _buildMainTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [Colors.white, _primarySoft, Colors.white],
          ).createShader(bounds),
          child: const Text(
            'CRASH LIGHT',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'GACOR  ·  TERUPDATE  ·  STABIL',
          style: TextStyle(
            color: _primarySoft.withOpacity(0.8),
            letterSpacing: 3,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return _glassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.shield_outlined, color: _primarySoft, size: 40),
          const SizedBox(height: 10),
          Text('CRASH LIGHT BUG',
              style: TextStyle(color: _text, fontSize: 20)),
          const SizedBox(height: 10),
          Text(
            'Aplikasi dengan desain elegan dan fitur terbaru.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return _outlineButton(
      icon: FontAwesomeIcons.bolt,
      label: 'LOGIN TO CRASH LIGHT',
      glow: true,
      onTap: () => Navigator.pushNamed(context, '/login'),
    );
  }

  Widget _buildContactSupportButton() {
    return _outlineButton(
      icon: FontAwesomeIcons.headset,
      label: 'CONTACT SUPPORT',
      glow: false,
      onTap: () => _openUrl('https://t.me/YUKIJI_MD'),
    );
  }

  Widget _buildBottomContactCard() {
    return _glassCard(
      padding: const EdgeInsets.all(18),
      child: Text(
        'HUBUNGI KAMI',
        style: TextStyle(color: _muted),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool glow = false,
  }) {
    return Container(
      height: 65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: glow ? _primary : _line,
        ),
        boxShadow: glow
            ? [BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 15)]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(icon, color: _primarySoft),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: _text)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _card.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: child,
    );
  }

  Widget _glow(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

// ── STAR BACKGROUND ─────────────────────────────────────────────
class _StarDust extends StatelessWidget {
  const _StarDust();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarDustPainter());
  }
}

class _StarDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x553B82F6);

    for (int i = 0; i < 30; i++) {
      canvas.drawCircle(
        Offset(
          (size.width * i) % size.width,
          (size.height * i * 0.3) % size.height,
        ),
        1,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}