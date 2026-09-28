import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'domain/app_state.dart';
import 'presentation/home.dart';
import 'presentation/auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(ApiClient());
  runApp(
    ChangeNotifierProvider.value(value: state, child: const StartupScreen()),
  );
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});
  @override
  State<StartupScreen> createState() => _StartupState();
}

class _StartupState extends State<StartupScreen> {
  late Future<void> initialization;
  @override
  void initState() {
    super.initState();
    initialization = context.read<AppState>().init();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const MatchIQApp();
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xff080e1a),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  color: Color(0xff3578ff),
                  size: 80,
                ),
                const SizedBox(height: 24),
                const Text(
                  'MATCHIQ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 24),
                if (!snapshot.hasError)
                  const CircularProgressIndicator()
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(
                      () => initialization = context.read<AppState>().init(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class MatchIQApp extends StatelessWidget {
  const MatchIQApp({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff3578ff),
      brightness: state.dark ? Brightness.dark : Brightness.light,
    );
    return MaterialApp(
      title: 'MatchIQ',
      debugShowCheckedModeBanner: false,
      locale: state.locale,
      supportedLocales: const [Locale('en'), Locale('so'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: state.dark
            ? const Color(0xff080e1a)
            : const Color(0xfff3f6fb),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: state.dark ? const Color(0xff121d30) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .35),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri?.path == '/reset-password') {
          return MaterialPageRoute(
            builder: (_) => AuthScreen(
              mode: 'reset',
              token: uri!.queryParameters['token'],
              email: uri.queryParameters['email'],
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) =>
              state.onboarded ? const HomeScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}
