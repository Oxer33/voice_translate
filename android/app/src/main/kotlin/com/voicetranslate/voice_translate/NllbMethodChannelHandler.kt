package com.voicetranslate.voice_translate

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

internal class NllbMethodChannelHandler(
    messenger: BinaryMessenger,
    private val activity: FlutterActivity,
) : MethodChannel.MethodCallHandler, AutoCloseable {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_VALIDATE_BACKEND -> {
                val modelDir = call.argument<String>(ARG_MODEL_DIR)
                if (modelDir.isNullOrBlank()) {
                    result.error(ERROR_INVALID_ARGS, "Parametro modelDir mancante", null)
                    return
                }

                runAsync(result) {
                    NllbBackend.validate(modelDir)
                }
            }

            METHOD_TRANSLATE -> {
                val modelDir = call.argument<String>(ARG_MODEL_DIR)
                val inputText = call.argument<String>(ARG_INPUT_TEXT)
                val sourceLanguageCode = call.argument<String>(ARG_SOURCE_LANGUAGE_CODE)
                val targetLanguageCode = call.argument<String>(ARG_TARGET_LANGUAGE_CODE)

                if (modelDir.isNullOrBlank() ||
                    inputText.isNullOrBlank() ||
                    sourceLanguageCode.isNullOrBlank() ||
                    targetLanguageCode.isNullOrBlank()) {
                    result.error(ERROR_INVALID_ARGS, "Parametri traduzione mancanti", null)
                    return
                }

                runAsync(result) {
                    NllbBackend.translate(
                        modelDir = modelDir,
                        inputText = inputText,
                        sourceLanguageCode = sourceLanguageCode,
                        targetLanguageCode = targetLanguageCode,
                    )
                }
            }

            else -> result.notImplemented()
        }
    }

    override fun close() {
        channel.setMethodCallHandler(null)
        executor.shutdownNow()
        NllbBackend.close()
    }

    private fun runAsync(
        result: MethodChannel.Result,
        work: () -> Any?,
    ) {
        executor.execute {
            try {
                val value = work()
                activity.runOnUiThread {
                    result.success(value)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "Errore backend NLLB", error)
                activity.runOnUiThread {
                    result.error(
                        ERROR_BACKEND,
                        error.message ?: "Errore backend NLLB",
                        Log.getStackTraceString(error),
                    )
                }
            }
        }
    }

    companion object {
        private const val TAG = "NllbMethodChannel"
        private const val CHANNEL_NAME = "voice_translate/nllb"
        private const val METHOD_VALIDATE_BACKEND = "validateBackend"
        private const val METHOD_TRANSLATE = "translate"
        private const val ARG_MODEL_DIR = "modelDir"
        private const val ARG_INPUT_TEXT = "inputText"
        private const val ARG_SOURCE_LANGUAGE_CODE = "sourceLanguageCode"
        private const val ARG_TARGET_LANGUAGE_CODE = "targetLanguageCode"
        private const val ERROR_INVALID_ARGS = "NLLB_INVALID_ARGS"
        private const val ERROR_BACKEND = "NLLB_BACKEND_ERROR"
    }
}
