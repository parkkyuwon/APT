package com.bluetilelab.apt_ev

import android.app.*
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.*
import com.google.android.gms.location.*
import org.json.JSONObject

/** Bounded native session, independent of Flutter. Never restored after process death. */
class IndoorLocationService : Service() {
    private lateinit var monitor: IndoorLocationMonitor
    private val fused by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val handler = Handler(Looper.getMainLooper())
    private val policy = IndoorEntryPolicy()
    private var observing = false
    private var configuration: String? = null
    private var started = 0L
    private var lastGood = 0L
    private var outsideSince: Long? = null
    private var outsideCount = 0
    private val callback = object : LocationCallback() {
        override fun onLocationAvailability(availability: LocationAvailability) {
            // Availability alone is not proof of GPS loss. Only active requests feed policy.
        }
        override fun onLocationResult(result: LocationResult) {
            for (location in result.locations) accept(location)
        }
    }
    private fun accept(location: Location) {
        if (configuration != monitor.prefs.getString("config", null)) { stopSelf(); return }
        val now = SystemClock.elapsedRealtime()
        val age = now - location.elapsedRealtimeNanos / 1_000_000
        if (age !in 0..15000 || !location.hasAccuracy() || location.accuracy < 0) return
        val config = JSONObject(monitor.prefs.getString("config", "{}")!!)
        val distance = FloatArray(1)
        Location.distanceBetween(location.latitude, location.longitude, config.getDouble("latitude"), config.getDouble("longitude"), distance)
        if (location.accuracy <= 30) {
            lastGood = now
            policy.evaluate(now, observing, false)
            if (distance[0] + location.accuracy <= config.getDouble("radiusMeters")) {
                monitor.prefs.edit().putLong("evidence", now).apply(); policy.refresh(now)
            }
            if (distance[0] - location.accuracy > config.getDouble("radiusMeters") + 50) {
                if (outsideSince == null) outsideSince = now
                outsideCount++
                if (outsideCount >= 2 && now - outsideSince!! >= 10000) {
                    monitor.prefs.edit().remove("visit").remove("evidence").remove("entry").putBoolean("notified", false).commit()
                    getSystemService(NotificationManager::class.java).cancel(IndoorLocationMonitor.NOTIFICATION)
                    stopSelf(); return
                }
            } else { outsideSince = null; outsideCount = 0 }
        }
    }
    private val tick = object : Runnable {
        override fun run() {
            val now = SystemClock.elapsedRealtime()
            val enabled = monitor.prefs.getBoolean("enabled", false) && configuration == monitor.prefs.getString("config", null)
            if (!enabled || now - started >= 1_200_000 || !monitor.locationAllowed() || !monitor.backgroundAllowed() || !monitor.locationEnabled()) {
                stopSelf(); return
            }
            val evidence = monitor.prefs.getLong("evidence", -1)
            if (evidence < 0 || now < evidence || now - evidence > 1_200_000) { stopSelf(); return }
            if (policy.evaluate(now, observing, now - lastGood >= 15000) && !monitor.prefs.getBoolean("notified", false) && monitor.notificationAllowed()) notifyEntry()
            handler.postDelayed(this, 1000)
        }
    }
    override fun onCreate() {
        super.onCreate(); monitor = IndoorLocationMonitor(this)
    }
    @Suppress("MissingPermission")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (observing) return START_NOT_STICKY
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("indoor_observation", "실내 위치 안내", NotificationManager.IMPORTANCE_LOW))
            manager.createNotificationChannel(NotificationChannel(IndoorLocationMonitor.CHANNEL, "실내 위치 안내", NotificationManager.IMPORTANCE_HIGH))
        }
        try {
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "indoor_observation") else Notification.Builder(this)
            startForeground(28401, builder.setSmallIcon(R.drawable.ic_stat_departure).setContentTitle("주변 위치를 확인하고 있습니다")
                .setContentText("실내 위치 안내를 위한 최대 20분 관찰").setOngoing(true).build())
            if (!monitor.locationAllowed() || !monitor.backgroundAllowed() || !monitor.prefs.getBoolean("enabled", false)) { stopSelf(); return START_NOT_STICKY }
            configuration = monitor.prefs.getString("config", null)
            started = SystemClock.elapsedRealtime(); lastGood = started
            val evidence = monitor.prefs.getLong("evidence", -1)
            if (evidence < 0 || started < evidence || started - evidence > 1_200_000) { stopSelf(); return START_NOT_STICKY }
            policy.arm(evidence)
            fused.requestLocationUpdates(LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000).setMinUpdateIntervalMillis(2000).build(), callback, Looper.getMainLooper())
                .addOnSuccessListener { observing = true; handler.post(tick) }
                .addOnFailureListener { monitor.prefs.edit().putString("reason", "observationUnavailable").apply(); stopSelf() }
        } catch (_: RuntimeException) {
            monitor.prefs.edit().putString("reason", "observationStartRestricted").apply()
            monitor.offerObservation(); stopSelf()
        }
        return START_NOT_STICKY
    }
    private fun notifyEntry() {
        val config = JSONObject(monitor.prefs.getString("config", "{}")!!)
        val payload = JSONObject().put("type", "indoorEntry").put("version", 1).put("siteId", "home")
            .put("visitId", monitor.prefs.getString("visit", "")).put("areaRevision", config.getLong("revision"))
            .put("accountScope", config.getString("accountScope")).toString()
        val intent = Intent(this, MainActivity::class.java).putExtra("indoorEntry", payload).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val tap = PendingIntent.getActivity(this, 28402, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, IndoorLocationMonitor.CHANNEL) else Notification.Builder(this)
        try {
            getSystemService(NotificationManager::class.java).notify(IndoorLocationMonitor.NOTIFICATION,
                builder.setSmallIcon(R.drawable.ic_stat_departure).setContentTitle("실내 위치 안내")
                    .setContentText("실내 지도를 열어 위치를 확인하세요").setVisibility(Notification.VISIBILITY_PRIVATE)
                    .setContentIntent(tap).setAutoCancel(true).build())
            monitor.prefs.edit().putBoolean("notified", true).commit()
        } catch (_: SecurityException) { monitor.prefs.edit().putString("reason", "notificationPermissionRequired").apply() }
    }
    override fun onDestroy() {
        observing = false; handler.removeCallbacksAndMessages(null); fused.removeLocationUpdates(callback)
        super.onDestroy()
    }
    override fun onBind(intent: Intent?): IBinder? = null
}
