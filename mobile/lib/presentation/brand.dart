import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'widgets.dart';

const navy = Color(0xff040d19),
    panel = Color(0xff0b1c30),
    blue = Color(0xff087cff),
    gold = Color(0xffffce62),
    cyan = Color(0xff29c9ff);
const green = Color(0xff24d789), red = Color(0xffff4962);
ThemeData matchTheme(bool dark) => ThemeData(
  useMaterial3: true,
  brightness: dark ? Brightness.dark : Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: blue,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(primary: blue, secondary: gold),
  scaffoldBackgroundColor: dark ? navy : const Color(0xffeef4fb),
  visualDensity: VisualDensity.compact,
  appBarTheme: AppBarTheme(
    backgroundColor: dark ? navy : Colors.white,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: dark ? Colors.white : navy,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  ),
  cardTheme: CardThemeData(
    color: dark ? panel : Colors.white,
    margin: const EdgeInsets.symmetric(vertical: 5),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: blue.withValues(alpha: .25)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: blue,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  chipTheme: ChipThemeData(
    side: BorderSide(color: blue.withValues(alpha: .4)),
    selectedColor: blue,
    labelStyle: const TextStyle(fontSize: 12),
    padding: const EdgeInsets.symmetric(horizontal: 5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: dark ? panel : Colors.white,
    isDense: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: blue),
    ),
    contentPadding: const EdgeInsets.all(14),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 66,
    backgroundColor: dark ? const Color(0xff061321) : Colors.white,
    indicatorColor: blue.withValues(alpha: .22),
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    ),
  ),
);

class MatchBrand extends StatelessWidget {
  final bool large;
  const MatchBrand({super.key, this.large = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: large ? 92 : 42,
        height: large ? 100 : 45,
        child: CustomPaint(painter: CrestPainter()),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'MATCH',
                style: TextStyle(color: gold),
              ),
              const TextSpan(
                text: 'IQ',
                style: TextStyle(color: cyan),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: large ? 40 : 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -.6,
          ),
        ),
      ),
    ],
  );
}

class CrestPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 100, s.height / 110);
    final shield = Path()
      ..moveTo(12, 37)
      ..lineTo(88, 37)
      ..lineTo(82, 78)
      ..quadraticBezierTo(65, 99, 50, 104)
      ..quadraticBezierTo(28, 94, 18, 78)
      ..close();
    c.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff118dff), Color(0xff031027)],
        ).createShader(const Rect.fromLTWH(0, 35, 100, 70)),
    );
    c.drawPath(
      shield,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final crown = Path()
      ..moveTo(15, 33)
      ..lineTo(8, 9)
      ..lineTo(30, 23)
      ..lineTo(50, 0)
      ..lineTo(69, 23)
      ..lineTo(92, 9)
      ..lineTo(84, 33)
      ..close();
    c.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xffffec9c), Color(0xffb77815)],
        ).createShader(const Rect.fromLTWH(8, 0, 84, 35)),
    );
    final m = Path()
      ..moveTo(25, 78)
      ..lineTo(25, 49)
      ..lineTo(50, 71)
      ..lineTo(75, 49)
      ..lineTo(75, 78);
    c.drawPath(
      m,
      Paint()
        ..color = gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawCircle(const Offset(51, 91), 11, Paint()..color = Colors.white);
    final p = Path();
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      final x = 51 + 5 * math.cos(a), y = 91 + 5 * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = navy);
    c.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class GlowCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  const GlowCard({
    super.key,
    required this.child,
    this.accent = blue,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: .4)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent.withValues(alpha: .16), Theme.of(context).cardColor],
      ),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(13), child: child),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'WIN' => green,
      'LOSS' => red,
      'PENDING' || 'PARTIAL' => gold,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tr(context, status),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  final Map<String, String> values;
  const MetricGrid(this.values, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.entries
          .map(
            (e) => SizedBox(
              width:
                  (c.maxWidth - 8 * (c.maxWidth > 520 ? 3 : 2)) /
                  (c.maxWidth > 520 ? 4 : 3),
              child: GlowCard(
                child: Column(
                  children: [
                    Text(
                      tr(context, e.key),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.blueGrey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      e.value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: gold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

String pct(dynamic value) => value == null
    ? '—'
    : '${(double.parse('$value') * 100).toStringAsFixed(0)}%';
String decimal(dynamic value) =>
    value == null ? '—' : double.parse('$value').toStringAsFixed(2);
String pickLabel(Map item) {
  final market = '${item['market']}', selection = '${item['selection']}';
  if (market.startsWith('goals_')) {
    return '${selection == 'over' ? 'Over' : 'Under'} ${market.substring(6)}';
  }
  return switch (market) {
    '1x2' =>
      {'home': 'Home Win', 'away': 'Away Win', 'draw': 'Draw'}[selection] ??
          selection,
    'btts' => 'BTTS ${selection == 'yes' ? 'Yes' : 'No'}',
    'double_chance' =>
      {'home_draw': '1X', 'draw_away': 'X2', 'home_away': '12'}[selection] ??
          selection,
    _ => '$market · $selection',
  };
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionTitle(this.title, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            tr(context, title),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        ?action,
      ],
    ),
  );
}
