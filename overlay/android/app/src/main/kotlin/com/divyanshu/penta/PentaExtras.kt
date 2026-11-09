package com.divyanshu.penta

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Floating box and screen share logic, kept apart from MainActivity. */
object PentaExtras {
    @Volatile var channel: MethodChannel? = null
    @Volatile var visible = false
    @Volatile var shareRequested = false
    @Volatile var inDialog = false
    @Volatile var suppressUntil = 0L
    private const val REQ_SHARE = 4242
    private val main = Handler(Looper.getMainLooper())

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("penta_native", Context.MODE_PRIVATE)
    private fun floatingOn(ctx: Context) = prefs(ctx).getBoolean("floating", false)

    fun emit(type: String, extra: Map<String, Any?> = emptyMap()) {
        main.post {
            try {
                val payload = HashMap<String, Any?>(extra)
                payload["type"] = type
                channel?.invokeMethod("overlayEvent", payload)
            } catch (e: Exception) {
            }
        }
    }

    // ---- lifecycle hooks called from MainActivity ----

    fun onLeave(activity: Activity) {
        visible = false
        if (inDialog) return
        if (System.currentTimeMillis() < suppressUntil) return
        val ctx = activity.applicationContext
        if (floatingOn(ctx) && Settings.canDrawOverlays(ctx)) {
            if (PentaOverlay.show(ctx)) emit("shown")
        }
    }

    fun onPause() {
        visible = false
    }

    fun onResume(activity: Activity) {
        visible = true
        suppressUntil = 0L
        PentaOverlay.hide()
        if (shareRequested) {
            shareRequested = false
            requestShare(activity)
        }
    }

    fun onResult(activity: Activity, requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQ_SHARE) return
        inDialog = false
        val ctx = activity.applicationContext
        if (resultCode == Activity.RESULT_OK && data != null) {
            ScreenShare.start(ctx, resultCode, data)
            main.postDelayed({
                activity.moveTaskToBack(true)
                if (floatingOn(ctx) && Settings.canDrawOverlays(ctx)) PentaOverlay.show(ctx)
            }, 600)
        } else {
            emit("shareState", mapOf("on" to false))
        }
    }

    // ---- screen share ----

    fun requestShare(activity: Activity) {
        if (!visible) {
            // Bring Penta to the front first, then show Android's permission pop-up.
            shareRequested = true
            val i = Intent(activity, MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            try {
                activity.startActivity(i)
            } catch (e: Exception) {
                shareRequested = false
                emit("shareState", mapOf("on" to false))
            }
            return
        }
        inDialog = true
        PentaOverlay.hide()
        val mpm = activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        try {
            activity.startActivityForResult(mpm.createScreenCaptureIntent(), REQ_SHARE)
        } catch (e: Exception) {
            inDialog = false
            emit("shareState", mapOf("on" to false))
        }
    }

    private fun capture(result: MethodChannel.Result) {
        if (!ScreenShare.active) {
            result.success(null)
            return
        }
        PentaOverlay.setVisible(false)
        main.postDelayed({
            val bytes = ScreenShare.capture()
            PentaOverlay.setVisible(true)
            result.success(bytes)
        }, 380)
    }

    /** Returns true when the call was handled here. */
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result): Boolean {
        val ctx = activity.applicationContext
        when (call.method) {
            "setFloating" -> {
                prefs(ctx).edit().putBoolean("floating", call.argument<Boolean>("on") == true).apply()
                result.success(true)
            }
            "canOverlay" -> result.success(Settings.canDrawOverlays(ctx))
            "askOverlayPermission" -> {
                val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}"))
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    activity.startActivity(i)
                } catch (e: Exception) {
                }
                result.success(true)
            }
            "showOverlay" -> result.success(PentaOverlay.show(ctx))
            "hideOverlay" -> {
                PentaOverlay.hide()
                result.success(true)
            }
            "overlayUpdate" -> {
                PentaOverlay.update(
                    call.argument<String>("text") ?: "",
                    call.argument<String>("mood") ?: "idle",
                    call.argument<Boolean>("listening") == true,
                    call.argument<Boolean>("sharing") == true
                )
                result.success(true)
            }
            "minimizeApp" -> {
                activity.moveTaskToBack(true)
                result.success(true)
            }
            "startShare" -> {
                requestShare(activity)
                result.success(ScreenShare.active)
            }
            "stopShare" -> {
                ScreenShare.stop(ctx)
                emit("shareState", mapOf("on" to false))
                result.success(true)
            }
            "isSharing" -> result.success(ScreenShare.active)
            "captureScreen" -> capture(result)
            else -> return false
        }
        return true
    }
}
