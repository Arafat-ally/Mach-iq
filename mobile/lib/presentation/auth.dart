import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_state.dart';
import 'widgets.dart';
import 'home.dart';
import 'brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingState();
}

class _OnboardingState extends State<OnboardingScreen> {
  Future<void> finish({bool account = false}) async {
    await context.read<AppState>().finishOnboarding();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
    if (account) open(context, const AuthScreen());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BrandBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: finish,
                        child: Text(tr(context, 'skip')),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Image.asset(
                      crestAsset,
                      width: 340,
                      height: box.maxHeight * .42,
                      fit: BoxFit.contain,
                      semanticLabel: 'MATCHIQ',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'Football Analysis'),
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 3,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        for (final item in [
                          (Icons.insights, 'Match Analysis'),
                          (Icons.bolt, 'Daily Tickets'),
                          (Icons.emoji_events_outlined, 'Track Your Results'),
                        ])
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  item.$1,
                                  color: item.$1 == Icons.emoji_events_outlined
                                      ? gold
                                      : cyan,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr(context, item.$2),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => finish(account: true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(tr(context, 'get_started')),
                            const Icon(Icons.arrow_forward),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context, 'Real football. Clear analysis.'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final String mode;
  final String? token, email;
  const AuthScreen({super.key, this.mode = 'device', this.token, this.email});
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
  bool busy = false, showPassword = false;
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
          if (mode == 'register' || mode == 'device') 'name': name.text.trim(),
          if (mode == 'device') 'device_key': await state.api.deviceKey(),
          if (mode != 'forgot' && mode != 'device') 'password': password.text,
          if (mode == 'register' || mode == 'reset')
            'password_confirmation': confirmation.text,
          if (mode == 'reset') 'token': widget.token,
        },
      );
      if (mode == 'login' || mode == 'register' || mode == 'device') {
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
    body: BrandBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      DropdownButton<String>(
                        value: context.watch<AppState>().locale.languageCode,
                        dropdownColor: panel,
                        style: const TextStyle(color: Colors.white),
                        icon: const Icon(
                          Icons.expand_more,
                          color: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(
                            value: 'so',
                            child: Text('Soomaali'),
                          ),
                          DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        ],
                        onChanged: (v) {
                          if (v != null) context.read<AppState>().language(v);
                        },
                      ),
                    ],
                  ),
                  Center(
                    child: Image.asset(
                      crestAsset,
                      width: mode == 'device' ? 150 : 190,
                      height: mode == 'device' ? 150 : 190,
                      semanticLabel: 'MATCHIQ',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      context,
                      mode == 'device'
                          ? 'Create Account'
                          : mode == 'login'
                          ? 'Welcome Back'
                          : mode == 'forgot'
                          ? 'forgot'
                          : 'reset',
                    ),
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      mode == 'device'
                          ? 'Join MATCHIQ for football analysis and daily tickets.'
                          : 'Continue your football analysis journey.',
                    ),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  if (mode == 'device' || mode == 'register')
                    field(name, 'name'),
                  field(email, 'email'),
                  if (mode != 'device' && mode != 'forgot')
                    field(password, 'password', secret: true),
                  if (mode == 'register' || mode == 'reset')
                    field(confirmation, 'confirm_password', secret: true),
                  if (mode == 'device')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        tr(context, 'device_account_note'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr(
                              context,
                              mode == 'device' ? 'Create Account' : mode,
                            ),
                          ),
                          busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),
                  if (mode == 'login')
                    TextButton(
                      onPressed: () => setState(() => mode = 'forgot'),
                      child: Text(tr(context, 'forgot')),
                    ),
                  if (mode == 'login' &&
                      const bool.fromEnvironment('FIREBASE_ENABLED')) ...[
                    OutlinedButton(
                      onPressed: busy ? null : () => social(false),
                      child: Text(tr(context, 'google_signin')),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : () => social(true),
                      child: Text(tr(context, 'apple_signin')),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(
                      () => mode = mode == 'device' ? 'login' : 'device',
                    ),
                    child: Text(
                      tr(
                        context,
                        mode == 'device' ? 'existing_password_login' : 'device',
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      obscureText: secret && !showPassword,
      style: const TextStyle(color: Colors.white),
      keyboardType: key == 'email'
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: tr(context, key),
        labelStyle: const TextStyle(color: Colors.white70),
        fillColor: const Color(0xee051522),
        prefixIcon: Icon(
          key == 'email'
              ? Icons.mail_outline
              : secret
              ? Icons.lock_outline
              : Icons.person_outline,
          color: Colors.white70,
        ),
        suffixIcon: secret
            ? IconButton(
                onPressed: () => setState(() => showPassword = !showPassword),
                icon: Icon(
                  showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                ),
              )
            : null,
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
