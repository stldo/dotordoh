#!/bin/ash

import utils/uci/get

require awk
require ip
require sleep

get_ula() {
  local attempt lan_device result

  lan_device="$(uci_get "network.${LAN_INTERFACE}.device")"
  [ -n "$lan_device" ] || error "No LAN device found"

  attempt=0
  result=

  while [ -z "$result" ] && [ "$attempt" -lt 10 ]; do
    result="$(
      ip -6 addr show dev "$lan_device" \
      | awk '$1=="inet6" && $2 ~ /^fd/{sub(/\/.*/,"",$2);print $2;exit}'
    )"

    if [ -z "$result" ]; then
      attempt=$((attempt + 1))
      sleep 1
    fi
  done

  [ -n "$result" ] || error "No LAN ULA found"

  printf '%s\n' "$result"
}
