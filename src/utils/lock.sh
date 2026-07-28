#!/bin/ash

lock() {
  local lock_dir

  case "$1" in
    ""|/*|*/|*//*|*[!a-z0-9_/-]*) error "Invalid lock name '$1'" ;;
  esac

  lock_dir="/tmp/$1.lock"

  if ! mkdir -p "$lock_dir" 2>/dev/null; then
    log "${2:-$1 is already running}"
    return 1
  fi

  trap 'rm -rf "$lock_dir"' EXIT INT TERM
}
