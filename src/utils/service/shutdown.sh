#!/bin/ash

service_shutdown() {
  local script service service_status status

  status=0

  for service; do
    script="/etc/init.d/${service}"
    service_status=0

    if [ ! -x "$script" ]; then
      ( error "Service \"$service\" not found or not executable" )
      status=1
      continue
    fi

    "$script" stop 2>/dev/null
    [ "$?" -ne 0 ] && service_status=1
    "$script" disable 2>/dev/null
    [ "$?" -ne 0 ] && service_status=1

    if [ "$service_status" -ne 0 ]; then
      ( error "Service \"$service\" shutdown failed" )
      status="$service_status"
    fi
  done

  return "$status"
}
