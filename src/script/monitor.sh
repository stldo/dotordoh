#!/bin/ash

import core/monitor/dot_is_available
import core/monitor/run
import utils/lock

require sleep

# - Probe DoT connectivity and switch between DoT and DoH accordingly.
# - RETRIES tracks consecutive probe results:
#     * Positive values = consecutive DoT successes.
#     * Negative values = consecutive DoT failures.
# - Three consecutive successes/failures are required before switching mode,
#   avoiding mode changes due to transient network issues.
# - The absolute RETRIES value is converted into a CONFIDENCE level. As
#   confidence increases, probes become less frequent, reducing unnecessary
#   network activity while the connection is stable.
# - Any opposite probe result immediately resets the streak, causing probes to
#   become frequent again until stability is re-established.

lock dotordoh/monitor "monitor mode is already running" || exit 0

CLEANING_UP=0
CONFIDENCE=1
RETRIES=0

MAX_RETRIES=$((
  $MONITOR_CONFIDENCE_FACTOR *
  $MONITOR_MAX_CONFIDENCE
))

monitor_cleanup() {
  [ "$CLEANING_UP" -eq 1 ] && return

  CLEANING_UP=1

  service https-dns-proxy stop 2>/dev/null
  service stubby stop 2>/dev/null
  service https-dns-proxy disable 2>/dev/null
  service stubby disable 2>/dev/null
}

monitor_terminate() {
  monitor_cleanup
  exit 0
}

trap monitor_cleanup EXIT
trap monitor_terminate INT TERM
trap 'CONFIDENCE=1; RETRIES=0' HUP

while true; do
  if monitor_dot_is_available "$CONFIDENCE"; then
    [ "$RETRIES" -lt 1 ] && RETRIES=0
    RETRIES=$((RETRIES + 1))

    if [ "$RETRIES" -eq "$MONITOR_RETRIES" ]; then
      monitor_run dot
    fi
  else
    [ "$RETRIES" -gt -1 ] && RETRIES=0
    RETRIES=$((RETRIES - 1))

    if [ "$RETRIES" -eq $(($MONITOR_RETRIES * -1)) ]; then
      monitor_run doh
    fi
  fi

  if [ "$RETRIES" -gt "$MAX_RETRIES" ]; then
    RETRIES=$MAX_RETRIES
  elif [ "$RETRIES" -lt "$((-MAX_RETRIES))" ]; then
    RETRIES=$((-MAX_RETRIES))
  fi

  ABS_RETRIES=${RETRIES#-}
  DIVIDEND=$((ABS_RETRIES + $MONITOR_CONFIDENCE_FACTOR - 1))
  CONFIDENCE=$((DIVIDEND / $MONITOR_CONFIDENCE_FACTOR))

  if [ "$ABS_RETRIES" -ge "$MONITOR_RETRIES" ]; then
    sleep "$((CONFIDENCE * $MONITOR_SLEEP_FACTOR))" & wait $!
  else
    sleep 1 & wait $!
  fi
done
