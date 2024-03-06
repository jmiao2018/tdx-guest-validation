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

# @desc     This script checks if there is any lpc device connected
# @returns
# @history  2017-12-26: First version

############################# FUNCTIONS #######################################
source "common.sh"
source "lpc_common.sh"
source "functions.sh"

check_lpc_devices() {
  test_print_trc "Checking if LPC devices are connected"
  test -d ${PSMOUSE_SYSFS}
  if [ "$?" -ne 0 ]; then
    test_print_trc "PS2/Mouse is not connected"
  else
    test_print_trc "PS Mouse connected and bound"
  fi
  test -d ${ATKBD_SYSFS}
  if [ "$?" -ne 0 ]; then
    test_print_trc "PS2/Keyboard is not connected"
  else
    test_print_trc "PS Mouse connected and bound"
  fi
}

check_lpc_devices
