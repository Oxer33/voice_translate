library;

import 'package:voice_translate/core/utils/logger.dart';
import 'package:voice_translate/data/datasources/nllb_platform_channel.dart';

const String _tag = 'OnnxFFI';

class OnnxFFI {
  final String modelDir;

  OnnxFFI({
    required this.modelDir,
  });

  static Future<String?> validateNativeBackend({
    required String modelDir,
  }) async {
    AppLogger.info(_tag, 'Validazione backend NLLB Android...');
    return NllbPlatformChannel.validateBackend(modelDir: modelDir);
  }

  static Future<String> translateInIsolate({
    String? libraryPath,
    required String modelDir,
    required String inputText,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    AppLogger.info(_tag, 'Avvio traduzione NLLB via backend Android...');
    AppLogger.debug(_tag,
        'Traduzione: $sourceLanguageCode -> $targetLanguageCode');
    AppLogger.debug(_tag, 'Testo: $inputText');

    final result = await NllbPlatformChannel.translate(
      modelDir: modelDir,
      inputText: inputText,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );

    AppLogger.info(_tag, 'Traduzione completata: $result');
    return result;
  }
}
