/// Helper per la gestione dei permessi dell'app.
/// Gestisce microfono e storage tramite permission_handler.
library;

import 'package:permission_handler/permission_handler.dart';
import 'package:voice_translate/core/utils/logger.dart';

/// Tag per i log di questo modulo
const String _tag = 'PermissionsHelper';

/// Helper centralizzato per la gestione dei permessi
class PermissionsHelper {
  PermissionsHelper._();

  /// Richiede il permesso del microfono.
  /// Restituisce true se concesso, false altrimenti.
  static Future<bool> requestMicrophonePermission() async {
    AppLogger.info(_tag, 'Richiesta permesso microfono...');
    final status = await Permission.microphone.request();
    AppLogger.info(_tag, 'Stato permesso microfono: $status');

    if (status.isGranted) {
      AppLogger.info(_tag, 'Permesso microfono concesso');
      return true;
    }

    if (status.isPermanentlyDenied) {
      AppLogger.warning(
          _tag, 'Permesso microfono negato permanentemente - aprire impostazioni');
    }

    return false;
  }

  /// Controlla se il permesso microfono è già concesso
  static Future<bool> isMicrophoneGranted() async {
    final status = await Permission.microphone.status;
    AppLogger.debug(_tag, 'Stato attuale permesso microfono: $status');
    return status.isGranted;
  }

  /// Richiede il permesso di notifica (per download in background)
  static Future<bool> requestNotificationPermission() async {
    AppLogger.info(_tag, 'Richiesta permesso notifiche...');
    final status = await Permission.notification.request();
    AppLogger.info(_tag, 'Stato permesso notifiche: $status');
    return status.isGranted;
  }

  /// Richiede tutti i permessi necessari all'app
  static Future<Map<Permission, bool>> requestAllPermissions() async {
    AppLogger.info(_tag, 'Richiesta di tutti i permessi...');

    final results = <Permission, bool>{};

    // Microfono (obbligatorio per la registrazione)
    results[Permission.microphone] = await requestMicrophonePermission();

    // Notifiche (per download in background)
    results[Permission.notification] = await requestNotificationPermission();

    AppLogger.info(_tag, 'Risultati permessi: $results');
    return results;
  }

  /// Apre le impostazioni dell'app per concedere permessi manualmente
  static Future<bool> openSettings() async {
    AppLogger.info(_tag, 'Apertura impostazioni app...');
    return await openAppSettings();
  }
}
