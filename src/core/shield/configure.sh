#!/bin/ash

import utils/get_ipv4
import utils/get_ula
import utils/service/restart
import utils/uci/add_list
import utils/uci/commit
import utils/uci/delete
import utils/uci/exists
import utils/uci/get
import utils/uci/set

shield_configure() {
  local \
    changed \
    interface \
    ipv4_check \
    status \
    uci_dhcp_key \
    uci_dns_key \
    uci_dns_value

  [ -n "$(state lan_ipv4)" ] || state lan_ipv4 "$(get_ipv4)"
  [ -n "$(state lan_ula)" ] || state lan_ula "$(get_ula)"

  changed=0
  status=0
  uci_dhcp_key="dhcp.${LAN_INTERFACE}"
  uci_dns_key="${uci_dhcp_key}.dns"
  uci_dns_value="$(uci_get "$uci_dns_key")"

  log "Disabling PeerDNS..."

  for interface in $WAN_INTERFACES; do
    uci_exists "network.$interface" || continue
    uci_set "network.$interface.peerdns" "0" && changed=1
  done

  log "Configuring DHCPv4 DNS..."

  ipv4_check=$(set -f; set -- $uci_dns_value; printf '%s' "$#:${1-}")

  if [ "$ipv4_check" != "1:$(state lan_ipv4)" ]; then
    uci_delete "$uci_dns_key" && changed=1
    uci_add_list "$uci_dns_key" "$(state lan_ipv4)" && changed=1
  fi

  log "Configuring DHCPv6 / RDNSS..."

  uci_set "${uci_dhcp_key}.dhcpv6" "server" && changed=1
  uci_set "${uci_dhcp_key}.ra" "server" && changed=1
  uci_set "${uci_dhcp_key}.ra_dns" "$(state lan_ula)" && changed=1

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
