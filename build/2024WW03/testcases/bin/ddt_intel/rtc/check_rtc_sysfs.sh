#!/bin/bash
###############################################################################
# Copyright (C) 2018, Intel - http://www.intel.com
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
# Jan, 2018. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This script checks if RTC device is bound and attributes on sysfs
# @returns
# @history  2018-01-23: First version

############################# FUNCTIONS #######################################
source "common.sh"
source "rtc_common.sh"
source "functions.sh"

check_rtc_sysfs_func() {

  test_print_trc "Checking RTC Devices enabled"
  rtc_devices=$(ls  /dev/rtc0)
  test_print_trc "Devices enabled are: $rtc_devices"
  test_print_trc "Cheking is RTC device is bound"
  symlink="/sys/class/rtc/rtc0"
  test -d ${symlink}
  if [ "$?" -ne 0 ]; then
    test_print_rtc "Your RTC devices is not bound"
  else
    test_print_trc "==========================================================="
    test_print_trc "Testing $rtc_devices sysfs"
    test_print_trc "==========================================================="
    for attr in "${ATTRIBUTE[@]}"; do
      check_file "${attr}" "${symlink}" || return 1
      test_print_trc "Testing ${attr} sysfs"
    done
  fi
  return 0
}

check_rtc_sysfs_func
