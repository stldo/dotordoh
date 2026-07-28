#!/bin/zsh

set -euo pipefail

COMMAND="${1:-build}"
ROOT_DIR=$(realpath $(pwd)) || exit 1

if [ "$COMMAND" = "run" ]; then
  shift
  . src/main.sh
  exit $?
elif [ "$COMMAND" != "build" ]; then
  exit 1
fi

[ -f "$ROOT_DIR/bundle.conf" ] && . "$ROOT_DIR/bundle.conf"

DIST_DIR="$ROOT_DIR/dist"
DIST_FILE="$(basename $ROOT_DIR).sh"
ROUTES_DIR="$ROOT_DIR/src/script"

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
$(find "$ROOT_DIR/src/builtin" -type f \
! -name 'import.sh' -exec awk \
'FNR==1 && /^#!/{next}{print}' {} +)
"

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
  local default_route route route_name routes_tempfile usage

  default_route=${DEFAULT_ROUTE:-main}
  routes_tempfile=$(mktemp) || return 1

  if [ -f "$ROUTES_DIR/$default_route.sh" ]; then
    usage="$(printf '%s' "$default_route" | tr '[:lower:]' '[:upper:]')"
  else
    default_route=""
    usage=""
  fi

  VARS_TEMPLATE+='is_argument "${1:-}" && ROUTE="'"$default_route"'" '
  VARS_TEMPLATE+=$'|| ROUTE="${1:-'"$default_route"$'}"\n\n'

  ROUTES_TEMPLATE+=$'case "$ROUTE" in\n'

  if ! find "$ROUTES_DIR" -type f -name '*.sh' | sort >"$routes_tempfile"; then
    rm -f "$routes_tempfile"
    return 1
  fi

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
  done < "$routes_tempfile"

  rm -f "$routes_tempfile"

  usage="${usage#|}"
  [ -n "$default_route" ] && usage="[$usage]"

  ROUTES_TEMPLATE+="*)"$'\nprintf '"\$'Usage: \%s $usage\n' "$'"$0"\n;;\n\nesac\n'
}

process_routes

VARS_TEMPLATE+="unset -f is_argument parse_arguments"$'\n\nreadonly ROUTE'

mkdir -p "$DIST_DIR"

printf \
  $'#!/bin/ash\n%s\n%s\n%s\n%s' \
  "$HELPERS_TEMPLATE" \
  "$VARS_TEMPLATE" \
  "$IMPORT_TEMPLATE" \
  "$ROUTES_TEMPLATE" \
  > "$DIST_DIR/$DIST_FILE"

chmod +x "$DIST_DIR/$DIST_FILE"

printf "Bundle created at 'dist/$DIST_FILE'\n"
