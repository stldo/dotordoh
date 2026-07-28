#!/bin/ash

require sleep

kill_wait() {
  local pid remaining_time wait_time

  pid=$1

  [ -z "$pid" ] && return 0

  wait_time=${2:-5}
  case "$wait_time" in ''|*[!0-9]*) wait_time=5 ;; esac

  if kill -0 "$pid" 2>/dev/null; then
    remaining_time="$wait_time"
    kill -TERM "$pid" 2>/dev/null
    while [ "$remaining_time" -gt 0 ]; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
      remaining_time=$((remaining_time - 1))
    done
  fi

  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null
  fi

  remaining_time="$wait_time"

  while [ "$remaining_time" -gt 0 ] && kill -0 "$pid" 2>/dev/null; do
    sleep 1
    remaining_time=$((remaining_time - 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    ( error "PID '$pid' still alive after kill_wait" )
    return 1
  fi

  wait "$pid" 2>/dev/null
  return 0
}
