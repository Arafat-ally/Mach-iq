import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:matchiq/main.dart';
import 'package:matchiq/data/api_client.dart';
import 'package:matchiq/domain/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('empty real fixture state, navigation and locale switching', (
    tester,
  ) async {
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'data': [], 'provider_configured': false}),
          200,
        ),
      ),
    );
    final state = AppState(api)..onboarded = true;
    await state.language('en');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const MatchIQApp()),
    );
    await tester.pumpAndSettle();
    expect(find.text('MATCHIQ'), findsOneWidget);
    expect(find.text('Football data is not available yet'), findsOneWidget);
    expect(find.textContaining('Arsenal'), findsNothing);
    await state.language('ar');
    await tester.pumpAndSettle();
    expect(find.text('المباريات'), findsOneWidget);
    final context = tester.element(find.text('المباريات'));
    expect(Directionality.of(context), TextDirection.rtl);
  });
  test('provider errors never become invented match data', () async {
    final api = ApiClient(
      client: MockClient(
        (r) async => http.Response('{"message":"Unavailable"}', 503),
      ),
    );
    await expectLater(
      api.request('fixtures', cache: true),
      throwsA(isA<ApiException>()),
    );
  });
  test('offline cached fixtures explicitly marked stale', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cache:fixtures',
      jsonEncode({
        'data': {'data': []},
        'saved_at': '2026-01-01',
      }),
    );
    final api = ApiClient(
      client: MockClient((r) async => throw Exception('offline')),
    );
    final result = await api.request('fixtures', cache: true);
    expect(result['stale'], isTrue);
    expect(api.offline, isTrue);
  });
}
