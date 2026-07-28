#!/bin/ash

require uci

uci_delete() {
  uci -q delete "$1" 2>/dev/null || true
}
