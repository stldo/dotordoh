#!/bin/ash

service_is() {
  local log_command script service status target

  status=0

  if [ "${1:-}" = "down" ] || [ "${1:-}" = "up" ]; then
    target="$1"
    shift
  else
    target=""
  fi

  for service; do
    log_command="log"
    script="/etc/init.d/${service}"

    if [ ! -x "$script" ]; then
      ( error "Service \"$service\" not found or not executable" )
      status=1
    elif ! "$script" running; then
      if [ "$target" != "down" ]; then
        [ -n "$target" ] && log_command="error" && status=1
        ( "$log_command" "Service \"$service\" is down" )
      fi
    elif [ "$target" != "up" ]; then
      [ -n "$target" ] && log_command="error" && status=1
      ( "$log_command" "Service \"$service\" is up" )
    fi
  done

  return "$status"
}
