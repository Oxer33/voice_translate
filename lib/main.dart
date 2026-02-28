// Entry point dell'applicazione VoiceTranslate.
// Inizializza Hive, logger e avvia l'app con Riverpod.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:voice_translate/app.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'Main';

void main() async {
  // Assicura che i binding Flutter siano inizializzati
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza il logger
  AppLogger.init(enabled: true, minLevel: LogLevel.debug);
  AppLogger.info(_tag, 'Avvio VoiceTranslate...');

  // Inizializza Hive per la persistenza locale
  AppLogger.info(_tag, 'Inizializzazione Hive...');
  await Hive.initFlutter();
  AppLogger.info(_tag, 'Hive inizializzato');

  // Imposta orientamento preferito (portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Stile barra di sistema trasparente
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  AppLogger.info(_tag, 'Avvio app con ProviderScope...');

  // Avvia l'app con Riverpod ProviderScope
  runApp(
    const ProviderScope(
      child: VoiceTranslateApp(),
    ),
  );
}
