import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/app_state.dart';
import 'brand.dart';
import 'widgets.dart';
import 'home.dart';
import 'account.dart';
import 'tickets.dart';
import 'analysis.dart';
import 'match_center.dart';

class MatchDashboard extends StatefulWidget {
  const MatchDashboard({super.key});
  @override
  State<MatchDashboard> createState() => _DashboardState();
}

class _DashboardState extends State<MatchDashboard>
    with WidgetsBindingObserver {
  int nav = 0, tab = 0, revision = 0;
  Timer? timer;
  bool active = true;
  DateTime date = DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && active && nav == 0 && tab == 2) setState(() => revision++);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final api = context.read<AppState>().api;
    final result = <String, dynamic>{};
    await Future.wait([
      (() async {
        try {
          result['fixtures'] = await api.request(
            'fixtures?${tab == 2 ? 'live=1' : 'date=${DateFormat('yyyy-MM-dd').format(date)}'}&utc_offset=${date.timeZoneOffset.inMinutes}',
            cache: true,
          );
        } catch (e) {
          result['fixture_error'] = '$e';
        }
      })(),
      (() async {
        try {
          result['tickets'] = await api.request(
            'daily-tickets?date=${DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc())}',
            cache: true,
          );
        } catch (e) {
          result['ticket_error'] = '$e';
        }
      })(),
    ]);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const MatchBrand(),
        actions: [
          IconButton(
            tooltip: tr(context, 'search'),
            icon: const Icon(Icons.search),
            onPressed: () => open(context, const SearchScreen()),
          ),
          IconButton(
            tooltip: tr(context, 'notifications'),
            icon: const Icon(Icons.notifications_none),
            onPressed: () => open(context, const NotificationsScreen()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: switch (nav) {
              1 => const LeagueHub(),
              2 => const MatchSelector(embedded: true),
              3 => const TicketsScreen(embedded: true),
              4 => const ProfileScreen(),
              _ => Column(
                children: [
                  FilterStrip(
                    values: const ['0', '1', '2', '3'],
                    labels: const ['today', 'tomorrow', 'live', 'my_picks'],
                    selected: '$tab',
                    onChanged: (v) => setState(() {
                      tab = int.parse(v);
                      date = DateTime.now().add(
                        Duration(days: tab == 1 ? 1 : 0),
                      );
                    }),
                  ),
                  Expanded(
                    child: tab == 3
                        ? const FavoritesScreen(embedded: true)
                        : AsyncPanel(
                            key: ValueKey('$tab:$revision'),
                            load: load,
                            builder: (raw) {
                              final data = raw as Map;
                              final fixtures = List<Map<String, dynamic>>.from(
                                data['fixtures']?['data'] ?? [],
                              );
                              final tickets = List<Map<String, dynamic>>.from(
                                data['tickets']?['tickets']?['data'] ?? [],
                              );
                              return ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  4,
                                  14,
                                  20,
                                ),
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  GlowCard(
                                    onTap: () => setState(() => nav = 3),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.confirmation_number,
                                          color: gold,
                                          size: 36,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tr(context, 'Daily Tickets'),
                                                style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              Text(
                                                tr(
                                                  context,
                                                  'Automatically prepared from available match data',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.arrow_circle_right,
                                          color: cyan,
                                          size: 30,
                                        ),
                                      ],
                                    ),
                                  ),
                                  LayoutBuilder(
                                    builder: (c, box) => Wrap(
                                      spacing: 8,
                                      runSpacing: 3,
                                      children: ['safe', 'balanced', 'high_odds', 'full'].map((
                                        category,
                                      ) {
                                        final found = tickets
                                            .where(
                                              (t) => t['category'] == category,
                                            )
                                            .firstOrNull;
                                        final color = switch (category) {
                                          'safe' => green,
                                          'balanced' => blue,
                                          'high_odds' => const Color(
                                            0xffbc58ff,
                                          ),
                                          _ => gold,
                                        };
                                        return SizedBox(
                                          width: (box.maxWidth - 8) / 2,
                                          child: GlowCard(
                                            accent: color,
                                            onTap: () => found == null
                                                ? open(
                                                    context,
                                                    const TicketsScreen(),
                                                  )
                                                : open(
                                                    context,
                                                    TicketDetail(
                                                      id: found['id'],
                                                    ),
                                                  ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  switch (category) {
                                                    'safe' =>
                                                      Icons
                                                          .verified_user_outlined,
                                                    'balanced' => Icons.balance,
                                                    'high_odds' =>
                                                      Icons
                                                          .local_fire_department_outlined,
                                                    _ =>
                                                      Icons.workspace_premium,
                                                  },
                                                  color: color,
                                                  size: 25,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  tr(context, category),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  found == null
                                                      ? tr(
                                                          context,
                                                          'Awaiting available data',
                                                        )
                                                      : '${found['selection_count']} ${tr(context, 'Matches')}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(
                                                  found == null
                                                      ? '—'
                                                      : '${decimal(found['total_odds'])} ${tr(context, 'Odds')} · ${pct(found['confidence'])}',
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  if (data['ticket_error'] != null)
                                    Text(
                                      tr(
                                        context,
                                        'Daily tickets temporarily unavailable. Pull to retry.',
                                      ),
                                      style: const TextStyle(
                                        color: gold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GlowCard(
                                          onTap: () => setState(() => nav = 2),
                                          child: Column(
                                            children: [
                                              const Icon(
                                                Icons.manage_search,
                                                color: cyan,
                                              ),
                                              Text(
                                                tr(
                                                  context,
                                                  'Create My Analysis',
                                                ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: GlowCard(
                                          onTap: () => open(
                                            context,
                                            const TicketsScreen(
                                              source: 'personal',
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              const Icon(
                                                Icons.folder_open,
                                                color: gold,
                                              ),
                                              Text(
                                                tr(context, 'My Analyses'),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SectionTitle(
                                    tab == 2 ? 'Live Matches' : 'Matches',
                                    action: Text(
                                      DateFormat.MMMd().format(date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: cyan,
                                      ),
                                    ),
                                  ),
                                  if (data['fixtures']?['stale'] == true)
                                    CacheNote(
                                      updated: data['fixtures']?['synced_at'],
                                    ),
                                  if (data['fixture_error'] != null)
                                    GlowCard(
                                      child: Text(
                                        '${data['fixture_error']}\n${tr(context, 'Pull to refresh')}',
                                      ),
                                    ),
                                  if (fixtures.isEmpty &&
                                      data['fixture_error'] == null)
                                    Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        tr(
                                          context,
                                          data['fixtures']?['provider_configured'] ==
                                                  false
                                              ? 'provider_unavailable'
                                              : 'no_fixtures',
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ...fixtures.map((f) => CompactFixture(f)),
                                  if (data['fixtures']?['next_page'] != null)
                                    TextButton(
                                      onPressed: () => setState(() => nav = 2),
                                      child: Text(
                                        tr(context, 'Browse all matches'),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (state.selection.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton.icon(
                        onPressed: () => open(context, const AnalysisBuilder()),
                        icon: const Icon(Icons.insights),
                        label: Text(
                          '${tr(context, 'Analyze Selected Matches')} (${state.selection.length})',
                        ),
                      ),
                    ),
                ],
              ),
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav,
        onDestinationSelected: (i) {
          setState(() => nav = i);
          if (i == 4 && state.signedIn) attempt(context, state.refreshProfile);
        },
        destinations: [
          for (final item in [
            (Icons.home_outlined, 'Home'),
            (Icons.emoji_events_outlined, 'leagues'),
            (Icons.analytics_outlined, 'Analysis'),
            (Icons.confirmation_number_outlined, 'Tickets'),
            (Icons.person_outline, 'profile'),
          ])
            NavigationDestination(
              icon: Icon(item.$1),
              label: tr(context, item.$2),
            ),
        ],
      ),
    );
  }
}

class CompactFixture extends StatelessWidget {
  final Map<String, dynamic> fixture;
  final bool selectable;
  const CompactFixture(this.fixture, {super.key, this.selectable = false});
  @override
  Widget build(BuildContext context) {
    final f = fixture;
    final state = context.watch<AppState>();
    final live = ['1H', 'HT', '2H', 'ET', 'P', 'LIVE'].contains(f['status']);
    final kickoff = DateTime.parse(f['kickoff']).toLocal();
    return GlowCard(
      onTap: () =>
          selectable ? state.select(f) : open(context, MatchCenter(fixture: f)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f['league']?['name'] ?? '',
                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                live
                    ? 'LIVE ${f['elapsed'] ?? ''}′'
                    : '${f['status']} · ${DateFormat.Hm().format(kickoff)}',
                style: TextStyle(
                  fontSize: 10,
                  color: live ? red : cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Logo(f['home_team']?['logo']),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['home_team']?['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      f['away_team']?['name'] ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (selectable)
                Checkbox(
                  value: state.selection.containsKey(f['id']),
                  onChanged:
                      f['status'] == 'NS' && kickoff.isAfter(DateTime.now())
                      ? (_) => state.select(f)
                      : null,
                )
              else ...[
                Text(
                  f['home_goals'] == null
                      ? 'VS'
                      : '${f['home_goals']} – ${f['away_goals']}',
                  style: TextStyle(
                    fontSize: f['home_goals'] == null ? 12 : 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 10),
                Logo(f['away_team']?['logo']),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class MatchSelector extends StatefulWidget {
  final bool embedded;
  const MatchSelector({super.key, this.embedded = false});
  @override
  State<MatchSelector> createState() => _MatchSelectorState();
}

class _MatchSelectorState extends State<MatchSelector> {
  DateTime date = DateTime.now();
  String search = '', country = '', league = '';
  int page = 1;
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SectionTitle(
            'Create My Analysis',
            action: IconButton(
              icon: const Icon(Icons.calendar_month, color: cyan),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (d != null) {
                  setState(() {
                    date = d;
                    page = 1;
                  });
                }
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr(context, 'Search teams, leagues or countries'),
            ),
            onChanged: (v) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) {
                  setState(() {
                    search = v;
                    page = 1;
                  });
                }
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            DateFormat.yMMMd().format(date),
            style: const TextStyle(fontSize: 12, color: cyan),
          ),
        ),
        Expanded(
          child: AsyncPanel(
            key: ValueKey('$date:$search:$page'),
            load: () => state.api.request(
              'fixtures?date=${DateFormat('yyyy-MM-dd').format(date)}&utc_offset=${date.timeZoneOffset.inMinutes}&search=${Uri.encodeQueryComponent(search)}&page=$page',
              cache: true,
            ),
            builder: (d) {
              final rows = List<Map<String, dynamic>>.from(d['data'] ?? []);
              final groups = <String, List<Map<String, dynamic>>>{};
              for (final f in rows) {
                groups.putIfAbsent('${f['league']?['name']}', () => []).add(f);
              }
              return ListView(
                padding: const EdgeInsets.all(14),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (d['stale'] == true) CacheNote(updated: d['synced_at']),
                  if (rows.isEmpty) Text(tr(context, 'no_fixtures')),
                  for (final group in groups.entries) ...[
                    SectionTitle(group.key),
                    ...group.value.map(
                      (f) => CompactFixture(f, selectable: true),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: page > 1
                            ? () => setState(() => page--)
                            : null,
                        child: Text(tr(context, 'Previous')),
                      ),
                      Text('$page'),
                      TextButton(
                        onPressed: d['next_page'] != null
                            ? () => setState(() => page++)
                            : null,
                        child: Text(tr(context, 'Next')),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(top: BorderSide(color: blue.withValues(alpha: .3))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tr(context, 'Selected Matches')} (${state.selection.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: state.clear,
                    child: Text(tr(context, 'Clear All')),
                  ),
                ],
              ),
              if (state.selection.isNotEmpty)
                SizedBox(
                  height: 35,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: state.selection.values
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsetsDirectional.only(end: 9),
                            child: Logo(f['home_team']?['logo']),
                          ),
                        )
                        .toList(),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.selection.isEmpty
                      ? null
                      : () => open(context, const AnalysisBuilder()),
                  icon: const Icon(Icons.insights),
                  label: Text(tr(context, 'Analyze Selected Matches')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(tr(context, 'Create My Analysis'))),
            body: body,
          );
  }
}

class LeagueHub extends StatefulWidget {
  const LeagueHub({super.key});
  @override
  State<LeagueHub> createState() => _LeagueHubState();
}

class _LeagueHubState extends State<LeagueHub> {
  String tab = 'popular', search = '';
  int page = 1, revision = 0;
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SectionTitle('leagues'),
      ),
      FilterStrip(
        values: const ['popular', 'all', 'favorites'],
        labels: const ['Popular', 'All Leagues', 'Favorites'],
        selected: tab,
        onChanged: (v) => setState(() {
          tab = v;
          page = 1;
        }),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: tr(context, 'Search leagues'),
          ),
          onChanged: (v) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 400), () {
              if (mounted) {
                setState(() {
                  search = v;
                  page = 1;
                });
              }
            });
          },
        ),
      ),
      Expanded(
        child: AsyncPanel(
          key: ValueKey('$tab:$search:$page:$revision'),
          load: () => context.read<AppState>().api.request(
            tab == 'favorites'
                ? 'favorites'
                : 'leagues?search=${Uri.encodeQueryComponent(search)}&popular=${tab == 'popular' ? 1 : 0}&page=$page',
            cache: true,
          ),
          builder: (d) {
            final rows =
                List<Map<String, dynamic>>.from(
                      d[tab == 'favorites' ? 'leagues' : 'data'] ?? [],
                    )
                    .where(
                      (l) => '${l['name']}'.toLowerCase().contains(
                        search.toLowerCase(),
                      ),
                    )
                    .toList();
            return ListView(
              padding: const EdgeInsets.all(14),
              children: [
                if (rows.isEmpty) Text(tr(context, 'no_data')),
                ...rows.map(
                  (l) => GlowCard(
                    onTap: () =>
                        open(context, CatalogDetail(kind: 'leagues', item: l)),
                    child: Row(
                      children: [
                        Logo(l['logo']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: tr(context, 'favorite'),
                          icon: Icon(
                            tab == 'favorites' ? Icons.star : Icons.star_border,
                            color: gold,
                          ),
                          onPressed: () => attempt(context, () async {
                            await context.read<AppState>().api.request(
                              'favorites/leagues/${l['id']}',
                              method: tab == 'favorites' ? 'DELETE' : 'PUT',
                            );
                            if (mounted) setState(() => revision++);
                          }),
                        ),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
                if (tab != 'favorites')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: page > 1
                            ? () => setState(() => page--)
                            : null,
                        child: Text(tr(context, 'Previous')),
                      ),
                      Text('$page'),
                      TextButton(
                        onPressed: d['next_page_url'] != null
                            ? () => setState(() => page++)
                            : null,
                        child: Text(tr(context, 'Next')),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
