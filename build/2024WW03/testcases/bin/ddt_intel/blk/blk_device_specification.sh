#!/bin/bash

################################################################################
#
# Copyright (C) 2017 Intel - http://www.intel.com/
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
#
# File: blk_device_specification.sh
#
# Description: This script checks the device specifications for SATA device
#
# Author(s): Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#
# Contributors: Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#
# Date: Ene 10 2016 - Initial Version.
#
# History: Ene 10 2016 - Created an initial draft.
#                        Updated script to align it with LCK standard.
#          Ene 10 2017 - Added to LTP-DDT
#          Jul 01 2017 - Added source "blk_device_common.sh".
#                        Added 'check_blk_test_env' function call.
#          Nov 27 2017 - Modified - Juan Carlos Alonso
#          - Update File description and Histoy
#          Aug 10 2018 - Modified - Hongyu Ning
#          - Fix bug of $SATA_DEV empty in Simics Environment
#          Oct 12 2018 - Modified - Hongyu Ning
#          - Remove "CD-ROM" device from $SATA_DEV_ID
#
###############################################################################
#
# TODO:
#
################################ Functions ####################################

usage() {
cat <<-EOF >&2
  usage: ./${0##*/} [-e ENUM_DEV] [-g GEN_DEV] [-n NCQ_DEV] [-a AHCI_DEV] [-t HOTPLUG_DEV] [-h]
    -e ENUM_DEV    Look for SATA enumeration device.
    -g GEN_DEV     Check SATA generation device.
    -n NCQ_DEV     Check if SATA device support Native Command Queueing.
    -a AHCI_DEV    Check AHCI driver specification.
    -t HOTPLUG_DEV Check if Hot Plug is supported and enabled.
    -h Help        Print this usage
EOF
exit 0
}

################################# Do the work #################################

source "common.sh"
source "blk_device_common.sh"

while getopts :egnah arg; do
case "${arg}" in
  e)  ENUM_DEV=1 ;;
  g)  GEN_DEV=1 ;;
  n)  NCQ_DEV=1 ;;
  a)  AHCI_DEV=1 ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      die
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      die
      ;;
  esac
done

# CHECK SATA TEST ENVIRONMENT
check_blk_test_env

# DEFAULT VALUES IF NOT SET IN 'getopts'
: ${ENUM_DEV:='0'}
: ${GEN_DEV:='0'}
: ${NCQ_DEV:='0'}
: ${AHCI_DEV:='0'}

SATA_DEV_ID=$(ls /dev/disk/by-id/* \
  | grep -v "DRW" \
  | grep -v "DVD" \
  | grep -v "CD-ROM" \
  | grep -i "ata"-.* \
  | grep -v "part[0-9]")

#fix $SATA_DEV empty bug in Simics Environment
for sata_dev_id in $SATA_DEV_ID
do
  SATA_DEV=$(readlink -e "${sata_dev_id}")
  break
done

# LOOK FOR SATA ENUMERATION DEVICE
if [[ "${ENUM_DEV}" -eq 1 ]]; then
  test_print_trc "Look for SATA enumeration device"
  SATA_ENUM=$(lspci | grep "SATA" | cut -d' ' -f1)
  if [[ -n "${SATA_ENUM}" ]]; then
    test_print_trc "Enumeration of SATA port: ${SATA_ENUM}"
  else
    die "No PCI port was found"
  fi

# CHECK SATA GENERATION DEVICE
elif [[ "${GEN_DEV}" -eq 1 ]]; then
  test_print_trc "Check SATA generation device"
  GENERATION=$(hdparm -iI "${SATA_DEV}" | grep "Gen3" | awk '{print $2}')
  SPEED=$(hdparm -iI "${SATA_DEV}" | grep "Gen3" | awk '{print $5}' | sed 's/[()]//g')

  test_print_trc "SATA GENERATION IS: ${GENERATION}"
  test_print_trc "SATA SPPED IS: ${SPEED}"

  if [[ "${GENERATION}" == "Gen3" ]] && [[ "${SPEED}" == "6.0Gb/s" ]]; then
    test_print_trc "SATA driver supports SATA Gen 3"
  else
    die "SATA driver DOES NOT support SATA Gen 3"
  fi

# CHECK IF SATA DEVICE SUPPORT NATIVE COMMAND QUEUEING
elif [[ "${NCQ_DEV}" -eq 1 ]]; then
  test_print_trc "Check if SATA device support Native Command Queueing"
  NCQ=$(hdparm -iI "${SATA_DEV}" | grep "Native Command Queueing" | awk '{print $5}' | sed 's/[()]//g')
  NCQ_STR=$(hdparm -iI "${SATA_DEV}" | grep "Native Command Queueing")
  NCQ_FLAG=$(dmesg | grep "ahci" | grep "ncq")

  if [[ ! -z "${NCQ}" ]] || [[ ! -z "${NCQ_FLAG}" ]]; then
    test_print_trc "${NCQ_STR}"
    test_print_trc "${NCQ_FLAG}"
    test_print_trc "SATA driver supports Native Command Queueing"
  else
    die "SATA driver DOES NOT support Native Command Queueing"
  fi

# CHECK AHCI SPECIFICATION
elif [[ "${AHCI_DEV}" -eq 1 ]]; then
  test_print_trc "Check SATA AHCI Specification"
  DEVSLP=$(hdparm -iI "${SATA_DEV}" | grep "DEVSLP" | head -1 | sed 's/\t\+//g')
  EXIT_TIMEOUT=$(hdparm -iI "${SATA_DEV}" | grep "Exit Timeout" | sed 's/\t\+//g')
  ASSERTION_TIME=$(hdparm -iI "${SATA_DEV}" | grep "Assertion Time" | sed 's/\t\+//g')
  FLAGS_ARRAY=($(dmesg | grep "ahci" | grep "flags"))
  FLAGS=${FLAGS_ARRAY[@]:4}

  test_print_trc "${DEVSLP}"
  test_print_trc "${EXIT_TIMEOUT}"
  test_print_trc "${ASSERTION_TIME}"
  test_print_trc "${FLAGS}"
fi
