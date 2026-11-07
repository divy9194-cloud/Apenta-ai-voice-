package com.divyanshu.penta

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

/** Registers Penta as a digital assistant (long-press Home). */
class PentaInteractionService : VoiceInteractionService()

class PentaSessionService : VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return PentaSession(this)
    }
}

/** Opens Penta and asks it to start listening, then closes the assistant overlay. */
class PentaSession(context: Context) : VoiceInteractionSession(context) {
    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            .putExtra("penta_listen", true)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
        }
        hide()
    }
}
