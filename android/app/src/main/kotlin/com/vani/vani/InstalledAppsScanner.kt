package com.vani.vani

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

object InstalledAppsScanner {
    // Queries launchable activities rather than enumerating every installed
    // package. QUERY_ALL_PACKAGES is a Play-restricted permission and the
    // old getInstalledApplications() call discarded everything without a
    // launch intent anyway — this asks for exactly the set VANI can act on.
    fun scan(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager

        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolved = pm.queryIntentActivities(intent, 0)

        return resolved
            .filter { it.activityInfo.packageName != context.packageName }
            .map { ri ->
                mapOf(
                    "packageName"     to ri.activityInfo.packageName,
                    "displayName"     to ri.loadLabel(pm).toString(),
                    "hasLaunchIntent" to true
                )
            }
            .distinctBy { it["packageName"] as String }
            .sortedBy { it["displayName"] as String }
    }
}