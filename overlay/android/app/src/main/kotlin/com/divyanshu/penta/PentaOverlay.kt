package com.divyanshu.penta

import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Outline
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.io.File

/** The small floating Penta box that sits over other apps. */
object PentaOverlay {
    private var root: LinearLayout? = null
    private var frame: GradientDrawable? = null
    private var bubble: TextView? = null
    private var avatarView: ImageView? = null
    private var micBtn: TextView? = null
    private var shareBg: GradientDrawable? = null
    private var bounce: ObjectAnimator? = null
    private var lastMood = ""
    private var lastX = -1
    private var lastY = -1

    private fun dp(ctx: Context, v: Int): Int = (v * ctx.resources.displayMetrics.density).toInt()

    private fun square(bmp: Bitmap): Bitmap {
        val side = minOf(bmp.width, bmp.height)
        return Bitmap.createBitmap(bmp, 0, 0, side, side)
    }

    // Uses the picture chosen in the Photo editor, otherwise the built-in boy picture.
    private fun loadAvatar(ctx: Context): Bitmap? {
        try {
            val sp = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val path = sp.getString("flutter.avatarPath", null)
            if (path != null && File(path).exists()) {
                val opts = BitmapFactory.Options()
                opts.inSampleSize = 3
                val bmp = BitmapFactory.decodeFile(path, opts)
                if (bmp != null) return square(bmp)
            }
        } catch (e: Exception) {
        }
        return try {
            ctx.assets.open("flutter_assets/assets/boy.jpg").use { stream ->
                val opts = BitmapFactory.Options()
                opts.inSampleSize = 3
                val bmp = BitmapFactory.decodeStream(stream, null, opts)
                if (bmp == null) null else square(bmp)
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun pill(ctx: Context, color: String): GradientDrawable {
        val g = GradientDrawable()
        g.cornerRadius = dp(ctx, 10).toFloat()
        g.setColor(Color.parseColor(color))
        return g
    }

    private fun makeButton(ctx: Context, label: String, bg: GradientDrawable, onClick: () -> Unit): TextView {
        val tv = TextView(ctx)
        tv.text = label
        tv.textSize = 16f
        tv.gravity = Gravity.CENTER
        tv.setTextColor(Color.WHITE)
        tv.setPadding(dp(ctx, 12), dp(ctx, 5), dp(ctx, 12), dp(ctx, 5))
        tv.background = bg
        tv.setOnClickListener { onClick() }
        return tv
    }

    private fun openPenta(ctx: Context) {
        val i = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        try {
            ctx.startActivity(i)
        } catch (e: Exception) {
        }
    }

    @Suppress("DEPRECATION")
    fun show(context: Context): Boolean {
        val ctx = context.applicationContext
        if (root != null) return true
        if (!Settings.canDrawOverlays(ctx)) return false
        val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val box = LinearLayout(ctx)
        box.orientation = LinearLayout.VERTICAL
        box.setPadding(dp(ctx, 10), dp(ctx, 10), dp(ctx, 10), dp(ctx, 8))
        val bg = GradientDrawable()
        bg.cornerRadius = dp(ctx, 18).toFloat()
        bg.setColor(Color.parseColor("#EE0A1030"))
        bg.setStroke(dp(ctx, 2), Color.parseColor("#8B5CF6"))
        box.background = bg
        frame = bg

        val row = LinearLayout(ctx)
        row.orientation = LinearLayout.HORIZONTAL
        row.gravity = Gravity.CENTER_VERTICAL

        val img = ImageView(ctx)
        img.scaleType = ImageView.ScaleType.CENTER_CROP
        img.clipToOutline = true
        img.outlineProvider = object : ViewOutlineProvider() {
            override fun getOutline(view: View, outline: Outline) {
                outline.setRoundRect(0, 0, view.width, view.height, dp(ctx, 12).toFloat())
            }
        }
        val face = loadAvatar(ctx)
        if (face != null) img.setImageBitmap(face)
        avatarView = img
        row.addView(img, LinearLayout.LayoutParams(dp(ctx, 60), dp(ctx, 60)))

        val tv = TextView(ctx)
        tv.setTextColor(Color.WHITE)
        tv.textSize = 13f
        tv.maxLines = 4
        tv.ellipsize = TextUtils.TruncateAt.END
        tv.setPadding(dp(ctx, 10), 0, 0, 0)
        tv.text = "Main yahin hoon. Bolo!"
        bubble = tv
        row.addView(tv, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        box.addView(row)

        val bar = LinearLayout(ctx)
        bar.orientation = LinearLayout.HORIZONTAL
        bar.gravity = Gravity.END
        bar.setPadding(0, dp(ctx, 8), 0, 0)

        fun add(v: TextView) {
            val lp = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT)
            lp.leftMargin = dp(ctx, 6)
            bar.addView(v, lp)
        }

        val mic = makeButton(ctx, "🎤", pill(ctx, "#335F7BFF")) { PentaExtras.emit("mic") }
        micBtn = mic
        add(mic)
        val shareDrawable = pill(ctx, "#33FFFFFF")
        shareBg = shareDrawable
        add(makeButton(ctx, "📺", shareDrawable) { PentaExtras.emit("share") })
        add(makeButton(ctx, "⤢", pill(ctx, "#33FFFFFF")) { openPenta(ctx) })
        add(makeButton(ctx, "✕", pill(ctx, "#33FFFFFF")) {
            hide()
            PentaExtras.emit("close")
        })
        box.addView(bar)

        val type = if (Build.VERSION.SDK_INT >= 26) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val lp = WindowManager.LayoutParams(
            dp(ctx, 270),
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )
        lp.gravity = Gravity.TOP or Gravity.START
        lp.x = if (lastX >= 0) lastX else dp(ctx, 12)
        lp.y = if (lastY >= 0) lastY else dp(ctx, 140)

        var startX = 0
        var startY = 0
        var touchX = 0f
        var touchY = 0f
        box.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = lp.x
                    startY = lp.y
                    touchX = e.rawX
                    touchY = e.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    lp.x = startX + (e.rawX - touchX).toInt()
                    lp.y = startY + (e.rawY - touchY).toInt()
                    lastX = lp.x
                    lastY = lp.y
                    try {
                        wm.updateViewLayout(box, lp)
                    } catch (ex: Exception) {
                    }
                    true
                }
                else -> false
            }
        }

        return try {
            wm.addView(box, lp)
            root = box
            lastMood = ""
            true
        } catch (e: Exception) {
            false
        }
    }

    fun hide() {
        val r = root ?: return
        try {
            val wm = r.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.removeView(r)
        } catch (e: Exception) {
        }
        bounce?.cancel()
        bounce = null
        root = null
    }

    fun setVisible(visible: Boolean) {
        root?.visibility = if (visible) View.VISIBLE else View.INVISIBLE
    }

    fun update(msg: String, mood: String, listening: Boolean, sharing: Boolean) {
        val r = root ?: return
        val ctx = r.context
        bubble?.text = msg
        micBtn?.text = if (listening) "⏹" else "🎤"
        val color = when {
            listening -> "#22D3EE"
            mood == "speaking" -> "#F472B6"
            else -> "#8B5CF6"
        }
        frame?.setStroke(dp(ctx, 2), Color.parseColor(color))
        shareBg?.setColor(Color.parseColor(if (sharing) "#6622C55E" else "#33FFFFFF"))
        avatarView?.alpha = if (mood == "sleeping") 0.5f else 1f
        if (mood != lastMood) {
            lastMood = mood
            bounce?.cancel()
            bounce = null
            val a = avatarView
            if (a != null) {
                a.translationY = 0f
                if (mood == "speaking") {
                    val anim = ObjectAnimator.ofFloat(a, "translationY", 0f, -dp(ctx, 4).toFloat(), 0f)
                    anim.duration = 450
                    anim.repeatCount = ValueAnimator.INFINITE
                    anim.start()
                    bounce = anim
                }
            }
        }
    }
}
