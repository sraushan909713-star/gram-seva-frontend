// lib/features/about/screens/welcome_cards_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
// Welcome Cards Screen — 4-card horizontal swipe flow shown ONCE after
// first login (per-user, via has_seen_welcome_user_{id} flag — wired in D4.5).
//
// DELIVERY 4.2 (this version):
//   • 4-card PageView with locked EN+HI copy (from May 16 translation rounds)
//   • Per-card SVG illustration (welcome_1..4.svg in assets/illustrations/)
//   • Hindi/English toggle pill in app bar — applies across all cards
//   • Simultaneous left-to-right wipe animation on language switch
//     (same pattern as about_screen.dart, kept consistent)
//   • Skip button (top-right) on cards 1-3 → jumps to Card 4
//   • Bottom dot indicator (4 dots, active = terracotta)
//   • Card 4 has two buttons: "Start using the app" (primary) and
//     "Learn about all features" (outlined, opens About page)
//
// What's NOT here (later deliveries):
//   - has_seen_welcome_user_{id} flag setting — D4.5
//   - Card entry / draw-in animations — D4.3
//   - Cinematic welcome that runs before this — D4.4
//   - Routing logic (first-launch routing) — D4.5
//
// For D4.2 testing: "Start using the app" simply closes the screen.
// A temporary test entry will live in profile_screen.dart, removed in D4.5.
//
// Visual conventions match about_screen.dart:
//   - Page bg #FAFAF7
//   - Primary green #1A8870, terracotta #C2440A
//   - Playfair for headings, Inter for body, Noto Sans Devanagari for Hindi
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'about_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';                   // ✅ ADD (D4.5)
import '../../home/screens/home_screen.dart';                                  // ✅ ADD (D4.5)

class WelcomeCardsScreen extends StatefulWidget {
  const WelcomeCardsScreen({super.key});

  @override
  State<WelcomeCardsScreen> createState() => _WelcomeCardsScreenState();
}

class _WelcomeCardsScreenState extends State<WelcomeCardsScreen>
    with TickerProviderStateMixin {

  // ══ Palette (locked, matches About) ════════════════════════════════════════
  static const Color _green     = Color(0xFF1A8870);
  static const Color _terracotta= Color(0xFFC2440A);
  static const Color _bg        = Color(0xFFFAFAF7);
  static const Color _ink       = Color(0xFF1F2937);
  static const Color _body      = Color(0xFF374151);
  static const Color _dotIdle   = Color(0xFFD7CFC2);

  // ══ State ═════════════════════════════════════════════════════════════════
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  bool _isHindi = false;
  bool _animating = false;
  late final AnimationController _wipeCtrl;

  // All cards animate simultaneously (no stagger), same as About page.
  static const Duration _wipePerBlock = Duration(milliseconds: 950);

  // ✅ NEW (D4.3) — Card entry animation. Fires when:
  //   1. Screen first opens (post-frame callback in initState)
  //   2. The active page changes (swipe or Skip)
  //
  // One controller drives 4 staggered slices using Interval curves:
  //   - illoSweep:  0.00..0.40  diagonal pencil-edge reveal of illustration
  //   - titleFade:  0.20..0.53  title slides up 12px and fades in
  //   - para1Fade:  0.40..0.73  paragraph 1 slides up and fades in
  //   - para2Fade:  0.60..1.00  paragraph 2 slides up and fades in
  //
  // Total duration: 1500ms. Only the currently active card animates —
  // off-screen cards in the PageView render at final state to avoid
  // wasted rebuilds.
  late final AnimationController _entryCtrl;
  late final Animation<double> _illoSweep;
  late final Animation<double> _titleFade;
  late final Animation<double> _para1Fade;
  late final Animation<double> _para2Fade;
  static const Duration _entryDuration = Duration(milliseconds: 2400);

  // ══ Lifecycle ═════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _wipeCtrl = AnimationController(vsync: this);
    _pageCtrl.addListener(_onPageChanged);

    // ✅ NEW (D4.3) — entry animation setup
    _entryCtrl = AnimationController(vsync: this, duration: _entryDuration);
    _illoSweep = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.00, 0.40, curve: Curves.easeOutCubic),
    );
    _titleFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.20, 0.53, curve: Curves.easeOutCubic),
    );
    _para1Fade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.40, 0.73, curve: Curves.easeOutCubic),
    );
    _para2Fade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.60, 1.00, curve: Curves.easeOutCubic),
    );

    // Fire the entry animation for Card 1 as soon as the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entryCtrl.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onPageChanged);
    _pageCtrl.dispose();
    _wipeCtrl.dispose();
    _entryCtrl.dispose();                                          // ✅ NEW
    super.dispose();
  }

  void _onPageChanged() {
    final newPage = _pageCtrl.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      _entryCtrl.forward(from: 0);                                  // ✅ NEW (D4.3) — re-fire on card change
    }
  }

  void _toggleLanguage() {
    if (_animating) return;
    setState(() {
      _isHindi = !_isHindi;
      _animating = true;
    });
    _wipeCtrl
      ..duration = _wipePerBlock
      ..forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _animating = false);
      });
  }

  void _skipToEnd() {
    _pageCtrl.animateToPage(
      _cards.length - 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  // ✅ CHANGE (D4.5) — sets the per-user has_seen_welcome flag and routes
  // to home. Uses pushAndRemoveUntil to clear the welcome stack so the
  // user can't back-button back into the cinematic.
  Future<void> _exitWelcome() async {
    await _markWelcomeSeen();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  // ✅ CHANGE (D4.5) — also marks welcome seen, since reaching Card 4
  // means the user has been through the welcome flow regardless of which
  // button they tap. Then opens About on top of the welcome cards.
  Future<void> _openAbout() async {
    await _markWelcomeSeen();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutScreen()),
    );
  }

  // ✅ CHANGE (D4.5 simplified) — sets a device-global flag instead of
  // per-user. Avoids the user_id-empty edge case across auth flows.
  Future<void> _markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
  }

  // ══ Build ═════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isLastCard = _currentPage == _cards.length - 1;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Skip (left blank if last card) + language toggle ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip button (only on cards 1-3)
                  isLastCard
                      ? const SizedBox(width: 60)
                      : TextButton(
                          onPressed: _skipToEnd,
                          style: TextButton.styleFrom(
                            foregroundColor: _ink.withOpacity(0.55),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          child: Text(
                            _isHindi ? 'छोड़ें' : 'Skip',
                            style: (_isHindi
                                    ? GoogleFonts.notoSansDevanagari
                                    : GoogleFonts.inter)(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                  // Language toggle pill (same pattern as About page)
                  _languageToggle(),
                ],
              ),
            ),

            // ── 4-card PageView (the main content) ──
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _cards.length,
                itemBuilder: (context, i) =>
                    _buildCard(_cards[i], i, isActive: i == _currentPage),  // ✅ CHANGE
              ),
            ),

            // ── Dot indicator + bottom area (buttons on card 4) ──
            _bottomArea(isLastCard),
          ],
        ),
      ),
    );
  }

  // ══ One card body ═════════════════════════════════════════════════════════
  // ✅ CHANGE (D4.3) — when isActive == true, the card's elements animate in
  // staggered (illustration sweep → title → para1 → para2). When inactive,
  // the card renders at final state (no animation, no rebuild cost).
  Widget _buildCard(_WelcomeCard card, int idx, {required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 14, 26, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration zone — soft coloured background like About cards.
          // When active, the SVG inside reveals via a diagonal sweep.
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [card.zoneLight, card.zoneDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _illustration(card.illustrationAsset, isActive),
            ),
          ),
          const SizedBox(height: 24),

          // Small "STEP N OF 4" label (not animated — small UI label)
          Text(
            _isHindi ? 'चरण ${idx + 1} / 4' : 'STEP ${idx + 1} OF 4',
            style: (_isHindi
                    ? GoogleFonts.notoSansDevanagari
                    : GoogleFonts.inter)(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: _terracotta,
            ),
          ),
          const SizedBox(height: 6),

          // Title — entry slide-up + language wipe stacked
          _entryFade(
            anim: _titleFade,
            isActive: isActive,
            child: _WipeText(
              controller: _wipeCtrl,
              isHindi: _isHindi,
              animating: _animating,
              perBlock: _wipePerBlock,
              child: Text(
                _isHindi ? card.titleHi : card.titleEn,
                style: (_isHindi
                        ? GoogleFonts.notoSansDevanagari
                        : GoogleFonts.playfairDisplay)(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                  height: 1.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Paragraph 1 — entry fade + language wipe
          _entryFade(
            anim: _para1Fade,
            isActive: isActive,
            child: _WipeText(
              controller: _wipeCtrl,
              isHindi: _isHindi,
              animating: _animating,
              perBlock: _wipePerBlock,
              child: Text(
                _isHindi ? card.para1Hi : card.para1En,
                style: (_isHindi
                        ? GoogleFonts.notoSansDevanagari
                        : GoogleFonts.inter)(
                  fontSize: 13.5,
                  height: 1.72,
                  color: _body,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Paragraph 2 — entry fade + language wipe
          _entryFade(
            anim: _para2Fade,
            isActive: isActive,
            child: _WipeText(
              controller: _wipeCtrl,
              isHindi: _isHindi,
              animating: _animating,
              perBlock: _wipePerBlock,
              child: Text(
                _isHindi ? card.para2Hi : card.para2En,
                style: (_isHindi
                        ? GoogleFonts.notoSansDevanagari
                        : GoogleFonts.inter)(
                  fontSize: 13.5,
                  height: 1.72,
                  color: _body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Illustration with diagonal sweep when active ───────────────────────────
  Widget _illustration(String assetPath, bool isActive) {
    final svg = SvgPicture.asset(assetPath, fit: BoxFit.contain);
    if (!isActive) return svg;
    return AnimatedBuilder(
      animation: _illoSweep,
      builder: (context, _) {
        final t = _illoSweep.value;
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            final diag = bounds.width + bounds.height;
            final cut  = (diag * t).clamp(0.0, diag);
            const edge = 60.0;
            final stop1 = (cut / diag).clamp(0.0, 1.0);
            final stop2 = ((cut + edge) / diag).clamp(0.0, 1.0);
            return LinearGradient(
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, stop1, stop2],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: svg,
        );
      },
    );
  }

  // ── Fade-up entry wrapper (used for title, para1, para2) ───────────────────
  // When inactive, renders the child plainly (no animation, no rebuild cost).
  // When active, wraps in AnimatedBuilder so child slides up from 12px below
  // and fades from 0 to full opacity as `anim` progresses 0→1.
  Widget _entryFade({
    required Animation<double> anim,
    required bool isActive,
    required Widget child,
  }) {
    if (!isActive) return child;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, c) {
        final t = anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: c,
          ),
        );
      },
      child: child,
    );
  }

  // ══ Bottom area: dot indicator + buttons (or empty space) ═════════════════
  Widget _bottomArea(bool isLastCard) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 22),
      child: Column(
        children: [
          // 4-dot indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_cards.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? _terracotta : _dotIdle,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),

          // On Card 4 only: two buttons. Otherwise: empty space same height.
          if (isLastCard)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _exitWelcome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isHindi
                          ? 'ऐप इस्तेमाल शुरू करें'
                          : 'Start using the app',
                      style: (_isHindi
                              ? GoogleFonts.notoSansDevanagari
                              : GoogleFonts.inter)(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _openAbout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: BorderSide(color: _green.withOpacity(0.5), width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isHindi
                          ? 'सभी सुविधाओं के बारे में जानें'
                          : 'Learn about all features',
                      style: (_isHindi
                              ? GoogleFonts.notoSansDevanagari
                              : GoogleFonts.inter)(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            // Match height of the two-button block so the layout doesn't jump
            // between cards 1-3 and card 4. Two buttons ≈ 110px including the
            // gap. Empty SizedBox keeps cards 1-3 visually settled.
            const SizedBox(height: 110),
        ],
      ),
    );
  }

  // ══ Hindi/English toggle pill ═════════════════════════════════════════════
  Widget _languageToggle() {
    return GestureDetector(
      onTap: _toggleLanguage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.10),
          border: Border.all(color: _green.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _togglePillSide(label: 'EN', active: !_isHindi),
            _togglePillSide(label: 'हिं', active: _isHindi),
          ],
        ),
      ),
    );
  }

  Widget _togglePillSide({required String label, required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? _green : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: (label == 'हिं'
                ? GoogleFonts.notoSansDevanagari
                : GoogleFonts.inter)(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : _green,
        ),
      ),
    );
  }

  // ══ The 4 cards — locked copy in BOTH languages ═══════════════════════════
  // Source: May 16 translation rounds (all approved by Raushan).
  static final List<_WelcomeCard> _cards = [
    // ─── Card 1 ───────────────────────────────────────────────────────────
    _WelcomeCard(
      illustrationAsset: 'assets/illustrations/welcome_1.svg',
      zoneLight: const Color(0xFFFCE9D4),
      zoneDark:  const Color(0xFFF5D9A8),
      titleEn: 'Welcome to Jagruk Durbe',
      titleHi: 'जागरूक दुर्बे ऐप में आपका स्वागत है',
      para1En: 'This app is built for the people of Durbe — so that '
               'essential information reaches you easily, so that people '
               'can come together to fix what needs fixing, and so that '
               'the promises made to you stay on record.',
      para1Hi: 'यह ऐप दुर्बे के लोगों के लिए बनाया गया है। ताकि ज़रूरी '
               'जानकारी आसानी से मिल सके, किसी चीज़ को ठीक कराने के लिए लोग '
               'साथ आ सकें, और जो वादे आपसे किए गए हैं उनका हिसाब रखा जा '
               'सके।',
      para2En: 'Everything here is free. It is run by the people of Durbe '
               'themselves, by their own choice. No company, no money.',
      para2Hi: 'यहाँ सब कुछ मुफ़्त है। इसे दुर्बे के ही लोग, अपनी मर्ज़ी से '
               'चलाते हैं। कोई कंपनी नहीं, कोई पैसा नहीं।',
    ),
    // ─── Card 2 ───────────────────────────────────────────────────────────
    _WelcomeCard(
      illustrationAsset: 'assets/illustrations/welcome_2.svg',
      zoneLight: const Color(0xFFDDEAD7),
      zoneDark:  const Color(0xFFBCD6B0),
      titleEn: 'Who runs this app',
      titleHi: 'यह ऐप कौन चलाता है',
      para1En: 'Jagruk Durbe is run by the people of Durbe themselves, by '
               'their own choice. They add the schemes, verify real '
               'residents, and keep the app running.',
      para1Hi: 'इस ऐप को दुर्बे के ही लोग चलाते हैं, अपनी मर्ज़ी से। वही '
               'योजनाएँ जोड़ते हैं, असली निवासियों की पहचान करते हैं, और '
               'ऐप को चलाते रहते हैं।',
      para2En: 'Need help? You can reach any admin from the \'Members\' '
               'list inside the app.',
      para2Hi: 'मदद चाहिए? आप ऐप के अंदर \'सदस्य\' सूची से किसी भी एडमिन '
               'तक पहुँच सकते हैं।',
    ),
    // ─── Card 3 ───────────────────────────────────────────────────────────
    _WelcomeCard(
      illustrationAsset: 'assets/illustrations/welcome_3.svg',
      zoneLight: const Color(0xFFF5E2D2),
      zoneDark:  const Color(0xFFE6C5A8),
      titleEn: 'What you can do here',
      titleHi: 'आप यहाँ क्या कर सकते हैं',
      para1En: 'Once you are recognised as a resident of Durbe, you can '
               'report problems, support what others have raised, and put '
               'forward new ideas for the village.',
      para1Hi: 'दुर्बे के निवासी के रूप में पहचान हो जाने के बाद, आप '
               'समस्याएँ बता सकते हैं, दूसरों ने जो उठाया है उसका समर्थन '
               'कर सकते हैं, और गाँव के लिए नए सुझाव दे सकते हैं।',
      para2En: 'Why this recognition? So that the village\'s voice stays '
               'with the village. Use your real photo as your profile '
               'picture — that is your trust.',
      para2Hi: 'पहचान क्यों? ताकि गाँव की आवाज़ गाँव के पास ही रहे। अपनी '
               'असली तस्वीर ही अपनी फ़ोटो रखें — यही आपका भरोसा है।',
    ),
    // ─── Card 4 ───────────────────────────────────────────────────────────
    _WelcomeCard(
      illustrationAsset: 'assets/illustrations/welcome_4.svg',
      zoneLight: const Color(0xFFFFF3D6),
      zoneDark:  const Color(0xFFF5DDA0),
      titleEn: 'You\'re in',
      titleHi: 'आप जुड़ गए',
      para1En: 'Welcome again to Jagruk Durbe. We\'re glad you\'re with us.',
      para1Hi: 'जागरूक दुर्बे ऐप में हम आपका फिर से स्वागत करते हैं। हमें '
               'खुशी है कि आप हमारे साथ हैं।',
      para2En: 'Want to learn more about each feature? You can read the '
               'full guide anytime.',
      para2Hi: 'हर सुविधा के बारे में और जानना चाहते हैं? आप पूरी जानकारी '
               'कभी भी पढ़ सकते हैं।',
    ),
  ];
}

// ── Data model ───────────────────────────────────────────────────────────────
class _WelcomeCard {
  final String illustrationAsset;
  final Color zoneLight;
  final Color zoneDark;
  final String titleEn;
  final String titleHi;
  final String para1En;
  final String para1Hi;
  final String para2En;
  final String para2Hi;

  const _WelcomeCard({
    required this.illustrationAsset,
    required this.zoneLight,
    required this.zoneDark,
    required this.titleEn,
    required this.titleHi,
    required this.para1En,
    required this.para1Hi,
    required this.para2En,
    required this.para2Hi,
  });
}

// ══ _WipeText ═══════════════════════════════════════════════════════════════
// Same simultaneous left-to-right wipe used on About page. When the user
// toggles EN↔हिं, every text block reveals together with a ShaderMask wipe.
// Letters always fully formed — Devanagari conjuncts don't break.
class _WipeText extends StatelessWidget {
  final AnimationController controller;
  final bool isHindi;
  final bool animating;
  final Duration perBlock;
  final Widget child;

  const _WipeText({
    required this.controller,
    required this.isHindi,
    required this.animating,
    required this.perBlock,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!animating) {
      return KeyedSubtree(
        key: ValueKey('block-$isHindi'),
        child: child,
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value.clamp(0.0, 1.0);
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            final width = bounds.width;
            final edge  = (width * 0.06).clamp(8.0, 28.0);
            final cut   = (width * t).clamp(0.0, width);
            final stop1 = (cut / width).clamp(0.0, 1.0);
            final stop2 = ((cut + edge) / width).clamp(0.0, 1.0);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, stop1, stop2],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}