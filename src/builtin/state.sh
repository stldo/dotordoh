#!/bin/ash

state() {
  case "$1" in
    *[!a-zA-Z0-9_]*) error "Invalid characters in key \"$1\"" >&2 ;;
  esac

  if [ "$#" -eq 1 ]; then
    eval "echo \"\$__STATE_$1\""
  else
    eval "__STATE_$1=\"\$2\""
  fi
}
