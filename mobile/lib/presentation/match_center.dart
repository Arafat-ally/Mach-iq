import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'analysis.dart';
import 'home.dart';

class MatchCenter extends StatelessWidget {
  final Map<String, dynamic> fixture;
  const MatchCenter({super.key, required this.fixture});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    const sections = [
      'overview',
      'ai_analysis',
      'statistics',
      'h2h',
      'lineups',
      'injuries',
      'odds',
    ];
    return DefaultTabController(
      length: sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${fixture['home_team']['name']} • ${fixture['away_team']['name']}',
          ),
          bottom: TabBar(
            isScrollable: true,
            tabs: sections.map((s) => Tab(text: tr(context, s))).toList(),
          ),
        ),
        body: TabBarView(
          children: sections.map<Widget>((section) {
            if (section == 'ai_analysis') {
              return Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.insights),
                  label: Text(tr(context, 'analyze')),
                  onPressed: () =>
                      open(context, AnalysisBuilder(fixtures: [fixture])),
                ),
              );
            }
            if (section == 'overview') {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(fixture['league']['name'], textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Logo(fixture['home_team']['logo']),
                      Text(
                        '${fixture['home_goals'] ?? '—'} : ${fixture['away_goals'] ?? '—'}',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      Logo(fixture['away_team']['logo']),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${fixture['status']} • ${DateTime.parse(fixture['kickoff']).toLocal()}',
                    textAlign: TextAlign.center,
                  ),
                  for (final side in ['home_team', 'away_team'])
                    ListTile(
                      leading: Logo(fixture[side]['logo']),
                      title: Text(fixture[side]['name']),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(
                        context,
                        CatalogDetail(
                          kind: 'teams',
                          item: Map<String, dynamic>.from(fixture[side]),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, 'responsible_text'),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    height: 500,
                    child: AsyncPanel(
                      load: () => state.api.request(
                        'fixtures/${fixture['id']}/events',
                        cache: true,
                      ),
                      builder: (data) => DataCards(data['data']),
                    ),
                  ),
                ],
              );
            }
            return AsyncPanel(
              load: () => state.api.request(
                'fixtures/${fixture['id']}/$section',
                cache: true,
              ),
              builder: (data) {
                if ((data['data'] as List).isEmpty) {
                  return Empty(
                    label: section == 'lineups'
                        ? 'lineup_unavailable'
                        : 'no_data',
                  );
                }
                if (section == 'statistics') {
                  return StatisticsPanel(
                    List<Map<String, dynamic>>.from(data['data']),
                  );
                }
                if (section == 'lineups') {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr(context, 'confirmed_lineup')),
                      ),
                      Expanded(child: DataCards(data['data'])),
                    ],
                  );
                }
                if (section == 'h2h') {
                  return H2HPanel(
                    List<Map<String, dynamic>>.from(data['data']),
                    fixture: fixture,
                  );
                }
                return DataCards(data['data']);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class StatisticsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const StatisticsPanel(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    if (rows.length < 2) return const Empty();
    final home = rows[0]['statistics'] as List,
        away = rows[1]['statistics'] as List;
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
                  Text(tr(context, entry['type'])),
                  Text('${other?['value'] ?? '—'}'),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: a != null && b != null && a + b > 0 ? a / (a + b) : .5,
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
