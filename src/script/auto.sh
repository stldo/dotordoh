#!/bin/ash

import core/dnsproxy/keepalive
import core/dnsproxy/run
import core/dnsproxy/should_use_dot
import utils/lock

require killall
require sleep

# - Probe DoT connectivity and switch between DoT and DoH accordingly.
# - RETRIES tracks consecutive probe results:
#     * Positive values = consecutive DoT successes.
#     * Negative values = consecutive DoT failures.
# - Three consecutive successes/failures are required before switching
#   dnsproxy, avoiding mode changes due to transient network issues.
# - The absolute RETRIES value is converted into a CONFIDENCE level.
#   As confidence increases, probes become less frequent, reducing
#   unnecessary network activity while the connection is stable.
# - Any opposite probe result immediately resets the streak, causing
#   probes to become frequent again until stability is re-established.

lock dotordoh/auto "auto mode is already running" || exit 0

killall dnsproxy 2>/dev/null || true

CONFIDENCE=1
RETRIES=0

MAX_RETRIES=$((
  $DNSPROXY_AUTO_CONFIDENCE_FACTOR *
  $DNSPROXY_AUTO_MAX_CONFIDENCE
))

trap 'kill_wait "$(global dnsproxy_pid)"; exit 130' INT TERM
trap 'kill_wait "$(global dnsproxy_pid)"' EXIT
trap 'CONFIDENCE=1; RETRIES=0' HUP

while true; do
  dnsproxy_keepalive

  if dnsproxy_should_use_dot "$CONFIDENCE"; then
    [ "$RETRIES" -lt 1 ] && RETRIES=0
    RETRIES=$((RETRIES + 1))

    if [ "$RETRIES" -eq "$DNSPROXY_AUTO_RETRIES" ]; then
      dnsproxy_run dot
    fi
  else
    [ "$RETRIES" -gt -1 ] && RETRIES=0
    RETRIES=$((RETRIES - 1))

    if [ "$RETRIES" -eq $(($DNSPROXY_AUTO_RETRIES * -1)) ]; then
      dnsproxy_run doh
    fi
  fi

  if [ "$RETRIES" -gt "$MAX_RETRIES" ]; then
    RETRIES=$MAX_RETRIES
  elif [ "$RETRIES" -lt "$((-MAX_RETRIES))" ]; then
    RETRIES=$((-MAX_RETRIES))
  fi

  ABS_RETRIES=${RETRIES#-}
  DIVIDEND=$((ABS_RETRIES + $DNSPROXY_AUTO_CONFIDENCE_FACTOR - 1))
  CONFIDENCE=$((DIVIDEND / $DNSPROXY_AUTO_CONFIDENCE_FACTOR))

  if [ "$ABS_RETRIES" -ge "$DNSPROXY_AUTO_RETRIES" ]; then
    sleep "$((CONFIDENCE * $DNSPROXY_AUTO_SLEEP_FACTOR))" & wait $!
  else
    sleep 1 & wait $!
  fi
done
