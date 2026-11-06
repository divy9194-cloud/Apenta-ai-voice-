package com.divyanshu.penta

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/** Used only for the "take a screenshot" command. It reads no screen content. */
class ScreenshotService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: ScreenshotService? = null
    }

    override fun onServiceConnected() {
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }
}
