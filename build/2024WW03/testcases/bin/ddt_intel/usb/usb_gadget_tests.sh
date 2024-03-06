#!/bin/bash
#
# Copyright 2016 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Jun. 25, 2016 - (Ammy Yi)Creation


# @desc This script verify usb gadget test
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage()
{
  cat <<__EOF
  usage: ./${0##*/}  [-m GADGET_MODE] [-t GADGET_TEST_METHOD][-H]
  -m  gadget mode, such as serial
  -t  gadget test method, such as configfs
  -H  show This
__EOF
}
: ${WAITTIME:=5}
: ${VIDN:="0"}
: ${PRODUCTID:="0"}
#####usb serial test#######
#####test with configfs############
gadget_serial_configfs_test()
{
  GPATH="g1"
  teardown_handler="configfs_teardown"
  configfs_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb serial device fail to enumrate!"
  fi
#  serial_check || die "usb serial test failed!"
}

#####usb serial test#######
#####test with module############
gadget_serial_module_test()
{
  MODULE_NAME="g_serial"
  teardown_handler="module_teardown"
  module_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb serial device fail to enumrate!"
  fi
#  serial_check || die "usb serial test failed!"
}

#####usb mass storage test#######
#####test with configfs############
gadget_storage_configfs_test()
{
  speed="5000"
  GPATH="g2"
  bs="1M"
  count=10
  temp_file="/dev/shm/file"
  do_cmd "dd if=/dev/zero of=$temp_file bs=$bs count=$count"
  teardown_handler="configfs_teardown"
  configfs_setup "storage" $temp_file
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb mass storage device fail to enumrate!"
  fi
  usb_speed_check $speed || die "usb mass storage speed check failed!"
  mass_storage_check $bs $count|| die "usb storage configfs test failed!"
}


#####usb mass storage test#######
#####test with module############
gadget_storage_module_test()
{
  MODULE_NAME="g_mass_storage"
  speed="5000"
  bs="1M"
  count=10
  temp_file="/dev/shm/file"
  module_p="file="$temp_file
  do_cmd "dd if=/dev/zero of=$temp_file bs=$bs count=$count"
  teardown_handler="module_teardown"
  module_setup $module_p
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb mass storage device fail to enumrate!"
  fi
  usb_speed_check $speed || die "usb mass storage speed check failed!"
  mass_storage_check $bs $count|| die "usb storage module test failed!"
}

#####usb midi test#######
#####test with configfs############
gadget_midi_configfs_test()
{
  GPATH="g3"
  teardown_handler="configfs_teardown"
  configfs_setup "midi"
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb midi device fail to enumrate!"
  fi
  usb_midi_check || die "usb midi device check failed!"
}

#####usb midi test#######
#####test with module############
gadget_midi_module_test()
{
  MODULE_NAME="g_midi"
  teardown_handler="module_teardown"
  module_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb midi device fail to enumrate!"
  fi
  usb_midi_check || die "usb midi device check failed!"
}

#####usb rndis test#######
#####test with configfs############
gadget_rndis_configfs_test()
{
  GPATH="g4"
  teardown_handler="configfs_teardown"
  configfs_setup "rndis"
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb rndis device fail to enumrate!"
  fi
  usb_rndis_check || die "usb rndis device check failed!"
}

#####usb rndis test#######
#####test with module############
gadget_rndis_module_test()
{
  MODULE_NAME="g_ether"
  teardown_handler="module_teardown"
  module_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb rndis device fail to enumrate!"
  fi
  usb_rndis_check || die "usb rndis device check failed!"
}

#####usb printer test#######
#####test with configfs############
gadget_printer_configfs_test()
{
  GPATH="g5"
  teardown_handler="configfs_teardown"
  configfs_setup "printer"
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb printer device fail to enumrate!"
  fi
  usb_printer_check || die "usb printer device check failed!"
}

#####usb printer test#######
#####test with module############
gadget_printer_module_test()
{
  MODULE_NAME="g_printer"
  teardown_handler="module_teardown"
  module_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb printer device fail to enumrate!"
  fi
  usb_printer_check || die "usb printer device check failed!"
}

#####usb audio1 test#######
#####test with configfs############
gadget_audio1_configfs_test()
{
  GPATH="g6"
  teardown_handler="configfs_teardown"
  configfs_setup "uac1"
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb audio device fail to enumrate!"
  fi
  usb_audio_check || die "usb audio device check failed!"
}

#####usb audio test#######
#####test with module############
gadget_audio_module_test()
{
  MODULE_NAME="g_audio"
  teardown_handler="module_teardown"
  module_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb audio device fail to enumrate!"
  fi
  usb_audio_check || die "usb audio device check failed!"
}
#####usb audio2 test#######
#####test with configfs############
gadget_audio2_configfs_test()
{
  GPATH="g6"
  teardown_handler="configfs_teardown"
  configfs_setup "uac2"
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb audio device fail to enumrate!"
  fi
  usb_audio_check || die "usb audio device check failed!"
}

#####usb webcam test#######
#####test with module############
gadget_webcam_module_test()
{
  MODULE_NAME="g_webcam"
  teardown_handler="module_teardown"
  num1=$(ls /dev/ | grep -c video)
  module_setup
  sleep $WAITTIME
  num2=$(ls /dev/ | grep -c video)
  if [ $num1 -eq $num2 ]; then
    die "usb webcam device fail to enumrate!"
  fi
}

#####usb zero test#######
#####test with module############
gadget_zero_module_test()
{
  MODULE_NAME="g_zero"
  teardown_handler="module_teardown"
  module_setup
  sleep $WAITTIME
  lsusb | grep -q "$VIDN:$PRODUCTIDN"
  if [ $? -ne 0 ]; then
    die "usb zero device fail to enumrate!"
  fi
}

# verify kconfig values with gadget
gadget_kconfig_check(){
  local gadget_config[0]=CONFIG_USB_GADGET
  local gadget_config[1]=CONFIG_USB_CONFIGFS
  local gadget_config[2]=CONFIG_USB_ZERO
  for i in "${gadget_config[@]}"; do
    if [[ $(get_kconfig $i) =~ [ym] ]]; then
      test_print_trc "get $i kconfig value $(get_kconfig $i)"
    else
      die  "fail to verify $i Kconfig value"
    fi
  done
}

main()
{
  check_test_env
  VID=0x0525
  VIDN="0525"
  case $GADGET_MODE in
    serial)
      GNAME="gser"
      PRODUCTID=0xa4a7
      PRODUCTIDN="a4a7"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_serial_configfs_test
      elif [[ $GADGET_TEST_METHOD = "module" ]]; then
        gadget_serial_module_test
      fi
      ;;
    storage)
      GNAME="mass_storage"
      PRODUCTID=0xa4a5
      PRODUCTIDN="a4a5"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_storage_configfs_test
      elif [[ $GADGET_TEST_METHOD = "module" ]]; then
        gadget_storage_module_test
      fi
      ;;
    midi)
      GNAME="midi"
      VID=0x17b3
      VIDN="17b3"
      PRODUCTID=0x0004
      PRODUCTIDN="0004"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_midi_configfs_test
      elif [[ $GADGET_TEST_METHOD = "module" ]]; then
        gadget_midi_module_test
      fi
      ;;
    rndis)
      GNAME="rndis"
      PRODUCTID=0xa4a2
      PRODUCTIDN="a4a2"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_rndis_configfs_test
      elif [[ $GADGET_TEST_METHOD = "module" ]]; then
        gadget_rndis_module_test
      fi
      ;;
    printer)
      GNAME="printer"
      PRODUCTID=0xa4a8
      PRODUCTIDN="a4a8"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_printer_configfs_test
      elif [[ $GADGET_TEST_METHOD = "module" ]]; then
        gadget_printer_module_test
      fi
      ;;
    audio1)
      GNAME="uac1"
      VID=0x1d6b
      PRODUCTID=0x0101
      VIDN="1d6b"
      PRODUCTIDN="0101"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_audio1_configfs_test
      elif [[ $GADGET_TEST_METHOD = "module" ]]; then
        gadget_audio_module_test
      fi
      ;;
    audio2)
      GNAME="uac2"
      VID=0x1d6b
      PRODUCTID=0x0101
      VIDN="1d6b"
      PRODUCTIDN="0101"
      if [[ $GADGET_TEST_METHOD = "configfs" ]]; then
        gadget_audio2_configfs_test
      fi
      ;;
    webcam)
      gadget_webcam_module_test
      ;;
    zero)
      GNAME="zero"
      PRODUCTID=0xa4a0
      PRODUCTIDN="a4a0"
      gadget_zero_module_test
      ;;
    kconfig)
      gadget_kconfig_check
      ;;
    H)
      usage && exit 1
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
}

while getopts :m:t:H: arg
do
  case $arg in
    m)
      GADGET_MODE=$OPTARG
      ;;
    t)
      GADGET_TEST_METHOD=$OPTARG
      ;;
    H)
      usage && exit 1
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

usb_setup
main
usb_trace_check || die "usb log check fail, please check detailed trace and dmesg logs!"
usb_log_teardown
# Call teardown for passing case
exec_teardown
