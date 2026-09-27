import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../domain/app_state.dart';
import 'widgets.dart';
import 'auth.dart';
import 'home.dart';
import 'analysis.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const CircleAvatar(radius: 34, child: Icon(Icons.person_outline, size: 38)), const SizedBox(height: 16),
      Center(child: Text(state.profile?['user']?['name'] ?? tr(context, 'guest'), style: Theme.of(context).textTheme.headlineSmall)),
      Center(child: Text(state.profile?['user']?['email'] ?? '')),
      if (!state.signedIn) FilledButton(onPressed: () => open(context, const AuthScreen()), child: Text(tr(context, 'login'))),
      if (state.signedIn && state.profile?['user']?['email_verified_at'] == null) ListTile(title: Text(tr(context, 'verify_email')), trailing: const Icon(Icons.email_outlined), onTap: () => attempt(context, () async { await state.api.request('auth/verification-notification', method: 'POST'); if (context.mounted) message(context, 'verification_sent'); })),
      ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: Text(tr(context, 'subscription')), subtitle: Text(state.isPro ? 'PRO' : tr(context, 'free')), onTap: () => open(context, const SubscriptionScreen())),
      if (state.signedIn) ListTile(title: Text(tr(context, 'daily_usage')), trailing: Text('${state.profile?['used_today'] ?? 0} / ${state.profile?['daily_limit'] ?? '—'}')),
      ListTile(leading: const Icon(Icons.star_outline), title: Text(tr(context, 'favorites')), onTap: () => open(context, const FavoritesScreen())),
      ListTile(leading: const Icon(Icons.query_stats), title: Text(tr(context, 'history')), onTap: () => open(context, const HistoryScreen())),
      ListTile(leading: const Icon(Icons.bookmark_outline), title: Text(tr(context, 'saved')), onTap: () => open(context, const SavedScreen())),
      ListTile(leading: const Icon(Icons.notifications_outlined), title: Text(tr(context, 'notifications')), onTap: () => open(context, const NotificationsScreen())),
      const Divider(), DropdownButtonFormField<String>(initialValue: state.locale.languageCode, decoration: InputDecoration(labelText: tr(context, 'language')),
        items: const [DropdownMenuItem(value: 'en', child: Text('English')), DropdownMenuItem(value: 'so', child: Text('Soomaali')), DropdownMenuItem(value: 'ar', child: Text('العربية'))], onChanged: (v) => state.language(v!)),
      SwitchListTile(title: Text(tr(context, 'dark_mode')), value: state.dark, onChanged: state.appearance),
      for (final key in ['privacy', 'terms', 'responsible']) ListTile(title: Text(tr(context, key)), trailing: const Icon(Icons.chevron_right), onTap: () => open(context, Scaffold(appBar: AppBar(title: Text(tr(context, key))), body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Text(tr(context, '${key}_text')))))),
      if (state.signedIn) TextButton(onPressed: () => attempt(context, state.logout), child: Text(tr(context, 'logout'))),
    ]);
  }
}
class FavoritesScreen extends StatelessWidget {
  final bool embedded;
  const FavoritesScreen({super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final content = !state.signedIn ? Center(child: FilledButton(onPressed: () => open(context, const AuthScreen()), child: Text(tr(context, 'login')))) : AsyncPanel(load: () => state.api.request('favorites', cache: true), builder: (data) => ListView(padding: const EdgeInsets.all(12), children: [
      for (final f in data['matches']) FixtureCard(Map<String, dynamic>.from(f)),
      for (final kind in ['teams', 'leagues']) ...[ListTile(title: Text(tr(context, kind))), for (final item in data[kind]) ListTile(leading: Logo(item['logo']), title: Text(item['name']),
        onTap: () => open(context, CatalogDetail(kind: kind, item: Map<String, dynamic>.from(item))), trailing: IconButton(icon: const Icon(Icons.star), onPressed: () => attempt(context, () async {
          await state.api.request('favorites/$kind/${item['id']}', method: 'DELETE'); if (context.mounted) message(context, 'removed_pull_refresh');
        })))],
    ]));
    return embedded ? content : Scaffold(appBar: AppBar(title: Text(tr(context, 'favorites'))), body: content);
  }
}
class SavedScreen extends StatelessWidget {
  final bool embedded;
  const SavedScreen({super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final content = !state.signedIn ? Center(child: FilledButton(onPressed: () => open(context, const AuthScreen()), child: Text(tr(context, 'login')))) : AsyncPanel(load: () => state.api.request('saved-analyses', cache: true), builder: (data) {
      if ((data['data'] as List).isEmpty) return const Empty();
      return ListView(padding: const EdgeInsets.all(12), children: (data['data'] as List).map<Widget>((row) => Card(child: ListTile(title: Text(row['name']), subtitle: Text(row['created_at']),
        onTap: () => open(context, AnalysisResults(results: (row['matches'] as List).map<Map<String, dynamic>>((m) => {'prediction': m['prediction']}).toList())),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => attempt(context, () async { await state.api.request('saved-analyses/${row['id']}', method: 'DELETE'); if (context.mounted) message(context, 'removed_pull_refresh'); })))).toList());
    });
    return embedded ? content : Scaffold(appBar: AppBar(title: Text(tr(context, 'saved'))), body: content);
  }
}
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryState();
}
class _HistoryState extends State<HistoryScreen> {
  String days = '7', market = '1x2';
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr(context, 'history'))), body: Column(children: [
    Wrap(spacing: 8, children: ['7', '30', '90', 'all'].map((d) => ChoiceChip(label: Text(d == 'all' ? tr(context, 'all') : '$d ${tr(context, 'days')}'), selected: days == d, onSelected: (_) => setState(() => days = d))).toList()),
    Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String>(initialValue: market, items: ['1x2', 'btts', 'goals_0.5', 'goals_1.5', 'goals_2.5', 'goals_3.5'].map((m) => DropdownMenuItem(value: m, child: Text(tr(context, m)))).toList(), onChanged: (v) => setState(() => market = v!))),
    Expanded(child: AsyncPanel(key: ValueKey('$days:$market'), load: () => context.read<AppState>().api.request('history?days=$days&market=$market'), builder: (data) {
      if (data['total'] == 0) return const Empty(label: 'no_history');
      return ListView(padding: const EdgeInsets.all(16), children: [
        for (final key in ['total', 'correct', 'incorrect', 'accuracy', 'brier_score', 'log_loss']) Card(child: ListTile(title: Text(tr(context, key)), trailing: Text(data[key] is num ? (data[key] as num).toStringAsFixed(3) : '${data[key] ?? '—'}'))),
        Text(tr(context, 'calibration')), for (final bin in data['calibration']) if (bin['count'] > 0) ListTile(title: Text('${((bin['lower'] as num) * 100).round()}–${((bin['lower'] as num) * 100 + 10).round()}%'), subtitle: LinearProgressIndicator(value: (bin['observed_frequency'] as num).toDouble()), trailing: Text('${bin['count']}')),
      ]);
    })),
  ]));
}
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsState();
}
class _NotificationsState extends State<NotificationsScreen> {
  int refresh = 0;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr(context, 'notifications'))), body: Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: FilledButton(onPressed: () => attempt(context, () async {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && context.mounted) { await context.read<AppState>().api.request('devices', method: 'POST', body: {'token': token, 'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'}); if (context.mounted) message(context, 'saved'); }
    }), child: Text(tr(context, 'enable_notifications')))),
    Expanded(child: AsyncPanel(key: ValueKey(refresh), load: () => context.read<AppState>().api.request('notifications'), builder: (data) => (data['data'] as List).isEmpty ? const Empty() : ListView(children: (data['data'] as List).map<Widget>((n) => ListTile(leading: Icon(n['read_at'] == null ? Icons.notifications_active : Icons.notifications_none), title: Text('${n['data']['title'] ?? ''}'), subtitle: Text('${n['data']['body'] ?? ''}'), onTap: () => attempt(context, () async { await context.read<AppState>().api.request('notifications/${n['id']}', method: 'PATCH'); setState(() => refresh++); }))).toList()))),
  ]));
}
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override
  State<SubscriptionScreen> createState() => _SubscriptionState();
}
class _SubscriptionState extends State<SubscriptionScreen> {
  Future<dynamic> load() async {
    const key = String.fromEnvironment('REVENUECAT_PUBLIC_KEY');
    if (key.isEmpty || kIsWeb) throw Exception('subscriptions_unavailable');
    final state = context.read<AppState>();
    if (!state.signedIn) throw Exception('login_required');
    await Purchases.configure(PurchasesConfiguration(key)..appUserID = '${state.profile!['user']['id']}');
    return Purchases.getOfferings();
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(tr(context, 'subscription'))), body: Column(children: [
    Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.workspace_premium, color: Colors.amber, size: 60), Text('MatchIQ PRO', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 12), Text(tr(context, 'pro_description'), textAlign: TextAlign.center)])),
    Expanded(child: AsyncPanel(load: load, builder: (value) {
      final offerings = value as Offerings;
      final packages = offerings.current?.availablePackages ?? [];
      if (packages.isEmpty) return const Empty(label: 'subscriptions_unavailable');
      return ListView(children: [for (final package in packages) Card(child: ListTile(title: Text(package.storeProduct.title), subtitle: Text(package.storeProduct.description), trailing: Text(package.storeProduct.priceString), onTap: () => attempt(context, () async {
        await Purchases.purchase(PurchaseParams.package(package));
        if (!context.mounted) return;
        final state = context.read<AppState>(); await state.api.request('subscriptions/sync', method: 'POST'); await state.refreshProfile();
      }))), TextButton(onPressed: () => attempt(context, () async {
        await Purchases.restorePurchases(); if (!context.mounted) return;
        final state = context.read<AppState>(); await state.api.request('subscriptions/sync', method: 'POST'); await state.refreshProfile();
      }), child: Text(tr(context, 'restore_purchases')))]);
    })),
  ]));
}
