#!/bin/ash

import core/shield/configure
import core/shield/verify
import utils/get_ipv4
import utils/get_ula
import utils/local_server_is_ready
import utils/lock

require sleep

lock dotordoh/shield "shield is already running" || exit 0

REMAINING=30

if [ "${ARG_WAIT:-0}" -eq 1 ]; then
  while ! local_server_is_ready; do
    REMAINING=$((REMAINING - 1))
    [ "$REMAINING" -gt 0 ] || error "monitor is not ready"
    sleep 1
  done
fi

state lan_ipv4 "$(get_ipv4)"
state lan_ula "$(get_ula)"

shield_configure "$ARG_BOOT"
shield_verify
