package com.voicetranslate.voice_translate

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxValue
import ai.onnxruntime.OrtSession
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

internal object NllbBackend {
    private const val MAX_SOURCE_TOKENS = 512
    private const val MAX_TARGET_TOKENS = 128

    private val lock = ReentrantLock()
    private var cachedBundle: NllbModelBundle? = null

    fun validate(modelDir: String): String? = lock.withLock {
        return try {
            getOrLoadBundle(modelDir)
            null
        } catch (error: Throwable) {
            buildUserFriendlyError(error)
        }
    }

    fun translate(
        modelDir: String,
        inputText: String,
        sourceLanguageCode: String,
        targetLanguageCode: String,
    ): String = lock.withLock {
        val normalizedInput = inputText.trim().replace(Regex("\\s+"), " ")
        require(normalizedInput.isNotEmpty()) {
            "Il testo da tradurre e' vuoto"
        }

        val bundle = getOrLoadBundle(modelDir)
        val encoderInputIds = buildEncoderInputIds(bundle, normalizedInput, sourceLanguageCode)
        val encoderAttentionMask = LongArray(encoderInputIds.size) { 1L }
        val targetLanguageId = bundle.resolveLanguageTokenId(targetLanguageCode)

        val encoderState = runEncoder(
            bundle = bundle,
            encoderInputIds = encoderInputIds,
            encoderAttentionMask = encoderAttentionMask,
        )

        val generatedIds = mutableListOf(bundle.config.decoderStartTokenId.toLong())
        val maxTargetTokens = bundle.config.maxLength.coerceAtMost(MAX_TARGET_TOKENS)

        for (step in 0 until maxTargetTokens) {
            val logits = runDecoder(
                bundle = bundle,
                decoderInputIds = generatedIds.toLongArray(),
                encoderState = encoderState,
                encoderAttentionMask = encoderAttentionMask,
            )

            val nextTokenId = if (step == 0) {
                targetLanguageId
            } else {
                NllbTensorUtils.argmax(logits)
            }

            generatedIds.add(nextTokenId.toLong())

            if (nextTokenId == bundle.config.eosTokenId) {
                break
            }
        }

        return bundle.tokenizer.decode(generatedIds.toLongArray(), true).trim()
    }

    fun close() = lock.withLock {
        cachedBundle?.close()
        cachedBundle = null
    }

    private fun getOrLoadBundle(modelDir: String): NllbModelBundle {
        val current = cachedBundle
        if (current != null && current.modelDir == modelDir) {
            return current
        }

        current?.close()
        val loaded = NllbModelBundle.load(modelDir)
        cachedBundle = loaded
        return loaded
    }

    private fun buildEncoderInputIds(
        bundle: NllbModelBundle,
        inputText: String,
        sourceLanguageCode: String,
    ): LongArray {
        val sourceLanguageId = bundle.resolveLanguageTokenId(sourceLanguageCode).toLong()
        val textEncoding = bundle.tokenizer.encode(inputText, false, false)
        val tokenIds = textEncoding.ids
        val maxBodyTokens = (MAX_SOURCE_TOKENS - 2).coerceAtLeast(1)
        val bodySize = minOf(tokenIds.size, maxBodyTokens)
        val encoderInputIds = LongArray(bodySize + 2)
        encoderInputIds[0] = sourceLanguageId
        System.arraycopy(tokenIds, 0, encoderInputIds, 1, bodySize)
        encoderInputIds[encoderInputIds.lastIndex] = bundle.config.eosTokenId.toLong()
        return encoderInputIds
    }

    private fun runEncoder(
        bundle: NllbModelBundle,
        encoderInputIds: LongArray,
        encoderAttentionMask: LongArray,
    ): EncoderState {
        val inputs = linkedMapOf<String, OnnxTensor>()
        try {
            inputs[resolveName(bundle.encoderInputNames, listOf("input_ids"))] =
                NllbTensorUtils.createLongTensor(
                    env = bundle.env,
                    data = encoderInputIds,
                    shape = longArrayOf(1, encoderInputIds.size.toLong()),
                )

            val attentionMaskName = resolveOptionalName(
                bundle.encoderInputNames,
                listOf("attention_mask", "encoder_attention_mask"),
            )
            if (attentionMaskName != null) {
                inputs[attentionMaskName] = NllbTensorUtils.createLongTensor(
                    env = bundle.env,
                    data = encoderAttentionMask,
                    shape = longArrayOf(1, encoderAttentionMask.size.toLong()),
                )
            }

            bundle.encoderSession.run(inputs).use { result ->
                val outputName = resolveOptionalName(
                    bundle.encoderOutputNames,
                    listOf("last_hidden_state", "encoder_last_hidden_state"),
                ) ?: bundle.encoderOutputNames.first()

                val value = getTensorValue(result, outputName)
                @Suppress("UNCHECKED_CAST")
                val hiddenStates = value as Array<Array<FloatArray>>
                val sequenceLength = hiddenStates[0].size
                val hiddenSize = hiddenStates[0][0].size
                val flattened = FloatArray(sequenceLength * hiddenSize)

                var offset = 0
                for (tokenIndex in 0 until sequenceLength) {
                    val tokenVector = hiddenStates[0][tokenIndex]
                    System.arraycopy(tokenVector, 0, flattened, offset, hiddenSize)
                    offset += hiddenSize
                }

                return EncoderState(
                    flattenedHiddenStates = flattened,
                    sequenceLength = sequenceLength,
                    hiddenSize = hiddenSize,
                )
            }
        } finally {
            inputs.values.forEach { it.close() }
        }
    }

    private fun runDecoder(
        bundle: NllbModelBundle,
        decoderInputIds: LongArray,
        encoderState: EncoderState,
        encoderAttentionMask: LongArray,
    ): FloatArray {
        val decoderAttentionMask = LongArray(decoderInputIds.size) { 1L }
        val inputs = linkedMapOf<String, OnnxTensor>()

        try {
            for (name in bundle.decoderInputNames) {
                when {
                    name == "input_ids" || name == "decoder_input_ids" -> {
                        inputs[name] = NllbTensorUtils.createLongTensor(
                            env = bundle.env,
                            data = decoderInputIds,
                            shape = longArrayOf(1, decoderInputIds.size.toLong()),
                        )
                    }

                    name == "encoder_attention_mask" -> {
                        inputs[name] = NllbTensorUtils.createLongTensor(
                            env = bundle.env,
                            data = encoderAttentionMask,
                            shape = longArrayOf(1, encoderAttentionMask.size.toLong()),
                        )
                    }

                    name == "attention_mask" || name == "decoder_attention_mask" -> {
                        inputs[name] = NllbTensorUtils.createLongTensor(
                            env = bundle.env,
                            data = decoderAttentionMask,
                            shape = longArrayOf(1, decoderAttentionMask.size.toLong()),
                        )
                    }

                    name == "encoder_hidden_states" || name == "encoder_last_hidden_state" -> {
                        inputs[name] = NllbTensorUtils.createFloatTensor(
                            env = bundle.env,
                            data = encoderState.flattenedHiddenStates,
                            shape = longArrayOf(
                                1,
                                encoderState.sequenceLength.toLong(),
                                encoderState.hiddenSize.toLong(),
                            ),
                        )
                    }

                    name == "use_cache_branch" -> {
                        inputs[name] = NllbTensorUtils.createBooleanTensor(bundle.env, false)
                    }

                    name.startsWith("past_key_values.") -> {
                        inputs[name] = NllbTensorUtils.createEmptyPastTensor(
                            env = bundle.env,
                            numHeads = bundle.config.decoderAttentionHeads,
                            headDim = bundle.config.headDim,
                        )
                    }

                    else -> {
                        throw IllegalStateException("Input decoder NLLB non supportato: $name")
                    }
                }
            }

            bundle.decoderSession.run(inputs).use { result ->
                val outputName = resolveOptionalName(bundle.decoderOutputNames, listOf("logits"))
                    ?: bundle.decoderOutputNames.first()
                val value = getTensorValue(result, outputName)
                @Suppress("UNCHECKED_CAST")
                val logits = value as Array<Array<FloatArray>>
                return logits[0][logits[0].lastIndex]
            }
        } finally {
            inputs.values.forEach { it.close() }
        }
    }

    private fun getTensorValue(result: OrtSession.Result, name: String): Any {
        val output = result.get(name).orElseThrow {
            IllegalStateException("Output ONNX non trovato: $name")
        }
        require(output is OnnxTensor) {
            "Output ONNX non tensoriale per $name: ${output.type}"
        }
        return output.value
    }

    private fun resolveName(candidates: Set<String>, preferredNames: List<String>): String {
        return resolveOptionalName(candidates, preferredNames)
            ?: throw IllegalStateException(
                "Nodo ONNX richiesto non trovato. Disponibili: ${candidates.joinToString()}"
            )
    }

    private fun resolveOptionalName(
        candidates: Set<String>,
        preferredNames: List<String>,
    ): String? {
        for (preferred in preferredNames) {
            if (candidates.contains(preferred)) {
                return preferred
            }
        }
        return null
    }

    private fun buildUserFriendlyError(error: Throwable): String {
        val messages = generateSequence(error) { it.cause }
            .mapNotNull { throwable ->
                throwable.message?.takeIf { it.isNotBlank() } ?: throwable.javaClass.simpleName
            }
            .toList()
        val combinedMessage = messages.joinToString(" | ")
        val normalizedMessage = combinedMessage.lowercase()

        return when {
            combinedMessage.contains("LibUtils") ||
                normalizedMessage.contains("huggingface native library") ||
                normalizedMessage.contains("tokenizer-native") -> {
                "Backend NLLB non disponibile: tokenizer Android non inizializzabile in questa build."
            }

            normalizedMessage.contains("unsatisfiedlinkerror") ||
                normalizedMessage.contains("dlopen failed") -> {
                "Backend NLLB non disponibile: libreria nativa non caricabile su questo dispositivo."
            }

            messages.isNotEmpty() -> "Backend NLLB non disponibile: ${messages.first()}"
            else -> "Backend NLLB non disponibile."
        }
    }

    private data class EncoderState(
        val flattenedHiddenStates: FloatArray,
        val sequenceLength: Int,
        val hiddenSize: Int,
    )
}
