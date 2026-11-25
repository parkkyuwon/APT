package com.bluetilelab.apt_ev
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
class IndoorBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val monitor = IndoorLocationMonitor(context)
        monitor.prefs.edit().remove("evidence").remove("entry").putString("reason", "notRegistered").commit()
        val pending = goAsync()
        monitor.register { pending.finish() }
    }
}
