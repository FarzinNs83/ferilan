// ignore_for_file: deprecated_member_use
// window_manager 0.6 marks its 0.5.x-style API (legacy.dart) deprecated; it is the documented bridge.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

/// Design A "Midnight" tokens.
abstract final class C {
  static const bg = Color(0xFF0B0F14);
  static const surface = Color(0xFF121821);
  static const field = Color(0xFF0E141B);
  static const line = Color(0xFF1F2A36);
  static const lineSoft = Color(0xFF1A2330);
  static const edge = Color(0xFF2A3644);
  static const text = Color(0xFFE6EDF3);
  static const muted = Color(0xFF8B98A5);
  static const accent = Color(0xFFB8F04A);
  static const accentHi = Color(0xFFDDFF8F);
  static const amber = Color(0xFFF5A524);
  static const danger = Color(0xFFFF8A8A);
}

/// Text in Space Grotesk; the bundled font is variable, so the weight goes in as an axis too.
TextStyle sans(double size, [FontWeight w = FontWeight.w400, Color color = C.text]) => TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: size,
      fontWeight: w,
      fontVariations: [FontVariation.weight(w.value.toDouble())],
      color: color,
    );

TextStyle mono(double size, [FontWeight w = FontWeight.w400, Color color = C.text]) =>
    sans(size, w, color).copyWith(fontFamily: 'JetBrainsMono');

TextStyle caps(double size, [Color color = C.muted]) => sans(size, FontWeight.w600, color).copyWith(letterSpacing: size * .1);

/// The frameless window's own title bar: drag area, actions, minimize and close.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key, required this.title, this.leading, this.actions = const [], required this.onClose});

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.lineSoft))),
        child: Row(children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(children: [
                const SizedBox(width: 8),
                leading ?? const Padding(padding: EdgeInsets.only(left: 6), child: Logo(size: 20)),
                const SizedBox(width: 10),
                Text(title, style: sans(13, FontWeight.w600).copyWith(letterSpacing: .3)),
              ]),
            ),
          ),
          ...actions,
          BarButton(tooltip: 'Minimize', icon: Icons.remove_rounded, onTap: () => windowManager.minimize()),
          BarButton(tooltip: 'Close', icon: Icons.close_rounded, onTap: onClose),
          const SizedBox(width: 6),
        ]),
      );
}

/// The app icon (the same image as app_icon.ico), drawn from 256 px.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 18});
  final double size;

  // medium = mipmapped, so the 256 px image stays sharp at 18 px instead of shimmering
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/logo.png', width: size, height: size, filterQuality: FilterQuality.medium, semanticLabel: 'FeriLAN');
}

class BarButton extends StatelessWidget {
  const BarButton({super.key, required this.tooltip, required this.icon, required this.onTap});
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: C.lineSoft,
          child: SizedBox(width: 36, height: 30, child: Icon(icon, size: 16, color: C.muted, semanticLabel: tooltip)),
        ),
      );
}

/// Fades and lifts its child in, [delay] after it first builds.
class Rise extends StatelessWidget {
  const Rise({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    const run = Duration(milliseconds: 450);
    final total = run + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Curves.easeOutCubic),
      builder: (_, t, c) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: c)),
      child: child,
    );
  }
}

/// A slow on/off blink for status dots.
class Blink extends StatefulWidget {
  const Blink({super.key, required this.child});
  final Widget child;

  @override
  State<Blink> createState() => _BlinkState();
}

class _BlinkState extends State<Blink> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: Tween(begin: 1.0, end: .35).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
}

/// Three bars that breathe: the live-ping glyph.
class PingBars extends StatefulWidget {
  const PingBars({super.key, required this.live});
  final bool live;

  @override
  State<PingBars> createState() => _PingBarsState();
}

class _PingBarsState extends State<PingBars> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  void _sync() => widget.live ? _c.repeat() : _c.stop();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PingBars old) {
    super.didUpdateWidget(old);
    if (old.live != widget.live) _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Container(
                width: 3,
                height: (5.0 + 3.5 * i) * (widget.live ? .55 + .45 * (.5 + .5 * math.sin((_c.value - i * .12) * 2 * math.pi)) : .5),
                decoration: BoxDecoration(color: widget.live ? C.accent : C.edge, borderRadius: BorderRadius.circular(1)),
              ),
            ],
          ],
        ),
      );
}

/// The big connect button: a glowing disc inside a ring that a comet of light circles while connected,
/// a fast arc while connecting, and soft ripples spreading out once on.
class ConnectButton extends StatefulWidget {
  const ConnectButton({super.key, required this.on, required this.busy, required this.onTap});
  final bool on, busy;
  final VoidCallback onTap;

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> with TickerProviderStateMixin {
  late final _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final _orbit = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _hover = false, _down = false;

  // run only what the state shows: the window idles in the tray for hours
  void _sync() {
    for (final (c, run) in [(_ripple, widget.on), (_orbit, widget.on), (_spin, widget.busy)]) {
      if (run && !c.isAnimating) c.repeat();
      if (!run) c.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ripple.dispose();
    _orbit.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.on, busy = widget.busy;
    final label = on ? 'CONNECTED' : busy ? 'CONNECTING' : 'CONNECT';
    final fg = on ? C.bg : C.text;
    return Semantics(
      button: true,
      label: on ? 'Disconnect' : busy ? 'Connecting, tap to cancel' : 'Connect',
      excludeSemantics: true,
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_ripple, _orbit, _spin]),
              builder: (_, _) => CustomPaint(painter: _RingPainter(on: on, busy: busy, ripple: _ripple.value, orbit: _orbit.value, spin: _spin.value)),
            ),
          ),
          AnimatedScale(
            scale: _down ? .95 : _hover ? 1.03 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on
                    ? const RadialGradient(center: Alignment(-.35, -.45), radius: 1.05, colors: [C.accentHi, C.accent, Color(0xFF8CC92A)], stops: [0, .55, 1])
                    : const RadialGradient(center: Alignment(-.35, -.45), radius: 1.05, colors: [Color(0xFF1C2532), C.surface, Color(0xFF0D131A)], stops: [0, .55, 1]),
                border: Border.all(color: on ? const Color(0x55FFFFFF) : (_hover ? C.accent.withValues(alpha: .6) : C.edge), width: 1.2),
                boxShadow: [
                  BoxShadow(color: on ? C.accent.withValues(alpha: .45) : Colors.black.withValues(alpha: .5), blurRadius: on ? 44 : 24, spreadRadius: on ? 2 : 0),
                  if (on) BoxShadow(color: C.accent.withValues(alpha: .18), blurRadius: 90, spreadRadius: 10),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.onTap,
                  onHover: (h) => setState(() => _hover = h),
                  onHighlightChanged: (d) => setState(() => _down = d),
                  splashColor: (on ? C.bg : C.accent).withValues(alpha: .12),
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: C.accent.withValues(alpha: .15),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: on ? C.bg : (busy ? C.accent : C.text)),
                      duration: const Duration(milliseconds: 400),
                      builder: (_, c, _) => Icon(Icons.power_settings_new_rounded, size: 42, color: c),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(label, key: ValueKey(label), style: sans(11, FontWeight.w700, fg).copyWith(letterSpacing: 2.2)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.on, required this.busy, required this.ripple, required this.orbit, required this.spin});
  final bool on, busy;
  final double ripple, orbit, spin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const ring = 84.0;

    if (on) {
      for (var i = 0; i < 3; i++) {
        final t = (ripple + i / 3) % 1;
        final r = 68 + 42 * Curves.easeOut.transform(t);
        canvas.drawCircle(c, r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = C.accent.withValues(alpha: .35 * (1 - t)));
      }
    }

    // the track
    canvas.drawCircle(c, ring, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = on ? C.accent.withValues(alpha: .18) : C.line);

    // tick marks, like a dial
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * math.pi;
      final major = i % 5 == 0;
      final from = c + Offset(math.cos(a), math.sin(a)) * (ring + 6);
      final to = c + Offset(math.cos(a), math.sin(a)) * (ring + (major ? 11 : 8));
      canvas.drawLine(from, to, Paint()
        ..strokeWidth = major ? 1.4 : 1
        ..color = (on ? C.accent : C.muted).withValues(alpha: major ? .45 : .18));
    }

    final rect = Rect.fromCircle(center: c, radius: ring);
    if (on) {
      // a comet: bright head, fading tail
      final start = orbit * 2 * math.pi;
      canvas.drawArc(rect, start, math.pi * 1.2, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 1.2,
          colors: [C.accent.withValues(alpha: 0), C.accent],
          transform: GradientRotation(start),
        ).createShader(rect));
      final head = c + Offset(math.cos(start + math.pi * 1.2), math.sin(start + math.pi * 1.2)) * ring;
      canvas.drawCircle(head, 4, Paint()..color = C.accentHi);
      canvas.drawCircle(head, 10, Paint()
        ..color = C.accent.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    } else if (busy) {
      final start = spin * 2 * math.pi;
      canvas.drawArc(rect, start, math.pi * .55, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = C.accent);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.on != on || o.busy != busy || o.ripple != ripple || o.orbit != orbit || o.spin != spin;
}

/// The last pings as bars, scaled to the worst one; a check with no answer is a full-height red bar.
class PingChart extends StatelessWidget {
  const PingChart({super.key, required this.samples, required this.slots});
  final List<int?> samples;
  final int slots;

  @override
  Widget build(BuildContext context) {
    final got = samples.whereType<int>().toList();
    final lost = samples.length - got.length;
    final avg = got.isEmpty ? null : got.reduce((a, b) => a + b) ~/ got.length;
    final loss = samples.isEmpty ? 0 : (100 * lost / samples.length).round();
    return Semantics(
      label: 'Ping over the last ${samples.length * 3} seconds: average ${avg ?? 'unknown'} ms, $loss% lost',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 28, child: CustomPaint(painter: _PingChartPainter(samples, slots))),
        const SizedBox(height: 4),
        Row(children: [
          Text('avg ${avg ?? '…'} ms', style: mono(11, FontWeight.w400, C.muted)),
          const Spacer(),
          Text('loss $loss%', style: mono(11, FontWeight.w500, loss == 0 ? C.muted : loss < 10 ? C.amber : C.danger)),
        ]),
      ]),
    );
  }
}

class _PingChartPainter extends CustomPainter {
  _PingChartPainter(this.samples, this.slots);
  final List<int?> samples;
  final int slots;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / slots, top = math.max(80, samples.whereType<int>().fold(0, math.max)).toDouble();
    final p = Paint();
    // newest on the right; the left fills in as samples arrive
    for (final (i, ms) in samples.indexed) {
      final x = size.width - (samples.length - i) * w;
      final h = ms == null ? size.height : math.max(2.0, size.height * ms / top);
      p.color = ms == null ? C.danger : ms < 100 ? C.accent : C.amber;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, size.height - h, w - 2, h), const Radius.circular(1)), p);
    }
  }

  @override
  bool shouldRepaint(_PingChartPainter old) => true; // the list is mutated in place
}
