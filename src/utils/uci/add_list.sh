#!/bin/ash

require uci

uci_add_list() {
  uci add_list "$1=$2"
}
