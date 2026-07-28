#!/bin/ash

import core/dnsproxy/run

dnsproxy_keepalive() {
  local mode pid

  mode="$(global dnsproxy_mode)"
  pid="$(global dnsproxy_pid)"

  [ -z "$mode" ] && return 0
  [ -n "$pid" ] && \
    kill -0 "$pid" 2>/dev/null && \
    return 0

  global dnsproxy_pid ""

  ( error "dnsproxy exited unexpectedly" )
  dnsproxy_run "$mode"
}
