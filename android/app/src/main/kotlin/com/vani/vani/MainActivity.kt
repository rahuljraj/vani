package com.vani.vani

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.provider.ContactsContract

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.vani/app_actions"
        const val EXTRA_AUTO_LISTEN = "auto_listen"

        // One-shot flag: set when VANI is opened via the QS tile,
        // cleared the moment Dart consumes it.
        @Volatile
        var autoListenPending = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        readAutoListenExtra(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readAutoListenExtra(intent)
    }

    private fun readAutoListenExtra(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_AUTO_LISTEN, false) == true) {
            autoListenPending = true
        }
    }

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
                else -> result.notImplemented()
            }
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