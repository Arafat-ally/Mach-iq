import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/app_state.dart';
import 'brand.dart';
import 'dashboard.dart';
import 'tickets.dart';
import 'widgets.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});
  @override
  State<MatchesScreen> createState() => _MatchesState();
}

class _MatchesState extends State<MatchesScreen> with WidgetsBindingObserver {
  DateTime date = DateTime.now();
  String group = 'all';
  int page = 1, revision = 0;
  Timer? timer;
  bool active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && active && group == 'live') setState(() => revision++);
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

  void day(int direction) => setState(() {
    date = date.add(Duration(days: direction));
    page = 1;
  });
  String bucket(dynamic status) {
    if (['1H', 'HT', '2H', 'ET', 'BT', 'P', 'LIVE'].contains(status)) {
      return 'Live';
    }
    if (['NS', 'TBD'].contains(status)) return 'Upcoming';
    if (['FT', 'AET', 'PEN'].contains(status)) return 'Finished';
    return fixtureStatus(status);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FilterStrip(
        values: const ['all', 'upcoming', 'live', 'finished'],
        labels: const ['All', 'Upcoming', 'Live', 'Finished'],
        selected: group,
        onChanged: (v) => setState(() {
          group = v;
          page = 1;
        }),
      ),
      Row(
        children: [
          IconButton(
            tooltip: tr(context, 'Previous Day'),
            onPressed: () => day(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() {
                    date = picked;
                    page = 1;
                  });
                }
              },
              child: Text(DateFormat('EEE, d MMM yyyy').format(date)),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Next Day'),
            onPressed: () => day(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      Expanded(
        child: AsyncPanel(
          key: ValueKey('$date:$group:$page:$revision'),
          load: () => context.read<AppState>().api.request(
            'fixtures?date=${DateFormat('yyyy-MM-dd').format(date)}&utc_offset=${date.timeZoneOffset.inMinutes}&group=$group&page=$page',
            cache: true,
          ),
          builder: (data) {
            final rows = List<Map<String, dynamic>>.from(data['data'] ?? []);
            final sections = <String, List<Map<String, dynamic>>>{};
            for (final f in rows) {
              (sections[bucket(f['status'])] ??= []).add(f);
            }
            final order = [
              'Live',
              'Upcoming',
              'Finished',
              ...sections.keys.where(
                (k) => !['Live', 'Upcoming', 'Finished'].contains(k),
              ),
            ];
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (data['stale'] == true)
                  CacheNote(updated: data['cached_at'] ?? data['synced_at']),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      tr(
                        context,
                        group == 'live'
                            ? 'No live matches right now.'
                            : 'No matches for this date.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (final section in order)
                  if (sections.containsKey(section)) ...[
                    SectionTitle(section),
                    for (final f in sections[section]!) CompactFixture(f),
                  ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: page > 1 ? () => setState(() => page--) : null,
                      child: Text(tr(context, 'Previous')),
                    ),
                    Text('$page'),
                    TextButton(
                      onPressed: data['next_page'] != null
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
