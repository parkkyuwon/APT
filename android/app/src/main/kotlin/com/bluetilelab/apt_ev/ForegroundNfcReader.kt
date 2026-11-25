package com.bluetilelab.apt_ev

import android.app.Activity
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Handler
import android.os.Build
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Read-only, foreground-only NDEF. No tag IDs or payloads are logged. */
class ForegroundNfcReader(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "apt_ev/foreground_nfc")
    private val handler = Handler(Looper.getMainLooper())
    private val adapter: NfcAdapter? = try {
        NfcAdapter.getDefaultAdapter(activity)
    } catch (_: RuntimeException) { null }
    private var requested = false
    private var resumed = false
    @Volatile private var generation = 0
    @Volatile private var reading = false
    private val tagLock = Any()
    private var presentTag: ByteArray? = null
    private var scanSequence = 0L

    init {
        suppressDispatchedTag(activity.intent)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    requested = true
                    enable()
                    result.success(adapter?.isEnabled == true)
                }
                "stop" -> {
                    requested = false
                    disable()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** A cold/warm OS NFC link already goes through Flutter navigation once. */
    @Suppress("DEPRECATION")
    fun suppressDispatchedTag(intent: Intent) {
        val tag = try {
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
            } else {
                intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)
            }
        } catch (_: RuntimeException) { null } ?: return
        synchronized(tagLock) { presentTag = tag.id.copyOf() }
        // If seeding removal detection fails, keep the suppression. A later
        // reader callback can retry ignore, but cannot toggle the OS action.
        ignoreUntilRemoved(tag)
    }

    private fun ignoreUntilRemoved(tag: Tag): Boolean {
        val tagId = tag.id.copyOf()
        return try {
            adapter?.ignore(tag, 750, {
                synchronized(tagLock) {
                    if (presentTag?.contentEquals(tagId) == true) presentTag = null
                }
            }, handler) == true
        } catch (_: RuntimeException) { false }
    }

    fun resume() {
        resumed = true
        enable()
    }

    fun pause() {
        resumed = false
        disable()
    }

    fun dispose() {
        requested = false
        disable()
        channel.setMethodCallHandler(null)
    }

    private fun enable() {
        if (!requested || !resumed || reading || adapter?.isEnabled != true) return
        val epoch = ++generation
        try {
            reading = true
            adapter.enableReaderMode(activity, { tag -> read(tag, epoch) },
                NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
                    NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V,
                null)
        } catch (_: RuntimeException) {
            reading = false
        }
    }

    private fun disable() {
        generation++
        reading = false
        try {
            adapter?.disableReaderMode(activity)
        } catch (_: RuntimeException) {
            // Hardware/service may disappear while the activity is pausing.
        }
    }

    private fun read(tag: Tag, epoch: Int) {
        if (!reading || epoch != generation) return
        val tagId = tag.id.copyOf()
        val duplicate = synchronized(tagLock) {
            if (presentTag?.contentEquals(tagId) == true) true else {
            presentTag = tagId
                false
            }
        }
        if (duplicate) {
            ignoreUntilRemoved(tag)
            return
        }
        try {
            val message = try { Ndef.get(tag)?.cachedNdefMessage } catch (_: Exception) { null }
            val uri = if (message != null && message.toByteArray().size <= 4096) {
                message.records.mapNotNull { it.toUri()?.toString() }.singleOrNull()
            } else null
            // Keep the tag suppressed for its entire presence, not just a timer.
            val ignored = ignoreUntilRemoved(tag)
            if (!ignored) {
                synchronized(tagLock) {
                    if (presentTag?.contentEquals(tagId) == true) presentTag = null
                }
                return
            }
            if (uri == null) return
            handler.post {
                if (reading && epoch == generation) {
                    scanSequence++
                    channel.invokeMethod("tag", mapOf("scanId" to scanSequence, "uri" to uri))
                }
            }
        } catch (_: Exception) {
            // Tag loss, malformed NDEF, or a service failure cannot register parking.
            if (!ignoreUntilRemoved(tag)) {
                synchronized(tagLock) {
                    if (presentTag?.contentEquals(tagId) == true) presentTag = null
                }
            }
        }
    }
}
