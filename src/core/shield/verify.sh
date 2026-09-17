#!/bin/ash

import utils/local_server_is_ready
import utils/timeout
import utils/uci/exists
import utils/uci/get

require nslookup

shield_verify() {
  local dns_options success uci_dhcp_key

  success=1
  uci_dhcp_key="dhcp.${LAN_INTERFACE}"

  assert() {
    if [ "$1" -eq 0 ]; then
      log "PASS" "$2"
    else
      log "FAIL" "$2"
      success=0
    fi
  }

  log "Checking shield configuration..."

  dns_options=$(
    options=$(uci -q show "${uci_dhcp_key}.dhcp_option" 2>/dev/null || true)

    eval "set -- ${options#*=}"
    for option in "$@"; do
      case "$option" in
        6,*) printf '%s\n' "$option" ;;
      esac
    done
  )

  for interface in $WAN_INTERFACES; do
    uci_exists "network.$interface" || continue
    [ "$(uci_get "network.$interface.peerdns")" = "0" ]
    assert $? "network.$interface.peerdns PeerDNS disabled"
  done

  [ "$dns_options" = "6,$(state lan_ipv4)" ]
  assert $? "DHCPv4 advertises router DNS"

  [ "$(uci_get "${uci_dhcp_key}.dhcpv6")" = "server" ]
  assert $? "DHCPv6 server enabled"

  [ "$(uci_get "${uci_dhcp_key}.ra")" = "server" ]
  assert $? "Router Advertisements enabled"

  [ "$(uci_get "${uci_dhcp_key}.ra_dns")" = "1" ]
  assert $? "IPv6 RDNSS advertises router ULA"

  [ "$(uci_get "${uci_dhcp_key}.dns")" = "$(state lan_ula)" ]
  assert $? "IPv6 RDNSS uses router ULA"

  [ "$(uci_get "${uci_dhcp_key}.dns_service")" = "0" ]
  assert $? "IPv6 automatic DNS advertisement disabled"

  timeout 3 nslookup localhost "$(state lan_ipv4)" >/dev/null 2>&1
  assert $? "dnsmasq is reachable and responding"

  local_server_is_ready 3
  assert $? "dotordoh service is reachable and responding"

  if [ "$success" -eq 1 ]; then
    log "shield verified successfully"
  else
    error "shield verification failed"
  fi

  unset -f assert

  return $((1 - success))
}
