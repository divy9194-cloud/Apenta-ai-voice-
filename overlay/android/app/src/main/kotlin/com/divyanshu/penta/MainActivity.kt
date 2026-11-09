package com.divyanshu.penta

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.AlarmClock
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var assistRequested = false
    private val ui = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.getBooleanExtra("penta_listen", false) == true) {
            assistRequested = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("penta_listen", false)) {
            assistRequested = true
        }
    }

    // The floating Penta box appears when you leave the app (Home, recents, or opening another app).
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        PentaExtras.onLeave(this)
    }

    override fun onPause() {
        super.onPause()
        PentaExtras.onPause()
    }

    override fun onResume() {
        super.onResume()
        PentaExtras.onResume(this)
    }

    // The photo picker and similar screens should not trigger the floating box.
    override fun startActivityForResult(intent: Intent, requestCode: Int, options: Bundle?) {
        if (requestCode != 4242) {
            PentaExtras.suppressUntil = System.currentTimeMillis() + 90000L
        }
        super.startActivityForResult(intent, requestCode, options)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        PentaExtras.onResult(this, requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "penta/device")
        PentaExtras.channel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                if (PentaExtras.handle(this, call, result)) return@setMethodCallHandler
                when (call.method) {
                    "typeText" -> typeText(call.argument<String>("text") ?: "", result)
                    "pressSearch" -> pressSearch(result)
                    "saveToGallery" -> result.success(saveToGallery(call.argument<String>("path") ?: ""))
                    "searchInOpenApp" -> searchInOpenApp(call.argument<String>("query") ?: "", result)
                    "scroll" -> inOtherApp(result) { svc -> svc.scroll(call.argument<Boolean>("forward") != false) }
                    "tapText" -> inOtherApp(result) { svc -> svc.clickByText(call.argument<String>("text") ?: "") }
                    "readScreen" -> inOtherApp(result) { svc -> svc.screenText() }
                    else -> result.success(handle(call))
                }
            } catch (e: Exception) {
                result.error("PENTA", e.message, null)
            }
        }
    }

    // Steps back to the previous app, then runs the action on that app's screen.
    private fun inOtherApp(result: MethodChannel.Result, block: (ScreenshotService) -> Any?) {
        val svc = ScreenshotService.instance
        if (svc == null) {
            result.success("no_service")
            return
        }
        moveTaskToBack(true)
        ui.postDelayed({
            try {
                result.success(block(svc))
            } catch (e: Exception) {
                result.success(false)
            }
        }, 800)
    }

    // Steps back to the previous app, then types into its focused text box.
    private fun typeText(text: String, result: MethodChannel.Result) {
        val svc = ScreenshotService.instance
        if (svc == null) {
            result.success("no_service")
            return
        }
        moveTaskToBack(true)
        ui.postDelayed({
            val ok = svc.typeIntoFocused(text)
            result.success(if (ok) "ok" else "no_field")
        }, 900)
    }

    private fun pressSearch(result: MethodChannel.Result) {
        val svc = ScreenshotService.instance
        if (svc == null) {
            result.success("no_service")
            return
        }
        moveTaskToBack(true)
        ui.postDelayed({
            result.success(if (svc.pressSearch()) "ok" else "failed")
        }, 900)
    }

    // The app is already launching. Wait, open its search box, type, and press search.
    private fun searchInOpenApp(query: String, result: MethodChannel.Result) {
        val svc = ScreenshotService.instance
        if (svc == null) {
            result.success("no_service")
            return
        }
        ui.postDelayed({
            if (!svc.openSearchBox()) {
                result.success("no_search_box")
                return@postDelayed
            }
            ui.postDelayed({
                if (!svc.typeIntoFocused(query)) {
                    result.success("no_field")
                    return@postDelayed
                }
                ui.postDelayed({
                    svc.pressSearch()
                    result.success("ok")
                }, 500)
            }, 800)
        }, 1800)
    }

    // Copies a photo into the phone Gallery.
    private fun saveToGallery(path: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            val url = MediaStore.Images.Media.insertImage(
                contentResolver, path, "Penta ${System.currentTimeMillis()}", "Photo made with Penta"
            )
            url != null
        } catch (e: Exception) {
            false
        }
    }

    // Sends a picture to another app (for example Canva). The photo is also saved to the Gallery.
    private fun shareImage(path: String, pkg: String): Boolean {
        return try {
            @Suppress("DEPRECATION")
            val url = MediaStore.Images.Media.insertImage(
                contentResolver, path, "Penta ${System.currentTimeMillis()}", "Photo edited with Penta"
            ) ?: return false
            val uri = Uri.parse(url)
            val send = Intent(Intent.ACTION_SEND)
            send.type = "image/*"
            send.putExtra(Intent.EXTRA_STREAM, uri)
            send.setPackage(pkg)
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
            PentaExtras.suppressUntil = System.currentTimeMillis() + 90000L
            startActivity(send)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun launch(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun launchableApps(): List<Pair<String, String>> {
        val query = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return packageManager.queryIntentActivities(query, 0)
            .map { it.loadLabel(packageManager).toString() to it.activityInfo.packageName }
            .distinctBy { it.second }
            .sortedBy { it.first.lowercase() }
    }

    private fun findContact(query: String): Map<String, String>? {
        val needle = query.lowercase().trim()
        val uri = ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        val cols = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        var best: Map<String, String>? = null
        var bestScore = 0
        contentResolver.query(uri, cols, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(0) ?: continue
                val number = cursor.getString(1) ?: continue
                val n = name.lowercase()
                val score = if (n == needle) 3 else if (n.startsWith(needle)) 2 else if (n.contains(needle)) 1 else 0
                if (score > bestScore) {
                    bestScore = score
                    best = mapOf("name" to name, "number" to number)
                }
            }
        }
        return best
    }

    private fun handle(call: MethodCall): Any? {
        return when (call.method) {
            "torch" -> {
                val cm = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                val id = cm.cameraIdList.first {
                    cm.getCameraCharacteristics(it).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                }
                cm.setTorchMode(id, call.argument<Boolean>("on") == true)
                true
            }
            "canWriteSettings" -> Settings.System.canWrite(this)
            "askWriteSettings" -> launch(
                Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS, Uri.parse("package:$packageName"))
            )
            "getBrightness" ->
                Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128) * 100 / 255
            "setBrightness" -> {
                if (!Settings.System.canWrite(this)) {
                    false
                } else {
                    val percent = (call.argument<Int>("percent") ?: 50).coerceIn(1, 100)
                    Settings.System.putInt(
                        contentResolver,
                        Settings.System.SCREEN_BRIGHTNESS_MODE,
                        Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                    )
                    Settings.System.putInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, percent * 255 / 100)
                    true
                }
            }
            "openApp" -> {
                val q = (call.argument<String>("name") ?: "").lowercase().trim()
                val apps = launchableApps()
                val hit = apps.firstOrNull { it.first.lowercase() == q }
                    ?: apps.filter { it.first.lowercase().startsWith(q) }.minByOrNull { it.first.length }
                    ?: apps.filter { it.first.lowercase().contains(q) }.minByOrNull { it.first.length }
                val intent = hit?.let { packageManager.getLaunchIntentForPackage(it.second) }
                if (intent == null) false else launch(intent)
            }
            "appNames" -> launchableApps().map { it.first }
            "findContact" -> findContact(call.argument<String>("query") ?: "")
            "dial" -> launch(
                Intent(Intent.ACTION_CALL, Uri.fromParts("tel", call.argument<String>("number") ?: "", null))
            )
            "alarm" -> launch(
                Intent(AlarmClock.ACTION_SET_ALARM)
                    .putExtra(AlarmClock.EXTRA_HOUR, call.argument<Int>("hour") ?: 7)
                    .putExtra(AlarmClock.EXTRA_MINUTES, call.argument<Int>("minute") ?: 0)
                    .putExtra(AlarmClock.EXTRA_MESSAGE, "Penta alarm")
                    .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            )
            "timer" -> launch(
                Intent(AlarmClock.ACTION_SET_TIMER)
                    .putExtra(AlarmClock.EXTRA_LENGTH, call.argument<Int>("seconds") ?: 60)
                    .putExtra(AlarmClock.EXTRA_MESSAGE, call.argument<String>("message") ?: "Penta timer")
                    .putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            )
            "settingsPage" -> {
                val action = when (call.argument<String>("page")) {
                    "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
                    "wifi" -> Settings.ACTION_WIFI_SETTINGS
                    else -> Settings.ACTION_SETTINGS
                }
                launch(Intent(action))
            }
            "battery" -> {
                val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            }
            "mediaKey" -> {
                val code = call.argument<Int>("code") ?: KeyEvent.KEYCODE_MEDIA_PLAY
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
                true
            }
            "volume" -> {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                when (call.argument<String>("action")) {
                    "up" -> repeat(3) {
                        am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                    }
                    "down" -> repeat(3) {
                        am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                    }
                    "mute" -> am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_MUTE, AudioManager.FLAG_SHOW_UI)
                    "unmute" -> am.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_UNMUTE, AudioManager.FLAG_SHOW_UI)
                    "set" -> {
                        val percent = (call.argument<Int>("percent") ?: 50).coerceIn(0, 100)
                        am.setStreamVolume(AudioManager.STREAM_MUSIC, percent * max / 100, AudioManager.FLAG_SHOW_UI)
                    }
                }
                am.getStreamVolume(AudioManager.STREAM_MUSIC) * 100 / max
            }
            "muteBeeps" -> {
                val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val on = call.argument<Boolean>("on") == true
                val media = call.argument<Boolean>("media") == true
                val direction = if (on) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE
                val streams = mutableListOf(AudioManager.STREAM_NOTIFICATION, AudioManager.STREAM_SYSTEM)
                if (media) streams.add(AudioManager.STREAM_MUSIC)
                var any = false
                for (s in streams) {
                    try {
                        am.adjustStreamVolume(s, direction, 0)
                        any = true
                    } catch (e: Exception) {
                    }
                }
                any
            }
            "closeApp" -> {
                moveTaskToBack(true)
                true
            }
            "openBatterySettings" -> launch(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            "camera" -> launch(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA))
            "gallery" -> launch(Intent(Intent.ACTION_VIEW).setType("image/*"))
            "openUrl" -> launch(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url") ?: "")))
            "shareImage" -> shareImage(call.argument<String>("path") ?: "", call.argument<String>("package") ?: "")
            "screenshotReady" -> ScreenshotService.instance != null
            "askScreenshotAccess" -> launch(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            "screenshot" -> {
                val svc = ScreenshotService.instance
                if (svc == null || Build.VERSION.SDK_INT < 28) {
                    false
                } else {
                    svc.performGlobalAction(AccessibilityService.GLOBAL_ACTION_TAKE_SCREENSHOT)
                }
            }
            "lockScreen" -> {
                val svc = ScreenshotService.instance
                if (svc == null) false else svc.lockScreen()
            }
            "globalAction" -> {
                val svc = ScreenshotService.instance
                if (svc == null) {
                    false
                } else {
                    val code = when (call.argument<String>("name")) {
                        "home" -> AccessibilityService.GLOBAL_ACTION_HOME
                        "back" -> AccessibilityService.GLOBAL_ACTION_BACK
                        "recents" -> AccessibilityService.GLOBAL_ACTION_RECENTS
                        "notifications" -> AccessibilityService.GLOBAL_ACTION_NOTIFICATIONS
                        "quick" -> AccessibilityService.GLOBAL_ACTION_QUICK_SETTINGS
                        "power" -> AccessibilityService.GLOBAL_ACTION_POWER_DIALOG
                        else -> -1
                    }
                    if (code < 0) false else svc.performGlobalAction(code)
                }
            }
            "consumeAssistLaunch" -> {
                val requested = assistRequested
                assistRequested = false
                requested
            }
            "openAssistantSettings" -> {
                var ok = false
                val actions = listOf(
                    Settings.ACTION_VOICE_INPUT_SETTINGS,
                    Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS,
                    Settings.ACTION_SETTINGS
                )
                for (action in actions) {
                    if (!ok) ok = launch(Intent(action))
                }
                ok
            }
            "startListen" -> {
                val i = Intent(this, MicService::class.java)
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                true
            }
            "stopListen" -> {
                stopService(Intent(this, MicService::class.java))
                true
            }
            else -> throw IllegalArgumentException("Unknown method ${call.method}")
        }
    }
}
