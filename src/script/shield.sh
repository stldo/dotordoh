#!/bin/ash

import core/shield/configure
import core/shield/verify
import utils/get_ipv4
import utils/get_ula
import utils/lock
import utils/timeout

require nslookup
require sleep

lock dotordoh/shield "shield is already running" || exit 0

DNS_SERVER="127.0.0.1:$LOCAL_PORT"
REMAINING=30

if [ "${ARG_WAIT:-0}" -eq 1 ]; then
  while ! timeout 1 nslookup localhost "$DNS_SERVER" >/dev/null 2>&1; do
    REMAINING=$((REMAINING - 1))
    [ "$REMAINING" -gt 0 ] || error "monitor is not ready"
    sleep 1
  done
fi

state lan_ipv4 "$(get_ipv4)"
state lan_ula "$(get_ula)"

shield_configure "$ARG_BOOT"
shield_verify
