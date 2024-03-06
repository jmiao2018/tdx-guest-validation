#!/bin/bash

###############################################################################
#
# Copyright (C) 2016 Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
###############################################################################

############################ CONTRIBUTORS #####################################

# Author: Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#
# Jan, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Initial draft.
#     - Added 'load_module()' and 'unload_module()' functions.
#     - Added 'check_lsmod()' function.
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Ported to LCK-GDC suite to LTP-DDT.

############################ DESCRIPTION ######################################

# @desc    This script load/unload different driver modules.
# @params  [-l] [-u] [-d DRIVER] [-h]
# @return
# @history 2016-01-01: Created and initial draft.
# @history 2016-12-15: Integrated to LTP-DDT.

############################# FUNCTIONS #######################################

usage() {
  cat<<_EOF
  Usage:./${0##*/} [-l] [-u] [-c] [-p PARAMS] [-d DRIVER] [-h]
  Option:
    -l  Load module
    -u  Unload module
    -c  Check module
    -d  Driver to be loaded/unloded/checked
    -p  Module Parameter
    -h  Look for usage
_EOF
}

# LOAD DRIVER MODULE
load_module() {
  local mod=$1
  local param=$2

  if [ -z "$mod" ]; then
    test_print_err "Please input module to be loaded"
    return 1
  fi

  do_cmd modprobe "$mod" "$param"

  test_print_trc "$mod : Loaded"
  mod_loaded=$(echo "$mod" | tr '-' '_')
  check_lsmod "$mod_loaded"
}

# UNLOAD DRIVER MODULE
unload_module() {
  local mod=$1

  if [ $# -ne 1 ]; then
    test_print_err "Please input module to be unloaded"
    return 1
  fi

  mod_loaded=$(echo "$mod" | tr '-' '_')
  do_cmd modprobe -r "$mod_loaded"

  test_print_trc "$mod : Unloaded"
  check_lsmod "$mod_loaded"
}

# CHECK DRIVER MODULE LOADED WITH 'lsmod' COMMAND
check_lsmod() {
  local mod=$1

  if [ $# -ne 1 ]; then
    test_print_err "Please input module to be check"
    return 1
  fi

  LSMOD=$(lsmod | grep -w -e "^$mod")
  if [ $? -ne 0 ]; then
    test_print_trc "Module $mod is not loaded"
    return 1
  fi

  test_print_trc "lsmod:$LSMOD"
}

################################ DO THE WORK ##################################

source "common.sh"

while getopts :lucd:p:h arg
do case $arg in
  l)  LOAD=1;;
  u)  UNLOAD=1;;
  c)  CHECK=1;;
  d)  DRIVER="$OPTARG";;
  p)  PARAMS="$OPTARG";;
  h)  usage;;
  :)  test_print_err "Must supply an argument to -$OPTARG." >&2
      exit 1
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored." >&2
      usage
      exit 1
      ;;
esac
done

# DEFAULT VALUES IF NOT SET IN 'getopts'
: ${LOAD:='0'}
: ${UNLOAD:='0'}
: ${CHECK:='0'}
: ${PARAMS:=''}

# LOAD MODULE DRIVER
if [ "$LOAD" -eq 1 ]; then
  load_module "$DRIVER" "$PARAMS"
fi

# UNLOAD MODULE DRIVER
if [ "$UNLOAD" -eq 1 ]; then
  unload_module "$DRIVER"
fi

if [ "$CHECK" -eq 1 ]; then
  check_lsmod "$DRIVER"
fi
