import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_page.dart';
import 'owner_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'change_password_page.dart';
import 'tools_gateway.dart';
import 'login_page.dart';
import 'bug_sender.dart';
import 'contact_page.dart';
import 'profile_page.dart';
import 'riwayat_page.dart';
import 'info_page.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF0B0F1A);
  static const surface   = Color(0xFF0E1320);
  static const card      = Color(0xFF131C2E);
  static const cardAlt   = Color(0xFF192236);
  static const border    = Color(0xFF1E2D4A);
  static const borderLit = Color(0xFF253560);
  static const teal      = Color(0xFF4ECDC4);
  static const green     = Color(0xFF22C55E);
  static const blue      = Color(0xFF3B82F6);
  static const amber     = Color(0xFFF59E0B);
  static const red       = Color(0xFFEF4444);
  static const orange    = Color(0xFFFF6B35);
  static const pink      = Color(0xFFEC4899);
  static const indigo    = Color(0xFF4169E1);
  static const text      = Color(0xFFEEEEEE);
  static const textSub   = Color(0xFF7B8DB3);
  static const textDim   = Color(0xFF2D3A5A);
}

// ─── Role helpers ──────────────────────────────────────────────────────────────
Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return const Color(0xFFFBBF24);
    case 'admin':    return const Color(0xFFFF5555);
    case 'reseller': return const Color(0xFF4ADE80);
    case 'vip':      return const Color(0xFFA78BFA);
    default:         return _C.pink;
  }
}
IconData _roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'owner':    return Icons.workspace_premium_rounded;
    case 'admin':    return Icons.admin_panel_settings_rounded;
    case 'reseller': return Icons.storefront_rounded;
    case 'vip':      return Icons.star_rounded;
    default:         return Icons.shield_rounded;
  }
}
String _roleShort(String role) {
  if (role.isEmpty) return '??';
  return role.substring(0, math.min(2, role.length)).toUpperCase();
}

// ─── Feature Card Model ────────────────────────────────────────────────────────
class _FC {
  final IconData icon;
  final String title, subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _FC({required this.icon, required this.title, required this.subtitle,
      required this.gradient, required this.onTap});
}

// ─── Dashboard Page ────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  final String username, password, role, expiredDate, sessionKey;
  final List<Map<String, dynamic>> listBug, listDoos;
  final List<dynamic> news;
  const DashboardPage({
    super.key, required this.username, required this.password,
    required this.role, required this.expiredDate, required this.listBug,
    required this.listDoos, required this.sessionKey, required this.news,
  });
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  late String sessionKey, username, password, role, expiredDate;
  late List<Map<String, dynamic>> listBug, listDoos;
  late List<dynamic> newsList;

  late WebSocketChannel channel;
  String androidId = 'unknown';
  File? _profileImage;
  VideoPlayerController? _menuVideoCtrl;

  int _navIndex = 0;
  Widget _body  = const SizedBox();
  int onlineUsers = 0, activeConns = 0;

  late AnimationController _bgCtrl, _pageCtrl, _pulseCtrl;
  late Animation<double> _pageFade, _pulse;
  late Animation<Offset> _pageSlide;

  // Hero banner page controller
  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;

  @override
  void initState() {
    super.initState();
    sessionKey  = widget.sessionKey; username = widget.username;
    password    = widget.password;   role     = widget.role;
    expiredDate = widget.expiredDate;
    listBug     = widget.listBug; listDoos = widget.listDoos;
    newsList    = widget.news;

    _bgCtrl    = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pageCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat(reverse: true);

    _pageFade  = CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pulse = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _body = _homeDashboard();
    _pageCtrl.forward();
    _initAndroidId();
    _loadProfileImage();
    _initMenuVideo();
  }

  @override
  void dispose() {
    channel.sink.close(status.goingAway);
    _bgCtrl.dispose(); _pageCtrl.dispose(); _pulseCtrl.dispose();
    _menuVideoCtrl?.dispose(); _bannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path  = prefs.getString('profile_image_$username');
    if (path != null && path.isNotEmpty && mounted)
      setState(() => _profileImage = File(path));
  }

  void _initMenuVideo() {
    _menuVideoCtrl = VideoPlayerController.asset('assets/videos/banner.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _menuVideoCtrl?.setLooping(true); _menuVideoCtrl?.play();
      });
  }

  Future<void> _initAndroidId() async {
    final info = await DeviceInfoPlugin().androidInfo;
    androidId = info.id;
    _connectWS();
  }

  void _connectWS() {
    channel = WebSocketChannel.connect(
        Uri.parse('https://panel-legal.jhonaley.net:3519'));
    channel.sink.add(jsonEncode({'type': 'validate', 'key': sessionKey, 'androidId': androidId}));
    channel.sink.add(jsonEncode({'type': 'stats'}));
    channel.stream.listen((event) {
      final data = jsonDecode(event);
      if (data['type'] == 'myInfo' && data['valid'] == false) {
        _handleInvalidSession(data['reason'] == 'androidIdMismatch'
            ? 'Akun ini login di perangkat lain.'
            : 'Sesi tidak valid. Silakan login ulang.');
      }
      if (data['type'] == 'stats' && mounted) {
        setState(() {
          onlineUsers = data['onlineUsers'] ?? 0;
          activeConns = data['activeConnections'] ?? 0;
        });
      }
    });
  }

  Future<void> _openUrl(String url) async =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  void _handleInvalidSession(String msg) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    _showSystemDialog(title: 'Sesi Berakhir', message: msg,
        icon: Icons.lock_outline_rounded, color: _C.red,
        onOk: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false));
  }

  Future<void> _doLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  void _navigate(Widget page) {
    setState(() => _body = page);
    _pageCtrl.forward(from: 0);
  }

  // ── 5-item nav ─────────────────────────────────────────────────────────────
  void _onNavTap(int index) {
    setState(() => _navIndex = index);
    switch (index) {
      case 0: _navigate(_homeDashboard()); break;
      case 1: _navigate(InfoPage(sessionKey: sessionKey)); break;
      case 2: _navigate(HomePage(username: username, password: password,
          listBug: listBug, role: role, expiredDate: expiredDate,
          sessionKey: sessionKey)); break;
      case 3: _navigate(ToolsPage(sessionKey: sessionKey,
          userRole: role, listDoos: listDoos)); break;
      case 4: Navigator.push(context, _slideRoute(ProfilePage(
          username: username, password: password, role: role,
          expiredDate: expiredDate, sessionKey: sessionKey))); break;
    }
  }

  void _onDrawerNav(int index) {
    Navigator.pop(context);
    switch (index) {
      case 1: _navigate(SellerPage(keyToken: sessionKey)); break;
      case 2: _navigate(AdminPage(sessionKey: sessionKey)); break;
      case 3: _navigate(OwnerPage(sessionKey: sessionKey, username: username)); break;
    }
  }

  void _showSystemDialog({required String title, required String message,
      required IconData icon, required Color color, VoidCallback? onOk}) {
    showGeneralDialog(
      context: context, barrierDismissible: false, barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child)),
      pageBuilder: (ctx, _, __) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(color: _C.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 40)]),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: _C.textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 24),
            _MxBtn(label: 'OK', fullWidth: true, color: color, onTap: () {
              Navigator.pop(ctx); onOk?.call();
            }),
          ]),
        ),
      ),
    );
  }

  // ── Feature Cards ──────────────────────────────────────────────────────────
  List<_FC> _buildFeatureCards() => [
    _FC(icon: FontAwesomeIcons.whatsapp, title: 'Manage Sender',
        subtitle: 'Pairing & Configuration',
        gradient: [const Color(0xFFFF1744), const Color(0xFFFF6B9D)],
        onTap: () => Navigator.push(context, _slideRoute(BugSenderPage(
            sessionKey: sessionKey, username: username, role: role)))),
    _FC(icon: FontAwesomeIcons.telegram, title: 'Info Channel',
        subtitle: 'Gabung update channel',
        gradient: [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
        onTap: () => _openUrl('https://t.me/+TESTI_YUSI')),
    _FC(icon: Icons.headset_mic_outlined, title: 'Kontak Kami',
        subtitle: 'Hubungi tim support',
        gradient: [const Color(0xFF16A34A), const Color(0xFF4ADE80)],
        onTap: () => Navigator.push(context, _slideRoute(const ContactPage()))),
    _FC(icon: Icons.history_rounded, title: 'Riwayat Akun',
        subtitle: 'Log aktivitas akun kamu',
        gradient: [const Color(0xFF6D28D9), const Color(0xFFA78BFA)],
        onTap: () => Navigator.push(context,
            _slideRoute(RiwayatPage(sessionKey: sessionKey, role: role)))),
    _FC(icon: Icons.lock_outline_rounded, title: 'Ganti Password',
        subtitle: 'Perbarui keamanan akun',
        gradient: [const Color(0xFFDC2626), const Color(0xFFF87171)],
        onTap: () => Navigator.push(context, _slideRoute(
            ChangePasswordPage(username: username, sessionKey: sessionKey)))),
  ];

  // ── HOME DASHBOARD ─────────────────────────────────────────────────────────
  Widget _homeDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 1. Hero Banner
        _buildHeroBanner(),
        const SizedBox(height: 14),
        // 2. User Card
        _userCard(),
        const SizedBox(height: 14),
        // 3. Quick Actions Header Card
        _buildQuickActionsHeader(),
        const SizedBox(height: 12),
        // 4. Feature Cards Horizontal Scroll
        _buildFeatureCardsSection(),
        const SizedBox(height: 80),
      ]),
    );
  }

  // ── Hero Banner ────────────────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 258,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            // Background: news images as banner
            if (newsList.isNotEmpty)
              PageView.builder(
                controller: _bannerCtrl,
                onPageChanged: (i) => setState(() => _bannerPage = i),
                itemCount: newsList.length,
                itemBuilder: (_, i) => newsList[i]['image'] != null &&
                    newsList[i]['image'].toString().isNotEmpty
                    ? NewsMedia(url: newsList[i]['image'])
                    : _PlaceholderBanner(),
              )
            else
              _PlaceholderBanner(),

            // Dark gradient overlay (bottom heavy)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xE00B0F1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
            ),

            // Text overlay bottom-left: "CRASH LIGHT" style
            Positioned(
              left: 18, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBannerLogo(),
                ],
              ),
            ),

            // Banner dots top-right
            if (newsList.length > 1)
              Positioned(
                top: 12, right: 14,
                child: Row(
                  children: List.generate(newsList.length, (i) {
                    final active = i == _bannerPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: active ? 16 : 5, height: 5,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.9)
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBannerLogo() {
    return Stack(children: [
      // Stroke/outline layer
      Text('CRASH LIGHT',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white,
        ),
      ),
      // Fill layer (dark = hollow look)
      const Text('CRASH LIGHT',
        style: TextStyle(
          color: Color(0xFF1A1A2E),
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    ]);
  }

  // ── User Card with Hexagon Stats ───────────────────────────────────────────
  Widget _userCard() {
    final rColor = _roleColor(role);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.border, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35),
              blurRadius: 22, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          // ── Avatar row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Avatar circle (glow effect)
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: rColor,
                  boxShadow: [
                    BoxShadow(color: rColor.withOpacity(0.55), blurRadius: 16,
                        offset: const Offset(0, 4)),
                    BoxShadow(color: rColor.withOpacity(0.25), blurRadius: 28),
                  ],
                ),
                child: _profileImage != null
                    ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover))
                    : Icon(_roleIcon(role), color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),

              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome Back,',
                    style: TextStyle(color: _C.textSub, fontSize: 12)),
                const SizedBox(height: 1),
                Text(username.toUpperCase(),
                    style: const TextStyle(color: _C.text, fontSize: 20,
                        fontWeight: FontWeight.w900, height: 1.15,
                        letterSpacing: 0.5)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.borderLit,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _C.border),
                  ),
                  child: Text(_roleShort(role),
                      style: const TextStyle(color: _C.textSub, fontSize: 9,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ])),

              // Green pulsing timer button
              GestureDetector(
                onTap: () => Navigator.push(context, _slideRoute(ProfilePage(
                    username: username, password: password, role: role,
                    expiredDate: expiredDate, sessionKey: sessionKey))),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.teal.withOpacity(0.15),
                      border: Border.all(
                          color: _C.teal.withOpacity(_pulse.value * 0.8), width: 2),
                      boxShadow: [
                        BoxShadow(color: _C.teal.withOpacity(_pulse.value * 0.4),
                            blurRadius: 14),
                      ],
                    ),
                    child: const Icon(Icons.timer_outlined, color: _C.teal, size: 19),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Dashboard label bar ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border.all(color: _C.teal.withOpacity(0.25)),
                borderRadius: BorderRadius.circular(8),
                color: _C.teal.withOpacity(0.02),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _C.teal.withOpacity(0.6))),
                const SizedBox(width: 8),
                Text('CRASH LIGHT DASHBOARD',
                    style: TextStyle(color: _C.teal.withOpacity(0.7),
                        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2.2)),
                const SizedBox(width: 8),
                Container(width: 4, height: 4,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: _C.teal.withOpacity(0.6))),
              ]),
            ),
          ),

          // ── Divider ────────────────────────────────────────────────────────
          Container(margin: const EdgeInsets.only(top: 14), height: 1, color: _C.border),

          // ── Hexagon Stats ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _HexStat(icon: Icons.people_alt_rounded,
                  value: '$onlineUsers', label: 'Online Users',
                  color: _C.green, showLive: true),
              _HexStat(icon: Icons.link_rounded,
                  value: '$activeConns', label: 'Active Connections',
                  color: _C.blue),
              _HexStat(icon: Icons.calendar_month_rounded,
                  value: expiredDate, label: 'Expiration',
                  color: _C.amber, smallValue: true),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Quick Actions Header Card ──────────────────────────────────────────────
  Widget _buildQuickActionsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
              blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          // Lightning icon circle
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3A2D00),
              border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.35)),
              boxShadow: [BoxShadow(
                  color: const Color(0xFFFBBF24).withOpacity(0.2), blurRadius: 10)],
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Color(0xFFFBBF24), size: 24),
          ),
          const SizedBox(width: 14),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('QUICK\nACTIONS',
                style: TextStyle(color: _C.text, fontSize: 16,
                    fontWeight: FontWeight.w900, height: 1.1, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            const Text('Beberapa Menu Tambahan',
                style: TextStyle(color: _C.textSub, fontSize: 11)),
          ])),

          // CRASH badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _C.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.teal.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _C.teal,
                  boxShadow: [BoxShadow(
                      color: _C.teal.withOpacity(0.6), blurRadius: 5)],
                ),
              ),
              const SizedBox(width: 5),
              const Text('CRASH',
                  style: TextStyle(color: _C.teal, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Feature Cards Horizontal Scroll ───────────────────────────────────────
  Widget _buildFeatureCardsSection() {
    final fcs = _buildFeatureCards();
    return SizedBox(
      height: 192,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 8),
        itemCount: fcs.length,
        itemBuilder: (_, i) => _FeatureCard(fc: fcs[i]),
      ),
    );
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: Stack(children: [
        Positioned.fill(child: _AnimatedBg(controller: _bgCtrl)),
        SafeArea(
          child: FadeTransition(opacity: _pageFade,
              child: SlideTransition(position: _pageSlide, child: _body)),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── AppBar: "CRASH LIGHT" style ──────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      elevation: 0, centerTitle: true, titleSpacing: 0,
      leading: Builder(builder: (ctx) =>
          _MenuBtn(onTap: () => Scaffold.of(ctx).openDrawer())),
      title: _buildAppBarLogo(),
      actions: [
        _AppBarIconBtn(icon: Icons.headphones_outlined, onTap: () {}),
        _AppBarIconBtn(icon: Icons.notifications_outlined, onTap: () {}),
        _AppBarIconBtn(icon: Icons.logout_rounded, onTap: _doLogout),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }

  Widget _buildAppBarLogo() {
    // Outlined hollow-letter style like the photo
    return Stack(alignment: Alignment.center, children: [
      // White stroke outline
      Text('CRASH LIGHT',
        style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white,
        ),
      ),
      // Dark fill = hollow/outlined appearance
      Text('CRASH LIGHT',
        style: const TextStyle(
          color: _C.surface,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    ]);
  }

  // ── Bottom Nav: 5 items + center FAB ──────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Nav bar row (64px)
            SizedBox(
              height: 64,
              child: Row(children: [
                _buildNavItem5(0, Icons.home_rounded, 'Home'),
                _buildNavItem5(1, Icons.chat_bubble_outline_rounded, 'Berita'),
                // Center gap for FAB
                const Expanded(child: SizedBox()),
                _buildNavItem5(3, Icons.build_outlined, 'Tools'),
                _buildNavItem5(4, Icons.person_outline_rounded, 'Profile'),
              ]),
            ),
            // Center FAB (elevated above nav bar)
            Positioned(
              top: -22,
              child: GestureDetector(
                onTap: () => _onNavTap(2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: _C.red,
                      border: Border.all(color: _C.surface, width: 3),
                      boxShadow: [
                        BoxShadow(color: _C.red.withOpacity(0.5),
                            blurRadius: 16, offset: const Offset(0, 4)),
                        BoxShadow(color: _C.red.withOpacity(0.25),
                            blurRadius: 28),
                      ],
                    ),
                    child: const Icon(Icons.group_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 3),
                  Text('BUG WHATSAPP',
                      style: TextStyle(
                        color: _navIndex == 2 ? Colors.white : _C.textSub,
                        fontSize: 9, fontWeight: FontWeight.w600,
                      )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem5(int index, IconData icon, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Top blue bar indicator (active)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2, width: active ? 22 : 0,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: _C.indigo,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Icon(icon, size: 22,
              color: active ? _C.indigo : _C.textSub),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(
              color: active ? _C.indigo : _C.textSub,
              fontSize: 9,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.78,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.border))),
        child: Column(children: [
          _DrawerHeader(username: username, role: role,
              expiredDate: expiredDate, profileImage: _profileImage,
              videoCtrl: _menuVideoCtrl),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                children: [
                  if (role == 'reseller') _DrawerItem(icon: Icons.storefront_rounded,
                      label: 'Seller Page', onTap: () => _onDrawerNav(1)),
                  if (role == 'admin') _DrawerItem(icon: Icons.admin_panel_settings_rounded,
                      label: 'Admin Page', onTap: () => _onDrawerNav(2)),
                  if (role == 'owner') _DrawerItem(icon: Icons.workspace_premium_rounded,
                      label: 'Owner Page', onTap: () => _onDrawerNav(3)),
                ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _DrawerItem(icon: Icons.logout_rounded, label: 'Keluar',
                isDestructive: true, onTap: () async {
                  Navigator.pop(context); await _doLogout();
                }),
          ),
        ]),
      ),
    );
  }
}

// ─── Placeholder Banner ────────────────────────────────────────────────────────
class _PlaceholderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E2D4A), Color(0xFF0B0F1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF2D3A5A), size: 48),
      ),
    );
  }
}

// ─── Hexagon Stat Widget ───────────────────────────────────────────────────────
class _HexStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  final bool showLive, smallValue;

  const _HexStat({required this.icon, required this.value, required this.label,
      required this.color, this.showLive = false, this.smallValue = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Stack(clipBehavior: Clip.none, children: [
        // Hexagon shape
        SizedBox(
          width: 70, height: 70,
          child: CustomPaint(
            painter: _HexPainter(color),
            child: Center(child: Icon(icon, color: color, size: 26)),
          ),
        ),
        // Green live dot top-right
        if (showLive)
          Positioned(
            top: 6, right: 8,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: _C.green,
                border: Border.all(color: _C.card, width: 1.5),
                boxShadow: [BoxShadow(color: _C.green.withOpacity(0.6), blurRadius: 6)],
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(
          color: _C.text, fontSize: smallValue ? 11 : 16,
          fontWeight: FontWeight.w800),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      SizedBox(
        width: 85,
        child: Text(label, style: const TextStyle(color: _C.textSub, fontSize: 9),
            textAlign: TextAlign.center, maxLines: 2),
      ),
      // LIVE badge
      if (showLive) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: _C.green.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(20),
            color: _C.green.withOpacity(0.08),
          ),
          child: const Text('LIVE',
              style: TextStyle(color: _C.green, fontSize: 8,
                  fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
      ],
    ]);
  }
}

// ─── Hexagon Painter ───────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      // Flat-top hexagon (0° start)
      final angle = (math.pi / 3) * i;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();

    // Fill
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.10)
      ..style = PaintingStyle.fill);

    // Stroke
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_HexPainter old) => false;
}

// ─── Feature Card Widget ───────────────────────────────────────────────────────
class _FeatureCard extends StatefulWidget {
  final _FC fc;
  const _FeatureCard({required this.fc});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fc = widget.fc;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); fc.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 260,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: fc.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(color: fc.gradient[0].withOpacity(0.4),
                  blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Stack(children: [
            // Ghost icon (watermark bottom-right)
            Positioned(
              right: -10, bottom: -10,
              child: Icon(fc.icon, size: 90,
                  color: Colors.white.withOpacity(0.12)),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + "Tap →"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icon circle
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: Icon(fc.icon, color: Colors.white, size: 20),
                      ),
                      // Tap button
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Tap →',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Title
                  Text(fc.title,
                      style: const TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w900, height: 1.1)),
                  const SizedBox(height: 3),
                  // Subtitle
                  Text(fc.subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Drawer Header ─────────────────────────────────────────────────────────────
class _DrawerHeader extends StatefulWidget {
  final String username, role, expiredDate;
  final File? profileImage;
  final VideoPlayerController? videoCtrl;
  const _DrawerHeader({required this.username, required this.role,
      required this.expiredDate, required this.profileImage, required this.videoCtrl});
  @override
  State<_DrawerHeader> createState() => _DrawerHeaderState();
}

class _DrawerHeaderState extends State<_DrawerHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    _c.forward();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rColor = _roleColor(widget.role);
    return Container(
      height: 230, clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: _C.card,
          border: Border(bottom: BorderSide(color: _C.border))),
      child: Stack(children: [
        if (widget.videoCtrl != null && widget.videoCtrl!.value.isInitialized)
          Positioned.fill(child: FittedBox(fit: BoxFit.cover,
              child: SizedBox(width: widget.videoCtrl!.value.size.width,
                  height: widget.videoCtrl!.value.size.height,
                  child: VideoPlayer(widget.videoCtrl!)))),
        Positioned.fill(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0x440B0F1A), Color(0xF20B0F1A)],
          )),
        )),
        Positioned.fill(child: SafeArea(
          child: FadeTransition(opacity: _fade, child: SlideTransition(
            position: _slide,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Stack(children: [
                Container(
                  width: 74, height: 74,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rColor,
                      border: Border.all(color: rColor.withOpacity(0.6), width: 2),
                      boxShadow: [BoxShadow(color: rColor.withOpacity(0.3), blurRadius: 16)]),
                  child: ClipOval(child: widget.profileImage != null
                      ? Image.file(widget.profileImage!, fit: BoxFit.cover)
                      : Icon(_roleIcon(widget.role), size: 32, color: Colors.white)),
                ),
                Positioned(right: 0, bottom: 0, child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: rColor, shape: BoxShape.circle,
                      border: Border.all(color: _C.card, width: 2)),
                  child: Icon(_roleIcon(widget.role), size: 9, color: Colors.white),
                )),
              ]),
              const SizedBox(height: 12),
              Text(widget.username, style: const TextStyle(
                  color: _C.text, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: rColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: rColor.withOpacity(0.3))),
                child: Text(widget.role.toUpperCase(), style: TextStyle(
                    color: rColor, fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
              const SizedBox(height: 5),
              Text('Exp: ${widget.expiredDate}',
                  style: const TextStyle(color: _C.textSub, fontSize: 10)),
            ]),
          )),
        )),
      ]),
    );
  }
}

// ─── Drawer Item ───────────────────────────────────────────────────────────────
class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _DrawerItem({required this.icon, required this.label,
      required this.onTap, this.isDestructive = false});
  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.isDestructive ? _C.red : _C.textSub;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _pressed ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _pressed ? color.withOpacity(0.25) : _C.border),
        ),
        child: Row(children: [
          Icon(widget.icon, color: color, size: 17),
          const SizedBox(width: 14),
          Text(widget.label, style: TextStyle(
              color: widget.isDestructive ? _C.red : _C.text,
              fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: _C.textDim, size: 11),
        ]),
      ),
    );
  }
}

// ─── AppBar Icon Button ────────────────────────────────────────────────────────
class _AppBarIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarIconBtn({required this.icon, required this.onTap});
  @override
  State<_AppBarIconBtn> createState() => _AppBarIconBtnState();
}

class _AppBarIconBtnState extends State<_AppBarIconBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _down ? _C.borderLit : _C.card,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _C.border),
          ),
          child: Icon(widget.icon, color: _C.textSub, size: 17),
        ),
      ),
    );
  }
}

// ─── Menu Button ───────────────────────────────────────────────────────────────
class _MenuBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _MenuBtn({required this.onTap});
  @override
  State<_MenuBtn> createState() => _MenuBtnState();
}

class _MenuBtnState extends State<_MenuBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          decoration: BoxDecoration(
            color: _down ? _C.borderLit : _C.card,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _C.border),
          ),
          child: const Icon(Icons.menu_rounded, color: _C.textSub, size: 19),
        ),
      ),
    );
  }
}

// ─── Animated Background (Hex Grid) ───────────────────────────────────────────
class _AnimatedBg extends StatelessWidget {
  final AnimationController controller;
  const _AnimatedBg({required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
          painter: _BgPainter(controller.value), size: Size.infinite),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0B0F1A));

    final gridPaint = Paint()
      ..color = const Color(0xFF1E2D4A).withOpacity(0.3)
      ..strokeWidth = 0.5 ..style = PaintingStyle.stroke;
    const hexSize = 36.0;
    final hexW = hexSize * math.sqrt(3);
    final hexH = hexSize * 2;
    final rows = (size.height / (hexH * 0.75)).ceil() + 2;
    final cols = (size.width / hexW).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final dx = col * hexW + (row.isOdd ? hexW / 2 : 0);
        final dy = row * hexH * 0.75;
        _drawHex(canvas, Offset(dx, dy), hexSize, gridPaint);
      }
    }

    canvas.drawCircle(
      Offset(size.width / 2, -size.height * 0.1), size.width * 0.8,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF4ECDC4)
            .withOpacity(0.05 + math.sin(t * math.pi * 2) * 0.02),
        Colors.transparent,
      ], radius: 0.6).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, -size.height * 0.1),
          radius: size.width * 0.8)),
    );

    canvas.drawCircle(
      Offset(size.width * 0.15, size.height), size.width * 0.5,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFFEF4444)
            .withOpacity(0.04 + math.sin(t * math.pi * 2 + 1) * 0.01),
        Colors.transparent,
      ], radius: 0.5).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height),
          radius: size.width * 0.5)),
    );
  }

  void _drawHex(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 180) * (60 * i - 30);
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => old.t != t;
}

// ─── Mx Button ─────────────────────────────────────────────────────────────────
class _MxBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;
  final Color color;
  const _MxBtn({required this.label, required this.onTap,
      this.fullWidth = false, this.color = _C.teal});
  @override
  State<_MxBtn> createState() => _MxBtnState();
}

class _MxBtnState extends State<_MxBtn> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 46,
          width: widget.fullWidth ? double.infinity : null,
          padding: widget.fullWidth
              ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity(0.35)),
            boxShadow: _down ? [] : [BoxShadow(color: widget.color.withOpacity(0.12),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
              color: widget.color, fontWeight: FontWeight.w800,
              fontSize: 14, letterSpacing: 0.5))),
        ),
      ),
    );
  }
}

// ─── Shared ────────────────────────────────────────────────────────────────────
PageRoute _slideRoute(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: const Duration(milliseconds: 320),
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: FadeTransition(opacity: anim, child: child)),
);

// ─── NewsMedia ─────────────────────────────────────────────────────────────────
class NewsMedia extends StatefulWidget {
  final String url;
  const NewsMedia({super.key, required this.url});
  @override
  State<NewsMedia> createState() => _NewsMediaState();
}

class _NewsMediaState extends State<NewsMedia> {
  VideoPlayerController? _ctrl;
  @override
  void initState() {
    super.initState();
    if (_isVideo(widget.url)) {
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _ctrl?.setLooping(true); _ctrl?.setVolume(0); _ctrl?.play();
        });
    }
  }
  bool _isVideo(String url) => url.endsWith('.mp4') || url.endsWith('.webm')
      || url.endsWith('.mov') || url.endsWith('.mkv');
  @override
  void dispose() { _ctrl?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (_isVideo(widget.url)) {
      if (_ctrl?.value.isInitialized == true) {
        return AspectRatio(aspectRatio: _ctrl!.value.aspectRatio,
            child: VideoPlayer(_ctrl!));
      }
      return Container(color: _C.card, child: const Center(child: SizedBox(
          width: 18, height: 18, child: CircularProgressIndicator(
              strokeWidth: 1.5, color: _C.teal))));
    }
    return Image.network(widget.url, fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null ? child
          : Container(color: _C.card, child: Center(child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
              strokeWidth: 1.5, color: _C.teal))),
      errorBuilder: (_, __, ___) => Container(color: _C.card,
          child: const Icon(Icons.broken_image_outlined,
              color: _C.textSub, size: 28)),
    );
  }
}
