#!/bin/ash

require nc

find_mode() {
  local ip

  for ip in $BOOTSTRAP_SERVER; do
    if nc -z -w1 "$ip" 853 >/dev/null 2>&1; then
      printf '%s' "dot"
      return 0
    fi

    if nc -z -w1 "$ip" 443 >/dev/null 2>&1; then
      printf '%s' doh
      return 0
    fi
  done

  return 1
}
