#!/bin/ash

require uci

uci_exists() {
  uci -q get "$1" >/dev/null 2>&1
}
