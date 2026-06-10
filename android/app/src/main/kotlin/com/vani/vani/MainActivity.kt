package com.vani.vani

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.provider.ContactsContract
import androidx.core.content.IntentCompat

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.vani/app_actions"
        const val EXTRA_AUTO_LISTEN = "auto_listen"

        // One-shot flag: set when VANI is opened via the QS tile,
        // cleared the moment Dart consumes it.
        @Volatile
        var autoListenPending = false

        // One-shot share payload from ShareTargetAlias (Labs, default OFF),
        // cleared the moment Dart consumes it.
        @Volatile
        var pendingShare: Map<String, Any?>? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readAutoListenExtra(intent)
        readShareExtras(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readAutoListenExtra(intent)
        readShareExtras(intent)
    }

    private fun readAutoListenExtra(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_AUTO_LISTEN, false) == true) {
            autoListenPending = true
        }
    }

    /** Stashes an incoming ACTION_SEND(_MULTIPLE) payload for Dart to consume. */
    private fun readShareExtras(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND &&
            intent.action != Intent.ACTION_SEND_MULTIPLE) return

        val uris = mutableListOf<String>()
        if (intent.action == Intent.ACTION_SEND) {
            IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                ?.let { uris.add(it.toString()) }
        } else {
            IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                ?.forEach { uris.add(it.toString()) }
        }

        pendingShare = mapOf(
            "mimeType" to (intent.type ?: ""),
            "text"     to (intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""),
            "subject"  to (intent.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""),
            "uris"     to uris,
        )
    }

    private val shareAlias: ComponentName
        get() = ComponentName(this, "$packageName.ShareTargetAlias")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "setPendingAction" -> {
                    val action = call.argument<String>("action")
                    val data = call.argument<String>("data")
                    VaniAccessibilityService.pendingAction = action
                    VaniAccessibilityService.pendingData = data
                    result.success(true)
                }
                "consumeAutoListen" -> {
                    val pending = autoListenPending
                    autoListenPending = false
                    result.success(pending)
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(isPackageInstalled(packageName))
                }
                "getInstalledApps" -> {
                    result.success(InstalledAppsScanner.scan(this))
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    if (intent != null) {
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "launchUrlInPackage" -> {
                    val url = call.argument<String>("url") ?: ""
                    val pkg = call.argument<String>("package") ?: ""
                    try {
                        val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url))
                        intent.setPackage(pkg)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Package can't handle this URL → let Dart fall back.
                        result.success(false)
                    }
                }
                "getContacts" -> {
                    result.success(getContacts())
                }
                "consumeSharePayload" -> {
                    val payload = pendingShare
                    pendingShare = null
                    result.success(payload)
                }
                "setShareTargetEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        packageManager.setComponentEnabledSetting(
                            shareAlias,
                            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            PackageManager.DONT_KILL_APP
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isShareTargetEnabled" -> {
                    val state = packageManager.getComponentEnabledSetting(shareAlias)
                    result.success(state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED)
                }
                "forwardShareToPackage" -> {
                    val pkg  = call.argument<String>("package") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    val mime = call.argument<String>("mimeType") ?: ""
                    val uris = call.argument<List<String>>("uris") ?: emptyList()
                    result.success(forwardShare(pkg, text, mime, uris))
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    try {
                        startActivity(Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ))
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "startBubble" -> {
                    if (Settings.canDrawOverlays(this)) {
                        startForegroundService(Intent(this, VaniBubbleService::class.java))
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopBubble" -> {
                    stopService(Intent(this, VaniBubbleService::class.java))
                    result.success(true)
                }
                "isBubbleRunning" -> {
                    result.success(VaniBubbleService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Re-shares received content into [pkg] (a draft/picker in the target
     * app — the user always taps send there, VANI never auto-sends).
     * FLAG_GRANT_READ_URI_PERMISSION passes our temporary read grant along;
     * whether every provider honors that re-grant is device-verified
     * (docs/future-device-checklist.md).
     */
    private fun forwardShare(
        pkg: String, text: String, mime: String, uriStrings: List<String>
    ): Boolean {
        if (pkg.isEmpty()) return false
        return try {
            val uris = uriStrings.map { Uri.parse(it) }
            val fwd = Intent(
                if (uris.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND
            ).apply {
                setPackage(pkg)
                type = mime.ifEmpty { if (uris.isEmpty()) "text/plain" else "*/*" }
                if (text.isNotEmpty()) putExtra(Intent.EXTRA_TEXT, text)
                if (uris.size == 1) putExtra(Intent.EXTRA_STREAM, uris[0])
                if (uris.size > 1) putParcelableArrayListExtra(
                    Intent.EXTRA_STREAM, ArrayList(uris))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(fwd)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getContacts(): List<Map<String, String>> {
        val contacts = mutableListOf<Map<String, String>>()
        try {
            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null, null, null
            )
            cursor?.use {
                val nameIdx = it.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = it.getColumnIndex(
                    ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (it.moveToNext()) {
                    val name = if (nameIdx >= 0) it.getString(nameIdx) ?: "" else ""
                    val number = if (numIdx >= 0) it.getString(numIdx) ?: "" else ""
                    if (name.isNotEmpty() && number.isNotEmpty()) {
                        contacts.add(mapOf("name" to name, "number" to number))
                    }
                }
            }
        } catch (e: Exception) {
            // Permission not granted or query failed → return empty list.
        }
        return contacts
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val expectedService = "${packageName}/" +
            "${VaniAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(":")
            .any { it.equals(expectedService, ignoreCase = true) }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }
}