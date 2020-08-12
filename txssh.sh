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

# globals
PROGRAM_SSH='ssh'
PROGRAM_TMUX='tmux'
WINDOW_TITLE=''
WINDOW_LAYOUT='tiled'
CLUSTER=''

#
# usage()
#
# Display basic usage information and exit.
#
function usage() {
  local -i rc="${1:-0}"

  echo 'usage: txssh [-hv] [-e ssh] [-l layout] [-t title] host ...'
  echo
  echo 'options:'
  echo '  -c filename     - use list of hosts in ~/.txssh/filename'
  echo '  -e              - executable to use for ssh (default: ssh)'
  echo '  -h              - select the even-horizontal layout'
  echo '  -l layout       - select a custom layout (default: tiled)'
  echo '  -t title        - set the target window title (default: tssh)'
  echo '  -v              - select the even-vertical layout'
  echo

  exit "${rc}"
}

#
# err()
#
# Print a message to stderr.
#
function err() {
  echo "$*" >&2
}

#
# die()
#
# Print a message to stderr and exit.
#
function die() {
  echo "$*" >&2
  exit 1
}

#
# clusterssh()
#
# Create a new tmux window and populate it with panes containing ssh sessions
# to the specified hosts.
#
function clusterssh() {
  local -a host_list=( "$@" )
  local -i host_count
  local line

  if [[ -n "${CLUSTER}" ]]; then
    if [[ -s "${HOME}/.txssh/${CLUSTER}" ]]; then
      #
      # XXX: Do not use readarray to try and stay compatible with the version
      # of bash 3.x that shipped with macOS.
      #
      for line in $(< "${HOME}/.txssh/${CLUSTER}" ); do
        host_list+=( "${line}" )
      done
    fi
  fi

  # create tmux window and panes
  host_count=1
  for host in "${host_list[@]}"; do
    if (( host_count == 1 )); then
      "${PROGRAM_TMUX}" new-window -dn "${WINDOW_TITLE}" \
        "${PROGRAM_SSH}" "${host}"
    else
      "${PROGRAM_TMUX}" split-window -t "${WINDOW_TITLE}" \
        "${PROGRAM_SSH}" "${host}"
    fi

    # choose layout
    "${PROGRAM_TMUX}" select-layout -t "${WINDOW_TITLE}" "${WINDOW_LAYOUT}"

    (( ++host_count ))
  done

  # synchronize input between panes
  "${PROGRAM_TMUX}" set-option -t "${WINDOW_TITLE}" synchronize-panes on

  # switch to the new window
  "${PROGRAM_TMUX}" select-window -t "${WINDOW_TITLE}"
}

#
# main()
#
function main() {
  # print error and usage if no options given
  if [[ -z "$*" ]]; then
    err 'fatal: no hosts specified'
    usage
  fi

  # ensure tmux is running
  if [[ -z "${TMUX}" ]]; then
    die 'fatal: tmux is not running'
  fi

  # parse options
  while getopts "c:e:hl:t:v" option; do
    case "${option}" in
      'c') CLUSTER="${OPTARG}" ;;
      'e') PROGRAM_SSH="${OPTARG}" ;;
      'h') WINDOW_LAYOUT='even-horizontal' ;;
      'l') WINDOW_LAYOUT="${OPTARG}" ;;
      't') WINDOW_TITLE="${OPTARG}" ;;
      'v') WINDOW_LAYOUT='even-vertical' ;;
      *) usage 1 ;;
    esac
  done
  shift $(( OPTIND - 1 ))

  # generate a random window title if one wasn't provided
  if [[ -z "${WINDOW_TITLE}" ]]; then
    WINDOW_TITLE="$(printf 'txssh-%02x%02x%02x' \
      $(( RANDOM % 255 )) \
      $(( RANDOM % 255 )) \
      $(( RANDOM % 255 )) )"
  fi

  # make immutable
  readonly PROGRAM_SSH
  readonly PROGRAM_TMUX
  readonly WINDOW_TITLE
  readonly WINDOW_LAYOUT

  # create ssh sessions
  clusterssh "$@"
}

main "$@"
