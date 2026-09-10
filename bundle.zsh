#!/usr/bin/env zsh

set -euo pipefail
setopt null_glob

ROOT_DIR=${0:A:h}

[ -f "$ROOT_DIR/.env" ] && . "$ROOT_DIR/.env"

BUILTIN_DIR="$ROOT_DIR/src/builtin"
COMMAND_DIR="$ROOT_DIR/src/commands"
DIST_DIR="$ROOT_DIR/dist"

typeset -A COMMAND HEAD IMPORTED REQUIRED VISITING

BIN_FILE="/usr/bin/dotordoh"
DAEMON_FILE="/etc/init.d/dotordoh"

HEAD[builtin]=$(
  find "$BUILTIN_DIR" -type f -print0 |
  sort -z |
  xargs -0 awk 'FNR==1 && /^#!/{next}{print}'
)

HEAD[core]=""

HEAD[utils]=""

HEAD[variables]='
ARGUMENTS=""
COMMAND=""

for argument in "$@"; do
  if [ -z "$ARGUMENTS" ]; then
    case "$argument" in
      ""|*[!a-z]*)
        ;;
      *)
        COMMAND="${COMMAND:+$COMMAND }$argument"
        continue
        ;;
    esac
  fi

  ARGUMENTS="$ARGUMENTS $(
    printf "'\''"
    printf '\''%s'\'' "$argument" | sed "s/'\''/'\''\\\\'\'''\''/g"
    printf "'\''"
  )"
done

unset argument
readonly COMMAND
'

if [ -f "$ROOT_DIR/.env" ]; then
  HEAD[variables]+=$'\n'"$(<"$ROOT_DIR"/.env)"$'\n'
fi

process_script() {
  setopt local_options extended_glob

  local \
    body="" \
    command \
    command_path="${1#"$COMMAND_DIR/"}" \
    file="${1:A}" \
    key \
    line \
    path

  [[ ${VISITING[$file]:-0} == 1 ]] && return 1
  VISITING[$file]=1

  if [[ "$command_path" != "$1" ]]; then
    REQUIRED=()
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      \#!*)
        ;;

      [[:space:]]#import\ *)
        path=${line#*import }
        path=${path//[\'\"]}

        process_script "$ROOT_DIR/src/${path}.sh"
        ;;

      [[:space:]]#require\ *)
        path=${line#*require }
        path=${path//[\'\"]}

        [[ "$path" == '$'* ]] && path="\"$path\""
        [[ ${REQUIRED[$path]:-0} != 1 ]] && REQUIRED[$path]=1 || continue
        ;;

      *)
        [[ -z ${IMPORTED[$file]:-} ]] || continue

        body+="$line"$'\n'
        ;;
    esac
  done < "$file"

  unset "VISITING[$file]"

  # Return early for already imported files, so require directives are processed
  # in the loop.
  [[ -n ${IMPORTED[$file]:-} ]] && return
  IMPORTED[$file]=1

  body="${body##$'\n'#}"
  command="${command_path%.sh}"

  if [[ "$command_path" != "$1" ]]; then
    COMMAND[$command]=""
    for key in ${(k)REQUIRED}; do COMMAND[$command]+="require $key"$'\n'; done
    (( ${#REQUIRED} )) && COMMAND[$command]+=$'\n'
    COMMAND[$command]+="$body"
  elif [[ "$file" == "$ROOT_DIR/src/core/"* ]]; then
    HEAD[core]="${body}"$'\n'"${HEAD[core]}"
  else
    HEAD[utils]="${body}"$'\n'"${HEAD[utils]}"
  fi
}

for command_file in "$COMMAND_DIR"/**/*.sh; do
  process_script "$command_file"
done

mkdir -p "$(dirname "$DIST_DIR$BIN_FILE")"
mkdir -p "$(dirname "$DIST_DIR$DAEMON_FILE")"

{
  printf '%s\n' '#!/bin/ash'
  printf '%s\n' "$HEAD[builtin]"
  printf '%s\n' "$HEAD[variables]"
  printf '%s%s' "$HEAD[utils]" "$HEAD[core]"

  printf '%s\n' 'case "$(printf "%s" "$COMMAND" | tr " " "/")" in'

  for command in ${(ok)COMMAND}; do
    [[ "$command" == \[*\] ]] && continue

    printf '  %s\n' "${(qq)command})"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -n "$line" ]]; then
        printf '    %s\n' "$line"
      else
        printf '\n'
      fi
    done < <(printf '%s' "${COMMAND[$command]}")

    printf '    %s\n\n' ';;'
  done

  if (( ${+COMMAND[[root]]} )); then
    printf '  %s\n' "'')"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ -n "$line" ]]; then
        printf '    %s\n' "$line"
      else
        printf '\n'
      fi
    done < <(printf '%s' "${COMMAND[[root]]}")

    printf '    %s\n\n' ';;'
  fi

  printf '  %s\n' '*)'
  printf '    %s\n' 'error "'\''$COMMAND'\'' is not supported"'
  printf '    %s\n\n' ';;'
  printf '%s\n' 'esac'
} >| "$DIST_DIR$BIN_FILE"

{
  printf '%s\n' '#!/bin/sh /etc/rc.common'

  printf '\n%s\n' 'USE_PROCD=1'
  printf '%s\n' 'START=99'
  printf '%s\n' 'STOP=01'

  printf '\n%s\n' 'start_service() {'
  printf '  %s\n' 'procd_open_instance main'

  printf '\n  %s\n' "procd_set_param command \"$BIN_FILE\" monitor"

  printf '\n  %s\n' 'procd_set_param respawn 3600 5 5'
  printf '  %s\n' 'procd_set_param term_timeout 5'
  printf '  %s\n' 'procd_set_param stdout 1'
  printf '  %s\n' 'procd_set_param stderr 1'

  printf '\n  %s\n' 'procd_close_instance'

  printf '\n  %s\n' "(\"$BIN_FILE\" shield -r -w) &"
  printf '%s\n' '}'

  printf '\n%s\n' 'reload_service() {'
  printf '  %s\n' 'procd_send_signal dotordoh main HUP 2>/dev/null || true'
  printf '  %s\n' "(\"$BIN_FILE\" shield -w) &"
  printf '%s\n' '}'

  printf '\n%s\n' 'restart() {'
  printf '  %s\n' "trap '' TERM"
  printf '  %s\n' 'stop "$@"'
  printf '  %s\n' "trap - TERM"
  printf '  %s\n' 'sleep 10'
  printf '  %s\n' 'start "$@"'
  printf '%s\n' '}'

  printf '\n%s\n' 'service_triggers() {'
  printf '  %s\n' 'procd_open_trigger'

  for interface in ${=WAN_INTERFACES}; do
    printf '  %s\n' "procd_add_reload_interface_trigger \"$interface\""
  done

  printf '  %s\n' 'procd_close_trigger'
  printf '%s\n' '}'

  printf '\n%s\n' 'service_stopped() {'
  printf '  %s\n' 'service https-dns-proxy stop 2>/dev/null'
  printf '  %s\n' 'service https-dns-proxy disable 2>/dev/null'
  printf '  %s\n' 'service stubby stop 2>/dev/null'
  printf '  %s\n' 'service stubby disable 2>/dev/null'
  printf '%s\n' '}'
} >| "$DIST_DIR$DAEMON_FILE"

chmod +x "$DIST_DIR$BIN_FILE" "$DIST_DIR$DAEMON_FILE"

print "Bundle was created successfully"
