import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'brand.dart';
import 'tickets.dart';
import 'match_sections.dart';

class MatchCenter extends StatefulWidget {
  final Map<String, dynamic> fixture;
  const MatchCenter({super.key, required this.fixture});
  @override
  State<MatchCenter> createState() => _MatchCenterState();
}

class _MatchCenterState extends State<MatchCenter> {
  late Map<String, dynamic> fixture = widget.fixture;
  Future<void> refresh() async {
    await attempt(context, () async {
      final d = await context.read<AppState>().api.request(
        'fixtures/${fixture['id']}',
        cache: true,
      );
      if (mounted) {
        setState(() => fixture = Map<String, dynamic>.from(d['data']));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            f['league']?['name'] ?? '',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            IconButton(
              tooltip: tr(context, 'Refresh'),
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: tr(context, 'favorite'),
              icon: const Icon(Icons.star_border, color: gold),
              onPressed: () => attempt(context, () async {
                await context.read<AppState>().api.request(
                  'favorites/matches/${f['id']}',
                  method: 'PUT',
                );
                if (context.mounted) message(context, 'saved');
              }),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: GlowCard(
                child: Column(
                  children: [
                    Text(
                      '${f['status']} · ${DateTime.parse(f['kickoff']).toLocal()}',
                      style: const TextStyle(fontSize: 10, color: cyan),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Logo(f['home_team']?['logo']),
                              const SizedBox(height: 8),
                              Text(
                                f['home_team']?['name'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${f['home_goals'] ?? '—'} – ${f['away_goals'] ?? '—'}',
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Logo(f['away_team']?['logo']),
                              const SizedBox(height: 8),
                              Text(
                                f['away_team']?['name'] ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (f['elapsed'] != null)
                      Text(
                        '${f['elapsed']}′',
                        style: const TextStyle(color: red),
                      ),
                  ],
                ),
              ),
            ),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final t in [
                  'Overview',
                  'Statistics',
                  'Momentum',
                  'H2H',
                  'Lineups',
                  'Analysis',
                ])
                  Tab(text: tr(context, t)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      const SectionTitle('Recent Form'),
                      SizedBox(
                        height: 230,
                        child: MatchSection(
                          fixture: f,
                          section: 'home_form',
                          builder: (d) =>
                              RecentForm(d['data'], team: f['home_team']),
                        ),
                      ),
                      SizedBox(
                        height: 230,
                        child: MatchSection(
                          fixture: f,
                          section: 'away_form',
                          builder: (d) =>
                              RecentForm(d['data'], team: f['away_team']),
                        ),
                      ),
                      const SectionTitle('Match Events'),
                      SizedBox(
                        height: 420,
                        child: MatchSection(
                          fixture: f,
                          section: 'events',
                          builder: (d) => EventsPanel(d['data']),
                        ),
                      ),
                      const SectionTitle('Injuries'),
                      SizedBox(
                        height: 220,
                        child: MatchSection(
                          fixture: f,
                          section: 'injuries',
                          builder: (d) => InjuriesPanel(d['data']),
                        ),
                      ),
                    ],
                  ),
                  MatchSection(
                    fixture: f,
                    section: 'statistics',
                    builder: (d) => StatisticsPanel(
                      List<Map<String, dynamic>>.from(d['data']),
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GlowCard(
                        child: Column(
                          children: [
                            const Icon(Icons.show_chart, color: cyan, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              tr(context, 'Momentum data unavailable'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr(
                                context,
                                'The provider does not supply a reliable minute-by-minute momentum series. Match events are shown below.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 430,
                        child: MatchSection(
                          fixture: f,
                          section: 'events',
                          builder: (d) => EventsPanel(d['data']),
                        ),
                      ),
                    ],
                  ),
                  MatchSection(
                    fixture: f,
                    section: 'h2h',
                    builder: (d) => H2HPanel(
                      List<Map<String, dynamic>>.from(d['data']),
                      fixture: f,
                    ),
                  ),
                  MatchSection(
                    fixture: f,
                    section: 'lineups',
                    builder: (d) => PitchLineups(d['data']),
                  ),
                  MatchSection(
                    fixture: f,
                    section: 'analysis',
                    builder: (d) =>
                        PredictionPanel(prediction: d['data'], fixture: f),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MatchSection extends StatelessWidget {
  final Map<String, dynamic> fixture;
  final String section;
  final Widget Function(dynamic) builder;
  const MatchSection({
    super.key,
    required this.fixture,
    required this.section,
    required this.builder,
  });
  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () => context.read<AppState>().api.request(
      'fixtures/${fixture['id']}/$section',
      cache: true,
    ),
    builder: (data) => Column(
      children: [
        if (data['stale'] == true)
          CacheNote(updated: data['cached_at'] ?? data['updated_at']),
        Expanded(child: builder(data)),
      ],
    ),
  );
}

class StatisticsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const StatisticsPanel(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    if (rows.length < 2) return const Empty();
    final home = (rows[0]['statistics'] as List)
            .where((e) => e['value'] != null)
            .toList(),
        away = rows[1]['statistics'] as List;
    if (home.isEmpty) return const Empty();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: home.map<Widget>((entry) {
        final other = away.where((a) => a['type'] == entry['type']).firstOrNull;
        final a = double.tryParse('${entry['value']}'.replaceAll('%', '')),
            b = double.tryParse('${other?['value']}'.replaceAll('%', ''));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${entry['value'] ?? '—'}'),
                  Expanded(
                    child: Text(
                      tr(context, entry['type']),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text('${other?['value'] ?? '—'}'),
                ],
              ),
              const SizedBox(height: 10),
              if (a != null && b != null && a + b > 0)
                LinearProgressIndicator(
                  value: a / (a + b),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class H2HPanel extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> fixture;
  const H2HPanel(this.rows, {super.key, required this.fixture});
  @override
  Widget build(BuildContext context) {
    final completed = rows
        .where(
          (r) =>
              r['fixture']?['status']?['short'] == 'FT' &&
              r['goals']?['home'] != null &&
              r['goals']?['away'] != null,
        )
        .toList();
    final total = completed.length;
    final goals = completed.fold<int>(
      0,
      (s, r) => s + (r['goals']['home'] as int) + (r['goals']['away'] as int),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (total > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${tr(context, 'average_goals')}: ${(goals / total).toStringAsFixed(2)}',
                  ),
                  Text(
                    '${tr(context, 'btts')}: ${(completed.where((r) => r['goals']['home'] > 0 && r['goals']['away'] > 0).length / total * 100).toStringAsFixed(0)}%',
                  ),
                  Text(
                    '${tr(context, 'goals_2.5')}: ${(completed.where((r) => r['goals']['home'] + r['goals']['away'] > 2.5).length / total * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
          ),
        for (final row in rows)
          Card(
            child: ListTile(
              title: Text(
                '${row['teams']['home']['name']}  ${row['goals']['home'] ?? '—'} : ${row['goals']['away'] ?? '—'}  ${row['teams']['away']['name']}',
              ),
              subtitle: Text('${row['fixture']['date']}'),
            ),
          ),
      ],
    );
  }
}
