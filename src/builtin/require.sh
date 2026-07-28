#!/bin/ash

require() {
  command -v "$1" >/dev/null 2>&1 || {
    error "Command '$1' not found"
  }
}
