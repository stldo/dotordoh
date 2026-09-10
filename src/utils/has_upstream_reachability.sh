#!/bin/ash

require nc

has_upstream_reachability() {
  local ip

  log "Detecting upstream reachability..."

  for ip in $BOOTSTRAP_SERVER; do
    if nc -z -w1 "$ip" 53 >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}
