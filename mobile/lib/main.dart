import 'presentation/brand.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/demo_api_client.dart';
import 'domain/app_state.dart';
import 'presentation/home.dart';
import 'presentation/auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    const bool.fromEnvironment('DEMO_MODE') ? DemoApiClient() : ApiClient(),
  );
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: MatchBrand(large: true),
                ),
                const SizedBox(height: 32),
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
    return MaterialApp(
      title: state.api.isDemo ? 'MatchIQ Demo' : 'MatchIQ',
      builder: (context, child) => state.api.isDemo
          ? Column(
              children: [
                Material(
                  color: const Color(0xff553f12),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 15,
                            color: gold,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              state.t('DEMO • Sample data • Offline'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: child!,
                  ),
                ),
              ],
            )
          : child!,
      debugShowCheckedModeBanner: false,
      locale: state.locale,
      supportedLocales: const [Locale('en'), Locale('so'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: matchTheme(state.dark),
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
