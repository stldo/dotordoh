#!/bin/ash

restart_services() {
  local script service status

  status=0

  for service; do
    script="/etc/init.d/${service}"

    if [ ! -x "$script" ]; then
      ( error "Service '$service' not found or not executable" )
      status=1
    elif ! "$script" restart; then
      ( error "Service '$service' restart failed" )
      status=1
    fi
  done

  return "$status"
}
