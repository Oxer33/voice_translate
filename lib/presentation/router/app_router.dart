/// Router dell'applicazione VoiceTranslate.
/// Gestisce la navigazione tra le schermate usando go_router.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voice_translate/presentation/screens/download_screen.dart';
import 'package:voice_translate/presentation/screens/error_screen.dart';
import 'package:voice_translate/presentation/screens/home_screen.dart';
import 'package:voice_translate/presentation/screens/settings_screen.dart';

/// Nomi delle route
class AppRoutes {
  AppRoutes._();

  static const String download = '/download';
  static const String home = '/home';
  static const String settings = '/settings';
  static const String error = '/error';
}

/// Crea il router dell'app
GoRouter createAppRouter({required bool modelsReady}) {
  return GoRouter(
    initialLocation: modelsReady ? AppRoutes.home : AppRoutes.download,
    routes: [
      GoRoute(
        path: AppRoutes.download,
        name: 'download',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const DownloadScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SettingsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.easeInOut));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.error,
        name: 'error',
        pageBuilder: (context, state) {
          final errorMessage =
              state.extra as String? ?? 'Errore sconosciuto';
          return CustomTransitionPage(
            key: state.pageKey,
            child: ErrorScreen(errorMessage: errorMessage),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
    ],
  );
}
