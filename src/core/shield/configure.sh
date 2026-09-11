#!/bin/ash

import utils/get_ipv4
import utils/get_ula
import utils/service/restart
import utils/uci/commit
import utils/uci/exists
import utils/uci/replace_list
import utils/uci/set

shield_configure() {
  local changed=0 interface status=0 uci_dhcp_key="dhcp.${LAN_INTERFACE}"

  [ -n "$(state lan_ipv4)" ] || state lan_ipv4 "$(get_ipv4)"
  [ -n "$(state lan_ula)" ] || state lan_ula "$(get_ula)"

  log "Disabling PeerDNS..."

  for interface in $WAN_INTERFACES; do
    uci_exists "network.$interface" || continue
    uci_set "network.$interface.peerdns" "0" && changed=1
  done

  log "Configuring DHCPv4 DNS..."

  uci_replace_list "${uci_dhcp_key}.dhcp_option" "6," "6,$(state lan_ipv4)" \
    && changed=1

  log "Configuring DHCPv6 / RDNSS..."

  uci_set "${uci_dhcp_key}.dhcpv6" "server" && changed=1
  uci_set "${uci_dhcp_key}.dns_service" "0" && changed=1
  uci_set "${uci_dhcp_key}.ra" "server" && changed=1
  uci_set "${uci_dhcp_key}.ra_dns" "1" && changed=1

  uci_replace_list "${uci_dhcp_key}.dns" "" "$(state lan_ula)" && changed=1

  if [ "$changed" -eq 0 ]; then
    log "Configuration already up-to-date"
    return 0
  fi

  log "Applying configuration..."

  uci_commit "dhcp" || {
    ( error "Failed to commit dhcp config" )
    status=1
  }

  uci_commit "network" || {
    ( error "Failed to commit network config" )
    status=1
  }

  [ "$status" -ne 0 ] && return 1

  service_restart dnsmasq odhcpd || return 1

  log "Configuration applied successfully"
}
