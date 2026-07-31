#!/bin/ash

import core/monitor/find_mode
import core/monitor/run
import utils/lock
import utils/service/shutdown

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
NO_UPSTREAM=0
RETRIES=0

MAX_RETRIES=$((
  $MONITOR_CONFIDENCE_FACTOR *
  $MONITOR_MAX_CONFIDENCE
))

service_cleanup() {
  [ "${1:-$CLEANING_UP}" -eq 1 ] && return
  [ "${1:-1}" -ne 0 ] && CLEANING_UP=1

  service_shutdown https-dns-proxy
  service_shutdown stubby
}

service_terminate() {
  service_cleanup
  exit 0
}

trap service_cleanup EXIT
trap service_terminate INT TERM
trap 'CONFIDENCE=1; RETRIES=0' HUP

service_cleanup 0

while true; do
  case $(find_mode) in
    doh)
      [ "$RETRIES" -gt -1 ] && RETRIES=0
      RETRIES=$((RETRIES - 1))

      [ "$RETRIES" -eq "-$MONITOR_RETRIES" ] && monitor_run doh
      ;;

    dot)
      [ "$RETRIES" -lt 1 ] && RETRIES=0
      RETRIES=$((RETRIES + 1))

      [ "$RETRIES" -eq "$MONITOR_RETRIES" ] && monitor_run dot
      ;;

    *)
      [ "$NO_UPSTREAM" -eq 0 ] && log "Upstream is unavailable"
      NO_UPSTREAM=1

      sleep 1

      continue
      ;;
  esac

  [ "$NO_UPSTREAM" -eq 1 ] && log "Upstream is available"
  NO_UPSTREAM=0

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
