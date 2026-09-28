import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_state.dart';
import '../data/ad_service.dart';
import 'widgets.dart';
import 'match_center.dart';
import 'account.dart';
import 'analysis.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  int navigation = 0, tab = 0, refresh = 0;
  DateTime date = DateTime.now();
  int? league;
  Timer? timer;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && foreground && navigation == 0 && tab == 2) {
        setState(() => refresh++);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'MATCHIQ',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
            ),
            if (state.isPro)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Chip(
                  label: Text('PRO'),
                  backgroundColor: Color(0xff806723),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, 'search'),
            onPressed: () => open(context, const SearchScreen()),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: tr(context, 'notifications'),
            onPressed: () => open(context, const NotificationsScreen()),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: navigation == 0
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'football_intelligence'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: tr(context, 'calendar'),
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2010),
                            lastDate: DateTime.now().add(
                              const Duration(days: 730),
                            ),
                          );
                          if (selected != null) {
                            setState(() {
                              date = selected;
                              tab = 4;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      4,
                      (index) => Padding(
                        padding: const EdgeInsets.all(6),
                        child: ChoiceChip(
                          label: Text(
                            tr(
                              context,
                              ['today', 'tomorrow', 'live', 'my_picks'][index],
                            ),
                          ),
                          selected: tab == index,
                          onSelected: (_) => setState(() {
                            tab = index;
                            date = DateTime.now().add(
                              Duration(days: index == 1 ? 1 : 0),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => open(context, const AnalysisBuilder()),
                      icon: const Icon(Icons.auto_graph),
                      label: Text(tr(context, 'build_analysis')),
                    ),
                  ),
                ),
                if (tab != 2 && tab != 3)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      DateFormat.yMMMMEEEEd(state.locale.languageCode)
                          .format(date),
                    ),
                  ),
                Expanded(
                  child: tab == 3
                      ? const FavoritesScreen(embedded: true)
                      : AsyncPanel(
                          key: ValueKey('$date:$tab:$league:$refresh'),
                          load: () => state.api.request(
                            'fixtures?${tab == 2 ? 'live=1' : 'date=${DateFormat('yyyy-MM-dd').format(date)}'}&utc_offset=${date.timeZoneOffset.inMinutes}${league != null ? '&league_id=$league' : ''}',
                            cache: true,
                          ),
                          builder: (data) {
                            final rows = List<Map<String, dynamic>>.from(
                              data['data'],
                            );
                            if (rows.isEmpty) {
                              return Empty(
                                label: data['provider_configured'] == false
                                    ? 'provider_unavailable'
                                    : 'no_fixtures',
                              );
                            }
                            return ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                if (data['stale'] == true)
                                  ListTile(
                                    leading: const Icon(Icons.history),
                                    title: Text(tr(context, 'stale_data')),
                                  ),
                                ...rows.map((row) => FixtureCard(row)),
                              ],
                            );
                          },
                        ),
                ),
                const EligibleBanner(),
                if (state.selection.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${state.selection.length} ${tr(context, 'selected')}',
                            ),
                          ),
                          TextButton(
                            onPressed: state.clear,
                            child: Text(tr(context, 'clear')),
                          ),
                          FilledButton(
                            onPressed: () =>
                                open(context, const AnalysisBuilder()),
                            child: Text(tr(context, 'analyze')),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : navigation == 1
          ? const CatalogScreen(kind: 'leagues')
          : navigation == 2
          ? const SavedScreen(embedded: true)
          : const ProfileScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigation,
        onDestinationSelected: (value) => setState(() => navigation = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer),
            label: tr(context, 'matches'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            label: tr(context, 'leagues'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            label: tr(context, 'saved'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: tr(context, 'profile'),
          ),
        ],
      ),
    );
  }
}

class FixtureCard extends StatelessWidget {
  final Map<String, dynamic> fixture;
  const FixtureCard(this.fixture, {super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final home = fixture['home_team'] ?? {}, away = fixture['away_team'] ?? {};
    final live = [
      '1H',
      'HT',
      '2H',
      'ET',
      'BT',
      'P',
      'LIVE',
    ].contains(fixture['status']);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => open(context, MatchCenter(fixture: fixture)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fixture['league']?['name'] ?? '',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    live
                        ? '${fixture['elapsed'] ?? ''}′ • ${tr(context, 'live')}'
                        : '${fixture['status']}  ${DateFormat.Hm().format(DateTime.parse(fixture['kickoff']).toLocal())}',
                    style: TextStyle(color: live ? Colors.redAccent : null),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Logo(home['logo']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      home['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${fixture['home_goals'] ?? '—'}',
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Logo(away['logo']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      away['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${fixture['away_goals'] ?? '—'}',
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: state.selection.containsKey(fixture['id']),
                    onChanged: (_) => state.select(fixture),
                  ),
                  Text(tr(context, 'select_analysis')),
                  const Spacer(),
                  IconButton(
                    tooltip: tr(context, 'favorite'),
                    onPressed: () => attempt(context, () async {
                      await state.api.request(
                        'favorites/matches/${fixture['id']}',
                        method: 'PUT',
                      );
                      if (context.mounted) message(context, 'saved');
                    }),
                    icon: const Icon(Icons.star_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    length: 2,
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
          tabs: [
            Tab(text: tr(context, kind == 'leagues' ? 'standings' : 'squad')),
            Tab(text: tr(context, 'matches')),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          AsyncPanel(
            load: () => context.read<AppState>().api.request(
              '$kind/${item['id']}',
              cache: true,
            ),
            builder: (data) => DataCards(
              data[kind == 'leagues' ? 'standings' : 'squad']?['data'],
            ),
          ),
          AsyncPanel(
            load: () => context.read<AppState>().api.request(
              'fixtures?${kind == 'leagues' ? 'league_id' : 'team_id'}=${item['id']}',
              cache: true,
            ),
            builder: (data) => (data['data'] as List).isEmpty
                ? const Empty()
                : ListView(
                    children: (data['data'] as List)
                        .map<Widget>(
                          (f) => FixtureCard(Map<String, dynamic>.from(f)),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    ),
  );
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
