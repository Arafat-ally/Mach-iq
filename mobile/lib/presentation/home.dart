import 'dashboard.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'brand.dart';

class HomeScreen extends MatchDashboard {
  const HomeScreen({super.key});
}

class FixtureCard extends StatelessWidget {
  final Map<String, dynamic> fixture;
  const FixtureCard(this.fixture, {super.key});
  @override
  Widget build(BuildContext context) => CompactFixture(fixture);
}

class CatalogScreen extends StatelessWidget {
  final String kind;
  const CatalogScreen({super.key, required this.kind});
  @override
  Widget build(BuildContext context) => AsyncPanel(
    load: () => context.read<AppState>().api.request(kind, cache: true),
    builder: (data) {
      final rows = data['data'] as List;
      if (rows.isEmpty) return const Empty();
      return ListView(
        children: rows
            .map<Widget>(
              (row) => ListTile(
                leading: Logo(row['logo']),
                title: Text(row['name']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(
                  context,
                  CatalogDetail(
                    kind: kind,
                    item: Map<String, dynamic>.from(row),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class CatalogDetail extends StatelessWidget {
  final String kind;
  final Map<String, dynamic> item;
  const CatalogDetail({super.key, required this.kind, required this.item});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: Text(item['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_outline),
            onPressed: () => attempt(context, () async {
              await context.read<AppState>().api.request(
                'favorites/$kind/${item['id']}',
                method: 'PUT',
              );
              if (context.mounted) message(context, 'saved');
            }),
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: tr(context, 'Fixtures')),
            Tab(text: tr(context, 'Results')),
            Tab(text: tr(context, kind == 'leagues' ? 'standings' : 'squad')),
            Tab(text: tr(context, 'Statistics')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          for (final range in ['upcoming', 'results'])
            AsyncPanel(
              load: () => context.read<AppState>().api.request(
                'fixtures?${kind == 'leagues' ? 'league_id' : 'team_id'}=${item['id']}&range=$range',
                cache: true,
              ),
              builder: (d) => (d['data'] as List).isEmpty
                  ? const Empty()
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        for (final f in d['data'])
                          CompactFixture(Map<String, dynamic>.from(f)),
                      ],
                    ),
            ),
          AsyncPanel(
            load: () => context.read<AppState>().api.request(
              '$kind/${item['id']}',
              cache: true,
            ),
            builder: (d) => kind == 'leagues'
                ? StandingsPanel(d['standings']?['data'])
                : DataCards(d['squad']?['data']),
          ),
          AsyncPanel(
            load: () => context.read<AppState>().api.request(
              'fixtures?${kind == 'leagues' ? 'league_id' : 'team_id'}=${item['id']}&range=results',
              cache: true,
            ),
            builder: (d) {
              final rows = (d['data'] as List)
                  .where(
                    (r) => r['home_goals'] != null && r['away_goals'] != null,
                  )
                  .toList();
              if (rows.isEmpty) return const Empty();
              final goals = rows.fold<num>(
                0,
                (n, r) => n + r['home_goals'] + r['away_goals'],
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  MetricGrid({
                    'Completed Matches': '${rows.length}',
                    'Goals': '$goals',
                    'Goals / Match': (goals / rows.length).toStringAsFixed(2),
                    'BTTS':
                        '${rows.where((r) => r['home_goals'] > 0 && r['away_goals'] > 0).length}',
                  }),
                  Text(
                    tr(
                      context,
                      'Based on the latest available completed matches (up to 100).',
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class StandingsPanel extends StatelessWidget {
  final dynamic data;
  const StandingsPanel(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    final groups = <List>[];
    for (final row in data is List ? data : []) {
      for (final group in row['league']?['standings'] ?? []) {
        groups.add(group as List);
      }
    }
    if (groups.isEmpty) return const Empty(label: 'Standings unavailable');
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        for (final group in groups) ...[
          if (group.isNotEmpty)
            SectionTitle('${group.first['group'] ?? 'Standings'}'),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(child: Text(tr(context, 'Team'))),
                const Text('P     GD     Pts'),
              ],
            ),
          ),
          for (final r in group)
            GlowCard(
              child: Row(
                children: [
                  SizedBox(width: 24, child: Text('${r['rank']}')),
                  Logo(r['team']?['logo']),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${r['team']?['name'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${r['all']?['played'] ?? '—'}    ${r['goalsDiff'] ?? '—'}    ${r['points'] ?? '—'}',
                    style: const TextStyle(
                      color: cyan,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  Timer? debounce;
  String query = '';
  List<String> recent = [];
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => recent = p.getStringList('recent_searches') ?? []);
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void search(String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => query = value.trim());
      if (query.length >= 2) {
        recent = [query, ...recent.where((q) => q != query)].take(10).toList();
        await (await SharedPreferences.getInstance()).setStringList(
          'recent_searches',
          recent,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'search'))),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr(context, 'search_hint'),
            ),
          ),
        ),
        Expanded(
          child: query.length < 2
              ? ListView(
                  children: recent
                      .map(
                        (q) => ListTile(title: Text(q), onTap: () => search(q)),
                      )
                      .toList(),
                )
              : AsyncPanel(
                  key: ValueKey(query),
                  load: () => context.read<AppState>().api.request(
                    'search?q=${Uri.encodeQueryComponent(query)}',
                  ),
                  builder: (data) => ListView(
                    children: [
                      for (final kind in ['teams', 'leagues']) ...[
                        ListTile(title: Text(tr(context, kind))),
                        for (final row in data[kind])
                          ListTile(
                            leading: Logo(row['logo']),
                            title: Text(row['name']),
                            onTap: () => open(
                              context,
                              CatalogDetail(
                                kind: kind,
                                item: Map<String, dynamic>.from(row),
                              ),
                            ),
                          ),
                      ],
                      for (final fixture in data['fixtures'])
                        FixtureCard(Map<String, dynamic>.from(fixture)),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}
