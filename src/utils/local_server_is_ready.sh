import utils/timeout

require nslookup

local_server_is_ready() {
  local dns_server

  dns_server="127.0.0.1:$LOCAL_PORT"

  timeout "${1:-1}" nslookup "$DOH_DOMAIN" "$dns_server" >/dev/null 2>&1
}
