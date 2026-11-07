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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "penta/device")
            .setMethodCallHandler { call, result ->
                try {
                    result.success(handle(call))
                } catch (e: Exception) {
                    result.error("PENTA", e.message, null)
                }
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
            "camera" -> launch(Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA))
            "gallery" -> launch(Intent(Intent.ACTION_VIEW).setType("image/*"))
            "openUrl" -> launch(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url") ?: "")))
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
