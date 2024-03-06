#!/bin/bash
#
# Copyright 2017 Intel Corporation
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
#             Jul. 25, 2017 - (Ammy Yi)Creation


# @desc This script verify usb typec test
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-t $TEST_SCENARIO][-H]
  -t  test scenario
  -H  show This
__EOF
}

: ${TEST_SCENARIO:=""}
: ${TYPEC_PATH:="/sys/class/typec"}
: ${TYPEC_PORT:=""}
: ${TEARDOWN_FLAG:=0}
: ${DEFAULT_VALUE:=""}

# This function check sysinfo for typec
sysfsinfo_check() {
  ls $TYPEC_PATH || die "usb typec sysfs interface check fail!"
  TYPEC_PORT=$(ls $TYPEC_PATH | grep "port[0-9]$")
  test_print_trc "TYPEC_PORT = $TYPEC_PORT"
  [[ -z $TYPEC_PORT ]] && die "usb typec port check fail!"
  return 0
}

# This function check typec data role value
datarole_value_check() {
  local host_id=""
  local device_id=""
  TYPEC_PORT=$(ls $TYPEC_PATH | grep "port[0-9]$")
  [[ -z $TYPEC_PORT ]] && die "get usb typec port fail!"
  for node in $TYPEC_PORT
  do
    cat $TYPEC_PATH/$node/data_role | grep device
    data_value_1=$?
    cat $TYPEC_PATH/$node/data_role | grep host
    data_value_2=$?
    [[ $data_value_1 -eq 1 ]] && [[ $data_value_2 -eq 1 ]] && die "get usb typec port data_value fail!"
  done
  return 0
}


# This function check typec data role set function
datarole_value_set_check() {
  MODULE_NAME="g_zero"
  teardown_handler="module_teardown"
  module_setup
  TYPEC_PORT=$(ls $TYPEC_PATH | grep partner | cut -d "-" -f1)
  [[ -z $TYPEC_PORT ]] && die "get usb typec port fail which will check partner!"
  for node in $TYPEC_PORT
  do
    data_role_value=$(cat $TYPEC_PATH/$node/data_role)
    data_role_value="${data_role_value//\[[a-z]*\]/}"
    test_print_trc "Will try to set $data_role_value for $node !"
    do_cmd "echo $data_role_value > $TYPEC_PATH/$node/data_role"
  done
  return 0
}

# This function check typec power role value
powerrole_value_check() {
  TYPEC_PORT=$(ls $TYPEC_PATH | grep "port[0-9]$")
  [[ -z $TYPEC_PORT ]] && die "get usb typec port fail!"
  for node in $TYPEC_PORT
  do
    cat $TYPEC_PATH/$node/power_role | grep source
    power_value_1=$?
    cat $TYPEC_PATH/$node/power_role | grep sink
    power_value_2=$?
    [[ $power_value_1 -eq 1 ]] && [[ $power_value_2 -eq 1 ]] && die "get usb typec port power_role fail!"
  done
  return 0
}


# This function check typec port_type value
port_type_value_check() {
  [[ $DEFAULT_VALUE = "" ]] && DEFAULT_VALUE="dual"
  TYPEC_PORT=$(ls $TYPEC_PATH | grep "port[0-9]$")
  [[ -z $TYPEC_PORT ]] && die "get usb typec port fail!"
  for node in $TYPEC_PORT
  do
    cat $TYPEC_PATH/$node/port_type | grep source
    port_value_1=$?
    cat $TYPEC_PATH/$node/port_type | grep sink
    port_value_2=$?
    cat $TYPEC_PATH/$node/port_type | grep dual
    port_value_3=$?
    [[ $port_value_1 -eq 1 ]] && [[ $port_value_2 -eq 1 ]] && [[ $port_value_3 -eq 1 ]] && die "get usb typec port port_type fail!"
  done
  return 0
}

default_value_check() {
  local point_value=$2
  [[ $DEFAULT_VALUE = "" ]] && DEFAULT_VALUE=$1
  TYPEC_PORT=$(ls $TYPEC_PATH | grep "port[0-9]$")
  [[ -z $TYPEC_PORT ]] && die "get usb typec port fail!"
  for node in $TYPEC_PORT
  do
    get_value=$(cat $TYPEC_PATH/$node/$point_value)
    [[ -z $get_value ]] && die "usb typec $point_value value check fail!"
  done
  return 0
}

# This function check typec power role set function
powerrole_value_set_check() {
  MODULE_NAME="g_zero"
  teardown_handler="module_teardown"
  module_setup
  TYPEC_PORT=$(ls $TYPEC_PATH | grep partner | cut -d "-" -f1)
  [[ -z $TYPEC_PORT ]] && die "get usb typec port fail which will check partner!"
  for node in $TYPEC_PORT
  do
    power_role_value=$(cat $TYPEC_PATH/$node/power_role)
    power_role_value="${power_role_value//\[[a-z]*\]/}"
    test_print_trc "Will try to set $power_role_value for $node !"
    do_cmd "echo $power_role_value > $TYPEC_PATH/$node/power_role"
  done
  return 0
}

# verify kconfig values with typec
typec_kconfig_check(){
  local typec_config[0]=CONFIG_TYPEC
  local typec_config[1]=CONFIG_TYPEC_TCPM
  local typec_config[2]=CONFIG_TYPEC_TCPCI
  local typec_config[3]=CONFIG_TYPEC_UCSI
  local typec_config[4]=CONFIG_UCSI_ACPI
  for i in "${typec_config[@]}"; do
    if [[ $(get_kconfig $i) =~ [ym] ]]; then
      test_print_trc "get $i kconfig value $(get_kconfig $i)"
    else
      die  "fail to verify $i Kconfig value"
    fi
  done
}

# verify module values with typec
typec_module_check(){
  local typec_module[0]="typec_ucsi"
  local typec_module[1]="tps6598x"
  for module in "${typec_module[@]}"; do
    lsmod | grep typec | grep "$module"
    if [[ $? == 0 ]]; then
      test_print_trc "typec module check PASS"
      return
    fi
  done
  die "typec module check fail"
}

#verify if connect a storage will generate a partner point
storage_partner_check(){
  ls $TYPEC_PATH | grep partner
  [[ $? -ne 0 ]] && die "typec module check fail"
}

main() {
  case $TEST_SCENARIO in
    sysfsinfo)
      sysfsinfo_check
      ;;
    datap)
      TEARDOWN_FLAG=1
      datarole_value_check
      ;;
    datas)
      TEARDOWN_FLAG=1
      datarole_value_set_check
      ;;
    powerp)
      powerrole_value_check
      ;;
    powers)
      TEARDOWN_FLAG=1
      powerrole_value_set_check
      ;;
    kconfig)
      TEARDOWN_FLAG=1
      typec_kconfig_check
      ;;
    module)
      TEARDOWN_FLAG=1
      typec_module_check
      ;;
    port_type)
      port_type_value_check
      ;;
    vconn_source)
      default_value_check "no" "vconn_source"
      ;;
    power_operation_mode)
      default_value_check "default" "power_operation_mode"
      ;;
    supported_accessory_modes)
      default_value_check "none" "supported_accessory_modes"
      ;;
    all)
      path_all_polling_check "$TYPEC_PATH"
      ;;
    storage)
      storage_partner_check
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
  esac
}

while getopts :t:d:H: arg
do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
      usage && exit 1
      ;;
    d)
      DEFAULT_VALUE=$OPTARG
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
