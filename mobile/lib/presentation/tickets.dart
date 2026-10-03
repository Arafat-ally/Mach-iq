import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/app_state.dart';
import 'brand.dart';
import 'widgets.dart';
import 'auth.dart';
import 'match_center.dart';

class TicketsScreen extends StatefulWidget {
  final String source;
  final bool embedded;
  final bool bookmarks;
  const TicketsScreen({
    super.key,
    this.source = 'daily',
    this.embedded = false,
    this.bookmarks = false,
  });
  @override
  State<TicketsScreen> createState() => _TicketsState();
}

class _TicketsState extends State<TicketsScreen> {
  String category = 'all', period = '1', status = 'all';
  int page = 1;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final daily = widget.source == 'daily';
    if (!daily && !state.signedIn) return const AccountRequired();
    final title = widget.bookmarks
        ? 'Saved Tickets'
        : daily
        ? 'Daily Tickets'
        : 'My Analyses';
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SectionTitle(
            title,
            action: IconButton(
              tooltip: tr(context, 'Statistics'),
              icon: const Icon(Icons.bar_chart),
              onPressed: () =>
                  open(context, PerformanceScreen(source: widget.source)),
            ),
          ),
        ),
        if (!widget.bookmarks) ...[
          FilterStrip(
            values: daily
                ? const ['all', 'safe', 'balanced', 'high_odds', 'full']
                : const ['all', 'PENDING', 'settled', 'WIN', 'LOSS'],
            selected: daily ? category : status,
            onChanged: (v) => setState(() {
              if (daily) {
                category = v;
              } else {
                status = v;
              }
              page = 1;
            }),
          ),
          FilterStrip(
            values: const ['1', 'yesterday', '7', '30', 'all'],
            labels: const [
              'Today',
              'Yesterday',
              '7 Days',
              '30 Days',
              'All Time',
            ],
            selected: period,
            onChanged: (v) => setState(() {
              period = v;
              page = 1;
            }),
          ),
        ],
        Expanded(
          child: AsyncPanel(
            key: ValueKey(
              '$category:$period:$status:$page:${widget.source}:${widget.bookmarks}',
            ),
            load: () => state.api.request(
              widget.bookmarks
                  ? 'ticket-bookmarks'
                  : '${daily ? 'daily-tickets' : 'my-analyses'}?page=$page${period == 'yesterday' ? '&date=${DateFormat('yyyy-MM-dd').format(DateTime.now().toUtc().subtract(const Duration(days: 1)))}' : '&days=$period'}${daily && category != 'all' ? '&category=$category' : ''}${!daily && status != 'all' ? '&status=$status' : ''}',
              cache: true,
            ),
            builder: (data) {
              final envelope = daily && !widget.bookmarks
                  ? data['tickets']
                  : data;
              final rows = List<Map<String, dynamic>>.from(
                envelope['data'] ?? [],
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (data['stale'] == true) const CacheNote(),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.confirmation_number_outlined,
                            size: 46,
                            color: blue,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            tr(
                              context,
                              daily
                                  ? 'No daily tickets available'
                                  : 'No saved analyses yet',
                            ),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr(
                              context,
                              daily
                                  ? 'Tickets appear automatically when sufficient pre-match data and real odds are available.'
                                  : 'Choose upcoming matches, analyse them and save your ticket.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ...rows.map(
                    (t) => TicketCard(ticket: t, source: widget.source),
                  ),
                  if (envelope['last_page'] != null &&
                      (envelope['last_page'] as num) > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: page > 1
                              ? () => setState(() => page--)
                              : null,
                          child: Text(tr(context, 'Previous')),
                        ),
                        Text('$page / ${envelope['last_page']}'),
                        TextButton(
                          onPressed: page < envelope['last_page']
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
    return widget.embedded
        ? body
        : Scaffold(
            appBar: AppBar(title: Text(tr(context, title))),
            body: body,
          );
  }
}

class FilterStrip extends StatelessWidget {
  final List<String> values;
  final List<String>? labels;
  final String selected;
  final ValueChanged<String> onChanged;
  const FilterStrip({
    super.key,
    required this.values,
    this.labels,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: values.length,
      separatorBuilder: (_, i) => const SizedBox(width: 6),
      itemBuilder: (c, i) => ChoiceChip(
        showCheckmark: false,
        label: Text(tr(context, labels?[i] ?? values[i])),
        selected: selected == values[i],
        onSelected: (_) => onChanged(values[i]),
      ),
    ),
  );
}

class TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final String source;
  const TicketCard({super.key, required this.ticket, this.source = 'daily'});
  @override
  Widget build(BuildContext context) => GlowCard(
    accent: ticket['status'] == 'WIN'
        ? green
        : ticket['status'] == 'LOSS'
        ? red
        : blue,
    onTap: () => open(context, TicketDetail(id: ticket['id'], source: source)),
    child: Row(
      children: [
        const Icon(Icons.confirmation_number_outlined, color: gold, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ticket['name'] ?? 'Analysis #${ticket['id']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                '${ticket['selection_count']} ${tr(context, 'Matches')} · ${decimal(ticket['total_odds'])} ${tr(context, 'Odds')}',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 4),
              Text(
                matchDate(ticket['generated_at']),
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StatusPill(ticket['status'] ?? 'PENDING'),
            const SizedBox(height: 6),
            Text(
              '${ticket['correct'] ?? 0}/${ticket['selection_count']}',
              style: const TextStyle(color: gold, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    ),
  );
}

class TicketDetail extends StatelessWidget {
  final int id;
  final String source;
  const TicketDetail({super.key, required this.id, this.source = 'daily'});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        tr(context, source == 'daily' ? 'Daily Ticket' : 'My Analysis'),
      ),
    ),
    body: AsyncPanel(
      load: () => context.read<AppState>().api.request(
        '${source == 'daily' ? 'daily-tickets' : 'my-analyses'}/$id',
        cache: true,
      ),
      builder: (response) {
        final t = Map<String, dynamic>.from(response['data']);
        final items = List<Map<String, dynamic>>.from(t['items']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t['name'],
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusPill(t['status']),
              ],
            ),
            Text(
              '#$id · ${matchDate(t['generated_at'])}',
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            MetricGrid({
              'Matches': '${items.length}',
              'Total Odds': decimal(t['total_odds']),
              'Confidence': pct(t['confidence']),
            }),
            Text(
              tr(
                context,
                'Combined model probability assumes independence; it is not a guarantee.',
              ),
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            SectionTitle(t['settled_at'] != null ? 'Results' : 'Selections'),
            ...items.asMap().entries.map(
              (e) => SelectionCard(item: e.value, index: e.key + 1),
            ),
            if (t['status'] == 'LOSS')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  tr(context, 'Red selections caused this ticket to lose.'),
                  style: const TextStyle(color: red),
                ),
              ),
            if (source == 'daily') ...[
              FilledButton.icon(
                onPressed: () =>
                    _action(context, 'daily-tickets/$id/bookmark', 'PUT'),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(tr(context, 'Save Ticket')),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _action(context, 'daily-tickets/$id/picks', 'POST'),
                icon: const Icon(Icons.playlist_add),
                label: Text(tr(context, 'Add to My Picks')),
              ),
            ],
            TextButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      '${context.read<AppState>().api.isDemo ? 'MATCHIQ DEMO — fictional sample' : 'MATCHIQ'} · ${t['name']}\n${items.map((i) => "${i['fixture']['home_team']['name']} vs ${i['fixture']['away_team']['name']} — ${pickLabel(i)} · ${decimal(i['odds_at_prediction'])} · ${i['status']}").join('\n')}\nTotal odds ${decimal(t['total_odds'])} · ${t['status']}\nStatistical estimates, not guarantees.',
                ),
              ),
              icon: const Icon(Icons.share_outlined),
              label: Text(tr(context, 'Share')),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'Original selections, odds and confidence are preserved. Voids do not count as wins. All non-void selections must win for a winning ticket.',
              ),
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ],
        );
      },
    ),
  );
  void _action(BuildContext context, String path, String method) {
    if (!context.read<AppState>().signedIn) {
      open(context, const AuthScreen());
      return;
    }
    attempt(context, () async {
      await context.read<AppState>().api.request(path, method: method);
      if (context.mounted) message(context, 'saved');
    });
  }
}

class SelectionCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int? index;
  const SelectionCard({super.key, required this.item, this.index});
  @override
  Widget build(BuildContext context) {
    final f = Map<String, dynamic>.from(item['fixture'] ?? {});
    final status = item['status'] ?? 'PENDING';
    return GlowCard(
      accent: status == 'LOSS'
          ? red
          : status == 'WIN'
          ? green
          : blue,
      onTap: f.isEmpty ? null : () => open(context, MatchCenter(fixture: f)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (index != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Text(
                    '$index',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
              Logo(f['home_team']?['logo']),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${f['home_team']?['name'] ?? ''} vs ${f['away_team']?['name'] ?? ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item['status'] != null) StatusPill(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${f['league']?['name'] ?? ''} · ${matchDate(item['kickoff_time'] ?? f['kickoff'])}',
            style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  pickLabel(item),
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                decimal(item['odds_at_prediction']),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              Text(
                pct(item['confidence_at_prediction']),
                style: const TextStyle(
                  color: green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (item['final_home'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${tr(context, 'Final score')}: ${item['final_home']} – ${item['final_away']}',
                style: TextStyle(
                  color: status == 'LOSS' ? red : Colors.blueGrey,
                ),
              ),
            ),
          if (item['bookmaker'] != null)
            Text(
              '${item['bookmaker']} · ${tr(context, 'Snapshot')}: ${matchDate(item['odds_observed_at'])}',
              style: const TextStyle(fontSize: 9, color: Colors.blueGrey),
            ),
        ],
      ),
    );
  }
}

class AccountRequired extends StatelessWidget {
  const AccountRequired({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.person_outline, size: 48, color: gold),
        const SizedBox(height: 16),
        Text(tr(context, 'Sign in to save your analyses')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => open(context, const AuthScreen()),
          child: Text(tr(context, 'login')),
        ),
      ],
    ),
  );
}

class CacheNote extends StatelessWidget {
  final dynamic updated;
  const CacheNote({super.key, this.updated});
  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse('$updated');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        date == null
            ? tr(context, 'stale_data')
            : '${tr(context, 'Last updated')} ${DateTime.now().difference(date).inMinutes} ${tr(context, 'minutes ago')}',
        style: const TextStyle(color: gold, fontSize: 11),
      ),
    );
  }
}

class PerformanceScreen extends StatefulWidget {
  final String source;
  const PerformanceScreen({super.key, this.source = 'daily'});
  @override
  State<PerformanceScreen> createState() => _PerformanceState();
}

class _PerformanceState extends State<PerformanceScreen> {
  late String source = widget.source;
  String days = '30';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'Statistics'))),
    body: Column(
      children: [
        FilterStrip(
          values: const ['daily', 'personal'],
          labels: const ['Daily Tickets', 'My Analyses'],
          selected: source,
          onChanged: (v) => setState(() => source = v),
        ),
        FilterStrip(
          values: const ['7', '30', '90', 'all'],
          labels: const ['7 Days', '30 Days', '90 Days', 'All Time'],
          selected: days,
          onChanged: (v) => setState(() => days = v),
        ),
        Expanded(
          child: source == 'personal' && !context.watch<AppState>().signedIn
              ? const AccountRequired()
              : AsyncPanel(
                  key: ValueKey('$source:$days'),
                  load: () => context.read<AppState>().api.request(
                    'performance/$source?days=$days',
                    cache: true,
                  ),
                  builder: (data) {
                    final t = data['tickets'], s = data['selections'];
                    final trend = List<Map<String, dynamic>>.from(
                      data['trend'],
                    );
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          tr(
                            context,
                            source == 'daily'
                                ? 'MATCHIQ Daily Ticket Performance'
                                : 'My Personal Performance',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        MetricGrid({
                          'Total Tickets': '${t['total']}',
                          'Won': '${t['won']}',
                          'Lost': '${t['lost']}',
                          'Void': '${t['void']}',
                          'Pending': '${t['pending']}',
                          'Ticket Win Rate': pct(t['rate']),
                        }),
                        const SectionTitle('Selection Performance'),
                        MetricGrid({
                          'Selections': '${s['total']}',
                          'Correct': '${s['won']}',
                          'Incorrect': '${s['lost']}',
                          'Void': '${s['void']}',
                          'Pending': '${s['pending']}',
                          'Accuracy': pct(s['rate']),
                        }),
                        const SectionTitle('Performance Trend'),
                        GlowCard(
                          child: Column(
                            children: [
                              SizedBox(
                                height: 150,
                                child:
                                    trend
                                        .where((e) => e['rate'] != null)
                                        .isEmpty
                                    ? Center(
                                        child: Text(
                                          tr(
                                            context,
                                            'No settled predictions in this period',
                                          ),
                                        ),
                                      )
                                    : CustomPaint(
                                        size: const Size(double.infinity, 150),
                                        painter: TrendPainter(
                                          trend
                                              .where((e) => e['rate'] != null)
                                              .toList(),
                                        ),
                                      ),
                              ),
                              if (trend.isNotEmpty)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      trend.first['date'],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Text(
                                      trend.last['date'],
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        for (final group in ['markets', 'leagues']) ...[
                          SectionTitle(
                            group == 'markets'
                                ? 'Performance by Market'
                                : 'Performance by League',
                          ),
                          if ((data[group] as List).isEmpty)
                            Text(
                              tr(
                                context,
                                'No settled predictions in this period',
                              ),
                            ),
                          for (final row in data[group])
                            GlowCard(
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text('${row['name']}')),
                                      Text(
                                        '${row['won']}/${(row['won'] as num) + (row['lost'] as num)} · ${pct(row['rate'])}',
                                        style: const TextStyle(color: green),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value:
                                        (row['rate'] as num?)?.toDouble() ?? 0,
                                    color: cyan,
                                    backgroundColor: blue.withValues(
                                      alpha: .15,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          tr(
                            context,
                            'Win rates exclude pending and void results. Personal analyses never change public Daily Ticket statistics.',
                          ),
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class TrendPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  TrendPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = blue.withValues(alpha: .2)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final pos = Offset(
        points.length == 1
            ? size.width / 2
            : i * size.width / (points.length - 1),
        size.height * (1 - (points[i]['rate'] as num).toDouble()),
      );
      if (i == 0) {
        line.moveTo(pos.dx, pos.dy);
      } else {
        line.lineTo(pos.dx, pos.dy);
      }
      canvas.drawCircle(pos, 3, Paint()..color = cyan);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = cyan
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

String requestUuid() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}
