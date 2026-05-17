package com.vani.vani

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo

object InstalledAppsScanner {

    /**
     * Returns all user-installed apps (excludes system apps).
     * Each entry: { packageName, displayName, hasLaunchIntent }
     */
    fun scan(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps
            .filter { info ->
                // Skip system apps — only user-installed
                (info.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            }
            .filter { info ->
                // Must have a launch intent (skip background-only apps)
                pm.getLaunchIntentForPackage(info.packageName) != null
            }
            .map { info ->
                mapOf(
                    "packageName" to info.packageName,
                    "displayName" to pm.getApplicationLabel(info).toString(),
                    "hasLaunchIntent" to true
                )
            }
            .sortedBy { it["displayName"] as String }
    }
}