#!/bin/bash

###############################################################################
#
# Copyright (C) 2015 Intel - http://www.intel.com/
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
#     - Modified script to align to LCK standard.
# Jan, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Ported from LCK-GDC suite to LTP-DDT.
# Feb, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Added 'source "blk_device_common.sh"'.
#     - Added 'check_blk_test_env' function call to check test environment.

############################# DESCRIPTION #####################################

# @desc This script check if D0 is supported for SATA device reading the
#       'Runtime_Active_Counter' file.
# @params
# @return
# @history 2016-01-01: Created an initial draft.
#                      Updated script to align it with LCK standard.
# @history 2016-01-01: Integrated to LTP-DDT.
# @history 2017-02-07: Added 'source "blk_device_common.sh"'.
#                      Added 'check_blk_test_env' function call.
# @history 2018-10-12: Fix $SATA_ID illegal issue when there are multiple devices of sata controller

############################# FUNCTIONS #######################################

############################ DO THE WORK ######################################

source "common.sh"
source "blk_device_common.sh"

# CHECK SATA TEST ENVIRONMENT
check_blk_test_env

# GET SATA ID
SATA_ID_RAW=$(lspci | grep "SATA" | awk '{print $1}')
for SATA_ID in $SATA_ID_RAW;do
  test_print_trc "SATA ID is: ${SATA_ID}"
  break
done

# READ 'Runtime_Active_Counter' ONE TIME
SATA_RUNTIME_ACT_FILE="/sys/bus/pci/devices/0000:${SATA_ID}/power/runtime_active_time"
# Revise for multiple pci root ports platform
[[ -e "${SATA_RUNTIME_ACT_FILE}" ]] \
  || SATA_RUNTIME_ACT_FILE="/sys/bus/pci/devices/${SATA_ID}/power/runtime_active_time"

[[ -e "${SATA_RUNTIME_ACT_FILE}" ]] \
  || die "Sata runtime_active_time file does not exist"

do_cmd "RUN_ACT_TIME_1=$(cat "${SATA_RUNTIME_ACT_FILE}")"
test_print_trc "First read of Runtime_Active_Counter at value:${RUN_ACT_TIME_1}"

test_print_trc "Waiting 10 seconds"
sleep 10

# READ 'Runtime_Active_Counter' SECOND TIME
do_cmd "RUN_ACT_TIME_2=$(cat "${SATA_RUNTIME_ACT_FILE}")"
test_print_trc "Second read of Runtime_Active_Counter at value:${RUN_ACT_TIME_2}"

# COMPARE READINGS
if [[ "${RUN_ACT_TIME_1}" != "${RUN_ACT_TIME_2}" ]]; then
  test_print_trc "SATA driver supports D0"
else
  die "SATA driver DOES NOT support D0"
fi
