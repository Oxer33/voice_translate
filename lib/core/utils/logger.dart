/// Logger centralizzato dell'applicazione.
/// Fornisce log colorati con timestamp e livelli di severità.
library;

import 'dart:developer' as dev;

/// Livelli di log disponibili
enum LogLevel { debug, info, warning, error }

/// Logger centralizzato con supporto per tag e livelli
class AppLogger {
  AppLogger._();

  /// Abilita/disabilita i log in produzione
  static bool _enabled = true;

  /// Livello minimo di log da mostrare
  static LogLevel _minLevel = LogLevel.debug;

  /// Inizializza il logger con le configurazioni desiderate
  static void init({bool enabled = true, LogLevel minLevel = LogLevel.debug}) {
    _enabled = enabled;
    _minLevel = minLevel;
    info('Logger', 'Logger inizializzato - enabled: $enabled, minLevel: $minLevel');
  }

  /// Log di debug - per informazioni dettagliate durante lo sviluppo
  static void debug(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Log informativo - per eventi normali dell'app
  static void info(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Log di avviso - per situazioni potenzialmente problematiche
  static void warning(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  /// Log di errore - per errori e eccezioni
  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag, message);
    if (error != null) {
      _log(LogLevel.error, tag, 'Errore: $error');
    }
    if (stackTrace != null) {
      _log(LogLevel.error, tag, 'StackTrace: $stackTrace');
    }
  }

  /// Metodo interno per scrivere il log
  static void _log(LogLevel level, String tag, String message) {
    if (!_enabled) return;
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final prefix = _levelPrefix(level);
    final logMessage = '$prefix [$timestamp] [$tag] $message';

    dev.log(logMessage, name: 'VoiceTranslate');
  }

  /// Restituisce il prefisso emoji per il livello di log
  static String _levelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
    }
  }
}
