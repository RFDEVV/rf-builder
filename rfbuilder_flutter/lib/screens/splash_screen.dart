import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../core/config.dart';
import '../core/prefs.dart';

/// Splash: memakai video (assets/splash/splash.mp4) jika ada, kalau tidak
/// memakai splash bawaan yang meniru splash web (logo RF + progress).
class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _checked = false;
  bool _done = false;
  bool _dontShow = false;
  double _progress = 0;
  Timer? _tick;
  Timer? _max;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _max = Timer(Duration(seconds: AppConfig.splashMaxSeconds), _finish);
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final c = VideoPlayerController.asset(AppConfig.splashVideoAsset);
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      c.addListener(() {
        final v = c.value;
        if (v.isInitialized && !v.isPlaying && v.position >= v.duration && v.duration > Duration.zero) {
          _finish();
        }
      });
      await c.setLooping(false);
      await c.play();
      setState(() { _video = c; _videoReady = true; _checked = true; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checked = true);
      _startFakeProgress();
    }
  }

  void _startFakeProgress() {
    _tick = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) return;
      setState(() => _progress = (_progress + 0.022).clamp(0.0, 1.0));
      if (_progress >= 1) {
        t.cancel();
        Future.delayed(const Duration(milliseconds: 250), _finish);
      }
    });
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    if (_dontShow) Prefs.skipSplash = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _max?.cancel();
    _dots.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = Prefs.lastThemeLight;
    return Scaffold(
      backgroundColor: light ? const Color(0xFFF5F4FA) : const Color(0xFF07070E),
      body: Stack(fit: StackFit.expand, children: [
        if (_videoReady && _video != null)
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _video!.value.aspectRatio,
                child: VideoPlayer(_video!),
              ),
            ),
          )
        else if (_checked)
          _defaultSplash(light),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _skipButton(light || false),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GestureDetector(
                onTap: () => setState(() => _dontShow = !_dontShow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_dontShow ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18, color: (_videoReady ? Colors.white : (light ? const Color(0xFF5D5780) : const Color(0xFF9B97C0)))),
                  const SizedBox(width: 6),
                  Text('Jangan tampilkan lagi',
                      style: TextStyle(
                          fontSize: 12,
                          color: _videoReady ? Colors.white70 : (light ? const Color(0xFF5D5780) : const Color(0xFF9B97C0)))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _skipButton(bool light) {
    final fg = _videoReady ? Colors.white : (light ? const Color(0xFF1A1530) : Colors.white);
    return Material(
      color: Colors.black.withOpacity(_videoReady ? .35 : .0),
      shape: StadiumBorder(side: BorderSide(color: fg.withOpacity(.25))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _finish,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Lewati', style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.skip_next_rounded, color: fg, size: 18),
          ]),
        ),
      ),
    );
  }

  // Meniru .splash-screen di shared.css
  Widget _defaultSplash(bool light) {
    final inter = GoogleFonts.inter;
    final titleColors = light
        ? const [Color(0xFF1A1530), Color(0xFF7C3AED), Color(0xFF4338CA)]
        : const [Color(0xFFF0EEFF), Color(0xFFC084FC), Color(0xFF818CF8)];
    final subColor = light ? const Color(0xD95D5780) : const Color(0xD99B97C0);
    final loadColor = light ? const Color(0xCC5D5780) : const Color(0xCC9B97C0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .55, 1],
          colors: light
              ? const [Color(0xFFF5F4FA), Color(0xFFFFFFFF), Color(0xFFEEEDF6)]
              : const [Color(0xFF07070E), Color(0xFF0D0D1A), Color(0xFF111122)],
        ),
      ),
      child: CustomPaint(
        painter: _GridPainter(const Color(0xFF7C3AED).withOpacity(light ? .04 : .08)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF7C3AED), Color(0xFF6366F1)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(.2), blurRadius: 40)],
                  ),
                  alignment: Alignment.center,
                  child: Text('RF', style: inter(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
                const SizedBox(height: 18),
                ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    stops: const [0, .6, 1], colors: titleColors,
                  ).createShader(r),
                  child: Text('RFBuilder',
                      style: inter(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.96, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Text('Website to APK • Build • Create • Innovate',
                    textAlign: TextAlign.center, style: inter(fontSize: 14, color: subColor)),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 4,
                      color: (light ? Colors.black : Colors.white).withOpacity(light ? .08 : .08),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC084FC)]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('MEMUAT ${(_progress * 100).round()}%',
                    style: inter(fontSize: 11.5, color: loadColor, letterSpacing: 1.4)),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _dots,
                  builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _dot((_dots.value - i * .125) % 1.0),
                    ]
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // splashBlink: 0%,100% opacity .35 scale 1 -> 50% opacity 1 scale 1.2
  Widget _dot(double t) {
    final k = t < .5 ? t * 2 : (1 - t) * 2;
    return Opacity(
      opacity: .35 + .65 * k,
      child: Transform.scale(
        scale: 1 + .2 * k,
        child: Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFFA855F7), shape: BoxShape.circle)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color c;
  _GridPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = c..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 40) { canvas.drawLine(Offset(x, 0), Offset(x, s.height), p); }
    for (double y = 0; y < s.height; y += 40) { canvas.drawLine(Offset(0, y), Offset(s.width, y), p); }
  }
  @override
  bool shouldRepaint(covariant _GridPainter o) => o.c != c;
}
