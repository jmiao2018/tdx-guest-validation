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
# @Author   Hongyu, Ning <hongyu.ning@intel.com>
#
# Dec, 04, 2018. Hongyu, Ning <hongyu.ning@intel.com>
#     - Initial version, calling mtd-utils binary flash_erase & mtdinfo
#       to execute different spi-nor mtd device test

############################ DESCRIPTION ######################################

# @desc     This script is based on mtd-utils binary flash_erase & mtdinfo
#           to execute different spi-nor mtd BIOS device functional test
# @returns
# @history  2018-12-04: First version

############################# FUNCTIONS #######################################
usage() {
 cat <<-EOF
 usage: ./${0##*/} [-r CASE to run] [-h Help]
 -r WRITABLE_TEST|WRITE_PROTECTION|BIOS_BACKUP_TEST   CASE to run
 -h Help        print this usage
EOF
}

#function to switch spi-nor mtd device to writable (intel_spi.writeable=1)
#or not writable (intel_spi.writeable=0)
#writable value passed through function args $1
switch_mtd_writable() {
  local writable=$1
  lsmod | grep -wq ${DRV_MOD_NAME_3} || die "There is no module loaded: ${DRV_MOD_NAME_3}"
  test_print_trc "to remove module ${DRV_MOD_NAME_3}"
  rmmod ${DRV_MOD_NAME_3} || die "Failed to remove module: ${DRV_MOD_NAME_3}"
  lsmod | grep -wq ${DRV_MOD_NAME_2} || die "There is no module loaded: ${DRV_MOD_NAME_2}"
  test_print_trc "to remove module ${DRV_MOD_NAME_2}"
  rmmod ${DRV_MOD_NAME_2} || die "Failed to remove module: ${DRV_MOD_NAME_2}"
  test_print_trc "to probe module ${DRV_MOD_NAME_2} with writable parameter: ${writable}"
  modprobe ${DRV_MOD_NAME_2} writeable=${writable} || \
    die "Failed to probe module ${DRV_MOD_NAME_2} with writable parameter: ${writable}"
  test_print_trc "to probe module ${DRV_MOD_NAME_3}"
  modprobe ${DRV_MOD_NAME_3} || die "Failed to probe module ${DRV_MOD_NAME_3}"
  test_print_trc "SPI-NOR device: ${DEVICE} changed to writable: ${writable}"
}

#function to check if mtd device is writable or not based on binary mtdinfo return
#mtd device is writable: $INTEL_SPI_WRITEABLE=1
#mtd device is not writable: $INTEL_SPI_WRITEABLE=0
mtd_writable_chk() {
  local name
  local mtd_type
  local writable
  INTEL_SPI_WRITEABLE=0
  name=$(mtdinfo ${DEVICE} | grep -i 'name' | awk '{print $NF}')
  mtd_type=$(mtdinfo ${DEVICE} | grep -i 'type' | awk '{print $NF}')
  writable=$(mtdinfo ${DEVICE} | grep -i 'writable' | awk '{print $NF}')
  if [ ${name} = 'BIOS' ]; then
    test_print_trc "mtd device to check ${DEVICE} is ${name}"
  else
    die "mtd device to check ${DEVICE} is ${name}, not expected (BIOS)"
  fi
  if [ ${mtd_type} = 'nor' ]; then
    test_print_trc "mtd device to check ${DEVICE} is type of ${mtd_type}"
  else
    die "mtd device to check ${DEIVCE} is type of ${mtd_type}, not expected (nor)"
  fi
  if [ ${writable} = 'true' ]; then
    test_print_trc "mtd device to check ${DEVICE} is writable"
    INTEL_SPI_WRITEABLE=1
  elif [ ${writable} = 'false' ]; then
    test_print_trc "mtd device to check ${DEVICE} is not writable"
    INTEL_SPI_WRITEABLE=0
  else
    die "mtd device to check ${DEVICE} is not writable, ${writable} value not expected (true or false)"
  fi
}

#function to find the bios mtd device for SPI-NOR BIOS mtd device functional test
#bios mtd device for test: $DEVICE & $DEVICE_RO (read only)
find_bios_mtd() {
  local device
  device=$(cat /proc/mtd | grep -i 'BIOS' | awk -F: '{print $1}') || \
    die "cannot find SPI-NOR BIOS device under /proc/mtd, please check BIOS and kernel setting"
  DEVICE=/dev/${device}
  DEVICE_RO=/dev/${device}ro
  test_print_trc "Found SPI-NOR BIOS mtd device ${DEVICE} & ${DEVICE_RO}"
}

#function to do bios mtd device BIOS backup operation
#backup successful: $BIOS_BAK_SUCCEED=1, bios back file: $BIOS_BACKUP
#backup fail, including checksum comparison failure: $BIOS_BAK_SUCCEED=0
mtd_bios_backup() {
  BIOS_BACKUP=bios.bak
  local chk_sum=chk_sum_cmp
  local chk_sum_bios
  local chk_sum_bios_bak
  BIOS_BAK_SUCCEED=0
  if [ -f ${BIOS_BACKUP} ]; then
    rm ${BIOS_BACKUP} || die "can't remove previous bios backup file: ${BIOS_BACKUP}"
    touch ${BIOS_BACKUP}
  else
    touch ${BIOS_BACKUP}
  fi
  test_print_trc "Start to backup bios from ${DEVICE_RO}"
  dd if=${DEVICE_RO} of=${BIOS_BACKUP} || die "Failed to backup bios from ${DEVICE_RO}"
  sha1sum ${DEVICE} ${BIOS_BACKUP} > ${chk_sum} || die "Failed to calculate checksum on ${DEVICE} & ${BIOS_BACKUP}"
  chk_sum_bios=$(cat ${chk_sum} | grep ${DEVICE} | awk '{print $1}')
  chk_sum_bios_bak=$(cat ${chk_sum} | grep ${BIOS_BACKUP} | awk '{print $1}')
  if [ ${chk_sum_bios} = ${chk_sum_bios_bak} ]; then
    test_print_trc "bios backup succeed, backup file is ${BIOS_BACKUP}"
    BIOS_BAK_SUCCEED=1
  else
    BIOS_BAK_SUCCEED=0
    rm ${BIOS_BACKUP}
    die "Failed on bios backup checksum checking between ${DEVICE} & ${BIOS_BACKUP}"
  fi
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"
source "spi_nor_common.sh"

DEVICE='/dev/mtd0'
DEVICE_RO='/dev/mtd0ro'

#Try to find the SPI-NOR BIOS device on platform
find_bios_mtd

while getopts :r:h arg; do
  case $arg in
    r)
      TESTCASE=$OPTARG
      ;;
    h)
      usage && exit 0
      ;;
    :)
      test_print_err "Must supply an argument to -$OPTARG."
      usage && exit 1
      ;;
    \?)
      test_print_err "Invalid Option -$OPTARG ignored."
      usage && exit 1
      ;;
  esac
done

case $TESTCASE in
  WRITABLE_TEST)
    #run test to check SPI-NOR BIOS device writable parameter setting function
    test_print_trc "Run SPI-NOR BIOS WRITABLE switch test"
    #by default SPI-NOR BIOS device should be not writable
    mtd_writable_chk
    if [ ${INTEL_SPI_WRITEABLE} -eq 0 ]; then
      test_print_trc "SPI-NOR BIOS device ${DEVICE} is not writable, as expected"
    else
      die "SPI-NOR BIOS device ${DEVICE} should not be writable by default, test FAIL"
    fi
    #switch SPI-NOR BIOS device to writable
    switch_mtd_writable 1
    mtd_writable_chk
    if [ ${INTEL_SPI_WRITEABLE} -eq 1 ]; then
      test_print_trc "SPI-NOR BIOS device ${DEVICE} is switched to writable, as expected"
    else
      die "SPI-NOR BIOS device ${DEVICE} can't be switched to writable, test FAIL"
    fi
    #switch SPI-NOR BIOS device to not writable again
    switch_mtd_writable 0
    mtd_writable_chk
    if [ ${INTEL_SPI_WRITEABLE} -eq 0 ]; then
      test_print_trc  "SPI-NOR BIOS device ${DEVICE} is not writable, as expected"
    else
      die "SPI-NOR BIOS device ${DEVICE} can't be switched to not writable, test FAIL"
    fi
    exit 0
    ;;
  WRITE_PROTECTION)
    #run test to check write protection when mtd device is not writable
    switch_mtd_writable 0
    mtd_writable_chk
    if [ ${INTEL_SPI_WRITEABLE} -eq 0 ]; then
      #backup the bios before flash_erase operation
      mtd_bios_backup
      if [ ${BIOS_BAK_SUCCEED} -eq 1 ]; then
        flash_erase ${DEVICE} 0 0
        if [ $? -ne 0 ]; then
          test_print_trc "SPI-NOR BIOS mtd device writable protection check PASS"
          exit 0
        else
          test_print_err "SPI-NOR BIOS mtd device writable protection check FAIL"
          test_print_wrn "SPI-NOR BIOS has been erased, flash back the backup BIOS now"
          dd if=${BIOS_BACKUP} of=${DEVICE} || \
            die "Failed to flash back the backup bios file"
          sha1sum ${BIOS_BACKUP} ${DEVICE_RO} || \
            die "Failed to do the checksum checking after flashback the backup bios file"
          test_print_wrn "Please check the above checksum results manually on /\
            '${BIOS_BACKUP}' and '${DEVICE_RO}' "
          test_print_wrn "checksum results must be exactly the same, /\
            and then you may reboot the platform to recover the bios. "
          test_print_wrn "In case above checksum results are different, /\
            PLEASE MANUALLY FLASH BACK THE ${BIOS_BACKUP} to ${DEVICE} and do checksum again: "
          test_print_wrn "cmd: dd if=${BIOS_BACKUP} of=${DEVICE} /\
            sha1sum ${BIOS_BACKUP} ${DEVICE_RO} "
          exit 1
        fi
      else
        test_print_err "SPI-NOR BIOS mtd device backup FAIL, cannot do write protection test."
        exit 1
      fi
    else
      die "SPI-NOR BIOS mtd device is writable, cannot do write protection test."
    fi
    ;;
  BIOS_BACKUP_TEST)
    #run test to check spi-nor mtd device BIOS backup function
    test_print_trc "Run SPI-NOR BIOS device backup functional test"
    mtd_bios_backup
    if [ ${BIOS_BAK_SUCCEED} -eq 1 ]; then
      test_print_trc "SPI-NOR BIOS device backup test PASS"
      exit 0
    else
      test_print_err "SPI-NOR BIOS device backup test FAIL"
      exit 1
    fi
    ;;
  :)
    test_print_err "Must specify the test case option by [-r WRITABLE_TEST|WRITE_PROTECTION|BIOS_BACKUP_TEST]"
    usage && exit 1
    ;;
  \?)
    test_print_err "Input test case option $CASE is not supported"
    usage && exit 1
    ;;
esac
