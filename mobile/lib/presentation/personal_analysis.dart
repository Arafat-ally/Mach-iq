import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'brand.dart';
import 'tickets.dart';
import 'auth.dart';
import 'dashboard.dart';

class PersonalAnalysis extends StatefulWidget {
  final List<Map<String, dynamic>>? fixtures;
  const PersonalAnalysis({super.key, this.fixtures});
  @override
  State<PersonalAnalysis> createState() => _PersonalAnalysisState();
}

class _PersonalAnalysisState extends State<PersonalAnalysis> {
  bool busy = false, saved = false;
  String? previewId;
  String requestKey = requestUuid();
  List<Map<String, dynamic>>? results;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fixtures = widget.fixtures ?? state.selection.values.toList();
    final good = (results ?? []).where((r) => r['error'] == null).toList();
    double? odds = 1;
    double probability = 1;
    for (final i in good) {
      odds = odds == null || i['odds_at_prediction'] == null
          ? null
          : odds * double.parse('${i['odds_at_prediction']}');
      probability *= double.parse('${i['confidence_at_prediction']}');
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(context, results == null ? 'Create My Analysis' : 'My Analysis'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (results == null) ...[
            Text(
              '${tr(context, 'Selected Matches')} (${fixtures.length})',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            if (fixtures.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    'Choose upcoming matches, analyse them and save your ticket.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ...fixtures.map(
              (f) => CompactFixture(f, selectable: widget.fixtures == null),
            ),
            OutlinedButton.icon(
              onPressed: () => open(context, const MatchSelector()),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Edit Selections')),
            ),
            FilledButton.icon(
              onPressed: busy || fixtures.isEmpty
                  ? null
                  : () async {
                      if (!state.signedIn) {
                        open(context, const AuthScreen());
                        return;
                      }
                      setState(() => busy = true);
                      await attempt(context, () async {
                        final data = await state.api.request(
                          'analysis-preview',
                          method: 'POST',
                          body: {
                            'fixture_ids': fixtures
                                .map((f) => f['id'])
                                .toList(),
                          },
                        );
                        if (mounted) {
                          setState(() {
                            results = List<Map<String, dynamic>>.from(
                              data['data'],
                            );
                            previewId = data['preview_id'];
                          });
                        }
                      });
                      if (mounted) setState(() => busy = false);
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.insights),
              label: Text(
                tr(
                  context,
                  busy
                      ? 'Analysing available data…'
                      : 'Analyze Selected Matches',
                ),
              ),
            ),
          ] else ...[
            MetricGrid({
              'Matches': '${good.length}',
              'Total Odds': good.isEmpty ? '—' : decimal(odds),
              'Confidence': good.isEmpty ? '—' : pct(probability),
            }),
            Text(
              tr(
                context,
                'Combined model probability assumes independence; it is not a guarantee.',
              ),
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
            for (final row in results!)
              if (row['error'] != null)
                GlowCard(
                  accent: gold,
                  child: Text(
                    '${fixtures.where((f) => f['id'] == row['fixture_id']).firstOrNull?['home_team']?['name'] ?? row['fixture_id']}: ${row['error']}',
                  ),
                )
              else ...[
                SelectionCard(item: row),
                ExpansionTile(
                  title: Text(tr(context, 'Key Factors')),
                  children: [
                    for (final factor in row['factors'] ?? [])
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.check_circle_outline,
                          color: green,
                          size: 17,
                        ),
                        title: Text(_factor(factor)),
                      ),
                    if (row['expected_goals'] != null)
                      ListTile(
                        title: Text(tr(context, 'Model Expected Goals')),
                        subtitle: Text(
                          '${decimal(row['expected_goals']['home'])} – ${decimal(row['expected_goals']['away'])}',
                        ),
                      ),
                    for (final limitation in row['limitations'] ?? [])
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '$limitation',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            if (good.isNotEmpty)
              FilledButton.icon(
                onPressed: busy || saved
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await attempt(context, () async {
                          final result = await state.api.request(
                            'my-analyses',
                            method: 'POST',
                            body: {
                              'name': 'My Analysis',
                              'request_key': requestKey,
                              'preview_id': previewId,
                              'items': good
                                  .map(
                                    (i) => {
                                      'fixture_id': i['fixture_id'],
                                      'market': i['market'],
                                      'selection': i['selection'],
                                    },
                                  )
                                  .toList(),
                            },
                          );
                          if (context.mounted) {
                            setState(() => saved = true);
                            open(
                              context,
                              TicketDetail(
                                id: result['data']['id'],
                                source: 'personal',
                              ),
                            );
                          }
                          await state.refreshProfile();
                        });
                        if (mounted) setState(() => busy = false);
                      },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(tr(context, saved ? 'saved' : 'Save Analysis')),
              ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      results = null;
                      previewId = null;
                      saved = false;
                      requestKey = requestUuid();
                    }),
              child: Text(tr(context, 'Edit Selections')),
            ),
            if (good.length > 1 && !state.isPro)
              Text(
                tr(context, 'Pro is required to save multi-match analyses.'),
                style: const TextStyle(color: gold, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  String _factor(dynamic f) {
    if (f is! Map) return '$f';
    final team = f['team'] == 'home' ? 'Home' : 'Away';
    if (f['scored_in'] != null) {
      return '$team scored in ${f['scored_in']} of ${f['sample_size']} sampled matches';
    }
    if (f['conceded_in'] != null) {
      return '$team conceded in ${f['conceded_in']} of ${f['sample_size']} sampled matches';
    }
    return f['description']?.toString() ?? 'Available historical form';
  }
}
