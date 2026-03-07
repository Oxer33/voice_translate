/// Widget root dell'applicazione VoiceTranslate.
/// Configura tema, router e provider Riverpod.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voice_translate/core/theme/app_theme.dart';
import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/presentation/providers/app_providers.dart';
import 'package:voice_translate/presentation/router/app_router.dart';

/// Tag per i log di questo modulo
const String _tag = 'App';

/// Widget root dell'applicazione
class VoiceTranslateApp extends ConsumerStatefulWidget {
  const VoiceTranslateApp({super.key});

  @override
  ConsumerState<VoiceTranslateApp> createState() =>
      _VoiceTranslateAppState();
}

class _VoiceTranslateAppState extends ConsumerState<VoiceTranslateApp>
    with WidgetsBindingObserver {
  /// Router cached: viene creato una sola volta al primo avvio
  /// per evitare perdita di stato navigazione su rebuild
  GoRouter? _cachedRouter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.info(_tag, 'VoiceTranslateApp inizializzata');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    AppLogger.info(_tag, 'App lifecycle state: $state');

    // Gestione background/foreground per scarico modelli
    switch (state) {
      case AppLifecycleState.paused:
        AppLogger.info(_tag, 'App in background');
        // I modelli verranno scaricati dopo 5 minuti (gestito dai provider)
        break;
      case AppLifecycleState.resumed:
        AppLogger.info(_tag, 'App in foreground');
        // Ricarica modelli se necessario
        break;
      default:
        break;
    }
  }

  /// Helper per costruire il MaterialApp.router con il router cached
  Widget _buildWithRouter() {
    return MaterialApp.router(
      title: 'VoiceTranslate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _cachedRouter!,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verifica se i modelli sono pronti per decidere la route iniziale
    final modelsReady = ref.watch(modelsReadyProvider);

    return modelsReady.when(
      data: (ready) {
        AppLogger.debug(_tag, 'Modelli pronti: $ready');
        // Crea il router SOLO la prima volta, poi riusa il cached
        _cachedRouter ??= createAppRouter(modelsReady: ready);
        return _buildWithRouter();
      },
      loading: () {
        // Se il router esiste gia', continuiamo a usarlo (no splash flash)
        if (_cachedRouter != null) {
          return _buildWithRouter();
        }
        // Prima volta: mostra splash screen durante il caricamento
        return MaterialApp(
          title: 'VoiceTranslate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const _SplashScreen(),
        );
      },
      error: (error, stack) {
        AppLogger.error(_tag, 'Errore inizializzazione', error, stack);
        // Se il router esiste gia', continuiamo a usarlo
        if (_cachedRouter != null) {
          return _buildWithRouter();
        }
        return MaterialApp(
          title: 'VoiceTranslate',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Center(
              child: Text('Errore: $error'),
            ),
          ),
        );
      },
    );
  }
}

/// Splash screen mostrata durante l'inizializzazione
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo animato
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryBlue,
                    AppColors.primaryBlueLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'VoiceTranslate',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
