package com.divyanshu.penta

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import java.io.ByteArrayOutputStream

/** Keeps the newest screen picture ready, only after the user allowed screen capture. */
object ScreenShare {
    @Volatile var active = false
    private var projection: MediaProjection? = null
    private var reader: ImageReader? = null
    private var display: VirtualDisplay? = null
    private var thread: HandlerThread? = null
    private var held: Image? = null
    private val lock = Any()

    fun start(ctx: Context, resultCode: Int, data: Intent) {
        val i = Intent(ctx, ScreenShareService::class.java)
        i.putExtra("code", resultCode)
        i.putExtra("data", data)
        if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
    }

    fun stop(ctx: Context) {
        ctx.stopService(Intent(ctx, ScreenShareService::class.java))
        release()
    }

    /** Called by the service after it has become a foreground service. */
    fun begin(ctx: Context, code: Int, data: Intent) {
        release()
        val mpm = ctx.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val proj = mpm.getMediaProjection(code, data) ?: return
        val dm = ctx.resources.displayMetrics
        val scale = 0.6f
        val w = (dm.widthPixels * scale).toInt().coerceAtLeast(240)
        val h = (dm.heightPixels * scale).toInt().coerceAtLeast(240)
        val t = HandlerThread("penta-screen")
        t.start()
        val handler = Handler(t.looper)
        proj.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                release()
                PentaExtras.emit("shareState", mapOf("on" to false))
            }
        }, handler)
        val r = ImageReader.newInstance(w, h, PixelFormat.RGBA_8888, 3)
        r.setOnImageAvailableListener({ rd ->
            val img = try {
                rd.acquireLatestImage()
            } catch (e: Exception) {
                null
            }
            if (img != null) {
                synchronized(lock) {
                    try {
                        held?.close()
                    } catch (e: Exception) {
                    }
                    held = img
                }
            }
        }, handler)
        val disp = proj.createVirtualDisplay(
            "penta-screen", w, h, dm.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, r.surface, null, handler
        )
        projection = proj
        reader = r
        display = disp
        thread = t
        active = true
        PentaExtras.emit("shareState", mapOf("on" to true))
    }

    fun release() {
        active = false
        synchronized(lock) {
            try {
                held?.close()
            } catch (e: Exception) {
            }
            held = null
        }
        try {
            display?.release()
        } catch (e: Exception) {
        }
        display = null
        try {
            reader?.setOnImageAvailableListener(null, null)
            reader?.close()
        } catch (e: Exception) {
        }
        reader = null
        val p = projection
        projection = null
        try {
            p?.stop()
        } catch (e: Exception) {
        }
        try {
            thread?.quitSafely()
        } catch (e: Exception) {
        }
        thread = null
    }

    /** The newest screen picture as a JPEG, or null. */
    fun capture(): ByteArray? {
        synchronized(lock) {
            val img = held ?: return null
            return try {
                val plane = img.planes[0]
                val buffer = plane.buffer
                buffer.rewind()
                val pixelStride = plane.pixelStride
                val rowPadding = plane.rowStride - pixelStride * img.width
                val bmp = Bitmap.createBitmap(img.width + rowPadding / pixelStride, img.height, Bitmap.Config.ARGB_8888)
                bmp.copyPixelsFromBuffer(buffer)
                val cropped = Bitmap.createBitmap(bmp, 0, 0, img.width, img.height)
                val out = ByteArrayOutputStream()
                cropped.compress(Bitmap.CompressFormat.JPEG, 75, out)
                if (cropped !== bmp) cropped.recycle()
                bmp.recycle()
                out.toByteArray()
            } catch (e: Exception) {
                null
            }
        }
    }
}

class ScreenShareService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelId = "penta_screen"
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(channelId, "Penta screen share", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
        val notification = builder
            .setContentTitle("Penta can see your screen")
            .setContentText("Screen share is on. Say \"stop screen share\" to end it.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(2, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(2, notification)
        }
        val code = intent?.getIntExtra("code", 0) ?: 0
        @Suppress("DEPRECATION")
        val data: Intent? = intent?.getParcelableExtra("data")
        if (data == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            ScreenShare.begin(this, code, data)
        } catch (e: Exception) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        ScreenShare.release()
        PentaExtras.emit("shareState", mapOf("on" to false))
        super.onDestroy()
    }
}
