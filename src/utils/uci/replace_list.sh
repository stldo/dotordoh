#!/bin/ash

require uci

uci_replace_list() {
  local found=0 key="$1" matches=0 prefix="$2" replacement="$3" snapshot value

  snapshot=$(uci -q show "$key" 2>/dev/null || true)

  eval "set -- ${snapshot#*=}"

  for value in "$@"; do
    case "$value" in
      "$prefix"*)
        matches=$((matches + 1))
        [ "$value" != "$replacement" ] || found=1
        ;;
    esac
  done

  [ "$matches" -ne 1 ] || [ "$found" -ne 1 ] || return 1

  if [ -n "$snapshot" ]; then
    uci -q delete "$key" || error "Failed to delete $key"
  fi

  for value in "$@"; do
    case "$value" in
      "$prefix"*) ;;
      *) uci add_list "$key=$value" || error "Failed to update $key" ;;
    esac
  done

  uci add_list "$key=$replacement" || error "Failed to update $key"
  return 0
}
