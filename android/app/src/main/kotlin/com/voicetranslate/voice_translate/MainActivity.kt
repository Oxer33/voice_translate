package com.voicetranslate.voice_translate

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private var nllbMethodChannelHandler: NllbMethodChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nllbMethodChannelHandler?.close()
        nllbMethodChannelHandler = NllbMethodChannelHandler(
            messenger = flutterEngine.dartExecutor.binaryMessenger,
            activity = this,
        )
    }

    override fun onDestroy() {
        nllbMethodChannelHandler?.close()
        nllbMethodChannelHandler = null
        super.onDestroy()
    }
}
