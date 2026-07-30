#!/bin/ash

import utils/uci/add
import utils/uci/add_list
import utils/uci/commit
import utils/uci/delete
import utils/uci/set

require https-dns-proxy
require stubby

state mode ""

monitor_run() {
  local bootstrap_dns current_mode mode service_starting service_stopping

  mode="${1:-}"

  case "$mode" in
    dot)
      service_starting=stubby
      service_stopping=https-dns-proxy

      uci_delete stubby

      uci_set stubby.global "global"
      uci_set stubby.global.manual "0"
      uci_set stubby.global.round_robin_upstreams "1"
      uci_set stubby.global.tls_query_padding_blocksize "128"
      uci_add_list stubby.global.dns_transport_list "GETDNS_TRANSPORT_TLS"
      uci_add_list stubby.global.listen_address "127.0.0.1@$LOCAL_PORT"

      for server in $BOOTSTRAP_SERVER; do
        uci_add stubby resolver >/dev/null
        uci_set stubby.@resolver[-1].address="$server"
        uci_set stubby.@resolver[-1].tls_auth_name="$DOT_DOMAIN"
      done

      uci_commit stubby
      ;;
    doh)
      service_starting=https-dns-proxy
      service_stopping=stubby

      bootstrap_dns=""
      for server in $BOOTSTRAP_SERVER; do
        bootstrap_dns="${doh_upstream_servers:+$doh_upstream_servers,}$server"
      done

      uci_delete https-dns-proxy

      uci_set https-dns-proxy.dns="https-dns-proxy"
      uci_set https-dns-proxy.dns.listen_addr="127.0.0.1"
      uci_set https-dns-proxy.dns.listen_port="$LOCAL_PORT"
      uci_set https-dns-proxy.dns.resolver_url="https://$DOH_DOMAIN$DOH_PATH"
      uci_set https-dns-proxy.dns.bootstrap_dns="$bootstrap_dns"
      uci_set https-dns-proxy.dns.user="nobody"
      uci_set https-dns-proxy.dns.group="nogroup"

      uci_commit https-dns-proxy
      ;;
    *) return 1 ;;
  esac

  current_mode="$(state mode)"

  if [ "$current_mode" = "$mode" ] && service "$service_starting" running; then
    return 0
  elif [ -z "$current_mode" ]; then
    log "Starting dotordoh in $mode mode..."
  elif [ "$current_mode" = "$mode" ]; then
    log "Restarting dotordoh in $mode mode..."
  else
    log "Switching dotordoh from $current_mode to $mode..."
  fi

  state mode ""

  service "$service_starting" enable
  service "$service_starting" start

  sleep 1

  if ! service "$service_starting" running; then
    error "Failed to start dotordoh service"
    return 1
  fi

  service "$service_stopping" stop 2>/dev/null
  service "$service_stopping" disable 2>/dev/null

  log "dotordoh listening in \"$mode\" mode"

  state mode "$mode"
}
