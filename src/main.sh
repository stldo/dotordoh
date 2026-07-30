#!/bin/ash

is_argument() {
  case "$1" in --*) return 0 ;; *) return 1 ;; esac
}

ROOT_DIR=$(realpath "$(dirname "$0")/..") || exit 1

[ -f "$ROOT_DIR/bundle.conf" ] && . "$ROOT_DIR/bundle.conf"
[ -f "$ROOT_DIR/script.conf" ] && . "$ROOT_DIR/script.conf"

ROUTES_DIR="$ROOT_DIR/src/script"

# Accept "main" as argument only if explicitly set by DEFAULT_ROUTE
if [ "${1:-}" != "main" ] || [ "${DEFAULT_ROUTE:-}" = "main" ]; then
  is_argument "${1:-}" || ROUTE="${1:-}"
  ROUTE="${ROUTE:-${DEFAULT_ROUTE:-main}}"
  case "$ROUTE" in ""|/*|*/|*//*|*[!a-z0-9_/-]*) ROUTE= ;; esac
fi

readonly ROUTE

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
    key=$(printf '%s' "$key" | tr 'a-z' 'A-Z')
    eval "ARG_$key=\"\$value\""
  done
}

validate_route() {
  local default_route route routes_tempfile usage

  if [ -n "$ROUTE" ] && [ -f "$ROUTES_DIR/$ROUTE.sh" ]; then
    return 0
  fi

  default_route=${DEFAULT_ROUTE:-main}
  routes_tempfile=$(mktemp) || return 1

  if [ -f "$ROUTES_DIR/$default_route.sh" ]; then
    usage="$(printf '%s' "$default_route" | tr 'a-z' 'A-Z')"
  else
    default_route=""
    usage=""
  fi

  if ! find "$ROUTES_DIR" -type f -name '*.sh' | sort >"$routes_tempfile"; then
    rm -f "$routes_tempfile"
    return 1
  fi

  while IFS= read -r route; do
    route=${route#"$ROUTES_DIR"/}
    route=${route%.sh}

    if [ "$route" != "$default_route" ]; then
      usage="$usage|$route"
    fi
  done < "$routes_tempfile"

  rm -f "$routes_tempfile"

  usage="${usage#|}"
  [ -n "$default_route" ] && usage="[$usage]"

  printf 'Usage: %s %s\n' "$0" "$usage"

  return 1
}

. "$ROOT_DIR/src/builtin/error.sh"
. "$ROOT_DIR/src/builtin/import.sh"
. "$ROOT_DIR/src/builtin/log.sh"
. "$ROOT_DIR/src/builtin/require.sh"
. "$ROOT_DIR/src/builtin/state.sh"

# Check required commands here to avoid circular references
require date
require find
require logger
require mktemp
require realpath
require sort
require tr

validate_route || exit $?
parse_arguments "$@"

unset ROUTES_DIR
unset -f is_argument parse_arguments validate_route

. "$ROOT_DIR/src/script/$ROUTE.sh"
