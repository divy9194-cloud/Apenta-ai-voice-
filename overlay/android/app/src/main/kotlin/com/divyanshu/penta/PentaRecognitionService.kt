package com.divyanshu.penta

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognitionService
import android.speech.SpeechRecognizer

/**
 * Android requires an assistant to provide a recognizer. This one hands the request to Google's
 * recognizer, so voice keeps working when Penta is the default assistant.
 */
class PentaRecognitionService : RecognitionService() {

    private var inner: SpeechRecognizer? = null

    private fun safe(block: () -> Unit) {
        try {
            block()
        } catch (e: Exception) {
        }
    }

    override fun onStartListening(recognizerIntent: Intent?, listener: Callback?) {
        val cb = listener ?: return
        val google = ComponentName(
            "com.google.android.googlequicksearchbox",
            "com.google.android.voicesearch.serviceapi.GoogleRecognitionService"
        )
        val rec: SpeechRecognizer? = try {
            SpeechRecognizer.createSpeechRecognizer(this, google)
        } catch (e: Exception) {
            null
        }
        if (rec == null) {
            safe { cb.error(SpeechRecognizer.ERROR_CLIENT) }
            return
        }
        inner?.destroy()
        inner = rec
        rec.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { safe { cb.readyForSpeech(params ?: Bundle()) } }
            override fun onBeginningOfSpeech() { safe { cb.beginningOfSpeech() } }
            override fun onRmsChanged(rmsdB: Float) { safe { cb.rmsChanged(rmsdB) } }
            override fun onBufferReceived(buffer: ByteArray?) { safe { if (buffer != null) cb.bufferReceived(buffer) } }
            override fun onEndOfSpeech() { safe { cb.endOfSpeech() } }
            override fun onError(error: Int) { safe { cb.error(error) } }
            override fun onResults(results: Bundle?) { safe { cb.results(results ?: Bundle()) } }
            override fun onPartialResults(partialResults: Bundle?) { safe { cb.partialResults(partialResults ?: Bundle()) } }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        rec.startListening(recognizerIntent ?: Intent())
    }

    override fun onStopListening(listener: Callback?) {
        inner?.stopListening()
    }

    override fun onCancel(listener: Callback?) {
        inner?.cancel()
    }

    override fun onDestroy() {
        inner?.destroy()
        inner = null
        super.onDestroy()
    }
}
