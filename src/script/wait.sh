#!/bin/ash

import utils/timeout

require nslookup
require sleep

DNS_SERVER="127.0.0.1:$DNSPROXY_PORT"
REMAINING=30

while ! timeout 1 nslookup localhost "$DNS_SERVER" >/dev/null 2>&1; do
  REMAINING=$((REMAINING - 1))
  [ "$REMAINING" -gt 0 ] || error "dnsproxy did not become ready"
  sleep 1
done
