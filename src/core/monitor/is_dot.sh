#!/bin/ash

require nc

monitor_is_dot() {
  local ip

  for ip in $BOOTSTRAP_SERVER; do
    if nc -z -w1 "$ip" 853 >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}
