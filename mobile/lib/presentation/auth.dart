import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'home.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  int page = 0;
  final titles = [
    'live_football',
    'ai_analysis',
    'multi_analysis',
    'transparent_history',
  ];
  final icons = [
    Icons.sports_soccer,
    Icons.insights,
    Icons.playlist_add_check,
    Icons.query_stats,
  ];
  void finish() async {
    await context.read<AppState>().finishOnboarding();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: finish,
                child: Text(tr(context, 'skip')),
              ),
            ),
            const Spacer(),
            const Text(
              'MATCHIQ',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 5,
              ),
            ),
            Text(tr(context, 'tagline')),
            const SizedBox(height: 60),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icons[page],
                key: ValueKey(page),
                size: 110,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              tr(context, titles[page]),
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(tr(context, 'responsible_text'), textAlign: TextAlign.center),
            const Spacer(),
            Text('${page + 1} / ${titles.length}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => page == titles.length - 1
                    ? finish()
                    : setState(() => page++),
                child: Text(
                  tr(
                    context,
                    page == titles.length - 1 ? 'get_started' : 'next',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final String mode;
  final String? token, email;
  const AuthScreen({super.key, this.mode = 'login', this.token, this.email});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  late String mode;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    mode = widget.mode;
    email.text = widget.email ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    await attempt(context, () async {
      final state = context.read<AppState>();
      final endpoint = mode == 'forgot'
          ? 'forgot-password'
          : mode == 'reset'
          ? 'reset-password'
          : mode;
      final result = await state.api.request(
        'auth/$endpoint',
        method: 'POST',
        body: {
          'email': email.text.trim(),
          if (mode == 'register') 'name': name.text.trim(),
          if (mode != 'forgot') 'password': password.text,
          if (mode == 'register' || mode == 'reset')
            'password_confirmation': confirmation.text,
          if (mode == 'reset') 'token': widget.token,
        },
      );
      if (mode == 'login' || mode == 'register') {
        await state.login(Map<String, dynamic>.from(result));
        if (mounted) Navigator.pop(context);
      } else if (mounted) {
        message(context, result['message']);
        setState(() => mode = 'login');
      }
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> social(bool apple) async {
    if (!const bool.fromEnvironment('FIREBASE_ENABLED')) {
      message(context, 'social_unavailable');
      return;
    }
    setState(() => busy = true);
    await attempt(context, () async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final provider = apple ? AppleAuthProvider() : GoogleAuthProvider();
      final credential = await FirebaseAuth.instance.signInWithProvider(
        provider,
      );
      final token = await credential.user!.getIdToken();
      if (!mounted) return;
      final state = context.read<AppState>();
      final result = await state.api.request(
        'auth/social',
        method: 'POST',
        body: {'id_token': token},
      );
      await state.login(Map<String, dynamic>.from(result));
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr(context, mode))),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.sports_soccer, size: 64),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'MATCHIQ',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 28),
              if (mode == 'register') field(name, 'name'),
              field(email, 'email'),
              if (mode != 'forgot') field(password, 'password', secret: true),
              if (mode == 'register' || mode == 'reset')
                field(confirmation, 'confirm_password', secret: true),
              FilledButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr(context, mode)),
              ),
              if (mode == 'login') ...[
                TextButton(
                  onPressed: () => setState(() => mode = 'forgot'),
                  child: Text(tr(context, 'forgot')),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => social(false),
                  child: Text(tr(context, 'google_signin')),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => social(true),
                  child: Text(tr(context, 'apple_signin')),
                ),
              ],
              TextButton(
                onPressed: () => setState(
                  () => mode = mode == 'register' ? 'login' : 'register',
                ),
                child: Text(
                  tr(context, mode == 'register' ? 'login' : 'register'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget field(
    TextEditingController controller,
    String key, {
    bool secret = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      obscureText: secret,
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: tr(context, key),
        helperText: key == 'password' && mode == 'register'
            ? tr(context, 'password_hint')
            : null,
        helperMaxLines: 2,
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? tr(context, 'required')
          : null,
    ),
  );
}
