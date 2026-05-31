// lib/features/about/screens/cinematic_welcome_screen.dart
// ═══════════════════════════════════════════════════════════════════════════
// Cinematic Welcome — 21.5-second visual storyline shown ONCE before the
// welcome cards on a user's first launch (wiring in D4.5).
//
// DELIVERY 4.4b — REBUILT (storyline arc per scene):
//   • 4 scenes (Gram Awaaz, Vikas Prastav, Crop Prices, Schemes), 4.5s each
//   • Each scene shows BEFORE and AFTER illustrations TOGETHER, top-to-bottom,
//     connected by a downward arrow + middle caption (EN+HI)
//   • Story arc per scene:
//       0.00 – 0.156  BEFORE slides up from below, fades in
//       0.156 – 0.356 BEFORE holds (let user read it)
//       0.356 – 0.533 middle caption + arrow fade in
//       0.533 – 0.756 AFTER slides up, fades in
//       0.756 – 0.889 both held together (the "story complete" moment)
//       0.889 – 1.000 fade out
//   • Closing beat (~3.5s): green sunrise glow, EN + HI tagline, Welcome button
//   • Skip button always visible top-right
//   • Tap Welcome → routes to welcome cards (D4.5 will wire the real flow)
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'welcome_cards_screen.dart';

class CinematicWelcomeScreen extends StatefulWidget {
  const CinematicWelcomeScreen({super.key});

  @override
  State<CinematicWelcomeScreen> createState() => _CinematicWelcomeScreenState();
}

class _CinematicWelcomeScreenState extends State<CinematicWelcomeScreen>
    with SingleTickerProviderStateMixin {

  // ══ Palette ═══════════════════════════════════════════════════════════════
  static const Color _green     = Color(0xFF1A8870);
  static const Color _greenDark = Color(0xFF114F44);
  static const Color _gold      = Color(0xFFF5B940);
  static const Color _bg        = Color(0xFFFAFAF7);
  static const Color _ink       = Color(0xFF1F2937);
  static const Color _body      = Color(0xFF374151);

  // ══ Timeline ══════════════════════════════════════════════════════════════
  // 4 scenes × 4.5s = 18s, + 3.5s closing = 21.5s total
  static const Duration _totalDuration = Duration(milliseconds: 24000);

  static const double _s1Start = 0.000;
  static const double _s2Start = 0.209;
  static const double _s3Start = 0.419;
  static const double _s4Start = 0.628;
  static const double _closingStart = 0.837;

  late final AnimationController _ctrl;

  late final Animation<double> _closingBgFade;
  late final Animation<double> _closingLogoFade;
  late final Animation<double> _closingTaglineFade;
  late final Animation<double> _closingButtonFade;

  bool _finished = false;

  // ══ Lifecycle ═════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _totalDuration);

    _closingBgFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.837, 0.875, curve: Curves.easeOut),
    );
    _closingLogoFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.860, 0.910, curve: Curves.easeOut),
    );
    _closingTaglineFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.900, 0.960, curve: Curves.easeOut),
    );
    _closingButtonFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.955, 1.0, curve: Curves.easeOut),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _finished = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ══ Navigation ════════════════════════════════════════════════════════════
  void _skipCinematic() {
    _ctrl.animateTo(1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut);
  }

  void _enterApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeCardsScreen()),
    );
  }

  // ══ Per-scene phase calculator ════════════════════════════════════════════
  _SceneState _sceneState(double t, double sceneStart, double sceneEnd) {
    if (t < sceneStart || t > sceneEnd) {
      return const _SceneState(active: false);
    }
    final local = (t - sceneStart) / (sceneEnd - sceneStart);

    double sceneAlpha = 1.0;
    if (local > 0.889) {
      sceneAlpha = 1.0 - (local - 0.889) / 0.111;
    }

    double beforeOpacity;
    double beforeOffsetY;
    if (local < 0.156) {
      final p = local / 0.156;
      beforeOpacity = p;
      beforeOffsetY = (1 - p) * 18;
    } else {
      beforeOpacity = 1.0;
      beforeOffsetY = 0;
    }

    double middleOpacity;
    if (local < 0.356) {
      middleOpacity = 0;
    } else if (local < 0.533) {
      middleOpacity = (local - 0.356) / 0.177;
    } else {
      middleOpacity = 1.0;
    }

    double afterOpacity;
    double afterOffsetY;
    if (local < 0.533) {
      afterOpacity = 0;
      afterOffsetY = 18;
    } else if (local < 0.756) {
      final p = (local - 0.533) / 0.223;
      afterOpacity = p;
      afterOffsetY = (1 - p) * 18;
    } else {
      afterOpacity = 1.0;
      afterOffsetY = 0;
    }

    return _SceneState(
      active: true,
      sceneAlpha: sceneAlpha,
      beforeOpacity: beforeOpacity,
      beforeOffsetY: beforeOffsetY,
      middleOpacity: middleOpacity,
      afterOpacity: afterOpacity,
      afterOffsetY: afterOffsetY,
    );
  }

  // ══ Build ═════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _scene(
                    state: _sceneState(t, _s1Start, _s2Start),
                    beforePath: 'assets/illustrations/gram_awaaz.svg',
                    afterPath:  'assets/illustrations/gram_awaaz_after.svg',
                    captionEn:  'After your voice was raised…',
                    captionHi:  'आपकी आवाज़ उठने के बाद…',
                  ),
                  _scene(
                    state: _sceneState(t, _s2Start, _s3Start),
                    beforePath: 'assets/illustrations/vikas_prastav_before.svg',
                    afterPath:  'assets/illustrations/vikas_prastav_after.svg',
                    captionEn:  'When the village came together…',
                    captionHi:  'जब गाँव साथ आया…',
                  ),
                  _scene(
                    state: _sceneState(t, _s3Start, _s4Start),
                    beforePath: 'assets/illustrations/crop_prices_before.svg',
                    afterPath:  'assets/illustrations/crop_prices_after.svg',
                    captionEn:  'With the app on your phone…',
                    captionHi:  'ऐप आपके फ़ोन पर…',
                  ),
                  _scene(
                    state: _sceneState(t, _s4Start, _closingStart),
                    beforePath: 'assets/illustrations/schemes_before.svg',
                    afterPath:  'assets/illustrations/schemes_after.svg',
                    captionEn:  'When help reached the right people…',
                    captionHi:  'जब मदद सही लोगों तक पहुँची…',
                  ),
                ],
              );
            },
          ),

          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              if (_ctrl.value < _closingStart) return const SizedBox.shrink();
              return _closingBeat(w, h);
            },
          ),

          Positioned(
            top: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 14, 0),
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    if (_finished) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: _skipCinematic,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.95),
                        backgroundColor: Colors.black.withOpacity(0.20),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══ One storyline scene (before / arrow+caption / after stacked) ═══════════
  Widget _scene({
    required _SceneState state,
    required String beforePath,
    required String afterPath,
    required String captionEn,
    required String captionHi,
  }) {
    if (!state.active) return const SizedBox.shrink();

    return Positioned.fill(
      child: Opacity(
        opacity: state.sceneAlpha,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              children: [
                // BEFORE illustration
                Expanded(
                  flex: 5,
                  child: Opacity(
                    opacity: state.beforeOpacity,
                    child: Transform.translate(
                      offset: Offset(0, state.beforeOffsetY),
                      child: RepaintBoundary(
                        child: SvgPicture.asset(
                          beforePath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Middle: arrow + caption
                Expanded(
                  flex: 2,
                  child: Opacity(
                    opacity: state.middleOpacity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                            color: _green,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          captionEn,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: _ink,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          captionHi,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansDevanagari(
                            fontSize: 13,
                            color: _body,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // AFTER illustration
                Expanded(
                  flex: 5,
                  child: Opacity(
                    opacity: state.afterOpacity,
                    child: Transform.translate(
                      offset: Offset(0, state.afterOffsetY),
                      child: RepaintBoundary(
                        child: SvgPicture.asset(
                          afterPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══ Closing beat ═══════════════════════════════════════════════════════════
  Widget _closingBeat(double w, double h) {
    final bgOpacity = _closingBgFade.value;
    final logoOpacity = _closingLogoFade.value;
    final taglineOpacity = _closingTaglineFade.value;
    final buttonOpacity = _closingButtonFade.value;

    return Positioned.fill(
      child: Opacity(
        opacity: bgOpacity,
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.4,
              colors: [
                _gold.withOpacity(0.55),
                _green.withOpacity(0.92),
                _greenDark,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 80),
                Opacity(
                  opacity: logoOpacity,
                  child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.45), width: 1.5),
                    ),
                    child: const Center(
                      child: Text('🌿', style: TextStyle(fontSize: 44)),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: logoOpacity,
                  child: Text(
                    'JAGRUK DURBE',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: logoOpacity,
                  child: Text(
                    'जागरूक दुर्बे',
                    style: GoogleFonts.notoSansDevanagari(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.92),
                    ),
                  ),
                ),
                const Spacer(),
                Opacity(
                  opacity: taglineOpacity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          'Exclusively built in the service of the people of Durbe',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'दुर्बे के लोगों की सेवा में विशेष रूप से बनाया गया',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSansDevanagari(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Opacity(
                  opacity: buttonOpacity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: buttonOpacity < 0.9 ? null : _enterApp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _greenDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Welcome',
                          style: GoogleFonts.inter(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SceneState {
  final bool active;
  final double sceneAlpha;
  final double beforeOpacity;
  final double beforeOffsetY;
  final double middleOpacity;
  final double afterOpacity;
  final double afterOffsetY;

  const _SceneState({
    this.active = false,
    this.sceneAlpha = 0,
    this.beforeOpacity = 0,
    this.beforeOffsetY = 0,
    this.middleOpacity = 0,
    this.afterOpacity = 0,
    this.afterOffsetY = 0,
  });
}