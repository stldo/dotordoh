#!/bin/ash

require uci

uci_add() {
  uci add "$1" "$2"
}
