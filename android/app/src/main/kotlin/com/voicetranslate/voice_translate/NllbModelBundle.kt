package com.voicetranslate.voice_translate

import ai.djl.huggingface.tokenizers.HuggingFaceTokenizer
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import org.json.JSONObject
import java.io.File
import java.nio.file.Paths

internal data class NllbBackendConfig(
    val bosTokenId: Int,
    val eosTokenId: Int,
    val padTokenId: Int,
    val decoderStartTokenId: Int,
    val maxLength: Int,
    val decoderAttentionHeads: Int,
    val headDim: Int,
)

internal class NllbModelBundle(
    val modelDir: String,
    val env: OrtEnvironment,
    val encoderSession: OrtSession,
    val decoderSession: OrtSession,
    val tokenizer: HuggingFaceTokenizer,
    val config: NllbBackendConfig,
    private val specialTokenIds: Map<String, Int>,
) : AutoCloseable {
    val encoderInputNames: Set<String> = encoderSession.inputInfo.keys
    val encoderOutputNames: Set<String> = encoderSession.outputInfo.keys
    val decoderInputNames: Set<String> = decoderSession.inputInfo.keys
    val decoderOutputNames: Set<String> = decoderSession.outputInfo.keys

    fun resolveLanguageTokenId(languageCode: String): Int {
        specialTokenIds[languageCode]?.let { return it }

        val fallbackEncoding = tokenizer.encode(languageCode, false, false)
        val ids = fallbackEncoding.ids
        if (ids.size == 1) {
            return ids[0].toInt()
        }

        throw IllegalStateException(
            "Codice lingua NLLB non trovato nel tokenizer: $languageCode",
        )
    }

    override fun close() {
        tokenizer.close()
        decoderSession.close()
        encoderSession.close()
    }

    companion object {
        private const val ENCODER_FILE_NAME = "encoder_model_quantized.onnx"
        private const val DECODER_FILE_NAME = "decoder_model_merged_quantized.onnx"
        private const val TOKENIZER_FILE_NAME = "tokenizer.json"
        private const val CONFIG_FILE_NAME = "config.json"

        fun load(modelDir: String): NllbModelBundle {
            val dir = File(modelDir)
            require(dir.exists() && dir.isDirectory) {
                "Cartella modelli NLLB non trovata: $modelDir"
            }

            val encoderFile = File(dir, ENCODER_FILE_NAME)
            val decoderFile = File(dir, DECODER_FILE_NAME)
            val tokenizerFile = File(dir, TOKENIZER_FILE_NAME)
            val configFile = File(dir, CONFIG_FILE_NAME)

            val requiredFiles = listOf(encoderFile, decoderFile, tokenizerFile, configFile)
            val missingFiles = requiredFiles.filterNot { it.exists() }
            require(missingFiles.isEmpty()) {
                "File NLLB mancanti: ${missingFiles.joinToString { it.name }}"
            }

            val env = OrtEnvironment.getEnvironment()
            val encoderSession = createSession(env, encoderFile.absolutePath)
            val decoderSession = createSession(env, decoderFile.absolutePath)
            val tokenizer = HuggingFaceTokenizer.newInstance(Paths.get(tokenizerFile.absolutePath))
            val config = parseConfig(configFile)
            val specialTokenIds = parseSpecialTokenIds(tokenizerFile)

            return NllbModelBundle(
                modelDir = modelDir,
                env = env,
                encoderSession = encoderSession,
                decoderSession = decoderSession,
                tokenizer = tokenizer,
                config = config,
                specialTokenIds = specialTokenIds,
            )
        }

        private fun createSession(env: OrtEnvironment, modelPath: String): OrtSession {
            OrtSession.SessionOptions().use { options ->
                return env.createSession(modelPath, options)
            }
        }

        private fun parseConfig(configFile: File): NllbBackendConfig {
            val json = JSONObject(configFile.readText())
            val dModel = json.optInt("d_model", 1024)
            val decoderAttentionHeads = json.optInt("decoder_attention_heads", 16)
            val headDim = if (decoderAttentionHeads > 0) {
                dModel / decoderAttentionHeads
            } else {
                64
            }

            return NllbBackendConfig(
                bosTokenId = json.optInt("bos_token_id", 0),
                eosTokenId = json.optInt("eos_token_id", 2),
                padTokenId = json.optInt("pad_token_id", 1),
                decoderStartTokenId = json.optInt("decoder_start_token_id", 2),
                maxLength = json.optInt("max_length", 200),
                decoderAttentionHeads = decoderAttentionHeads,
                headDim = headDim,
            )
        }

        private fun parseSpecialTokenIds(tokenizerFile: File): Map<String, Int> {
            val json = JSONObject(tokenizerFile.readText())
            val map = mutableMapOf<String, Int>()
            val addedTokens = json.optJSONArray("added_tokens") ?: return emptyMap()

            for (index in 0 until addedTokens.length()) {
                val tokenObject = addedTokens.optJSONObject(index) ?: continue
                val content = tokenObject.optString("content")
                val id = tokenObject.optInt("id", -1)
                if (content.isNotBlank() && id >= 0) {
                    map[content] = id
                }
            }

            return map
        }
    }
}
