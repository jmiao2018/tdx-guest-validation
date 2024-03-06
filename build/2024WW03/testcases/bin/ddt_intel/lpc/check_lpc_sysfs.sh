#!/bin/bash

###############################################################################
# Copyright (C) 2017, Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################

############################ CONTRIBUTORS #####################################

# @Author   Juan Pablo Gomez <juan.p.gomez@intel>
#
# Dec, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This script checks if lpc device is bound and attributes on sysfs
# @returns
# @history  2017-12-26: First version

############################# FUNCTIONS #######################################
source "common.sh"
source "lpc_common.sh"
source "functions.sh"

check_lpc_sysfs_func() {

  test_print_trc "Checking if LPC Devices are enabled"
  test -d ${ATKBD_SYSFS}
  if [ "$?" -ne 0 ]; then
    test_print_trc "ATKBD or PS2 keyboard is not enabled on sysfs"
  else
    test_print_trc "ATKBD or PS2 keyboard is enabled"
    test_print_trc "==========================================================="
    test_print_trc "Testing ATKBD sysfs"
    test_print_trc "==========================================================="
    for attr in "${ATTRIBUTE_ATKBD[@]}"; do
      check_file "${attr}" "${ATKBD_SYSFS}" || return 1
      test_print_trc "Testing ${attr} sysfs"
    done
  fi

  test_print_trc "Checking if LPC Devices are enabled"
  test -d ${PSMOUSE_SYSFS}
  if [ "$?" -ne 0 ]; then
    test_print_trc "PSMOUSE or PS2 mouse is not enabled on sysfs"
  else
    test_print_trc "PSMOUSE or PS2 mouse is enabled"
    test_print_trc "==========================================================="
    test_print_trc "Testing PSMOUSE sysfs"
    test_print_trc "==========================================================="
    for attr in "${ATTRIBUTE_PSMOUSE[@]}"; do
      check_file "${attr}" "${PSMOUSE_SYSFS}" || return 1
      test_print_trc "Testing ${attr} sysfs"
    done
  fi
return 0
}

check_lpc_sysfs_func
