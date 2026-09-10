#!/bin/ash

import core/monitor/is_dot
import core/monitor/run
import utils/has_upstream_reachability
import utils/lock
import utils/service/shutdown

require sleep

lock dotordoh/monitor "monitor mode is already running" || exit 0

CLEANING_UP=0
SLEEP_PID=""

on_network_change() {
  local attempt

  [ -n "$SLEEP_PID" ] && kill "$SLEEP_PID" 2>/dev/null

  attempt=1

  while [ "$attempt" -le "$MONITOR_REACHABILITY_ATTEMPTS" ]; do
    if has_upstream_reachability; then
      if monitor_is_dot; then
        monitor_run dot || monitor_run doh
      else
        monitor_run doh
      fi

      return $?
    fi

    if [ "$attempt" -lt "$MONITOR_REACHABILITY_ATTEMPTS" ]; then
      sleep "$MONITOR_REACHABILITY_DELAY"
    fi

    attempt=$((attempt + 1))
  done

  ( error "Upstream is unreachable" )
  return 1
}

service_cleanup() {
  [ -n "$SLEEP_PID" ] && kill "$SLEEP_PID" 2>/dev/null
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
trap on_network_change HUP

service_cleanup 0
on_network_change

while true; do
  sleep 3600 &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null || true
done
