import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'auth.dart';
import 'match_center.dart';

class AnalysisBuilder extends StatefulWidget {
  final List<Map<String, dynamic>>? fixtures;
  const AnalysisBuilder({super.key, this.fixtures});
  @override
  State<AnalysisBuilder> createState() => _BuilderState();
}

class _BuilderState extends State<AnalysisBuilder> {
  String market = 'all', quality = 'all', mode = 'quick';
  double minimum = .5;
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final fixtures = widget.fixtures ?? state.selection.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'build_analysis'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(context, 'analysis_intro'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: ['quick', 'advanced', 'custom']
                .map(
                  (m) => ButtonSegment(value: m, label: Text(tr(context, m))),
                )
                .toList(),
            selected: {mode},
            onSelectionChanged: (s) => setState(() => mode = s.first),
          ),
          const SizedBox(height: 20),
          Text('${fixtures.length} ${tr(context, 'selected')}'),
          if (fixtures.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(tr(context, 'select_first')),
            ),
          for (final fixture in fixtures)
            ListTile(
              title: Text(
                '${fixture['home_team']['name']} • ${fixture['away_team']['name']}',
              ),
              trailing: widget.fixtures == null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => state.select(fixture),
                    )
                  : null,
            ),
          if (mode != 'quick') ...[
            DropdownButtonFormField<String>(
              initialValue: market,
              decoration: InputDecoration(labelText: tr(context, 'market')),
              items:
                  [
                        'all',
                        '1x2',
                        'double_chance',
                        'btts',
                        'goals_0.5',
                        'goals_1.5',
                        'goals_2.5',
                        'goals_3.5',
                      ]
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(tr(context, m)),
                        ),
                      )
                      .toList(),
              onChanged: (v) => setState(() => market = v!),
            ),
            const SizedBox(height: 16),
            Text(
              '${tr(context, 'minimum_probability')}: ${(minimum * 100).round()}%',
            ),
            Slider(
              value: minimum,
              min: .1,
              max: .95,
              divisions: 17,
              onChanged: (v) => setState(() => minimum = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: quality,
              decoration: InputDecoration(
                labelText: tr(context, 'data_quality'),
              ),
              items: ['all', 'LOW', 'MEDIUM', 'HIGH']
                  .map(
                    (m) =>
                        DropdownMenuItem(value: m, child: Text(tr(context, m))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => quality = v!),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.insights),
            label: Text(tr(context, 'analyze')),
            onPressed: busy || fixtures.isEmpty
                ? null
                : () async {
                    if (!state.signedIn) {
                      open(context, const AuthScreen());
                      return;
                    }
                    setState(() => busy = true);
                    await attempt(context, () async {
                      final result = await state.api.request(
                        'analyses',
                        method: 'POST',
                        body: {
                          'fixture_ids': fixtures.map((f) => f['id']).toList(),
                        },
                      );
                      if (context.mounted) {
                        open(
                          context,
                          AnalysisResults(
                            results: List<Map<String, dynamic>>.from(
                              result['data'],
                            ),
                            market: mode == 'quick' ? 'all' : market,
                            quality: mode == 'quick' ? 'all' : quality,
                            minimum: mode == 'quick' ? 0 : minimum,
                          ),
                        );
                      }
                    });
                    if (mounted) setState(() => busy = false);
                  },
          ),
          if (busy) const LinearProgressIndicator(),
          const SizedBox(height: 20),
          Text(tr(context, 'responsible_text')),
        ],
      ),
    );
  }
}

class AnalysisResults extends StatefulWidget {
  final List<Map<String, dynamic>> results;
  final String market, quality;
  final double minimum;
  const AnalysisResults({
    super.key,
    required this.results,
    this.market = 'all',
    this.quality = 'all',
    this.minimum = 0,
  });
  @override
  State<AnalysisResults> createState() => _ResultsState();
}

class _ResultsState extends State<AnalysisResults> {
  late List<Map<String, dynamic>> results;
  @override
  void initState() {
    super.initState();
    results = [...widget.results];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, 'analysis_results'))),
    body: results.isEmpty
        ? const Empty()
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tr(context, 'responsible_text')),
              const SizedBox(height: 16),
              for (final row in results)
                if (row['error'] != null)
                  Card(
                    child: ListTile(
                      title: Text('${row['fixture_id']}'),
                      subtitle: Text(row['error']),
                    ),
                  )
                else
                  prediction(row),
            ],
          ),
  );
  Widget prediction(Map<String, dynamic> row) {
    final p = row['prediction'] as Map, output = p['output'] as Map;
    final fixture = Map<String, dynamic>.from(p['fixture']);
    final title =
        '${fixture['home_team']['name']} • ${fixture['away_team']['name']}';
    final ranks = {'LOW': 0, 'MEDIUM': 1, 'HIGH': 2};
    if (widget.quality != 'all' &&
        (ranks[output['data_quality']] ?? 0) < (ranks[widget.quality] ?? 0)) {
      return Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(tr(context, 'filtered_out')),
        ),
      );
    }
    final markets = output['markets'] as Map;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${tr(context, 'data_quality')}: ${tr(context, output['data_quality'])}',
            ),
            Text(
              '${output['model_version']} • ${p['generated_at']}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            for (final entry in markets.entries)
              if (widget.market == 'all' || widget.market == entry.key) ...[
                const Divider(),
                Text(
                  tr(context, entry.key),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final selection in (entry.value as Map).entries)
                  if ((selection.value['probability'] as num) >= widget.minimum)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr(context, selection.key)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tr(context, 'fair_odds')}: ${selection.value['fair_odds'] ?? '—'}',
                          ),
                          LinearProgressIndicator(
                            value: (selection.value['probability'] as num)
                                .toDouble(),
                            minHeight: 4,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${((selection.value['probability'] as num) * 100).toStringAsFixed(1)}%',
                          ),
                          IconButton(
                            tooltip: tr(context, 'save'),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            onPressed: () => attempt(context, () async {
                              await context.read<AppState>().api.request(
                                'saved-analyses',
                                method: 'POST',
                                body: {
                                  'name': title,
                                  'matches': [
                                    {
                                      'prediction_id': p['id'],
                                      'market': entry.key,
                                      'selection': selection.key,
                                    },
                                  ],
                                },
                              );
                              if (mounted) message(context, 'saved');
                            }),
                          ),
                        ],
                      ),
                    ),
              ],
            const Divider(),
            Text(
              tr(context, 'why_analysis'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final factor in output['factors'] ?? [])
              Text(
                '${tr(context, factor['team'])}: ${factor['scored_in'] ?? factor['conceded_in']} / ${factor['sample_size']} ${tr(context, factor.containsKey('scored_in') ? 'scored_matches' : 'conceded_matches')}',
              ),
            Text(
              tr(context, 'model_limitations'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => open(context, MatchCenter(fixture: fixture)),
                  child: Text(tr(context, 'open_match')),
                ),
                TextButton(
                  onPressed: () => setState(() => results.remove(row)),
                  child: Text(tr(context, 'remove')),
                ),
                TextButton(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          '$title\n${tr(context, 'data_quality')}: ${output['data_quality']}\n${markets.entries.map((e) => '${e.key}: ${(e.value as Map).entries.map((v) => '${v.key} ${((v.value['probability'] as num) * 100).toStringAsFixed(1)}%').join(', ')}').join('\n')}\n${tr(context, 'responsible_text')}',
                    ),
                  ),
                  child: Text(tr(context, 'share')),
                ),
                TextButton(
                  onPressed: () =>
                      open(context, AnalysisBuilder(fixtures: [fixture])),
                  child: Text(tr(context, 'analyze_again')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
