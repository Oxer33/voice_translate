library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:voice_translate/core/utils/logger.dart';

const String _tag = 'NllbPlatformChannel';

class NllbPlatformChannel {
  static const MethodChannel _channel = MethodChannel('voice_translate/nllb');

  static String _normalizeBackendMessage(String? message) {
    final normalizedMessage = message?.trim();
    if (normalizedMessage == null || normalizedMessage.isEmpty) {
      return 'Errore sconosciuto nel backend NLLB.';
    }

    final lowerMessage = normalizedMessage.toLowerCase();
    if (normalizedMessage.contains('LibUtils') ||
        lowerMessage.contains('huggingface native library') ||
        lowerMessage.contains('tokenizer android')) {
      return 'Backend NLLB non disponibile: tokenizer Android non inizializzabile in questa build.';
    }

    return normalizedMessage;
  }

  static Future<String?> validateBackend({
    required String modelDir,
  }) async {
    if (!Platform.isAndroid) {
      return 'Il backend NLLB offline e\' disponibile solo su Android.';
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'validateBackend',
        <String, Object?>{
          'modelDir': modelDir,
        },
      );
      return result;
    } on PlatformException catch (e) {
      AppLogger.error(_tag, 'Errore validazione backend NLLB', e);
      return _normalizeBackendMessage(e.message);
    }
  }

  static Future<String> translate({
    required String modelDir,
    required String inputText,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception('La traduzione offline NLLB e\' supportata solo su Android.');
    }

    try {
      final result = await _channel.invokeMethod<String>(
        'translate',
        <String, Object?>{
          'modelDir': modelDir,
          'inputText': inputText,
          'sourceLanguageCode': sourceLanguageCode,
          'targetLanguageCode': targetLanguageCode,
        },
      );

      if (result == null || result.trim().isEmpty) {
        throw Exception('Il backend NLLB ha restituito una traduzione vuota.');
      }

      return result.trim();
    } on PlatformException catch (e) {
      AppLogger.error(_tag, 'Errore traduzione NLLB', e);
      throw Exception(_normalizeBackendMessage(e.message));
    }
  }
}
