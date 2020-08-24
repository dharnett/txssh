#!/bin/bash
# vim: set ft=bash sw=2 ts=2 sts=2 et ai:
#
# Copyright 2020 Daniel Harnett <daniel.harnett@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
# OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.
#

set -euo pipefail

: "${SSH_AGENT_PID:=}"
: "${SSH_AUTH_SOCK:=}"

ENVIRONMENT_FILE="$(mktemp /tmp/.txssh-agent.XXXXXXXXXXXX)"

SSH_AGENT_STATE='start'

SSH_AGENT_PID_OLD="${SSH_AGENT_PID}"
SSH_AGENT_PID_NEW=''

SSH_AUTH_SOCK_OLD="${SSH_AUTH_SOCK}"

#
# cleanup()
#
# Cleanup temporary files and agent sessions.
#
function cleanup() {
  if [[ "${SSH_AGENT_STATE}" == 'running' ]]; then
    if [[ -n "${SSH_AGENT_PID_NEW}" ]]; then
      kill "${SSH_AGENT_PID_NEW}"
    fi
  fi

  rm -f -- "${ENVIRONMENT_FILE}"
}

#
# session_new()
#
# Start a new ssh-agent.
#
function session_new() {
  local -r os="$(uname -s)"

  if ssh-agent -s > "${ENVIRONMENT_FILE}" 2> /dev/null; then
    # shellcheck disable=SC1090
    source "${ENVIRONMENT_FILE}"

    if kill -0 "${SSH_AGENT_PID}"; then
      SSH_AGENT_STATE='running'
      SSH_AGENT_PID_NEW="${SSH_AGENT_PID}"

      case "${os}" in
        'Darwin')
          ssh-add -A
          ;;

        'Linux')
          ssh-add ~/.ssh/id_rsa
          ;;
      esac
    fi
  fi
}

#
# session_run()
#
# Establish the ssh connection.
#
function session_run() {
  ssh -A "$@"
}

#
# session_end()
#
# Kill the temporary ssh-agent and restore the environment.
#
function session_end() {
  if [[ "${SSH_AGENT_STATE}" == 'running' ]]; then
    if ssh-agent -k > "${ENVIRONMENT_FILE}" 2> /dev/null; then
      # shellcheck disable=SC1090
      source "${ENVIRONMENT_FILE}"
    fi

    if [[ -n "${SSH_AGENT_PID_OLD}" ]]; then
      export SSH_AGENT_PID="${SSH_AGENT_PID_OLD}"
    fi

    if [[ -n "${SSH_AUTH_SOCK_OLD}" ]]; then
      export SSH_AUTH_SOCK="${SSH_AUTH_SOCK_OLD}"
    fi

    SSH_AGENT_STATE='killed'
  fi
}

#
# main()
#
function main() {
  session_new
  session_run "$@"
  session_end
}

trap 'cleanup' EXIT ERR INT TERM HUP
main "$@"
