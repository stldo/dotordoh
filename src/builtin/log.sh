#!/bin/ash

log() {
  local level

  if [ "$#" -ge 2 ]; then
    level="$1"
    shift
  else
    level="INFO"
  fi

  logger -t "dotordoh" "$level $*"
  printf '%s %s [dotordoh] %s\n' "$(date '+%Y/%m/%d %H:%M:%S       ')" "$level" "$*"
}
