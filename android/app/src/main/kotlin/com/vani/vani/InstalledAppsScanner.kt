package com.vani.vani

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo

object InstalledAppsScanner {

    fun scan(context: Context): List<Map<String, Any>> {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps
            .filter { info ->
                (info.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                (info.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
            }
            .filter { info ->
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