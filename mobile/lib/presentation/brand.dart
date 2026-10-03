import 'package:intl/intl.dart';

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

const crestAsset = 'assets/branding/matchiq-crest.png';

class MatchBrand extends StatelessWidget {
  final bool large;
  const MatchBrand({super.key, this.large = false});
  @override
  Widget build(BuildContext context) => large
      ? Image.asset(
          crestAsset,
          width: 240,
          height: 240,
          fit: BoxFit.contain,
          semanticLabel: 'MATCHIQ',
        )
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                crestAsset,
                width: 42,
                height: 42,
                semanticLabel: 'MATCHIQ crest',
              ),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'MATCH',
                      style: TextStyle(color: gold),
                    ),
                    TextSpan(
                      text: 'IQ',
                      style: TextStyle(color: cyan),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
}

class BrandBackdrop extends StatelessWidget {
  final Widget child;
  const BrandBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xff020913), Color(0xff05233c), Color(0xff020c16)],
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/branding/stadium.png', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  navy.withValues(alpha: .15),
                  Colors.transparent,
                  navy.withValues(alpha: .55),
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

String categoryLabel(String value) =>
    const {
      'safe': 'Safe Shax',
      'balanced': 'Balanced Shax',
      'high_odds': 'High Odds Shax',
      'full': 'Full Shax',
    }[value] ??
    value;
String fixtureStatus(dynamic value) =>
    const {
      'NS': 'Upcoming',
      'TBD': 'To be confirmed',
      '1H': 'Live',
      '2H': 'Live',
      'HT': 'Half Time',
      'ET': 'Extra Time',
      'BT': 'Extra Time Break',
      'P': 'Penalties',
      'LIVE': 'Live',
      'FT': 'Finished',
      'AET': 'After Extra Time',
      'PEN': 'After Penalties',
      'PST': 'Postponed',
      'CANC': 'Cancelled',
      'SUSP': 'Suspended',
      'INT': 'Interrupted',
      'ABD': 'Abandoned',
      'AWD': 'Awarded',
      'WO': 'Walkover',
    }['$value'] ??
    'Unavailable';
String matchDate(dynamic value) {
  final d = DateTime.tryParse('$value');
  return d == null
      ? 'Time unavailable'
      : DateFormat('d MMM yyyy • h:mm a').format(d.toLocal());
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
