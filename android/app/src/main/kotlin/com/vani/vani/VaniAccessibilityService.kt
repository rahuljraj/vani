package com.vani.vani

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class VaniAccessibilityService : AccessibilityService() {

    companion object {
        var instance: VaniAccessibilityService? = null

        // Pending action set by Flutter
        var pendingAction: String? = null
        var pendingData: String? = null

        // Debug-only screen-reading probe (never registered in release builds).
        // Trigger while the target app is in the foreground:
        //   adb shell am broadcast -a com.vani.vani.DEBUG_DUMP_TREE -p com.vani.vani
        // Read the dump:
        //   adb logcat -s VANI-PROBE
        const val ACTION_DEBUG_DUMP_TREE = "com.vani.vani.DEBUG_DUMP_TREE"

        // Supported app package names
        const val PKG_BLINKIT   = "com.blinkit.consumer"
        const val PKG_SWIGGY    = "in.swiggy.android"
        const val PKG_ZOMATO    = "com.application.zomato"
        const val PKG_WHATSAPP  = "com.whatsapp"
        const val PKG_YOUTUBE   = "com.google.android.youtube"
        const val PKG_AMAZON    = "in.amazon.mShop.android.shopping"
        const val PKG_FLIPKART  = "com.flipkart.android"
    }

    private val debugDumpReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            debugDumpNodeTree()
        }
    }

    override fun onServiceConnected() {
        instance = this
        android.util.Log.d("VANI", "✅ Accessibility Service Connected")

        if (BuildConfig.DEBUG) {
            val filter = IntentFilter(ACTION_DEBUG_DUMP_TREE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(debugDumpReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(debugDumpReceiver, filter)
            }
            android.util.Log.d("VANI", "🔎 Debug dump receiver registered ($ACTION_DEBUG_DUMP_TREE)")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // Only act on window state changes
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val action = pendingAction ?: return
        val data   = pendingData   ?: return
        val pkg    = event.packageName?.toString() ?: return

        android.util.Log.d("VANI", "Event: pkg=$pkg action=$action data=$data")

        when {
            // ── Blinkit ──────────────────────────
            pkg == PKG_BLINKIT && action == "blinkit_search" -> {
                android.os.Handler(mainLooper).postDelayed({
                    rootInActiveWindow?.let { performSearch(it, data) }
                    clearPending()
                }, 1200)
            }

            // ── Swiggy ───────────────────────────
            pkg == PKG_SWIGGY && action == "swiggy_search" -> {
                android.os.Handler(mainLooper).postDelayed({
                    rootInActiveWindow?.let { performSearch(it, data) }
                    clearPending()
                }, 1200)
            }

            // ── Zomato ───────────────────────────
            pkg == PKG_ZOMATO && action == "zomato_search" -> {
                android.os.Handler(mainLooper).postDelayed({
                    rootInActiveWindow?.let { performSearch(it, data) }
                    clearPending()
                }, 1200)
            }

            // ── WhatsApp ─────────────────────────
            pkg == PKG_WHATSAPP && action == "whatsapp_open" -> {
                android.util.Log.d("VANI", "WhatsApp opened for: $data")
                clearPending()
            }

            // ── YouTube ──────────────────────────
            pkg == PKG_YOUTUBE && action == "youtube_search" -> {
                android.os.Handler(mainLooper).postDelayed({
                    rootInActiveWindow?.let { performSearch(it, data) }
                    clearPending()
                }, 1500)
            }
        }
    }

    // ── Core Search Function ─────────────────────
    private fun performSearch(root: AccessibilityNodeInfo, query: String) {
        val searchField = findSearchField(root)

        if (searchField != null) {
            searchField.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            // Delay setText so the field is focused before we write into it
            android.os.Handler(mainLooper).postDelayed({
                val args = Bundle()
                args.putString(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    query
                )
                searchField.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
                android.util.Log.d("VANI", "✅ Searched: $query")
            }, 300)
        } else {
            android.util.Log.w("VANI", "❌ Search field not found")
        }
    }

    // ── Find Search Field ────────────────────────
    private fun findSearchField(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        // Strategy 1: EditText fields
        val editTexts = findByClassName(root, "android.widget.EditText")
        if (editTexts.isNotEmpty()) return editTexts.first()

        // Strategy 2: Search hint text
        for (hint in listOf("Search", "search", "खोजें", "खोजे")) {
            val nodes = root.findAccessibilityNodeInfosByText(hint)
            if (nodes.isNotEmpty()) return nodes.first()
        }

        // Strategy 3: ViewId containing "search"
        return findByViewIdContaining(root, "search")
    }

    // ── Helper: Find by class name ───────────────
    private fun findByClassName(
        node: AccessibilityNodeInfo,
        className: String
    ): List<AccessibilityNodeInfo> {
        val results = mutableListOf<AccessibilityNodeInfo>()
        if (node.className?.toString() == className) {
            results.add(node)
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let {
                results.addAll(findByClassName(it, className))
            }
        }
        return results
    }

    // ── Helper: Find by view ID ──────────────────
    private fun findByViewIdContaining(
        node: AccessibilityNodeInfo,
        idPart: String
    ): AccessibilityNodeInfo? {
        val viewId = node.viewIdResourceName ?: ""
        if (viewId.contains(idPart, ignoreCase = true)) return node

        for (i in 0 until node.childCount) {
            val result = node.getChild(i)?.let {
                findByViewIdContaining(it, idPart)
            }
            if (result != null) return result
        }
        return null
    }

    private fun clearPending() {
        pendingAction = null
        pendingData   = null
    }

    // ── Debug: Screen-Reading Probe ──────────────
    // Walks the current window's node tree and logs every node so we can
    // verify (via logcat) whether target apps expose restaurant names,
    // ratings, etc. as readable accessibility nodes.
    private fun debugDumpNodeTree() {
        if (!BuildConfig.DEBUG) return
        val root = rootInActiveWindow
        if (root == null) {
            android.util.Log.w("VANI-PROBE", "🔎 dump requested but rootInActiveWindow is null")
            return
        }
        android.util.Log.d(
            "VANI-PROBE",
            "🔎 ===== DUMP START pkg=${root.packageName} ====="
        )
        val count = debugDumpNode(root, 0, 0)
        android.util.Log.d("VANI-PROBE", "🔎 ===== DUMP END ($count nodes) =====")
    }

    private fun debugDumpNode(node: AccessibilityNodeInfo, depth: Int, index: Int): Int {
        val indent = ".".repeat(depth)
        android.util.Log.d(
            "VANI-PROBE",
            "🔎 $indent[$depth:$index] class=${node.className} " +
                "text=\"${node.text}\" desc=\"${node.contentDescription}\" " +
                "id=${node.viewIdResourceName}"
        )
        var count = 1
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { count += debugDumpNode(it, depth + 1, i) }
        }
        return count
    }

    override fun onInterrupt() {
        android.util.Log.d("VANI", "Accessibility Service Interrupted")
    }

    override fun onDestroy() {
        if (BuildConfig.DEBUG) {
            try {
                unregisterReceiver(debugDumpReceiver)
            } catch (_: IllegalArgumentException) {
                // Receiver was never registered (service died before connect).
            }
        }
        instance = null
        super.onDestroy()
    }
}
