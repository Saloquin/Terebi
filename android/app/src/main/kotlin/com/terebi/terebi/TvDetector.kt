package com.terebi.terebi

import android.content.Context
import android.content.res.Configuration
import android.app.UiModeManager

object TvDetector {
    fun isTelevision(context: Context): Boolean {
        val mgr = context.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return mgr.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }
}
