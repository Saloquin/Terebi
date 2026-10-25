package com.terebi.terebi

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration

object TvDetector {
    fun isTelevision(context: Context): Boolean {
        return try {
            val mgr = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            if (mgr?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
                return true
            }
            val pm = context.packageManager
            if (pm.hasSystemFeature(PackageManager.FEATURE_LEANBACK)) {
                return true
            }
            if (pm.hasSystemFeature(PackageManager.FEATURE_TELEVISION)) {
                return true
            }
            false
        } catch (_: Exception) {
            false
        }
    }
}
