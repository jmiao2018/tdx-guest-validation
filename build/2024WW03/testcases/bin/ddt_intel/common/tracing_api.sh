#!/usr/bin/env bash
##
## Copyright (c) 2018, Intel Corporation.
##
## This program is free software; you can redistribute it and/or modify it
## under the terms and conditions of the GNU General Public License,
## version 2, as published by the Free Software Foundation.
##
## This program is distributed in the hope it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
## more details.
##

# File: tracing_api.sh
#
# Description:  This script contains commons apis related to tracing.
#
# Authors:      Ning Han - ningx.han@intel.com
#
# History:      Mar 21 2018 - Creation - Ning Han
#                 - Add function open_trace_events()
#                 - Add function collect_trace_log()

source common.sh

TRACING_ROOT_PATH="/sys/kernel/debug/tracing/events"
TRACING_NODE="/sys/kernel/debug/tracing/trace"

# If you need trace more than one event, separate the event name with space
EVENTS=""

# Description: open the given trace events and clear trace buffer
# Input:       N/A
# Output:      N/A
# Return:      0 - on success
#              1 - on failure
#              2 - events not set
# Usage:       open_trace_events('EVENTS' must be set)
open_trace_events() {
  [[ -n "$EVENTS" ]] || {
    test_print_trc "EVENTS not set"
    return 2
  }

  for event in $EVENTS; do
    if [[ -e "$TRACING_ROOT_PATH/$event/enable" ]]; then
      echo 1 > "$TRACING_ROOT_PATH/$event/enable" || return 1
    else
      test_print_trc "event $event not found."
      return 1
    fi
  done

  echo > "$TRACING_NODE" || return 1
}

# Description: collect trace log
# Input:       -f - redirect trace log to file(optional)
# Output:      if -f is set, output filename in which trace log stored,
#              else, output trace log contents
# Return:      0 - on success
#              1 - on failure
# Usage:       collect_trace_log
#              collect_trace_log -f
#              ('EVENTS' must be set)
collect_trace_log() {
  local temp_file
  local trace_file

  while getopts "f" opt; do
    case $opt in
      f) temp_file=$(mktemp "${TAG}_XXXXXX") ;;
      \?) die "Invalid option: -$OPTARG" ;;
      :) die "Option -$OPTARG requires an argument." ;;
    esac
  done

  if [[ -n "$temp_file" ]]; then
    cat "$TRACING_NODE" > "$temp_file"
    trace_file="${temp_file}.trace"
    mv "$temp_file" "$LOG_PATH/$trace_file"
    echo "$trace_file"
  else
    cat "$TRACING_NODE"
  fi
}

# Description: close tracer, clear trace buffer
# Input:       N/A
# Output:      N/A
# Return:      0 - on success
#              1 - on failure
# Usage:       close_trace_events
close_trace_events() {
  # close all tracer
  for event in $EVENTS; do
    echo 0 > "$TRACING_ROOT_PATH/$event/enable" || return 1
    echo > "$TRACING_NODE" || return 1
  done
}
