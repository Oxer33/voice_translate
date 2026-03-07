package com.voicetranslate.voice_translate

import ai.onnxruntime.OnnxJavaType
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.LongBuffer

internal object NllbTensorUtils {
    fun createLongTensor(env: OrtEnvironment, data: LongArray, shape: LongArray): OnnxTensor {
        val buffer = LongBuffer.wrap(data)
        return OnnxTensor.createTensor(env, buffer, shape)
    }

    fun createFloatTensor(env: OrtEnvironment, data: FloatArray, shape: LongArray): OnnxTensor {
        val buffer = FloatBuffer.wrap(data)
        return OnnxTensor.createTensor(env, buffer, shape)
    }

    fun createBooleanTensor(env: OrtEnvironment, value: Boolean): OnnxTensor {
        val buffer = ByteBuffer.allocateDirect(1).order(ByteOrder.nativeOrder())
        buffer.put(if (value) 1 else 0)
        buffer.rewind()
        return OnnxTensor.createTensor(env, buffer, longArrayOf(1), OnnxJavaType.BOOL)
    }

    fun createEmptyPastTensor(
        env: OrtEnvironment,
        numHeads: Int,
        headDim: Int,
    ): OnnxTensor {
        return createFloatTensor(
            env = env,
            data = FloatArray(0),
            shape = longArrayOf(1, numHeads.toLong(), 0, headDim.toLong()),
        )
    }

    fun argmax(values: FloatArray): Int {
        var bestIndex = 0
        var bestValue = Float.NEGATIVE_INFINITY
        for (index in values.indices) {
            val candidate = values[index]
            if (candidate > bestValue) {
                bestValue = candidate
                bestIndex = index
            }
        }
        return bestIndex
    }
}
