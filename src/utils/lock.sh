#!/bin/ash

require dirname
require flock
require mkdir

lock() {
  local lock_file

  case "$1" in
    ""|/*|*/|*//*|*[!a-z0-9_/-]*) error "Invalid lock name \"$1\"" ;;
  esac

  lock_file="/var/lock/$1.lock"

  mkdir -p "$(dirname "$lock_file")" 2>/dev/null \
    || error "Cannot create lock dir"

  exec 9>"$lock_file" || error "Cannot open lock file \"$lock_file\""

  if ! flock -n 9; then
    if [ $# -eq 1 ]; then
      log "\"$1\" is already running"
    elif [ -n "$2" ]; then # Only log if argument $2 is not empty
      log "$2"
    fi
    return 1
  fi
}
