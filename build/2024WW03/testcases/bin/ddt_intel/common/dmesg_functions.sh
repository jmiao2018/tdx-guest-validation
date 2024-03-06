#!/usr/bin/env bash
##
## Copyright (c) 2017, Intel Corporation.
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

# File: dmesg_functions.sh
#
# Description:  This script contains the commons functions related to dmesg.
#
# Authors:      Yixin Zhang - yixin.zhang@intel.com
#
# History:      Aug 03 2017 - Creation - Yixin Zhang
#                 - Add fucntion check_dmesg_keyword()
#                 - Add fucntion clear_dmesg()
#                 - Add fucntion dump_dmesg()
#                 - Add fucntion get_dmesg_timestamp()
#                 - Add fucntion is_boot_dmesg_included()


source "common.sh"


# Description: Dump dmesg to file system
# Input:       $1 - optional, file path
# Output:      File path
# Return:      0 - dump succeed
#              1 - dump failed
# Usage:       dmesg_file=$(dump_dmesg) || die "xxxx"
#              $(dump_dmesg ./target_file) || die "xxxx"
dump_dmesg() {
  local dmesg_file=$1
  : "${dmesg_file:=$(mktemp /tmp/ddt-dmesg.XXXXXXXXXX)}"

  [[ -n $dmesg_file ]] || {
    test_print_err "Target file to dump dmesg is invalide!"
    return 1
  }

  dmesg > "$dmesg_file" || {
    test_print_err "Dump dmesg to file failed!"
    return 1
  }

  echo "$dmesg_file"
}


# Description: Clear dmesg
# Input:       NA
# Output:      NA
# Return:      0 - succeed
#              1 - failed
# Usage:       clear_dmesg || die "xxxx"
clear_dmesg() {
  dmesg -C
}


# Description: Get the timestamp of the first or last line of dmesg
# Input:       -h : head, get timestamp of the first line of dmesg
#              -t : tail, get timestamp of the last line of dmesg (default)
#              -f file : optional, read dmesg form file
# Output:      string of required time stamp
# Return:      0 - succeed
#              1 - failed
# Usage:       dmesg_time=$(get_dmesg_timestamp -h -f ./dmesg_file) || die "xxxx"
#              dmesg_time=$(get_dmesg_timestamp) || die "xxxx"
get_dmesg_timestamp() {
  local location_flag='t'
  local dmesg_file=''
  local dmesg_line=''

  local OPTIND
  while getopts "htf:" opt; do
    case "$opt" in
      h)
        location_flag='h';;
      t)
        location_flag='t';;
      f)
        dmesg_file=$OPTARG;;
      \?)
        die "Invalid option: -$OPTARG";;
      :)
        die "Option -$OPTARG requires an argument.";;
    esac
  done

  [[ -n $dmesg_file && ! -f $dmesg_file ]] && {
      test_print_err "Invalide dmesg file!"
      return 1
  }

  if [[ $location_flag == 'h' && -n $dmesg_file ]]; then
    dmesg_line=$(head -n 1 "$dmesg_file")
  elif [[ $location_flag == 't' && -n $dmesg_file ]]; then
    dmesg_line=$(tail -n 1 "$dmesg_file")
  elif [[ $location_flag == 'h' ]]; then
    dmesg_line=$(dmesg | head -n 1)
  else
    dmesg_line=$(dmesg | tail -n 1)
  fi

  local timestamp
  timestamp=$(echo "$dmesg_line" \
              | grep -oe "^\[ *[0-9]*\.[0-9]*\]" \
              | grep -oe "[0-9]*\.[0-9]*")

  [[ -n $timestamp ]] || return 1
  echo "$timestamp"
}


# Description: Check if boot dmesg included in current dmesg
# Input:       $1 - optional, dmesg file
# Output:      NA
# Return:      0 - boot dmesg is included
#              1 - boot dmesg is not included
# Usage:       is_boot_dmesg_included dmesg_file || block_test
is_boot_dmesg_included() {
  local dmesg_time
  dmesg_time=$(get_dmesg_timestamp -h -f "$1")

  if [[ $dmesg_time =~ ^0+\.0+$ ]]; then
    return 0
  else
    return 1
  fi
}


# Description: Check keyword pattern in dmesg
# Input:       -f    optional, dmesg file
#              -a/-o AND/OR, default value -a.
#              $@    regex pattern list
# Output:      NA
# Return:      0 - pattern in dmesg
#              1 - pattern not in dmesg
# Usage:       check_dmesg_keyword "0+:0+"
#              check_dmesg_keyword -f ./dmesg.log -a "0+:0+" "[0-9]\.[0-9]"
#              check_dmesg_keyword -f ./dmesg.log -o "0+:0+" "[0-9]\.[0-9]"
check_dmesg_keyword() {
  local check_mode=''
  local dmesg_file=''

  local OPTIND
  while getopts "f:ao" opt; do
    case "$opt" in
      f)
        dmesg_file=$OPTARG;;
      a)
        [[ -z $check_mode ]] || die "Option -a/-o can only be set once."
        check_mode='a';;
      o)
        [[ -z $check_mode ]] || die "Option -a/-o can only be set once."
        check_mode='o';;
      f)
        dmesg_file=$OPTARG;;
      \?)
        die "Invalid option: -$OPTARG";;
      :)
        die "Option -$OPTARG requires an argument.";;
    esac
  done
  shift $((OPTIND-1))

  if [[ $# -eq 0 ]]; then
    test_print_err "Pattern is required for check_dmesg_keyword!"
  fi

  : ${check_mode:='a'}
  : "${dmesg_file:=$(dump_dmesg)}"

  for pattern in "$@"; do
    if grep -qE "$pattern" "$dmesg_file"; then
      test_print_trc "Pattern $pattern found in dmesg"
      [[ $check_mode == 'o' ]] && return 0
    else
      test_print_trc "Pattern $pattern not found in dmesg"
      [[ $check_mode == 'a' ]] && return 1
    fi
  done

  if [[ $check_mode == 'o' ]]; then
    return 1;
  else
    return 0;
  fi
}

# Description: extract dmesg generated while a case running
# Input:       NA
# Output:      the name of dmesg file if -f specified, else
#              output case dmesg
# Usage:       extract_case_dmesg
extract_case_dmesg() {
  local start_tag
  local dmesg
  local start_tag_prefix
  local temp_file

  local OPTIND

  while getopts "f" opt; do
    case $opt in
      f) temp_file=$(mktemp ${TAG}_XXXXXX) ;;
      \?) die "Invalid option: -$OPTARG" ;;
      :) die "Option -$OPTARG requires an argument." ;;
    esac
  done

  start_tag_prefix="LTP: starting "
  start_tag="${start_tag_prefix}${TAG}"
  dmesg=$(dmesg | tac | grep -m 1 "$start_tag" -B100000 | tac)
  if [[ -z "$dmesg" ]]; then
    # Dmesg of this case is too long, even flush the start tag away.
    # In this case, we keep all the remained dmesg
    dmesg=$(dmesg | grep "$start_tag_prefix")
  fi

  if [[ -n "$temp_file" ]]; then
    # file name template: TAG-RANDOMSTRING.dmesg
    case_dmesg_file="${temp_file/./-}.dmesg"
    echo "$dmesg" > "${temp_file}"
    # move dmesg file to log directory
    mv "$temp_file" "$LOG_PATH/$case_dmesg_file"
    echo "$case_dmesg_file"
  else
    echo -e "$dmesg"
  fi
}

# Description: check specific pattern in dmesg
# Input:       $1 - dmesg file
#              $2 - pattern to check
# Output:      lines which contain the pattern
# Returns:     0 - pattern found
#              1 - pattern not found
# Usage:       dmesg_pattern_check $dmesg_file $pattern
dmesg_pattern_check() {
  local dmesg="$1"
  local pattern="$2"
  local lines

  [[ -f "$dmesg" ]] || die "dmesg file doesn't exist"

  lines=$(grep -E "$pattern" "$dmesg")
  echo "$lines"

  [[ -z "$lines" ]] || return 0

  return 1
}
