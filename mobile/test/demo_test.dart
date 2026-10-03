import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:matchiq/data/demo_api_client.dart';
import 'package:matchiq/domain/app_state.dart';
import 'package:matchiq/main.dart';
import 'package:matchiq/presentation/match_center.dart';
import 'package:matchiq/presentation/tickets.dart';
import 'package:matchiq/presentation/account.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  DemoApiClient client() =>
      DemoApiClient(clock: () => DateTime(2026, 10, 3, 12));
  test('offline demo supplies every match section and all statuses', () async {
    final api = client();
    await api.init();
    for (final group in ['all', 'upcoming', 'live', 'finished']) {
      final d = await api.request('fixtures?date=2026-10-03&group=$group');
      expect(d['data'], isNotEmpty);
    }
    final f = (await api.request('fixtures?group=upcoming'))['data'].first;
    for (final section in [
      'statistics',
      'events',
      'injuries',
      'h2h',
      'home_form',
      'away_form',
      'lineups',
      'analysis',
      'momentum',
    ]) {
      final d = await api.request('fixtures/${f['id']}/$section');
      expect(d['data'], isNotEmpty);
    }
    final tickets =
        (await api.request('daily-tickets?date=2026-10-03'))['tickets']['data']
            as List;
    expect(tickets.length, 4);
    for (final t in tickets) {
      expect(
        t['total_odds'],
        closeTo(
          (t['items'] as List).fold<double>(
            1,
            (n, i) => n * (i['odds_at_prediction'] as num),
          ),
          .00001,
        ),
      );
    }
    expect((await api.request('leagues/1'))['standings']['data'], isNotEmpty);
  });
  test(
    'demo save bookmarks persistence settlement and public metrics isolation',
    () async {
      final api = client();
      await api.init();
      final before = await api.request('performance/daily');
      final fixtures =
          (await api.request('fixtures?group=upcoming'))['data'] as List;
      final preview = await api.request(
        'analysis-preview',
        method: 'POST',
        body: {'fixture_ids': fixtures.take(2).map((f) => f['id']).toList()},
      );
      final body = {
        'request_key': 'demo-test-id',
        'preview_id': preview['preview_id'],
        'name': 'My sample ticket',
        'items': (preview['data'] as List)
            .map(
              (i) => {
                'fixture_id': i['fixture_id'],
                'market': i['market'],
                'selection': i['selection'],
              },
            )
            .toList(),
      };
      final saved = await api.request(
        'my-analyses',
        method: 'POST',
        body: body,
      );
      final retry = await api.request(
        'my-analyses',
        method: 'POST',
        body: body,
      );
      expect(retry['data']['id'], saved['data']['id']);
      final odds = saved['data']['total_odds'];
      await api.request('demo/settle', method: 'POST');
      final settled = await api.request('my-analyses/${saved['data']['id']}');
      expect(settled['data']['status'], 'LOSS');
      expect(settled['data']['total_odds'], odds);
      expect(
        (await api.request('performance/daily'))['tickets'],
        before['tickets'],
      );
      final daily = (await api.request(
        'daily-tickets?days=1',
      ))['tickets']['data'][0];
      await api.request('daily-tickets/${daily['id']}/bookmark', method: 'PUT');
      await api.request('favorites/teams/5', method: 'PUT');
      final restarted = client();
      await restarted.init();
      expect(
        (await restarted.request(
          'my-analyses/${saved['data']['id']}',
        ))['data']['status'],
        'LOSS',
      );
      expect((await restarted.request('ticket-bookmarks'))['data'], isNotEmpty);
      expect(
        (await restarted.request(
          'favorites',
        ))['teams'].where((t) => t['id'] == 5),
        isNotEmpty,
      );
      await restarted.logout();
      expect(restarted.token, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('access_token'),
        isNull,
      );
    },
  );
  testWidgets(
    'demo home navigation, match sections and tickets render on small phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = client();
      await api.init();
      final state = AppState(api)..onboarded = true;
      await tester.runAsync(() async {
        await state.language('en');
        await state.refreshProfile();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: state, child: const MatchIQApp()),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEMO • Sample data • Offline'), findsOneWidget);
      for (final nav in ['Matches', 'Analysis', 'Tickets', 'Profile', 'Home']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(nav),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final f = Map<String, dynamic>.from(
        (await api.request('fixtures'))['data'][0],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(home: MatchCenter(fixture: f)),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in [
        'Statistics',
        'Momentum',
        'H2H',
        'Lineups',
        'Analysis',
      ]) {
        final finder = find.descendant(
          of: find.byType(TabBar),
          matching: find.text(tab),
        );
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      final ticket = (await api.request(
        'daily-tickets?days=1',
      ))['tickets']['data'][0];
      for (final page in [
        TicketDetail(id: ticket['id']),
        const PerformanceScreen(),
        const SubscriptionScreen(),
      ]) {
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(home: page),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
