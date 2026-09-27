import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_client.dart';
class AppState extends ChangeNotifier {
  final ApiClient api;
  Locale locale = const Locale('en');
  Map<String, dynamic> strings = {};
  Map<String, dynamic>? profile;
  bool onboarded = false;
  bool dark = true;
  final Map<int, Map<String, dynamic>> selection = {};
  AppState(this.api);
  bool get signedIn => api.token != null;
  bool get isPro => profile?['is_pro'] == true;
  String t(String key) => strings[key]?.toString() ?? key;
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool('onboarded') ?? false;
    dark = prefs.getBool('dark') ?? true;
    await language(prefs.getString('language') ?? 'en');
    await api.init();
    if (signedIn) { try { await refreshProfile(); } catch (_) {} }
  }
  Future<void> language(String value) async {
    strings = jsonDecode(await rootBundle.loadString('assets/l10n/$value.json'));
    locale = Locale(value);
    await (await SharedPreferences.getInstance()).setString('language', value);
    notifyListeners();
  }
  Future<void> finishOnboarding() async {
    onboarded = true;
    await (await SharedPreferences.getInstance()).setBool('onboarded', true);
    notifyListeners();
  }
  Future<void> appearance(bool value) async { dark = value; await (await SharedPreferences.getInstance()).setBool('dark', value); notifyListeners(); }
  Future<void> refreshProfile() async { profile = Map<String, dynamic>.from(await api.request('profile')); notifyListeners(); }
  Future<void> login(Map<String, dynamic> session) async { await api.setToken(session['token']); await refreshProfile(); }
  Future<void> logout() async { await api.logout(); profile = null; selection.clear(); notifyListeners(); }
  void select(Map<String, dynamic> fixture) {
    final id = fixture['id'] as int;
    if (selection.containsKey(id)) { selection.remove(id); }
    else if (selection.length < 20) { selection[id] = fixture; }
    notifyListeners();
  }
  void clear() { selection.clear(); notifyListeners(); }
}
