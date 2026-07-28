#!/bin/ash

require uci

uci_commit() {
  uci commit "$1"
}
