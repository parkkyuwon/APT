package com.bluetilelab.apt_ev
import org.junit.Assert.*
import org.junit.Test
class IndoorEntryPolicyTest {
 @Test fun requiresRecentEvidenceAndActiveObservation() {
  val p = IndoorEntryPolicy()
  assertFalse(p.evaluate(0, false, true))
  p.arm(0)
  assertFalse(p.evaluate(30000, false, true))
  assertFalse(p.evaluate(60000, true, true))
  assertTrue(p.evaluate(90000, true, true))
  assertFalse(p.evaluate(120000, true, true))
 }
 @Test fun recoversAndExpires() {
  val p = IndoorEntryPolicy(); p.arm(0)
  assertFalse(p.evaluate(0, true, true))
  assertFalse(p.evaluate(29000, true, true))
  assertFalse(p.evaluate(30000, true, false))
  assertFalse(p.evaluate(31000, true, true))
  assertTrue(p.evaluate(61000, true, true))
  val expired = IndoorEntryPolicy(); expired.arm(0)
  assertFalse(expired.evaluate(1200001, true, true))
  assertFalse(expired.evaluate(1230001, true, true))
 }
}
