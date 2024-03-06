#!/bin/bash

###############################################################################
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
# File: gpio_chips.sh
#
# Description: This script look for GPIO chips and the GPIO numbers at sysfs.
#              Also export/unexport GPIOs ang get its signals.
#
# Author(s): Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#
# Contributors: Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#
# Date: Aug 01 2017 - First version.
#
# History: Aug 01 2017 - Initial version - Juan Carlos Alonso
#          Dec 08 2017 - Update - Juan Carlos Alonso
#          - Added 'export_gpios()' to export GPIOs.
#          - Added 'get_signals()' to get GPIO signals.
#
###############################################################################
#
# TODO:
#
############################ Functions ########################################

get_gpio_chips() {

  NUM_OF_CHIPS=$(ls "${DRV_SYS_PATH}" | grep -c "gpiochip")
  GPIO_CHIPS=($(ls "${DRV_SYS_PATH}" | grep "gpiochip"))

  test_print_trc "${MACHINE} has ${NUM_OF_CHIPS} chips:"

  if [[ "${NUM_OF_CHIPS}" -gt 0 ]]; then
    for chip in "${GPIO_CHIPS[@]}"; do
      test_print_trc "GPIO CHIP: ${chip}"
    done
    return 0
  else
    die "There is not GPIO Chips on ${MACHINE}"
  fi
}

get_gpios() {

  gpio_export=$1
  gpio_signal=$2

  GPIO_CHIPS=($(ls "${DRV_SYS_PATH}" | grep "gpiochip")) || die "No gpio chips"

  for chip in "${GPIO_CHIPS[@]}"; do

    do_cmd get_gpio_numbers "${chip}"

    test_print_trc "---------------------------"
    test_print_trc "GPIO Chip:      ${chip}"
    test_print_trc "GPIO Base:      ${GPIO_BASE}"
    test_print_trc "N GPIO:         ${N_GPIO}"
    test_print_trc "Total of GPIOs: ${N_GPIO}"
    test_print_trc "From \"gpio${GPIO_BASE}\" to \"gpio${GPIO_COUNT}\""

    if [[ "${gpio_export}" -eq 1 ]]; then
      export_gpios "${gpio_signal}"
    fi
  done
}

get_gpio_numbers() {

  CHIP=$1
  GPIO_COUNT=""

  [[ -d "${DRV_SYS_PATH}" ]] || die "${DRV_SYS_PATH} does not exists!."

  GPIO_BASE=$(cat "${DRV_SYS_PATH}/${CHIP}/base")
  N_GPIO=$(cat "${DRV_SYS_PATH}/${CHIP}/ngpio")

  if [[ -n "${GPIO_BASE}" ]] && [[ -n "${N_GPIO}" ]]; then
    for (( i=0; i < N_GPIO; i++ ))
    do
      GPIO_COUNT=$(( GPIO_BASE + i ))
      GPIOS+=(${GPIO_COUNT})
    done
    return 0
  else
    die "BASE and LABEL attributes don't exists"
  fi
}

export_gpios() {

  signals=$1

  test_print_trc "==> Export / Unexport GPIOs"
  for (( i=GPIO_BASE; i < GPIO_COUNT + 1; i++ ))
  do
    for gpio_skip in $GPIO_NUM_SKIPPED; do
      if [[ "${i}" -eq "${gpio_skip}" ]]; then
        test_print_trc "Skip GPIO ${i}"
        i=$(( i + 1 ))
        continue 2
      fi
    done

    test_print_trc "Export GPIO ${i}"
    do_cmd "echo ${i} > ${DRV_SYS_PATH}/export"
    sleep 2

    if [[ "${signals}" -eq 1 ]]; then
      do_cmd get_signals "${i}"
    fi

    test_print_trc "Unexport GPIO ${i}"
    do_cmd "echo ${i} > ${DRV_SYS_PATH}/unexport"
    sleep 2
  done
}

get_signals() {

  gpio_num=$1

  test_print_trc "==> Get GPIO ${gpio_num} Signals"
  direction=$(cat "${DRV_SYS_PATH}/gpio${gpio_num}/direction")
  value=$(cat "${DRV_SYS_PATH}/gpio${gpio_num}/value")
  edge=$(cat "${DRV_SYS_PATH}/gpio${gpio_num}/edge")
  active_low=$(cat "${DRV_SYS_PATH}/gpio${gpio_num}/active_low")

  if [[ -n "${direction}" ]] && [[ -n "${value}" ]] && [[ -n "${edge}" ]] && [[ -n "${active_low}" ]]; then
    test_print_trc "Direction:${direction}"
    test_print_trc "Value:${value}"
    test_print_trc "Edge:${edge}"
    test_print_trc "Active_Low:${active_low}"
    return 0
  else
    die "Cannot get GPIO ${gpio_num} signals"
  fi
}

############################ Do the work ######################################

source "common.sh"
source "gpio_common.sh"

while getopts :l:g:t:i:a:esfh arg
do case $arg in
  l)  TEST_LOOP="$OPTARG" ;;
  g)  GET="$OPTARG" ;;
  t)  SYSFS_TESTCASE="$OPTARG" ;;
  i)  TEST_INTERRUPT="$OPTARG" ;;
  f)  CTRL_INTERFACE="1" ;;
  a)  ACTION="$OPTARG" ;;
  e)  EXPORT="1" ;;
  s)  SIGNALS="1" ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG"
      exit 1
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored"
      usage
      exit 1
      ;;
  esac
done

# Default parameters
: ${TEST_LOOP:='1'}
: ${EXPORT:='0'}
: ${SIGNALS:='0'}
: ${TEST_INTERRUPT:='0'}
: ${CTRL_INTERFACE:='0'}

# Debug prints
test_print_trc "STARTING GPIO TEST"
test_print_trc "TEST_LOOP: ${TEST_LOOP}"

# Get GPIOs
if [[ -n "${GET}" ]]; then
  case "${GET}" in
    chips) test_print_trc "==> Get GPIO Chips"
           get_gpio_chips
           ;;
    gpios) test_print_trc "==> Get GPIO Numbers"
           get_gpios "${EXPORT}" "${SIGNALS}"
           ;;
  esac
fi

# Check Interfaces in Sysfs
if [[ "${CTRL_INTERFACE}" -eq "1" ]]; then

  test_print_trc "Check Control Interfaces"

  [[ -e "${DRV_SYS_PATH}/export" ]] || die "\"export\" control interface does not exists!"
  [[ -e "${DRV_SYS_PATH}/unexport" ]] || die "\"unexport\" control interface does not exists!"

  test_print_trc "Control Interfaces Exists:"
  test_print_trc "${DRV_SYS_PATH}/export"
  test_print_trc "${DRV_SYS_PATH}/unexport"
fi
