#!/bin/ash

require ubus
require jsonfilter

get_ipv4() {
  local result

  result=$(
    ubus call network.interface.lan status \
      | jsonfilter -e '@["ipv4-address"][0].address'
  )

  [ -n "$result" ] || error "No LAN IPv4 found"

  printf '%s\n' "$result"
}
