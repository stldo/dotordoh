#!/bin/ash

require uci

uci_replace_list() {
  local changed=0 found=0 key="$1" line prefix="$2" replacement="$3" value

  for line in $(uci -q show "$key" 2>/dev/null || true); do
    value="${line#*=}"
    value="${value#\'}"
    value="${value%\'}"

    case "$value" in
      "$prefix"*)
        if [ "$value" = "$replacement" ] && [ "$found" -eq 0 ]; then
          found=1
        else
          uci -q del_list "$key=$value"
          changed=1
        fi
        ;;
    esac
  done

  if [ "$found" -eq 0 ]; then
    uci add_list "$key=$replacement"
    changed=1
  fi

  return $((1 - changed))
}
