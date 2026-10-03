import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Offline sample world. Never calls the production API or stores a real token.
class DemoApiClient extends ApiClient {
  @override
  bool get isDemo => true;
  final DateTime Function() clock;
  DemoApiClient({DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  Map<String, dynamic> user = {
    'id': 1,
    'name': 'MatchIQ Demo',
    'email': 'demo@example.com',
    'notification_preferences': '{}',
  };
  bool pro = true;
  final List<Map<String, dynamic>> personal = [];
  final Map<String, List<int>> favorites = {
    'matches': [],
    'teams': [],
    'leagues': [],
  };
  final List<int> bookmarks = [];
  final Map<String, List<Map<String, dynamic>>> previews = {};
  final Set<String> readNotifications = {};
  final Map<int, Map<String, dynamic>> overrides = {};
  int previewSequence = 0;
  DateTime get today => DateTime(clock().year, clock().month, clock().day);
  String stamp(DateTime date) => date.toIso8601String();
  String day(DateTime date) => stamp(date).substring(0, 10);
  static const clubs = [
    'Real Madrid',
    'Napoli',
    'Arsenal',
    'Chelsea',
    'Inter',
    'Benfica',
    'Barcelona',
    'Porto',
    'Liverpool',
    'Brighton',
    'Manchester City',
    'RB Leipzig',
    'Dortmund',
    'AC Milan',
    'Juventus',
    'Roma',
    'Bayern Munich',
    'Leverkusen',
    'Paris Saint-Germain',
    'Lyon',
    'Atletico Madrid',
    'Sevilla',
    'Ajax',
    'PSV',
    'Sporting CP',
    'Braga',
    'Newcastle',
    'Aston Villa',
    'Atalanta',
    'Lazio',
    'Monaco',
    'Marseille',
  ];
  static const competitions = [
    'UEFA Champions League',
    'Premier League',
    'Serie A',
    'La Liga',
    'Bundesliga',
    'Ligue 1',
    'Eredivisie',
    'Primeira Liga',
  ];
  Map<String, dynamic> team(int id) => {
    'id': id,
    'provider_external_id': '$id',
    'name': clubs[(id - 1) % clubs.length],
    'logo': 'demo:${clubs[(id - 1) % clubs.length]}',
  };
  Map<String, dynamic> league(int id) => {
    'id': id,
    'name': competitions[(id - 1) % competitions.length],
    'logo': 'demo:L$id',
    'data': {
      'country': [
        'Europe',
        'England',
        'Italy',
        'Spain',
        'Germany',
        'France',
        'Netherlands',
        'Portugal',
      ][(id - 1) % 8],
    },
  };
  int fixtureId(DateTime date, int index) =>
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          86400000 *
          100 +
      index;
  Map<String, dynamic> fixture(int id) {
    if (overrides.containsKey(id)) return overrides[id]!;
    final index = id % 100;
    final utc = DateTime.fromMillisecondsSinceEpoch(
      (id ~/ 100) * 86400000,
      isUtc: true,
    );
    final date = DateTime(utc.year, utc.month, utc.day);
    final offset = date.difference(today).inDays;
    final status = offset < 0
        ? 'FT'
        : offset > 0
        ? 'NS'
        : index < 12
        ? 'NS'
        : index < 14
        ? '2H'
        : 'FT';
    final kickoff = offset == 0 && index < 12
        ? clock().add(
            Duration(hours: 2 + index ~/ 4, minutes: (index % 4) * 10),
          )
        : date.add(Duration(hours: 18 + index % 4));
    return {
      'id': id,
      'provider_external_id': '$id',
      'league_id': index % 8 + 1,
      'league': league(index % 8 + 1),
      'home_team': team(index * 2 + 1),
      'away_team': team(index * 2 + 2),
      'status': status,
      'kickoff': stamp(kickoff),
      'elapsed': status == '2H' ? 67 : null,
      'home_goals': status == 'NS' ? null : 2,
      'away_goals': status == 'NS'
          ? null
          : index % 3 == 0
          ? 2
          : 1,
      'synced_at': stamp(clock()),
      'demo': true,
    };
  }

  List<Map<String, dynamic>> fixtures(DateTime date) =>
      List.generate(16, (i) => fixture(fixtureId(date, i)));
  Map<String, dynamic> selection(Map<String, dynamic> f, int index) {
    final markets = ['1x2', 'goals_2.5', 'double_chance', 'btts'];
    final choices = ['home', 'over', 'home_draw', 'yes'];
    return {
      'fixture_id': f['id'],
      'fixture': f,
      'prediction_id': f['id'],
      'market': markets[index % 4],
      'selection': choices[index % 4],
      'odds_at_prediction': [1.55, 1.68, 1.32, 1.58][index % 4],
      'confidence_at_prediction': [.82, .78, .85, .76][index % 4],
      'bookmaker': 'DEMO odds',
      'odds_observed_at': stamp(clock()),
      'prediction_created_at': stamp(clock()),
      'kickoff_time': f['kickoff'],
      'locked_at': null,
      'status': 'PENDING',
      'factors': [
        {'description': 'Demo: strong home form in the sample results'},
        {'description': 'Demo: both teams scored in four of five sample games'},
      ],
      'expected_goals': {'home': 1.85, 'away': .95},
      'limitations': [
        'DEMO — fictional examples, not live predictions or betting advice.',
      ],
    };
  }

  Map<String, dynamic> ticket(
    int id,
    String category,
    List<Map<String, dynamic>> items, {
    String source = 'daily',
    String? name,
    DateTime? created,
  }) {
    final statuses = items.map((i) => i['status']).toList();
    final pending = statuses.where((s) => s == 'PENDING').length;
    final status = pending > 0
        ? (pending == items.length ? 'PENDING' : 'PARTIAL')
        : statuses.contains('LOSS')
        ? 'LOSS'
        : statuses.every((s) => s == 'VOID')
        ? 'VOID'
        : 'WIN';
    return {
      'id': id,
      'name':
          name ??
          '${const {'safe': 'Safe', 'balanced': 'Balanced', 'high_odds': 'High Odds', 'full': 'Full'}[category]} Shax',
      'category': category,
      'source': source,
      'generated_at': stamp(created ?? clock()),
      'ticket_date': day(created ?? clock()),
      'selection_count': items.length,
      'total_odds': items.fold<double>(
        1,
        (a, b) => a * (b['odds_at_prediction'] as num),
      ),
      'confidence': items.fold<double>(
        1,
        (a, b) => a * (b['confidence_at_prediction'] as num),
      ),
      'status': status,
      'correct': statuses.where((s) => s == 'WIN').length,
      'incorrect': statuses.where((s) => s == 'LOSS').length,
      'items': items,
      'confidence_method': 'DEMO probability product',
      'demo': true,
    };
  }

  List<Map<String, dynamic>> daily() {
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; offset >= -29; offset--) {
      final date = today.add(Duration(days: offset));
      for (var c = 0; c < 4; c++) {
        final count = [3, 5, 8, 12][c];
        final items = List.generate(
          count,
          (i) => selection(fixture(fixtureId(date, i)), i),
        );
        if (offset < 0) {
          for (var i = 0; i < items.length; i++) {
            final lose = (-offset + c) % 3 == 0 && i == items.length - 1;
            final isVoid = (-offset + c) % 13 == 0;
            items[i]['status'] = isVoid
                ? 'VOID'
                : lose
                ? 'LOSS'
                : 'WIN';
            items[i]['final_home'] = isVoid
                ? null
                : lose
                ? 0
                : 2;
            items[i]['final_away'] = isVoid
                ? null
                : lose
                ? 1
                : 1;
            items[i]['locked_at'] = stamp(date);
            items[i]['prediction_created_at'] = stamp(date);
            items[i]['odds_observed_at'] = stamp(date);
            items[i]['fixture'] = {
              ...items[i]['fixture'],
              'home_goals': items[i]['final_home'],
              'away_goals': items[i]['final_away'],
              'status': isVoid ? 'CANC' : 'FT',
            };
          }
        }
        rows.add(
          ticket(
            fixtureId(date, 80 + c),
            ['safe', 'balanced', 'high_odds', 'full'][c],
            items,
            created: date.add(const Duration(hours: 8)),
          ),
        );
      }
    }
    return rows;
  }

  @override
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getBool('demo:loggedOut') == true
        ? null
        : 'demo-local-session';
    final saved = prefs.getString('demo:world:v1');
    if (saved != null) {
      final d = jsonDecode(saved);
      user = Map<String, dynamic>.from(d['user']);
      pro = d['pro'];
      personal.addAll(List<Map<String, dynamic>>.from(d['personal']));
      for (final k in favorites.keys) {
        favorites[k] = List<int>.from(d['favorites'][k]);
      }
      bookmarks.addAll(List<int>.from(d['bookmarks']));
      readNotifications.addAll(List<String>.from(d['read'] ?? []));
    } else {
      favorites['teams']!.addAll([1, 3]);
      favorites['leagues']!.addAll([1, 2]);
      favorites['matches']!.add(fixtureId(today, 0));
      for (var i = 0; i < 3; i++) {
        final t = Map<String, dynamic>.from(daily()[4 + i]);
        t['id'] = i + 1;
        t['source'] = 'personal';
        t['name'] = 'Demo Analysis #${i + 1}';
        personal.add(t);
      }
      await persist();
    }
  }

  Future<void> persist() async {
    await (await SharedPreferences.getInstance()).setString(
      'demo:world:v1',
      jsonEncode({
        'user': user,
        'pro': pro,
        'personal': personal,
        'favorites': favorites,
        'bookmarks': bookmarks,
        'read': readNotifications.toList(),
      }),
    );
  }

  @override
  Future<String> deviceKey() async => 'demo-device-only';
  @override
  Future<void> setToken(String? value) async {
    token = value == null ? null : 'demo-local-session';
    await (await SharedPreferences.getInstance()).setBool(
      'demo:loggedOut',
      token == null,
    );
  }

  @override
  Future<void> logout() => setToken(null);
  List<Map<String, dynamic>> filterTickets(
    List<Map<String, dynamic>> rows,
    Map<String, String> q,
  ) => rows.where((t) {
    final date = DateTime.parse(t['generated_at']);
    if (q['date'] != null && day(date) != q['date']) return false;
    final days = int.tryParse(q['days'] ?? '');
    if (days != null && date.isBefore(today.subtract(Duration(days: days - 1)))) {
      return false;
    }
    if (q['category'] != null && t['category'] != q['category']) return false;
    if (q['status'] == 'settled') {
      return ['WIN', 'LOSS', 'VOID'].contains(t['status']);
    }
    return q['status'] == null || t['status'] == q['status'];
  }).toList();
  Map<String, dynamic> paginate(List rows, Map<String, String> q) {
    final page = int.tryParse(q['page'] ?? '1') ?? 1;
    return {
      'data': rows.skip((page - 1) * 20).take(20).toList(),
      'total': rows.length,
      'last_page': math.max(1, (rows.length / 20).ceil()),
      'current_page': page,
      'next_page_url': page * 20 < rows.length ? 'demo-next' : null,
    };
  }

  List<Map<String, dynamic>> notes() => [
    {
      'id': 'ready',
      'read_at': readNotifications.contains('ready') ? stamp(clock()) : null,
      'data': {
        'title': 'Demo Daily Tickets are ready',
        'body': 'Explore four sample ticket categories.',
      },
    },
    for (final t in personal.where(
      (t) => ['WIN', 'LOSS', 'VOID'].contains(t['status']),
    ))
      {
        'id': 'analysis-${t['id']}',
        'read_at': readNotifications.contains('analysis-${t['id']}')
            ? stamp(clock())
            : null,
        'data': {
          'title': 'Demo analysis #${t['id']} settled',
          'body':
              '${t['correct']}/${t['selection_count']} correct · ${t['status']}',
          'analysis_id': t['id'],
        },
      },
  ];
  @override
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    bool cache = false,
  }) async {
    final uri = Uri.parse(path);
    final p = uri.path.split('/');
    final q = uri.queryParameters;
    body ??= {};
    if (p.first == 'auth') {
      if ([
        'device',
        'register',
        'login',
        'social',
        'refresh',
      ].contains(p.last)) {
        if (body['name'] != null) user['name'] = body['name'];
        if (body['email'] != null) user['email'] = body['email'];
        await setToken('demo');
        await persist();
        return {'token': 'demo-local-session', 'user': user};
      }
      return {'message': 'Demo only — no email has been sent.'};
    }
    if (p.first == 'profile') {
      if (method == 'PATCH') {
        user.addAll(body);
        if (user['notification_preferences'] is Map) {
          user['notification_preferences'] = jsonEncode(
            user['notification_preferences'],
          );
        }
        await persist();
      }
      return {
        'user': user,
        'is_pro': pro,
        'daily_limit': pro ? 100 : 3,
        'used_today': personal
            .where((t) => day(DateTime.parse(t['generated_at'])) == day(today))
            .length,
        'ads_eligible': false,
        'demo': true,
      };
    }
    if (p.first == 'fixtures') {
      if (p.length > 1) {
        final f = fixture(int.parse(p[1]));
        return p.length == 2 ? {'data': f} : section(f, p[2]);
      }
      var rows = fixtures(DateTime.tryParse(q['date'] ?? '') ?? today);
      if (q['range'] == 'results') {
        rows = [
          for (var i = 1; i <= 5; i++)
            ...fixtures(today.subtract(Duration(days: i))),
        ];
      }
      if (q['range'] == 'upcoming') {
        rows = [
          ...fixtures(today),
          ...fixtures(today.add(const Duration(days: 1))),
        ].where((f) => f['status'] == 'NS').toList();
      }
      rows = rows
          .where(
            (f) =>
                (q['league_id'] == null ||
                    '${f['league_id']}' == q['league_id']) &&
                (q['team_id'] == null ||
                    '${f['home_team']['id']}' == q['team_id'] ||
                    '${f['away_team']['id']}' == q['team_id']) &&
                (q['search'] == null ||
                    '${f['home_team']['name']} ${f['away_team']['name']} ${f['league']['name']} ${f['league']['data']['country']}'
                        .toLowerCase()
                        .contains(q['search']!.toLowerCase())) &&
                (q['live'] != '1' && q['group'] != 'live' ||
                    f['status'] == '2H') &&
                (q['group'] != 'upcoming' || f['status'] == 'NS') &&
                (q['group'] != 'finished' || f['status'] == 'FT'),
          )
          .toList();
      return {
        'data': rows,
        'next_page': null,
        'synced_at': stamp(clock()),
        'stale': false,
        'provider_configured': true,
        'demo': true,
      };
    }
    if (p.first == 'leagues' || p.first == 'teams') {
      if (p.length > 1) {
        final id = int.parse(p[1]);
        if (p.first == 'teams') {
          return {
            'data': team(id),
            'squad': {
              'data': [
                {
                  'team': team(id),
                  'players': List.generate(
                    11,
                    (i) => {
                      'name': 'Demo Player ${i + 1}',
                      'number': i + 1,
                      'position': i == 0 ? 'Goalkeeper' : 'Outfield',
                    },
                  ),
                },
              ],
            },
          };
        }
        return {
          'data': league(id),
          'standings': {
            'data': [
              {
                'league': {
                  'standings': [
                    List.generate(
                      8,
                      (i) => {
                        'rank': i + 1,
                        'team': team(i * 2 + 1),
                        'group': league(id)['name'],
                        'all': {'played': 8},
                        'goalsDiff': 15 - i * 2,
                        'points': 22 - i * 2,
                      },
                    ),
                  ],
                },
              },
            ],
          },
        };
      }
      final rows =
          [
                for (var i = 1; i <= (p.first == 'leagues' ? 8 : 32); i++)
                  p.first == 'leagues' ? league(i) : team(i),
              ]
              .where(
                (r) => '${r['name']}'.toLowerCase().contains(
                  (q['search'] ?? '').toLowerCase(),
                ),
              )
              .toList();
      return paginate(rows, q);
    }
    if (p.first == 'search') {
      final term = (q['q'] ?? '').toLowerCase();
      return {
        'teams': [
          for (var i = 1; i <= 32; i++)
            if (clubs[i - 1].toLowerCase().contains(term)) team(i),
        ],
        'leagues': [
          for (var i = 1; i <= 8; i++)
            if (competitions[i - 1].toLowerCase().contains(term)) league(i),
        ],
        'fixtures': fixtures(today)
            .where(
              (f) => '${f['home_team']['name']} ${f['away_team']['name']}'
                  .toLowerCase()
                  .contains(term),
            )
            .toList(),
      };
    }
    if (p.first == 'daily-tickets') {
      final rows = daily();
      if (p.length == 1) {
        return {
          'tickets': paginate(filterTickets(rows, q), q),
          'generation': {'created': 4},
          'demo': true,
        };
      }
      final id = int.parse(p[1]);
      final t = rows.firstWhere((t) => t['id'] == id);
      if (p.length == 2) return {'data': t};
      if (p.last == 'bookmark') {
        bookmarks.remove(id);
        if (method != 'DELETE') bookmarks.add(id);
      }
      if (p.last == 'picks') {
        for (final i in t['items']) {
          if (!favorites['matches']!.contains(i['fixture_id'])) {
            favorites['matches']!.add(i['fixture_id']);
          }
        }
      }
      await persist();
      return {'saved': method != 'DELETE'};
    }
    if (p.first == 'ticket-bookmarks') {
      return {
        'data': daily().where((t) => bookmarks.contains(t['id'])).toList(),
      };
    }
    if (p.first == 'analysis-preview') {
      final items = [
        for (final id in body['fixture_ids'])
          selection(fixture(id as int), id % 100),
      ];
      final id = 'demo-preview-${previewSequence++}';
      previews[id] = items;
      return {'data': items, 'preview_id': id};
    }
    if (p.first == 'my-analyses') {
      if (method == 'POST') {
        final prior = personal
            .where((t) => t['request_key'] == body!['request_key'])
            .firstOrNull;
        if (prior != null) return {'data': prior};
        final preview = previews[body['preview_id']];
        if (preview == null) {
          throw ApiException(422, 'Please analyse the demo selections again.');
        }
        final ids = (body['items'] as List).map((i) => i['fixture_id']).toSet();
        final items = preview
            .where((i) => ids.contains(i['fixture_id']))
            .toList();
        if (items.isEmpty) throw ApiException(422, 'Select a match.');
        final t = ticket(
          personal.fold<int>(0, (a, b) => math.max(a, b['id'] as int)) + 1,
          'personal',
          items,
          source: 'personal',
          name: body['name'],
        );
        t['request_key'] = body['request_key'];
        personal.insert(0, t);
        await persist();
        return {'data': t};
      }
      if (p.length > 1) {
        return {'data': personal.firstWhere((t) => t['id'] == int.parse(p[1]))};
      }
      return paginate(filterTickets(personal, q), q);
    }
    if (p.first == 'favorites') {
      if (p.length > 2) {
        final ids = favorites[p[1]]!;
        final id = int.parse(p[2]);
        ids.remove(id);
        if (method != 'DELETE') ids.add(id);
        await persist();
        return {'saved': method != 'DELETE'};
      }
      return {
        'matches': favorites['matches']!.map(fixture).toList(),
        'teams': favorites['teams']!.map(team).toList(),
        'leagues': favorites['leagues']!.map(league).toList(),
      };
    }
    if (p.first == 'notifications') {
      if (p.length > 1) {
        readNotifications.add(p[1]);
        await persist();
        return {'saved': true};
      }
      return {'data': notes()};
    }
    if (p.first == 'performance') {
      return performance(
        p.last,
        filterTickets(p.last == 'daily' ? daily() : personal, q),
      );
    }
    if (p.first == 'saved-analyses') return {'data': []};
    if (p.first == 'history') return {'total': 0};
    if (p.first == 'devices' || p.first == 'ad-events') return {'saved': true};
    if (p.first == 'demo' && p.last == 'plan') {
      pro = body['pro'] == true;
      await persist();
      return {'saved': true};
    }
    if (p.first == 'demo' && p.last == 'settle') {
      for (var n = 0; n < personal.length; n++) {
        final t = personal[n];
        if (!['PENDING', 'PARTIAL'].contains(t['status'])) continue;
        final items = List<Map<String, dynamic>>.from(t['items']);
        for (var i = 0; i < items.length; i++) {
          final lose = i == items.length - 1 && items.length > 1;
          items[i]['status'] = lose ? 'LOSS' : 'WIN';
          items[i]['final_home'] = lose ? 0 : 2;
          items[i]['final_away'] = 1;
          items[i]['locked_at'] = stamp(clock());
          items[i]['fixture'] = {
            ...items[i]['fixture'],
            'status': 'FT',
            'home_goals': lose ? 0 : 2,
            'away_goals': 1,
          };
          overrides[items[i]['fixture_id']] = Map<String, dynamic>.from(
            items[i]['fixture'],
          );
        }
        personal[n] = {
          ...ticket(
            t['id'],
            'personal',
            items,
            source: 'personal',
            name: t['name'],
            created: DateTime.parse(t['generated_at']),
          ),
          'request_key': t['request_key'],
        };
      }
      await persist();
      return {'saved': true};
    }
    throw ApiException(
      404,
      'This action is not available in the offline demo.',
    );
  }

  Map<String, dynamic> metric(List<Map<String, dynamic>> rows) {
    final win = rows.where((r) => r['status'] == 'WIN').length,
        loss = rows.where((r) => r['status'] == 'LOSS').length;
    return {
      'total': rows.length,
      'won': win,
      'lost': loss,
      'void': rows.where((r) => r['status'] == 'VOID').length,
      'pending': rows
          .where((r) => ['PENDING', 'PARTIAL'].contains(r['status']))
          .length,
      'rate': win + loss == 0 ? null : win / (win + loss),
    };
  }

  Map<String, dynamic> performance(
    String source,
    List<Map<String, dynamic>> tickets,
  ) {
    final items = [
      for (final t in tickets) ...List<Map<String, dynamic>>.from(t['items']),
    ];
    List<Map<String, dynamic>> group(
      String Function(Map<String, dynamic>) key,
      String field,
    ) {
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final i in items) {
        (groups[key(i)] ??= []).add(i);
      }
      final keys = groups.keys.toList()..sort();
      return [
        for (final k in keys) {field: k, ...metric(groups[k]!)},
      ];
    }

    return {
      'source': source,
      'tickets': metric(tickets),
      'selections': metric(items),
      'markets': group(
        (i) =>
            const {
              '1x2': '1X2',
              'goals_2.5': 'Over/Under',
              'double_chance': 'Double Chance',
              'btts': 'BTTS',
            }[i['market']] ??
            'Other',
        'name',
      ),
      'leagues': group((i) => i['fixture']['league']['name'], 'name'),
      'trend': group(
        (i) => day(DateTime.parse(i['prediction_created_at'])),
        'date',
      ),
    };
  }

  Map<String, dynamic> rawMatch(Map<String, dynamic> f, int index) => {
    'fixture': {
      'date': stamp(today.subtract(Duration(days: index + 1))),
      'status': {'short': 'FT'},
    },
    'teams': {'home': f['home_team'], 'away': f['away_team']},
    'goals': {'home': index % 3 + 1, 'away': index % 2},
    'league': f['league'],
  };
  Map<String, dynamic> section(Map<String, dynamic> f, String name) {
    final home = f['home_team'], away = f['away_team'];
    dynamic data;
    switch (name) {
      case 'home_form':
      case 'away_form':
      case 'h2h':
        data = List.generate(5, (i) => rawMatch(f, i));
      case 'events':
        data = [
          {
            'time': {'elapsed': 12},
            'type': 'Goal',
            'detail': 'Demo goal',
            'player': {'name': 'Demo Forward 9'},
            'team': home,
          },
          {
            'time': {'elapsed': 38},
            'type': 'Card',
            'detail': 'Demo yellow card',
            'player': {'name': 'Demo Defender 4'},
            'team': away,
          },
          {
            'time': {'elapsed': 61},
            'type': 'subst',
            'detail': 'Demo substitution',
            'player': {'name': 'Demo Midfielder 8'},
            'team': home,
          },
        ];
      case 'injuries':
        data = [
          {
            'player': {
              'name': 'Demo Player 14',
              'reason': 'Sample muscle injury',
            },
            'team': away,
          },
        ];
      case 'statistics':
        data = [
          for (var side = 0; side < 2; side++)
            {
              'team': side == 0 ? home : away,
              'statistics': [
                for (final e in <String, List<dynamic>>{
                  'Ball Possession': ['58%', '42%'],
                  'expected_goals': [1.85, .95],
                  'Total Shots': [15, 9],
                  'Shots on Goal': [7, 3],
                  'Shots off Goal': [5, 4],
                  'Corner Kicks': [6, 3],
                  'Fouls': [10, 12],
                  'Yellow Cards': [1, 2],
                  'Red Cards': [0, 0],
                  'Total passes': [520, 380],
                  'Passes accurate': [468, 319],
                  'Passes %': ['90%', '84%'],
                }.entries)
                  {'type': e.key, 'value': e.value[side]},
              ],
            },
        ];
      case 'lineups':
        data = [
          for (var side = 0; side < 2; side++)
            {
              'team': side == 0 ? home : away,
              'formation': '4-3-3',
              'coach': {
                'name': side == 0 ? 'Demo Home Coach' : 'Demo Away Coach',
              },
              'startXI': List.generate(
                11,
                (i) => {
                  'player': {
                    'id': side * 20 + i,
                    'name': 'Demo ${i == 0 ? 'Keeper' : 'Player'} ${i + 1}',
                    'number': i + 1,
                    'pos': i == 0
                        ? 'G'
                        : i < 5
                        ? 'D'
                        : i < 8
                        ? 'M'
                        : 'F',
                    'grid': i == 0
                        ? '1:1'
                        : i < 5
                        ? '2:$i'
                        : i < 8
                        ? '3:${i - 4}'
                        : '4:${i - 7}',
                  },
                },
              ),
              'substitutes': List.generate(
                5,
                (i) => {
                  'player': {
                    'name': 'Demo Substitute ${i + 12}',
                    'number': i + 12,
                  },
                },
              ),
            },
        ];
      case 'analysis':
        data = {
          'generated_at': stamp(clock().subtract(const Duration(hours: 2))),
          'locked_at': f['status'] == 'NS' ? null : stamp(clock()),
          'output': {
            'expected_goals': {'home': 1.85, 'away': .95},
            'markets': {
              '1X2': {
                'Home Win': {'probability': .68},
                'Draw': {'probability': .20},
                'Away Win': {'probability': .12},
              },
              'Both Teams Score': {
                'Yes': {'probability': .76},
                'No': {'probability': .24},
              },
            },
            'limitations': [
              'DEMO — all statistics and predictions are fictional samples.',
            ],
          },
        };
      case 'momentum':
        data = List.generate(
          19,
          (i) => {
            'minute': i * 5,
            'home': (math.sin(i * 1.3) + 1) * 40,
            'away': (math.cos(i * 1.1) + 1) * 30,
          },
        );
      default:
        data = [];
    }
    return {
      'data': data,
      'stale': false,
      'updated_at': stamp(clock()),
      'demo': true,
    };
  }
}
