#!/bin/ash

require uci

uci_get() {
  uci -q get "$1" 2>/dev/null || true
}
