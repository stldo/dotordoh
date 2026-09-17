#!/bin/ash

import core/shield/configure
import utils/parse_options
import utils/service/powerup
import utils/uci/exists

require chmod
require cp
require dirname
require id
require ifup
require jsonfilter
require mkdir
require mv
require rm
require sleep
require ubus

parse_options

[ "$(id -u)" -eq 0 ] || error "Install must run as root"

APP_BIN="/usr/bin/dotordoh"
INIT_BIN="/etc/init.d/dotordoh"
RESTORE_RUNNING_INIT=0
SOURCE_BIN="$0"
TMP_APP_BIN="$APP_BIN.$$"
TMP_INIT_BIN="$INIT_BIN.$$"

case "$SOURCE_BIN" in
  */*)
    ;;
  *)
    SOURCE_BIN="$(command -v "$SOURCE_BIN")" ||
      error "Cannot locate the running command"
    ;;
esac

restore_service() {
  local status=$?

  rm -f "$TMP_APP_BIN" "$TMP_INIT_BIN" 2>/dev/null || true

  if [ "$status" -ne 0 ] && [ "$RESTORE_RUNNING_INIT" -eq 1 ]; then
    "$INIT_BIN" start >/dev/null 2>&1 || true
  fi

  exit "$status"
}

trap restore_service EXIT

mkdir -p "$(dirname "$APP_BIN")"

cp "$SOURCE_BIN" "$TMP_APP_BIN"
chmod +x "$TMP_APP_BIN"

mkdir -p "$(dirname "$INIT_BIN")"

{
  printf '%s\n' '#!/bin/sh /etc/rc.common'

  printf '\n%s\n' 'USE_PROCD=1'
  printf '%s\n' 'START=99'
  printf '%s\n' 'STOP=01'

  printf '\n%s\n' 'start_service() {'
  printf '  %s\n' 'procd_open_instance main'

  printf '\n  %s\n' 'procd_set_param command "/usr/bin/dotordoh" monitor'

  printf '\n  %s\n' 'procd_set_param respawn 3600 5 5'
  printf '  %s\n' 'procd_set_param term_timeout 5'
  printf '  %s\n' 'procd_set_param stderr 1'

  printf '\n  %s\n' 'procd_close_instance'

  printf '\n%s\n' '}'

  printf '\n%s\n' 'service_started() {'
  printf '  %s\n' '"/usr/bin/dotordoh" shield -w'
  printf '%s\n' '}'

  printf '\n%s\n' 'reload_service() {'
  printf '  %s\n' 'procd_send_signal dotordoh main HUP 2>/dev/null || true'
  printf '  %s\n' '"/usr/bin/dotordoh" shield -w'
  printf '%s\n' '}'

  printf '\n%s\n' 'restart() {'
  printf '  %s\n' "trap '' TERM"
  printf '  %s\n' 'stop "$@"'
  printf '  %s\n' 'trap - TERM'
  printf '  %s\n' 'sleep 10'
  printf '  %s\n' 'start "$@"'
  printf '%s\n' '}'

  printf '\n%s\n' 'service_triggers() {'
  printf '  %s\n' 'procd_open_trigger'

  for interface in $WAN_INTERFACES; do
    printf '  %s\n' "procd_add_reload_interface_trigger \"$interface\""
  done

  printf '  %s\n' 'procd_close_trigger'
  printf '%s\n' '}'

  printf '\n%s\n' 'service_stopped() {'
  printf '  %s\n' 'service https-dns-proxy stop 2>/dev/null'
  printf '  %s\n' 'service https-dns-proxy disable 2>/dev/null'
  printf '  %s\n' 'service stubby stop 2>/dev/null'
  printf '  %s\n' 'service stubby disable 2>/dev/null'
  printf '%s\n' '}'
} > "$TMP_INIT_BIN"

chmod +x "$TMP_INIT_BIN"

if [ -x "$INIT_BIN" ] && "$INIT_BIN" running >/dev/null 2>&1; then
  RESTORE_RUNNING_INIT=1

  "$INIT_BIN" stop || true

  remaining=10

  while "$INIT_BIN" running >/dev/null 2>&1 && [ "$remaining" -gt 0 ]; do
    sleep 1
    remaining=$((remaining - 1))
  done

  if "$INIT_BIN" running >/dev/null 2>&1; then
    error "Failed to stop dotordoh service"
  fi
fi

mv "$TMP_APP_BIN" "$APP_BIN"
mv "$TMP_INIT_BIN" "$INIT_BIN"

shield_configure

for interface in $WAN_INTERFACES; do
  uci_exists "network.$interface" || continue

  interface_is_up=$(
    ubus call "network.interface.$interface" status 2>/dev/null |
      jsonfilter -e '@.up'
  )

  [ "$interface_is_up" = "true" ] || continue

  log "Refreshing wan interface \"$interface\"..."

  if ! ifup "$interface" >/dev/null 2>&1; then
    ( log "WARN" "Failed to bring up \"$interface\"" )
  fi
done

service_powerup dotordoh
