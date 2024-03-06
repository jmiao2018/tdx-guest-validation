#!/bin/bash
###############################################################################
# Copyright (C) 2015 Intel - http://www.intel.com
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

# @Author   Luis Rivas(luis.miguel.rivas.zepeda@intel.com)
# @desc     Check required attributes for regultors sysfs
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version

source "pmic_functions.sh"

############################# Functions #######################################
check_regulators_sysfs() {
  local reg=$1
  shift 1

  test_print_trc "Validating $reg core atrributes"
  for core_attr in $CORE_ATTR; do
    check_file $core_attr ${REG_PATH}/${reg} || return 1
  done

  if ! is_reg_sysfs_simplified $reg; then
    test_print_trc "Validating $reg optional atrributes"
    for opt_attr in $OPT_ATTR; do
      check_file $opt_attr ${REG_PATH}/${reg} || return 1
    done
  fi
  return 0
}

############################ Script Variables ##################################
# Define default valus if possible
CORE_ATTR="microvolts name num_users state suspend_disk_state \
           suspend_mem_state suspend_standby_state uevent"

OPT_ATTR="max_microvolts min_microvolts"

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.
for_each_regulator check_regulators_sysfs || die "Error on regulators sysfs"
