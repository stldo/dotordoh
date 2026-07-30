#!/bin/zsh

set -euo pipefail

ROOT_DIR=$(realpath .) || exit 1
DIST_DIR="$ROOT_DIR/dist"
ROUTES_DIR="$ROOT_DIR/src/script"

case "${1:-build}" in
  run)
    shift
    . src/main.sh
    ;;
  build)
    ;;
  *)
    printf 'Usage: %s [build|run]\n' "$0" >&2
    exit 1
    ;;
esac

[ -f "$ROOT_DIR/bundle.conf" ] && . "$ROOT_DIR/bundle.conf"
[ -f "$ROOT_DIR/script.conf" ] && . "$ROOT_DIR/script.conf"

BIN_FILE="/usr/bin/dotordoh"
DAEMON_FILE="/etc/init.d/dotordoh"

IMPORT_TEMPLATE=""
ROUTE_REQUIRE_TEMPLATE=""
ROUTE_TEMPLATE=""
ROUTES_TEMPLATE=""
VARS_TEMPLATE=$'parse_arguments "$@"\n\n'

HELPERS_TEMPLATE='
is_argument() {
  case "$1" in --*) return 0 ;; *) return 1 ;; esac
}

parse_arguments() {
  local argument key value

  for argument in "$@"; do
    key="${argument#--}"

    [ "$key" = "$argument" ] && continue

    case "$argument" in
      --*=*)
        key="${key%%=*}"
        value="${argument#--*=}"
        ;;
      --*)
        key="${argument#--}"
        value="1"
        ;;
    esac

    case "$key" in *[!0-9a-z_]*|"") continue ;; esac
    key=$(printf '\''%s'\'' "$key" | tr '\''[:lower:]'\'' '\''[:upper:]'\'')
    eval "ARG_$key=\"\$value\""
  done
}'"
$(find "$ROOT_DIR/src/builtin" -type f ! -name import.sh -print0 |
  sort -z |
  xargs -0 awk 'FNR==1 && /^#!/{next}{print}')
"

DAEMON_TEMPLATE='
USE_PROCD=1
START=99
STOP=01

start_service() {
  procd_open_instance

  procd_set_param command "'"$BIN_FILE"'" auto

  procd_set_param respawn 3600 5 5
  procd_set_param term_timeout 5
  procd_set_param stdout 1
  procd_set_param stderr 1

  procd_close_instance

  ("'"$BIN_FILE"'" shield --boot --wait) &
}

reload_service() {
  procd_send_signal dotordoh main HUP 2>/dev/null || true
  ("'"$BIN_FILE"'" shield --wait) &
}

stop_service() {
  killall dnsproxy 2>/dev/null || true
}
'

if [ -f "$ROOT_DIR/script.conf" ]; then
  VARS_TEMPLATE+="$(<"$ROOT_DIR"/script.conf)"$'\n\n'
fi

declare -A IMPORTED
declare -A REQUIRED
declare -A VISITING

die() {
  printf $'%s\n' "$*" >&2
  exit 1
}

process_route() {
  local content file line trimmed_line value

  file=$(realpath "$1") 2>/dev/null || die "Cannot resolve $1"

  [[ -n ${VISITING[$file]:-} ]] && die "Circular import: $file"
  VISITING[$file]=1

  content=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed_line=${line#"${line%%[![:space:]]*}"}

    case "$trimmed_line" in
      \#!*) ;;
      import\ *)
        value=${trimmed_line#import }

        [[ $value == \"*\" ]] && value=${value#\"} && value=${value%\"}
        [[ $value == \'*\' ]] && value=${value#\'} && value=${value%\'}

        process_route "$ROOT_DIR/src/$value.sh"
        ;;
      require\ *)
        value=${trimmed_line#require }

        [[ $value == \"*\" ]] && value=${value#\"} && value=${value%\"}
        [[ $value == \'*\' ]] && value=${value#\'} && value=${value%\'}

        [[ -n ${REQUIRED[$value]:-} ]] && continue

        ROUTE_REQUIRE_TEMPLATE+="require ${value}"$'\n'
        REQUIRED[$value]=1
        ;;
      *)
        [[ -z ${IMPORTED[$file]:-} ]] && content="$content\n$line"
        ;;
    esac
  done <"$file"

  unset -v "VISITING[$file]"

  [[ -n ${IMPORTED[$file]:-} ]] && return
  IMPORTED[$file]=1

  content=${content//\\n/$'\n'}

  while [ "$content" != "${content#[[:space:]]}" ]; do
    content="${content#[[:space:]]}"
  done

  while [ "$content" != "${content%[[:space:]]}" ]; do
    content="${content%[[:space:]]}"
  done

  if [ "$file" != "${file#"$ROUTES_DIR"}" ]; then
    ROUTE_TEMPLATE+="$content"$'\n'
  else
    IMPORT_TEMPLATE+=$'\n'"$content"$'\n'
  fi
}

process_routes() {
  local default_route route routes route_name usage

  default_route=${DEFAULT_ROUTE:-main}

  if [ -f "$ROUTES_DIR/$default_route.sh" ]; then
    usage=${default_route:u}
  else
    default_route=""
    usage=""
  fi

  ROUTES_TEMPLATE+=$'case "$ROUTE" in\n'
  VARS_TEMPLATE+='is_argument "${1:-}" && ROUTE="'"$default_route"'" '
  VARS_TEMPLATE+=$'|| ROUTE="${1:-'"$default_route"$'}"\n\n'

  routes=$(find "$ROUTES_DIR" -type f -name '*.sh' | sort) || return 1

  while IFS= read -r route; do
    route_name=${route#"$ROUTES_DIR"/}
    route_name=${route_name%.sh}

    if [ "$route_name" != "$default_route" ]; then
      usage="$usage|$route_name"
    fi

    process_route "$route"

    ROUTES_TEMPLATE+="$route_name)"$'\n'
    ROUTES_TEMPLATE+="$ROUTE_REQUIRE_TEMPLATE"$'\n'
    ROUTES_TEMPLATE+="$ROUTE_TEMPLATE"
    ROUTES_TEMPLATE+=$';;\n\n'

    REQUIRED=()
    ROUTE_REQUIRE_TEMPLATE=""
    ROUTE_TEMPLATE=""
  done <<<"$routes"

  usage="${usage#|}"
  [ -n "$default_route" ] && usage="[$usage]"

  ROUTES_TEMPLATE+="*)"$'\nprintf '"\$'Usage: \%s $usage\n' "
  ROUTES_TEMPLATE+=$'"$0"\n;;\nesac\n'
}

process_routes

VARS_TEMPLATE+="unset -f is_argument parse_arguments"$'\n\nreadonly ROUTE'

DAEMON_TEMPLATE+=$'\n'"service_triggers() {"$'\n'
DAEMON_TEMPLATE+="  procd_open_trigger"$'\n'

for interface in ${=WAN_INTERFACES}; do
  DAEMON_TEMPLATE+="  procd_add_reload_interface_trigger \"$interface\""$'\n'
done

DAEMON_TEMPLATE+="  procd_close_trigger"$'\n'
DAEMON_TEMPLATE+="}"$'\n'

rm -rf "$DIST_DIR"
mkdir -p "$(dirname "$DIST_DIR$BIN_FILE")"
mkdir -p "$(dirname "$DIST_DIR$DAEMON_FILE")"

printf $'#!/bin/ash\n%s\n%s\n%s\n%s' \
  "$HELPERS_TEMPLATE" \
  "$VARS_TEMPLATE" \
  "$IMPORT_TEMPLATE" \
  "$ROUTES_TEMPLATE" \
> "$DIST_DIR$BIN_FILE"

printf $'#!/bin/sh /etc/rc.common\n%s' \
  "$DAEMON_TEMPLATE" \
> "$DIST_DIR$DAEMON_FILE"

chmod +x "$DIST_DIR$BIN_FILE" "$DIST_DIR$DAEMON_FILE"

printf "Bundle created successfully\n"
