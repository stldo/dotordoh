#!/bin/ash

import utils/kill_wait

require sleep

timeout() {
  local duration elapsed pid

  duration="$1"
  case "$duration" in ''|*[!0-9]*) error "Invalid duration '$duration'" ;; esac
  shift

  [ "$#" -eq 0 ] && return 1

  elapsed=0
  "$@" &
  pid=$!

  while [ "$elapsed" -lt "$duration" ]; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
    elapsed=$((elapsed + 1))
  done

  # duration=0 means no timeout (matches GNU timeout convention)
  if [ "$duration" -ne 0 ] && kill -0 "$pid" 2>/dev/null; then
    kill_wait "$pid" 1
    return 124
  fi

  wait "$pid"
}
