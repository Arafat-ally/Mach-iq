import 'package:flutter/material.dart';

import 'brand.dart';
import 'widgets.dart';
import 'analysis.dart';

class EventsPanel extends StatelessWidget {
  final dynamic data;
  const EventsPanel(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = data is List ? data as List : [];
    if (rows.isEmpty) return const Empty(label: 'No match events available');
    return ListView(
      children: rows
          .map<Widget>(
            (e) => ListTile(
              dense: true,
              leading: Text(
                "${e['time']?['elapsed'] ?? '—'}′",
                style: const TextStyle(
                  color: cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(
                '${e['player']?['name'] ?? e['team']?['name'] ?? ''}',
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                '${e['type']} · ${e['detail']}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Icon(
                e['type'] == 'Goal'
                    ? Icons.sports_soccer
                    : e['type'] == 'Card'
                    ? Icons.square
                    : Icons.swap_vert,
                color: e['type'] == 'Goal' ? green : gold,
                size: 18,
              ),
            ),
          )
          .toList(),
    );
  }
}

class InjuriesPanel extends StatelessWidget {
  final dynamic data;
  const InjuriesPanel(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    final rows = data is List ? data as List : [];
    return rows.isEmpty
        ? const Empty(label: 'No injury information available')
        : ListView(
            children: rows
                .map<Widget>(
                  (e) => ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.medical_services_outlined,
                      color: gold,
                    ),
                    title: Text('${e['player']?['name'] ?? ''}'),
                    subtitle: Text(
                      '${e['player']?['reason'] ?? ''} · ${e['team']?['name'] ?? ''}',
                    ),
                  ),
                )
                .toList(),
          );
  }
}

class RecentForm extends StatelessWidget {
  final dynamic data;
  final Map team;
  const RecentForm(this.data, {super.key, required this.team});
  @override
  Widget build(BuildContext context) {
    final rows = (data is List ? data as List : [])
        .where(
          (r) =>
              ['FT', 'AET', 'PEN'].contains(r['fixture']?['status']?['short']),
        )
        .take(5)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${team['name']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(tr(context, 'Recent results unavailable')),
          ),
        Expanded(
          child: ListView(
            children: rows.map<Widget>((r) {
              final home =
                  '${r['teams']?['home']?['id']}' ==
                  '${team['provider_external_id']}';
              final a = r['goals']?['home'], b = r['goals']?['away'];
              final status = a == null || b == null
                  ? 'PENDING'
                  : a == b
                  ? 'DRAW'
                  : (home ? a > b : b > a)
                  ? 'WIN'
                  : 'LOSS';
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: StatusPill(status),
                title: Text(
                  '${r['teams']?['home']?['name']} · ${r['teams']?['away']?['name']}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text('${a ?? '—'} – ${b ?? '—'}'),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class PitchLineups extends StatefulWidget {
  final dynamic data;
  const PitchLineups(this.data, {super.key});
  @override
  State<PitchLineups> createState() => _PitchState();
}

class _PitchState extends State<PitchLineups> {
  int team = 0;
  @override
  Widget build(BuildContext context) {
    final rows = widget.data is List ? widget.data as List : [];
    if (rows.isEmpty) return const Empty(label: 'lineup_unavailable');
    final current = rows[team.clamp(0, rows.length - 1)];
    final starters = current['startXI'] as List? ?? [];
    final groups = <int, List<Map>>{};
    var hasGrid = true;
    for (final item in starters) {
      final player = Map.from(item['player']);
      final grid = '${player['grid'] ?? ''}'.split(':');
      final line = int.tryParse(grid.first);
      if (line == null) {
        hasGrid = false;
        break;
      }
      groups.putIfAbsent(line, () => []).add(player);
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 8,
          children: List.generate(
            rows.length,
            (i) => ChoiceChip(
              label: Text('${rows[i]['team']?['name']}'),
              selected: team == i,
              onSelected: (_) => setState(() => team = i),
            ),
          ),
        ),
        Text(
          '${current['formation'] ?? ''} · ${tr(context, 'Coach')}: ${current['coach']?['name'] ?? '—'}',
          style: const TextStyle(fontSize: 12, color: gold),
        ),
        const SizedBox(height: 14),
        if (hasGrid && groups.isNotEmpty)
          Container(
            height: 390,
            decoration: BoxDecoration(
              color: const Color(0xff083a31),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: green.withValues(alpha: .5)),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: PitchPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: (groups.keys.toList()..sort())
                        .map(
                          (line) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children:
                                (groups[line]!..sort(
                                      (a, b) => '${a['grid']}'.compareTo(
                                        '${b['grid']}',
                                      ),
                                    ))
                                    .map(
                                      (p) => Expanded(
                                        child: Column(
                                          children: [
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundColor: blue,
                                              child: Text(
                                                '${p['number'] ?? ''}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${p['name']}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 9,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        const SectionTitle('Starting XI'),
        ...starters.map<Widget>(
          (p) => ListTile(
            dense: true,
            leading: Text(
              '${p['player']?['number'] ?? '—'}',
              style: const TextStyle(color: cyan),
            ),
            title: Text('${p['player']?['name']}'),
            trailing: Text('${p['player']?['pos'] ?? ''}'),
          ),
        ),
        const SectionTitle('Substitutes'),
        for (final p in current['substitutes'] ?? [])
          ListTile(
            dense: true,
            leading: Text('${p['player']?['number'] ?? '—'}'),
            title: Text('${p['player']?['name']}'),
          ),
      ],
    );
  }
}

class PitchPainter extends CustomPainter {
  const PitchPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    c.drawRect(Rect.fromLTWH(8, 8, s.width - 16, s.height - 16), p);
    c.drawLine(Offset(8, s.height / 2), Offset(s.width - 8, s.height / 2), p);
    c.drawCircle(Offset(s.width / 2, s.height / 2), 38, p);
    c.drawRect(Rect.fromLTWH(s.width * .25, 8, s.width * .5, 55), p);
    c.drawRect(
      Rect.fromLTWH(s.width * .25, s.height - 63, s.width * .5, 55),
      p,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class PredictionPanel extends StatelessWidget {
  final dynamic prediction;
  final Map<String, dynamic> fixture;
  const PredictionPanel({
    super.key,
    required this.prediction,
    required this.fixture,
  });
  @override
  Widget build(BuildContext context) {
    if (prediction == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.insights, size: 48, color: blue),
          const SizedBox(height: 16),
          Text(
            tr(context, 'No pre-match analysis stored'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (fixture['status'] == 'NS' &&
              DateTime.parse(fixture['kickoff']).isAfter(DateTime.now()))
            FilledButton(
              onPressed: () =>
                  open(context, AnalysisBuilder(fixtures: [fixture])),
              child: Text(tr(context, 'Create My Analysis')),
            ),
        ],
      );
    }
    final output = prediction['output'] as Map? ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${tr(context, 'Snapshot')}: ${matchDate(prediction['generated_at'])}',
          style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
        ),
        if (prediction['locked_at'] != null) const StatusPill('LOCKED'),
        if (output['expected_goals'] != null)
          GlowCard(
            accent: gold,
            child: Column(
              children: [
                Text(tr(context, 'Model Expected Goals')),
                Text(
                  '${(output['expected_goals']['home'] as num).toStringAsFixed(2)} – ${(output['expected_goals']['away'] as num).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: gold,
                  ),
                ),
              ],
            ),
          ),
        for (final entry in (output['markets'] as Map? ?? {}).entries)
          GlowCard(
            child: Column(
              children: [
                Text(
                  '${entry.key}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final v in (entry.value as Map).entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Expanded(child: Text('${v.key}')),
                        Text(
                          '${((v.value['probability'] as num) * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: green),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SectionTitle('Model Limitations'),
        for (final text in output['limitations'] ?? [])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$text',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
      ],
    );
  }
}
