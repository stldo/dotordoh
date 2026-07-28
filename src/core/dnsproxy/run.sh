#!/bin/ash

import utils/kill_wait
import utils/list_to_args

require dnsproxy
require sleep

global dnsproxy_mode ""
global dnsproxy_pid ""

dnsproxy_run() {
  local args current_mode mode next_pid pid upstream

  args="\
    --listen 127.0.0.1 \
    --port $DNSPROXY_PORT \
    --cache \
    --cache-size $DNSPROXY_CACHE_SIZE \
    --pending-requests-enabled \
    $(list_to_args "$DNSPROXY_BOOTSTRAP" "--bootstrap")
  "

  mode=$1

  case "$mode" in
    dot) upstream="tls://$DOT_DOMAIN" ;;
    doh) upstream="https://$DOH_DOMAIN$DOH_PATH" ;;
    *) return 1 ;;
  esac

  current_mode="$(global dnsproxy_mode)"
  pid="$(global dnsproxy_pid)"

  if [ "$2" = exec ]; then
    exec dnsproxy $args --upstream "$upstream"
  elif [ "$current_mode" = "$mode" ] &&
    [ -n "$pid" ] &&
    kill -0 "$pid" 2>/dev/null
  then
    return 0
  fi

  if [ -z "$current_mode" ] || [ -z "$pid" ] ; then
    log "Starting dnsproxy in $mode mode..."
  elif [ "$current_mode" = "$mode" ]; then
    log "Restarting dnsproxy in $mode mode..."
  else
    log "Switching dnsproxy from $current_mode to $mode..."
  fi

  kill_wait "$pid"

  global dnsproxy_mode ""
  global dnsproxy_pid ""

  dnsproxy $args --upstream "$upstream" &

  next_pid="$!"

  sleep 1

  kill -0 "$next_pid" 2>/dev/null || {
    ( error "Failed to start dnsproxy" )
    return 1
  }

  log "dnsproxy listening in \"$mode\" mode"

  global dnsproxy_mode "$mode"
  global dnsproxy_pid "$next_pid"
}
