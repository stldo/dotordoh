#!/bin/ash

import utils/timeout

require nc

dnsproxy_dot_is_available() {
  local status

  timeout "$1" nc "$DOT_DOMAIN" "853" </dev/null >/dev/null 2>&1
  status=$?

  [ "$status" -eq 124 ] && return 0

  return "$status"
}
