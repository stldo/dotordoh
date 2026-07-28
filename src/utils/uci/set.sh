#!/bin/ash

import utils/uci/get

require uci

uci_set() {
  if [ "$(uci_get "$1")" != "$2" ]; then
    uci set "$1=$2"
  else
    return 1
  fi
}
