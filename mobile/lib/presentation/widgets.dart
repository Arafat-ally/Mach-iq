import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/app_state.dart';

String tr(BuildContext context, String key) => context.read<AppState>().t(key);
void message(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, error.toString()))));
Future<void> attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) message(context, e);
  }
}

void open(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));

class AsyncPanel extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(dynamic) builder;
  const AsyncPanel({super.key, required this.load, required this.builder});
  @override
  State<AsyncPanel> createState() => _AsyncPanelState();
}

class _AsyncPanelState extends State<AsyncPanel> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Skeleton();
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 16),
                Text(
                  tr(context, snapshot.error.toString()),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => future = widget.load()),
                  child: Text(tr(context, 'retry')),
                ),
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: () async {
          setState(() => future = widget.load());
          await future;
        },
        child: widget.builder(snapshot.data),
      );
    },
  );
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    children: List.generate(
      5,
      (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(child: LinearProgressIndicator(minHeight: 2)),
        ),
      ),
    ),
  );
}

class Empty extends StatelessWidget {
  final String label;
  const Empty({super.key, this.label = 'no_data'});
  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const SizedBox(height: 90),
      const Icon(Icons.sports_soccer, size: 48),
      const SizedBox(height: 20),
      Center(child: Text(tr(context, label))),
    ],
  );
}

class Logo extends StatelessWidget {
  final dynamic url;
  const Logo(this.url, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 36,
    child: url is String && (url as String).startsWith('https://')
        ? Image.network(
            url,
            errorBuilder: (_, error, stack) =>
                const Icon(Icons.shield_outlined),
          )
        : const Icon(Icons.shield_outlined),
  );
}

class DataCards extends StatelessWidget {
  final dynamic data;
  const DataCards(this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    if (data == null ||
        (data is List && data.isEmpty) ||
        (data is Map && data.isEmpty)) {
      return const Empty();
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _nodes(context, data),
    );
  }

  List<Widget> _nodes(BuildContext context, dynamic value) {
    if (value is List) return value.expand((v) => _nodes(context, v)).toList();
    if (value is Map) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: value.entries
                  .where(
                    (e) => ![
                      'id',
                      'logo',
                      'photo',
                      'flag',
                      'provider',
                      'provider_external_id',
                    ].contains(e.key),
                  )
                  .map<Widget>((e) {
                    if (e.value is Map || e.value is List) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(context, '${e.key}'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ..._nodes(context, e.value),
                        ],
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(tr(context, '${e.key}'))),
                          Flexible(
                            child: Text(
                              '${e.value ?? '—'}',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(),
            ),
          ),
        ),
      ];
    }
    return [Text('$value')];
  }
}
