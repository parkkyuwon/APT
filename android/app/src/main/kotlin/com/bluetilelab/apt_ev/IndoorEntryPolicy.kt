package com.bluetilelab.apt_ev

/** Monotonic times only; a stopped observer can never manufacture signal loss. */
class IndoorEntryPolicy {
    private var evidence: Long? = null
    private var degraded: Long? = null
    private var notified = false
    fun arm(now: Long) { evidence = now; degraded = null; notified = false }
    fun refresh(now: Long) { evidence = now }
    fun evaluate(now: Long, observing: Boolean, poor: Boolean): Boolean {
        val entered = evidence
        if (!observing || entered == null || now < entered || now - entered > 1_200_000) {
            degraded = null; return false
        }
        if (!poor) { degraded = null; return false }
        val start = degraded ?: now.also { degraded = it }
        if (now < start) { degraded = null; return false }
        if (!notified && now - start >= 30_000) { notified = true; return true }
        return false
    }
}
