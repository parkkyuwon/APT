package com.bluetilelab.apt_ev
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
class IndoorGeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        val monitor = IndoorLocationMonitor(context)
        if (event.hasError()) { monitor.prefs.edit().putString("reason", "geofenceUnavailable").apply(); return }
        if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER && event.triggeringGeofences?.any { it.requestId == monitor.fenceId() } == true) monitor.entered()
        // An uncertain EXIT never resets a visit. Accurate outdoor observations do.
    }
}
