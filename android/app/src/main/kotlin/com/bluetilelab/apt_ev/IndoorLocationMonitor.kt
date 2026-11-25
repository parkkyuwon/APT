package com.bluetilelab.apt_ev

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.*
import android.provider.Settings
import android.net.Uri
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.*
import com.google.android.gms.tasks.CancellationTokenSource
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.UUID
import java.security.MessageDigest

/** Private preferences are excluded from backup by the application manifest. */
class IndoorLocationMonitor(private val context: Context) {
    private var permissionResult: MethodChannel.Result? = null
    val prefs = context.getSharedPreferences("indoor_location", Context.MODE_PRIVATE)
    private val geofences get() = LocationServices.getGeofencingClient(context)
    private val pending get() = PendingIntent.getBroadcast(context, 28401,
        Intent(context, IndoorGeofenceReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0))
    fun allowed(permission: String) = context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    fun locationAllowed() = allowed(Manifest.permission.ACCESS_FINE_LOCATION)
    fun locationEnabled(): Boolean {
        val manager = context.getSystemService(LocationManager::class.java)
        return if (Build.VERSION.SDK_INT >= 28) manager.isLocationEnabled else
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER) || manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }
    fun backgroundAllowed() = Build.VERSION.SDK_INT < 29 || allowed(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    fun notificationAllowed(): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = if (Build.VERSION.SDK_INT >= 26) manager.getNotificationChannel(CHANNEL) else null
        return manager.areNotificationsEnabled() && (channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE) &&
            (Build.VERSION.SDK_INT < 33 || allowed(Manifest.permission.POST_NOTIFICATIONS))
    }
    fun fenceId(): String {
        val bytes = prefs.getString("config", "")!!.toByteArray(Charsets.UTF_8)
        return "home:" + MessageDigest.getInstance("SHA-256").digest(bytes).take(12).joinToString("") { "%02x".format(it) }
    }
    fun supported() = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context) == 0
    fun status(): Map<String, Any> {
        val enabled = prefs.getBoolean("enabled", false)
        val location = locationAllowed() && locationEnabled()
        if (enabled && (!locationAllowed() || !backgroundAllowed())) {
            // OS permission revocation can discard a registered fence. Re-register after a grant.
            prefs.edit().putString("reason", "authorizationChanged").apply()
        }
        val reason = when {
            !enabled -> "disabled"
            !supported() -> "googlePlayServicesUnavailable"
            !location -> "locationUnavailable"
            !backgroundAllowed() -> "backgroundPermissionRequired"
            !notificationAllowed() -> "notificationPermissionRequired"
            else -> prefs.getString("reason", "notRegistered")!!
        }
        return mapOf("supported" to supported(), "monitoring" to (enabled && location && backgroundAllowed() && reason == "monitoring"),
            "reason" to reason, "notificationAllowed" to notificationAllowed(), "locationAllowed" to location,
            "backgroundAllowed" to backgroundAllowed())
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                val args = call.arguments as? Map<*, *> ?: return result.error("invalid", "Configuration required", null)
                val lat = (args["latitude"] as? Number)?.toDouble()
                val lon = (args["longitude"] as? Number)?.toDouble()
                val radius = (args["radiusMeters"] as? Number)?.toFloat()
                val scope = args["accountScope"] as? String
                val revision = (args["revision"] as? Number)?.toLong()
                if (lat == null || !lat.isFinite() || lat !in -90.0..90.0 || lon == null || !lon.isFinite() || lon !in -180.0..180.0 ||
                    radius == null || !radius.isFinite() || radius !in 100f..1000f || scope.isNullOrBlank() || revision == null || args["siteId"] != "home") {
                    return result.error("invalid", "Invalid home area", null)
                }
                val config = JSONObject().put("latitude", lat).put("longitude", lon).put("radiusMeters", radius)
                    .put("accountScope", scope).put("revision", revision).put("siteId", "home").toString()
                if (prefs.getString("config", null) == config && prefs.getBoolean("enabled", false) && args["enabled"] == true) {
                    if (prefs.getString("reason", null) == "monitoring") result.success(status())
                    else register { result.success(status()) }
                    return
                }
                disable()
                prefs.edit().putString("config", config).putBoolean("enabled", args["enabled"] == true).commit()
                register { result.success(status()) }
            }
            "disable" -> {
                val requestedScope = (call.arguments as? Map<*, *>)?.get("accountScope") as? String
                val activeScope = prefs.getString("config", null)?.let { JSONObject(it).optString("accountScope") }
                if (requestedScope == null || requestedScope == activeScope) disable()
                result.success(status())
            }
            "status" -> result.success(status())
            "openSettings" -> {
                val target = (call.arguments as? Map<*, *>)?.get("target") as? String
                val details = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${context.packageName}"))
                val intent = when (target) {
                    "locationServices" -> Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
                    "notifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    "location", "background" -> details
                    else -> { result.error("invalid", "Unknown settings target", null); return }
                }
                try {
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    try {
                        context.startActivity(details.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (_: ActivityNotFoundException) { result.success(false) }
                }
            }
            "consumeEntry" -> {
                val value = prefs.getString("entry", null)?.let { JSONObject(it) }
                val config = prefs.getString("config", null)?.let { JSONObject(it) }
                prefs.edit().remove("entry").commit()
                result.success(if (value != null && config != null && value.optString("accountScope") == config.optString("accountScope") &&
                    value.optLong("areaRevision") == config.optLong("revision") && value.optString("visitId") == prefs.getString("visit", null)) jsonMap(value) else null)
            }
            "currentLocation" -> currentLocation(result)
            "requestPermissions" -> {
                val activity = context as? Activity
                if (activity == null) { result.error("unavailable", "Foreground activity required", null); return }
                if (permissionResult != null) { result.error("busy", "Permission request in progress", null); return }
                val permissions = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                if (Build.VERSION.SDK_INT >= 33) permissions.add(Manifest.permission.POST_NOTIFICATIONS)
                val missing = permissions.filter { !allowed(it) }.toTypedArray()
                if (missing.isEmpty()) { result.success(status()); return }
                permissionResult = result
                activity.requestPermissions(missing, 28401)
            }
            "startObservation" -> { startObservation(); result.success(status()) }
            "requestBackgroundPermission" -> result.success(status()) // Android 11+: explicit settings UI via permission_handler.
            else -> result.notImplemented()
        }
    }
    fun permissionResponse(requestCode: Int) {
        if (requestCode != 28401) return
        val result = permissionResult ?: return
        permissionResult = null
        result.success(status())
    }
    fun dispose() {
        permissionResult?.error("cancelled", "Activity detached", null)
        permissionResult = null
    }
    @Suppress("MissingPermission")
    fun register(done: () -> Unit = {}) {
        if (!prefs.getBoolean("enabled", false) || !supported() || !locationAllowed() || !backgroundAllowed()) { done(); return }
        val config = JSONObject(prefs.getString("config", "{}")!!)
        val fence = Geofence.Builder().setRequestId(fenceId()).setCircularRegion(config.getDouble("latitude"), config.getDouble("longitude"), config.getDouble("radiusMeters").toFloat())
            .setExpirationDuration(Geofence.NEVER_EXPIRE).setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT).build()
        geofences.removeGeofences(pending).addOnCompleteListener {
            if (!prefs.getBoolean("enabled", false) || prefs.getString("config", null) != config.toString()) { done(); return@addOnCompleteListener }
            geofences.addGeofences(GeofencingRequest.Builder().setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER).addGeofence(fence).build(), pending)
                .addOnSuccessListener {
                    if (prefs.getBoolean("enabled", false) && prefs.getString("config", null) == config.toString()) prefs.edit().putString("reason", "monitoring").apply()
                    done()
                }
                .addOnFailureListener {
                    if (prefs.getString("config", null) == config.toString()) prefs.edit().putString("reason", "registrationFailed").apply()
                    done()
                }
        }
    }
    fun disable() {
        prefs.edit().clear().putString("reason", "disabled").commit()
        if (supported()) geofences.removeGeofences(pending)
        context.stopService(Intent(context, IndoorLocationService::class.java))
        context.getSystemService(NotificationManager::class.java).cancel(NOTIFICATION)
        context.getSystemService(NotificationManager::class.java).cancel(28403)
    }
    fun entered() {
        if (!prefs.getBoolean("enabled", false)) return
        // Repeated ENTERs do not create a new visit; only confirmed outdoor locations do.
        if (!prefs.contains("visit")) prefs.edit().putString("visit", UUID.randomUUID().toString()).putBoolean("notified", false).commit()
        prefs.edit().putLong("evidence", SystemClock.elapsedRealtime()).commit()
        startObservation()
    }
    private fun startObservation() {
        val evidence = prefs.getLong("evidence", -1)
        val now = SystemClock.elapsedRealtime()
        if (!prefs.getBoolean("enabled", false) || evidence < 0 || now < evidence || now - evidence > 1_200_000) return
        try {
            val intent = Intent(context, IndoorLocationService::class.java)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        } catch (_: RuntimeException) {
            prefs.edit().putString("reason", "observationStartRestricted").apply()
            offerObservation()
        }
    }
    fun offerObservation() {
        if (!notificationAllowed()) return
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "Indoor location", NotificationManager.IMPORTANCE_HIGH))
        val tap = PendingIntent.getActivity(context, 28403, Intent(context, MainActivity::class.java).putExtra("indoorObserve", true),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        manager.notify(28403, builder.setSmallIcon(R.drawable.ic_stat_departure).setContentTitle("Home area nearby")
            .setContentText("Tap to start indoor location observation").setContentIntent(tap).setAutoCancel(true).build())
    }
    fun recordTap(intent: Intent?) {
        if (intent?.getBooleanExtra("indoorObserve", false) == true) {
            intent.removeExtra("indoorObserve"); startObservation()
        }
        val payload = intent?.getStringExtra("indoorEntry") ?: return
        intent.removeExtra("indoorEntry")
        val config = prefs.getString("config", null)?.let(::JSONObject) ?: return
        val entry = runCatching { JSONObject(payload) }.getOrNull() ?: return
        if (prefs.getBoolean("enabled", false) && entry.optString("accountScope") == config.optString("accountScope") &&
            entry.optLong("areaRevision") == config.optLong("revision") && entry.optString("visitId") == prefs.getString("visit", null)) {
            prefs.edit().putString("entry", payload).commit()
        }
    }
    @Suppress("MissingPermission")
    private fun currentLocation(result: MethodChannel.Result) {
        if (!locationAllowed()) { result.error("permission", "Precise location permission required", null); return }
        val token = CancellationTokenSource()
        var completed = false
        val handler = Handler(Looper.getMainLooper())
        val timeout = Runnable { if (!completed) { completed = true; token.cancel(); result.error("timeout", "No fresh location", null) } }
        handler.postDelayed(timeout, 15000)
        LocationServices.getFusedLocationProviderClient(context).getCurrentLocation(
            CurrentLocationRequest.Builder().setPriority(Priority.PRIORITY_HIGH_ACCURACY).setMaxUpdateAgeMillis(0).setDurationMillis(15000).build(), token.token)
            .addOnCompleteListener { task ->
                if (!completed) {
                    completed = true; handler.removeCallbacks(timeout)
                    val loc = if (task.isSuccessful) task.result else null
                    if (loc == null) result.error("unavailable", "Current location unavailable", null)
                    else result.success(mapOf("latitude" to loc.latitude, "longitude" to loc.longitude, "accuracy" to loc.accuracy.toDouble(), "timestamp" to loc.time))
                }
            }
    }
    companion object {
        const val CHANNEL = "indoor_entry"
        const val NOTIFICATION = 28402
        fun jsonMap(json: JSONObject): Map<String, Any> = json.keys().asSequence().associateWith { json.get(it) }
    }
}
