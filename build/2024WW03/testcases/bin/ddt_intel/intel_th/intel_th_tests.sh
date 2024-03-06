#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA
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
#             Oct. 10, 2018 - (Ammy Yi)Creation


# @desc This script verify perf unit test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
source "dmesg_functions.sh"

: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -s  SOURCE TYPE
  -d  TEST DEVICE PONIT
  -p  PROFILE
  -i  IOMMU status
  -m  low power mode status
  -H  show this
__EOF
}

CONFIG_PATH="/config"
SYSFS_PATH="/sys/bus/intel_th/devices/"
SOURCE_PATH="/sys/class/stm_source/"
SOURCE="default"
PROFILE="basic"
DEV_POINT=""
TRACEINFO="th_test"
DEBUG_PATH="/debug"
OUTPUT=""
trace_end_times=0
lfile="ddt_intel/intel_th/msc_raw.out"
bfile="ddt_intel/intel_th/msc_raw_npktool.out"
LPOWER="NONE"
CON=0

policy_enable() {
  policy_name=$1
  [[ -d "$CONFIG_PATH" ]] || mkdir "$CONFIG_PATH"
  if ! grep -q "CONFIG_PATH" /proc/mounts; then
    mount -t configfs none "$CONFIG_PATH"
  else
    umount "$CONFIG_PATH"
    mount -t configfs none "$CONFIG_PATH"
  fi
  # mount -t configfs none $CONFIG_PATH
  [[ -d "$CONFIG_PATH"/stp-policy/"$policy_name" ]] || mkdir "$CONFIG_PATH"/stp-policy/"$policy_name"
}

policy_source_set() {
  policy_name=$1
  SOURCE_NAME=$2
  [[ -d "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE_NAME" ]] || mkdir "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE_NAME"
}


policy_master_set() {
  policy_name=$1
  SOURCE_NAME=$2
  value_1=$3
  value_2=$4
  min=$(cat "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE_NAME"/masters | awk '{print $1}')
  max=$(cat "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE_NAME"/masters | awk '{print $2}')
  if [[ $value_1 < $min ]] || [[ $value_2 > $max ]]; then
    value_1=$min
    value_2=$max
  fi
  test_print_trc "value_1=$value_1,  value_2=$value_2"
  do_cmd "echo $value_1 $value_2 > $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME/masters"
}

policy_channel_set() {
  policy_name=$1
  SOURCE_NAME=$2
  value_1=$3
  value_2=$4
  min=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME/channels | awk '{print $1}')
  max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME/channels | awk '{print $2}')
  if [[ $value_1 < $min ]] || [[ $value_2 > $max ]]; then
    value_1=$min
    value_2=$max
  fi
  test_print_trc "value_1=$value_1,  value_2=$value_2"
  do_cmd "echo $value_1 $value_2 > $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME/channels"
}

policy_clear() {
  if [ -d "$CONFIG_PATH"/stp-policy ]; then
    find "$CONFIG_PATH"/stp-policy/* -type d | sort -dr | xargs rmdir
  fi
  mount | grep -w "$CONFIG_PATH"
  [[ $? -eq 0 ]] && umount $CONFIG_PATH
}

gth_set() {
  port_id=$1
  gth_id=$2
  master=$3
  echo "$port_id" > "$SYSFS_PATH"/"$gth_id"-gth/masters/0
  echo "$port_id" > "$SYSFS_PATH"/"$gth_id"-gth/masters/32
  echo "$port_id" > "$SYSFS_PATH"/"$gth_id"-gth/masters/64
  echo "$port_id" > "$SYSFS_PATH"/"$gth_id"-gth/masters/"$master"
}

trace_enable() {
  point=$1
  echo 1 > $SYSFS_PATH/$point/active
}

trace_disable() {
  point=$1
  echo 0 > $SYSFS_PATH/$point/active
}

clear_sink() {
  ids=$(ls $SYSFS_PATH | grep msc | xargs)
  for id in $ids; do
    grep sink $SYSFS_PATH/$id/mode
    [[ $? -eq 0 ]] && echo multi > $SYSFS_PATH/$id/mode
  done
}

th_teardown() {
  clear_sink
  policy_clear
  load_unload_module.sh -u -d dummy_stm
  load_unload_module.sh -u -d intel_th_sth
  load_unload_module.sh -u -d stm_console
  load_unload_module.sh -u -d stm_ftrace
  load_unload_module.sh -u -d stm_heartbeat
  load_unload_module.sh -u -d stm_p_basic
  load_unload_module.sh -u -d stm_p_sys_t
  load_unload_module.sh -u -d intel_th_msu
  load_unload_module.sh -u -d intel_th_msu_sink
  mount | grep -w "$CONFIG_PATH"
  [[ $? -eq 0 ]] && umount $CONFIG_PATH
  mount | grep -w "$DEBUG_PATH"
  [[ $? -eq 0 ]] && umount $DEBUG_PATH
}

trace_generate_simple() {
  data=$1
  if [[ -c /dev/0-sth ]]; then
    test_print_trc "*************echo to /dev/0-sth*************"
    cat $data > /dev/0-sth
  else
    test_print_trc "No 0-sth found!"
  fi
}

trace_generate() {

  times=$1
  type=$2
  ftemp="temp.txt"

  if [[ $SOURCE = "console" ]]; then
    for i in $(seq $times); do
      echo "<0>${TRACEINFO}_dmesg" > /dev/kmsg
    done
  elif [[ $SOURCE = "default" ]]; then
    [[ -f $ftemp ]] && rm $ftemp
    for i in $(seq $times); do
      echo "${TRACEINFO}_default" >> $ftemp
    done
    if [[ -c /dev/1-sth ]]; then
      test_print_trc "*************echo to /dev/1-sth*************"
      cat $ftemp > /dev/1-sth
    else
      test_print_trc "No 1-sth found!"
    fi
    if [[ -c /dev/0-sth ]]; then
      test_print_trc "*************echo to /dev/0-sth*************"
      cat $ftemp > /dev/0-sth
    else
      test_print_trc "No 0-sth found!"
    fi
  elif [[ $SOURCE = "ftrace" ]]; then
    [[ -d "$DEBUG_PATH" ]] || mkdir $DEBUG_PATH
    if ! grep -q $DEBUG_PATH /proc/mounts; then
      mount -t debugfs nodev $DEBUG_PATH
    fi
    echo "nop" > $DEBUG_PATH/tracing/current_tracer
    echo "function" > $DEBUG_PATH/tracing/current_tracer
    echo 1 > $DEBUG_PATH/tracing/tracing_on
    sleep 1
  elif [[ $SOURCE =~ "heartbeat" ]]; then
    sleep 1
  fi
  sleep 1
}

trace_capture() {
  dev_id=${DEV_POINT:0:1}
  cat /dev/intel_th${dev_id}/${DEV_POINT:2} > $lfile
  npktool mem -t0 -b ${dev_id} -m ${DEV_POINT: -1} -o $bfile 
  test_print_trc "trace is $lfile and $bfile!"
}

dummy_stm_test() {
  MODULE_NAME="dummy_stm"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  number=$(ls /dev/ | grep -c dummy_stm)
  test_print_trc "number = $number"
  [[ $number -ne 4 ]] && die "dummy_stm failed to create /dev/ for character device"
}

sth_dev_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  ls /dev/ | grep "0-sth"
  [[ $? -ne 0 ]] && die "intel_th_sth failed to create /dev/ for character device"
}

stm_source_test() {
  MODULE_NAME=$1
  SOURCE_NAME=$2
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  ls $SOURCE_PATH | grep $SOURCE_NAME
  [[ $? -ne 0 ]] && die "$MODULE_NAME failed to create point under $SOURCE_PATH"
}

stm_source_dummy_test() {
  MODULE_NAME=$1
  SOURCE_NAME=$2
  policy_name="dummy_stm.0.testpolicy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  load_unload_module.sh -c -d dummy_stm || \
    do_cmd "load_unload_module.sh -l -d dummy_stm"
  load_unload_module.sh -c -d stm_p_basic || \
    do_cmd "load_unload_module.sh -l -d stm_p_basic"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE_NAME
  echo dummy_stm.0 > $SOURCE_PATH/$SOURCE_NAME/stm_source_link
  [[ $? -ne 0 ]] && die "dummy_stm faile to set with $MODULE_NAME"
}

stm_source_all_dummy_test() {
  MODULE_NAME_1="stm_console"
  SOURCE_NAME_1="console"
  MODULE_NAME_2="stm_ftrace"
  SOURCE_NAME_2="ftrace"
  MODULE_NAME_3="stm_heartbeat"
  SOURCE_NAME_3="heartbeat.0"
  policy_name="dummy_stm.0.testpolicy"
  load_unload_module.sh -c -d $MODULE_NAME_1 || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME_1"
  load_unload_module.sh -c -d $MODULE_NAME_2 || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME_2"
  load_unload_module.sh -c -d $MODULE_NAME_3 || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME_3"
  load_unload_module.sh -c -d dummy_stm || \
    do_cmd "load_unload_module.sh -l -d dummy_stm"
  load_unload_module.sh -c -d stm_p_basic || \
    do_cmd "load_unload_module.sh -l -d stm_p_basic"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE_NAME_1
  policy_source_set $policy_name $SOURCE_NAME_2
  policy_source_set $policy_name $SOURCE_NAME_3
  echo dummy_stm.0 > $SOURCE_PATH/$SOURCE_NAME_1/stm_source_link
  [[ $? -ne 0 ]] && die "dummy_stm faile to set with $MODULE_NAME_1"
  echo dummy_stm.0 > $SOURCE_PATH/$SOURCE_NAME_2/stm_source_link
  [[ $? -ne 0 ]] && die "dummy_stm faile to set with $MODULE_NAME_2"
  echo dummy_stm.0 > $SOURCE_PATH/$SOURCE_NAME_3/stm_source_link
  [[ $? -ne 0 ]] && die "dummy_stm faile to set with $MODULE_NAME_3"
}

stm_policy_dummy_test() {
  rmmod dummy_stm
  policy_name="dummy_stm.0.test"
  SOURCE_NAME="test"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -eq 0 ]] && die "policy with dummy_stm should not be created before load dummy_stm!"
  load_unload_module.sh -c -d dummy_stm || \
    do_cmd "load_unload_module.sh -l -d dummy_stm"
  load_unload_module.sh -c -d stm_p_basic || \
    do_cmd "load_unload_module.sh -l -d stm_p_basic"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -ne 0 ]] && die "policy with dummy_stm not created after load dummy_stm!"
  policy_source_set $policy_name $SOURCE_NAME
}

stm_policy_sth_test() {
  rmmod intel_th_sth
  policy_name="0-sth.test"
  SOURCE_NAME="test"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -eq 0 ]] && die "policy with intel_th_sth should not be created before load intel_th_sth!"
  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  load_unload_module.sh -c -d stm_p_basic || \
    do_cmd "load_unload_module.sh -l -d stm_p_basic"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -ne 0 ]] && die "policy with dummy_stm not created after load intel_th_sth!"
  policy_source_set $policy_name $SOURCE_NAME
}

stm_policy_set_test() {
  MODULE_NAME_1="stm_console"
  SOURCE_NAME_1="console"
  MODULE_NAME_2="stm_ftrace"
  SOURCE_NAME_2="ftrace"
  MODULE_NAME_3="stm_heartbeat"
  SOURCE_NAME_3="heartbeat.0"
  policy_name_dummy="dummy_stm.0.test"
  policy_name_sth="0-sth.test"
  test_value=300
  load_unload_module.sh -c -d dummy_stm || \
    do_cmd "load_unload_module.sh -l -d dummy_stm"
  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME_1 || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME_1"
  load_unload_module.sh -c -d $MODULE_NAME_2 || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME_2"
  load_unload_module.sh -c -d $MODULE_NAME_3 || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME_3"
  load_unload_module.sh -c -d stm_p_basic || \
    do_cmd "load_unload_module.sh -l -d stm_p_basic"
  policy_enable $policy_name_dummy
  policy_enable $policy_name_sth

  policy_source_set $policy_name_dummy $SOURCE_NAME_1
  policy_source_set $policy_name_dummy $SOURCE_NAME_2
  policy_source_set $policy_name_dummy $SOURCE_NAME_3

  policy_source_set $policy_name_sth $SOURCE_NAME_1
  policy_source_set $policy_name_sth $SOURCE_NAME_2
  policy_source_set $policy_name_sth $SOURCE_NAME_3

  policy_master_set $policy_name_dummy $SOURCE_NAME_1 $test_value $test_value
  policy_master_set $policy_name_dummy $SOURCE_NAME_2 $test_value $test_value
  policy_master_set $policy_name_dummy $SOURCE_NAME_3 $test_value $test_value

  policy_channel_set $policy_name_dummy $SOURCE_NAME_1 $test_value $test_value
  policy_channel_set $policy_name_dummy $SOURCE_NAME_2 $test_value $test_value
  policy_channel_set $policy_name_dummy $SOURCE_NAME_3 $test_value $test_value

  policy_master_set $policy_name_sth $SOURCE_NAME_1 $test_value $test_value
  policy_master_set $policy_name_sth $SOURCE_NAME_2 $test_value $test_value
  policy_master_set $policy_name_sth $SOURCE_NAME_3 $test_value $test_value

  policy_channel_set $policy_name_sth $SOURCE_NAME_1 $test_value $test_value
  policy_channel_set $policy_name_sth $SOURCE_NAME_2 $test_value $test_value
  policy_channel_set $policy_name_sth $SOURCE_NAME_3 $test_value $test_value
}
protocol_basic_test() {
  MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  do_cmd "rmmod $MODULE_NAME"
}

protocol_mipi_test() {
  MODULE_NAME="stm_p_sys-t"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  do_cmd "rmmod $MODULE_NAME"
}

protocol_basic_w_policy_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"

  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"
}

protocol_basic_w_default_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"

  MODULE_NAME="intel_th_sth"
  policy_name="0-sth:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"
}

protocol_mipi_w_default_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_sys-t.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_sys-t"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"

  MODULE_NAME="intel_th_sth"
  policy_name="0-sth:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"
}

protocol_mipi_w_policy_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_sys-t.test_policy"
  PROTOCOL_MODULE_NAME="stm_p_sys-t"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -ne 0 ]] && die "policy is created failure by p_sys-t!"

  MODULE_NAME="intel_th_sth"
  policy_name="0-sth:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy is created failure by default!"
}

protocol_n_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_basic.test_policy"
  PROTOCOL_MODULE_NAME="stm_p_basic"
  SOURCE_NAME="test"
  [[ -d "$CONFIG_PATH" ]] || mkdir $CONFIG_PATH
  if ! grep -q "CONFIG_PATH" /proc/mounts; then
    mount none $CONFIG_PATH -t configfs
  fi
  rmmod dummy_stm
  [[ -d $CONFIG_PATH/stp-policy/$policy_name ]] || mkdir $CONFIG_PATH/stp-policy/$policy_name
  [[ $? -ne 0 ]]  || die "policy cannot created before related driver is loaded!"

  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE_NAME

  [[ -f $CONFIG_PATH/stp-policy/$policy_name ]] && rm $CONFIG_PATH/stp-policy/$policy_name
  [[ $? -ne 0 ]] || die "policy cannot be deleted before related source is deleted!"
}

mth_test() {
  number=$(ls $SYSFS_PATH | grep -c "0-")
  [[ $number -lt 2 ]] && die "Devices number is less than 2!"
}

mth_cpu_test() {
  number=$(ls $SYSFS_PATH | grep -c "1-")
  [[ $number -lt 2 ]] && die "CPU TH Devices number is less than 2!"
}

protocol_basic_mipi_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -ne 0 ]] && die "dummy_stm policy is created failure by basic!"
  policy_name="dummy_stm.0:p_sys-t.test_policy"
  PROTOCOL_MODULE_NAME="stm_p_sys-t"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -eq 0 ]] && die "dummy_stm policy is created by p_sys-t!"

  MODULE_NAME="intel_th_sth"
  policy_name="0-sth:p_basic.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_basic"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -ne 0 ]] && die "intel_th_sth policy is created failure by basic!"
  policy_name="0-sth:p_sys-t.test_policy"
  PROTOCOL_MODULE_NAME="stm_p_sys-t"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -eq 0 ]] && die "intel_th_sth policy is created by p_sys-t!"
}

msu_test() {
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  ls /sys/bus/intel_th/devices | grep "msc"
  [[ $? -eq 0 ]] || die "msu device is not there!"
  do_cmd "rmmod intel_th_msu"
}

msu_sysfs_test() {
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  path="/sys/bus/intel_th/devices"
  device_dirs=$(ls $path | grep msc)
  for dir in $device_dirs; do
    val=$(cat $path/$dir/port)
    [[ $val = "unassigned" ]] && die "port is not assigned for $dir!"
    echo 0 > $path/$dir/active
    [[ $? -eq 0 ]] || die "active can not be set as 0 for $dir!"
    echo multi > $path/$dir/mode
    [[ $? -eq 0 ]] || die "mode can not be set as multi for $dir!"
    echo 1 > $path/$dir/wrap
    [[ $? -eq 0 ]] || die "wrap can not be set as 64 with multi for $dir!"
    echo 64 > $path/$dir/nr_pages
    [[ $? -eq 0 ]] || die "nr_pages can not be set as 64 with multi for $dir!"
    echo 64,64 > $path/$dir/nr_pages
    [[ $? -eq 0 ]] || die "nr_pages can not be set as 64,64 for $dir!"
    #check different mode
    echo single > $path/$dir/mode
    [[ $? -eq 0 ]] || die "mode can not be set as single for $dir!"
    echo 64 > $path/$dir/nr_pages
    [[ $? -eq 0 ]] || die "nr_pages can not be set as 64 with single for $dir!"
    echo 1 > $path/$dir/wrap
    [[ $? -eq 0 ]] || die "wrap can not be set as 64 with single for $dir!"
    echo ExI > $path/$dir/mode
    [[ $? -eq 0 ]] || die "mode can not be set as ExI for $dir!"
    echo debug > $path/$dir/mode
    [[ $? -eq 0 ]] || die "mode can not be set as debug for $dir!"

  done
}

msu_enable_disable_test() {
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  path="/sys/bus/intel_th/devices"
  device_dirs=$(ls $path | grep msc)
  for dir in $device_dirs; do
    echo single > $path/$dir/mode
    echo 64 > $path/$dir/nr_pages
    echo 1 > $path/$dir/active
    [[ $? -eq 0 ]] || die "active can not be set as 1 for $dir!"
    rmmod $MODULE_NAME
    [[ $? -eq 0 ]] && die "$MODULE_NAME can not be removed once it is enabled for $dir!"
    echo 0 > $path/$dir/active
  done
  do_cmd "rmmod $MODULE_NAME"
}

host_mode_test() {
  for MODULE_NAME in 'intel_th_gth' 'intel_th_acpi' 'intel_th'; do
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  done
  path="/sys/bus/intel_th/devices"
  ls $path | grep "gth"
  [[ $? -eq 0 ]] || die "gth device is not there!"
  ls $path | grep "sth"
  [[ $? -eq 0 ]] || die "sth device is not there!"
  v1=$(ls -l $path | grep -c "c")
  v2=$(ls $path  | grep -c "gth")
  v3=$(ls $path  | grep -c "sth")
  v2=$((v2 + v3))
  [[ $v1 -eq $v2 ]] || die "There is not only gth and sth there!"
}

host_module_test() {
  for MODULE_NAME in 'intel_th_gth' 'intel_th_acpi' 'intel_th'; do
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  done
  for MODULE_NAME in 'intel_th_gth' 'intel_th_acpi' 'intel_th'; do
    do_cmd "rmmod $MODULE_NAME"
  done
}


get_trace_count() {
  trace_capture
  if [ -s $lfile ]; then
    [[ -d "$DEV_POINT" ]] && rm $DEV_POINT -rf
    mkdir $DEV_POINT
    npktool -v decode -p -o $DEV_POINT $lfile
    test_print_trc "#########################################################"
    test_print_trc "TRACEINFO=$TRACEINFO"
    test_print_trc "#########################################################"
    trace_end_times=$(grep -rn "$TRACEINFO" $DEV_POINT | grep -c "output")
  fi
}

readonly POWER_STATE_NODE="/sys/power/state"
readonly POWER_DISK_NODE="/sys/power/disk"
readonly POWER_PM_TEST_NODE="/sys/power/pm_test"

suspend_to_resume() {
  local state=$1
  local rtc_time=20

  echo platform > "$POWER_DISK_NODE"
  echo none > "$POWER_PM_TEST_NODE"

  case $state in
    freeze)
      echo freeze > "$POWER_STATE_NODE" &
      rtcwake -m no -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      wait $!
      [[ $? -eq 0 ]] || die "fail to echo $state > $POWER_STATE_NODE!"
      ;;
    mem|disk)
      echo deep > /sys/power/mem_sleep
      rtcwake -m "$state" -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      ;;
    *)
      die "state: $state not supported!"
      ;;
  esac
}


trace_test() {
  type=$1
  times=100
  dev_id=${DEV_POINT:0:1}
  test_print_trc "start enable trace!"

  echo 1 > $SYSFS_PATH/$DEV_POINT/active

  if [[ $LPOWER != "NONE" ]]; then
    suspend_to_resume $LPOWER
  fi
  test_print_trc "start generate trace!"

  trace_generate $times $type

  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/$dev_id-gth/outputs/${dev_id}_flush
  echo 0 > $SYSFS_PATH/$DEV_POINT/active

  test_print_trc "get/decode/check trace!"
  if [[ $PROFILE = "basic" ]] && ([[ $SOURCE = "console" ]] || [[ $SOURCE = "default" ]]); then
    test_print_trc "will try to decode trace with profile as $PROFILE for source as $SOURCE!"
    get_trace_count

    test_print_trc "trace_end_times=$trace_end_times!"
    [[ $trace_end_times -eq $times ]] || die "trace count cannnot match!"
  else
    trace_capture
    [[ -s $lfile ]] || die "Trace file of $lfile is 0!"
  fi

}

trace_generate_mmap() {
  intel_th 3
}


trace_test_mmap() {
  times=10
  dev_id=${DEV_POINT:0:1}
  test_print_trc "start enable trace!"

  echo 1 > $SYSFS_PATH/$DEV_POINT/active

  test_print_trc "start generate trace!"

  trace_generate_mmap $times

  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/$dev_id-gth/outputs/${dev_id}_flush
  echo 0 > $SYSFS_PATH/$DEV_POINT/active

  test_print_trc "get/decode/check trace!"
  if [[ $PROFILE = "basic" ]] && ([[ $SOURCE = "console" ]] || [[ $SOURCE = "default" ]]); then
    test_print_trc "will try to decode trace with profile as $PROFILE for source as $SOURCE!"
    trace_end_times=$(get_trace_count)

    test_print_trc "trace_end_times=$trace_end_times!"
    [[ $trace_end_times -eq $times ]] || die "trace count cannnot match!"
  else
    lfile="/tmp/log.txt"
    trace_capture
    [[ -s $lfile ]] || die "Trace file of $lfile is 0!"
  fi

}

single_nowrap() {
  fpath=$1
  echo single > $fpath/mode
  echo 32 > $fpath/nr_pages
  echo 0 > $fpath/wrap
}

single_wrap() {
  fpath=$1
  echo single > $fpath/mode
  echo 32 > $fpath/nr_pages
  echo 1 > $fpath/wrap
}

multi_nowrap() {
  echo multi > $SYSFS_PATH/$DEV_POINT/mode
  echo 32,32 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 0 > $SYSFS_PATH/$DEV_POINT/wrap
}

multi_wrap() {
  echo multi > $SYSFS_PATH/$DEV_POINT/mode
  echo 32,32 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 1 > $SYSFS_PATH/$DEV_POINT/wrap
}


sink_nowrap() {
  echo sink > $SYSFS_PATH/$DEV_POINT/mode
  echo 32,32,32,32 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 0 > $SYSFS_PATH/$DEV_POINT/wrap
}

sink_wrap() {
  echo sink > $SYSFS_PATH/$DEV_POINT/mode
  echo 32,32,32,32 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 1 > $SYSFS_PATH/$DEV_POINT/wrap
}

msu_trace_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu_sink"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  if [[ $SOURCE = "console" ]]; then
    MODULE_NAME="stm_console"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  elif [[ $SOURCE = "ftrace" ]]; then
    MODULE_NAME="stm_ftrace"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  elif [[ $SOURCE =~ "heartbeat" ]]; then
    MODULE_NAME="stm_heartbeat"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  fi
  dev_id=${DEV_POINT:0:1}

  test_print_trc "start make policy!"
  if [[ $PROFILE = "basic" ]]; then
    MODULE_NAME="stm_p_basic"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
    policy_name="$dev_id-sth:p_basic.test_policy"
  elif [[ $PROFILE = "mipi" ]]; then
    MODULE_NAME="stm_p_sys-t"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
    policy_name="$dev_id-sth:p_sys-t.test_policy"
  fi
  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE/masters | cut -d' ' -f2)

  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/$DEV_POINT/port)
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/0
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/32
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/$m_max
  fi

  if [[ $SOURCE != "default" ]]; then
    test_print_trc "set $dev_id-sth with $SOURCE!"
    echo $dev_id-sth > /sys/class/stm_source/$SOURCE/stm_source_link
  fi

  if [[ $CON -eq 0 ]]; then
    ################test as single without wrap#############
    test_print_trc "*****************start set $DEV_POINT as single without wrap!*****************"
    single_nowrap "$SYSFS_PATH/$DEV_POINT"
    sleep 1
    trace_test 2

    ################test as single with wrap#############
    test_print_trc "*****************start set $DEV_POINT as single with wrap!*****************"
    echo 1 > $SYSFS_PATH/$DEV_POINT/wrap
    sleep 1
    trace_test 2

    ################test as multi without wrap#############
    test_print_trc "*****************start set $DEV_POINT as multi without wrap!*****************"
    multi_nowrap "$SYSFS_PATH/$DEV_POINT"
    sleep 1
    trace_test 2

    ################test as multi with wrap#############
    test_print_trc "*****************start set $DEV_POINT as multi with wrap!*****************"
    echo 1 > $SYSFS_PATH/$DEV_POINT/wrap
    sleep 1
    trace_test 2

  else
    if [[ $CON -eq 1 ]]; then
      ################test as single without wrap#############
      test_print_trc "*****************start set $DEV_POINT as single without wrap!*****************"
      single_nowrap "$SYSFS_PATH/$DEV_POINT"
    fi

    if [[ $CON -eq 2 ]]; then
      test_print_trc "*****************start set $DEV_POINT as single with wrap!*****************"
      single_wrap "$SYSFS_PATH/$DEV_POINT"
    fi
    if [[ $CON -eq 3 ]]; then
      test_print_trc "*****************start set $DEV_POINT as multi without wrap!*****************"
      multi_nowrap "$SYSFS_PATH/$DEV_POINT"
    fi
    if [[ $CON -eq 4 ]]; then
      test_print_trc "*****************start set $DEV_POINT as multi with wrap!*****************"
      multi_wrap "$SYSFS_PATH/$DEV_POINT"
    fi
    if [[ $CON -eq 5 ]]; then
      test_print_trc "*****************start set $DEV_POINT as sink without wrap!*****************"
      sink_nowrap "$SYSFS_PATH/$DEV_POINT"
    fi
    if [[ $CON -eq 6 ]]; then
      test_print_trc "*****************start set $DEV_POINT as sink with wrap!*****************"
      sink_wrap "$SYSFS_PATH/$DEV_POINT"
    fi
    sleep 1
    trace_test 2
  fi
}

output_basic_test() {
  ls $SYSFS_PATH | grep $OUTPUT
  [[ $? -eq 0 ]] || na_test "$OUTPUT is not support in this platform!"
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  # currently dcih is not supported, so na dcih cases
  [[ $OUTPUT = "dcih" ]] && na_test "$OUTPUT is not support in this platform!"
  ###########################
  if [[ $OUTPUT = "lpp" ]]; then
    MODULE_NAME="intel_th_pti"
    load_unload_module.sh -c -d $MODULE_NAME || \
      do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  else
    MODULE_NAME="intel_th_$OUTPUT"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  fi

  DEV=$(ls $SYSFS_PATH | grep $OUTPUT | awk '{print $1}')
  [[ -n $DEV ]] || na_test "$OUTPUT is not support in this platform!"
  dev_id=${DEV:0:1}

  SOURCE="default"

  MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  policy_name="$dev_id-sth:p_basic.test_policy"

  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE/masters | cut -d' ' -f2)

  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/$DEV/port)
  test_print_trc "port = $port!"
  test_print_trc "dev_id = $dev_id!"

  echo $port > $SYSFS_PATH/$dev_id-gth/masters/0
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/32
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/$m_max
  fi

  test_print_trc "start enable trace!"

  do_cmd "echo 1 > $SYSFS_PATH/$DEV/active"
  sleep 1

  test_print_trc "stop trace!"

  do_cmd "echo 0 > $SYSFS_PATH/$DEV/active"

}


output_with_msc_test() {
  output_basic_test
  msu_trace_test
}


ioctl_set_test() {

  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  policy_enable "0-sth.test"
  [[ -d $CONFIG_PATH/stp-policy/0-sth.test/th_test ]] || mkdir $CONFIG_PATH/stp-policy/0-sth.test/th_test
  th_test 1
  val=$?
  test_print_trc "result = $val"
  [[ $val = 0 ]] || die "policy ID set fail"
}

ioctl_n_test() {
  for module in "intel_th_pci" "intel_th_sth" "stm_p_basic"; do
    load_unload_module.sh -c -d $module || \
      load_unload_module.sh -l -d $module
  done
  policy_enable "0-sth.test"
  [[ -d $CONFIG_PATH/stp-policy/0-sth.test/th_test ]] || \
    mkdir $CONFIG_PATH/stp-policy/0-sth.test/th_test
  load_unload_module.sh -u -d intel_th_gth
  th_test 1
  val=$?
  test_print_trc "result = $val"
  [[ $val = 0 ]] && die "ioctl negative tset failed!"
}

ioctl_get_test() {
  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  policy_enable "0-sth.test"
  [[ -d $CONFIG_PATH/stp-policy/0-sth.test/th_test ]] || mkdir $CONFIG_PATH/stp-policy/0-sth.test/th_test
  th_test 2
  val=$?
  test_print_trc "result = $val"
  [[ $val = 0 ]] || die "policy ID get fail"
}

port_sys_test() {
  port_num=$(ls $SYSFS_PATH/0-gth/outputs | grep -c "port")
  [[ $port_num = 0 ]] && die "There is no port!"
}

mmap_test() {

  test_print_trc "start to test!"
  SOURCE="default"
  test_print_trc "start to load modules!"
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME

  dev_id=${DEV_POINT:0:1}

  test_print_trc "start make policy!"

  # set policy
  policy_name="0-sth.test"
  SOURCE="th_test"
  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE/masters | cut -d' ' -f2)

  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/$DEV_POINT/port)
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/0
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/32
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/$m_max
  fi

  echo single > $SYSFS_PATH/$DEV_POINT/mode
  echo 1 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 0 > $SYSFS_PATH/$DEV_POINT/wrap
  sleep 1
  echo 1 > $SYSFS_PATH/$DEV_POINT/active

  count=$(getconf PAGESIZE)
  test_print_trc "pagesize=$count!"
  # fake trace
  times=10
  trace_end_times=0
  th_test 3

  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/${dev_id}-gth/outputs/${dev_id}_flush
  echo 0 > $SYSFS_PATH/$DEV_POINT/active

  test_print_trc "get/decode/check trace!"
  # decode and get trace count
  trace_capture
  ch=" v"
  if [ -s $lfile ]; then
    [[ -d "$DEV_POINT" ]] && rm $DEV_POINT -rf
    mkdir $DEV_POINT
    npktool -v decode -p -o $DEV_POINT $lfile
    trace_end_times=$(grep -o "$ch" "$DEV_POINT"/packet-stream | wc -l)
  fi
  test_print_trc "trace_end_times=$trace_end_times!"
  [[ $trace_end_times -eq $times ]] || die "trace count cannnot match!"

}

wrap_test() {
  test_print_trc "start to test!"
  flag=$1
  SOURCE="default"
  test_print_trc "start to load modules!"
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME

  dev_id=${DEV_POINT:0:1}

  test_print_trc "start make policy!"

  MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  policy_name="$dev_id-sth:p_basic.test_policy"

  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE"/masters | cut -d' ' -f2)

  test_print_trc "start set gth!"
  port=$(cat "$SYSFS_PATH"/"$DEV_POINT"/port)
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/0
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/32
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/256+
  else
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/"$m_max"
  fi

  echo single > "$SYSFS_PATH"/"$DEV_POINT"/mode
  echo 1 > "$SYSFS_PATH"/"$DEV_POINT"/nr_pages
  echo "$flag" > "$SYSFS_PATH"/"$DEV_POINT"/wrap
  sleep 1
  echo 1 > "$SYSFS_PATH"/"$DEV_POINT"/active

  count=$(getconf PAGESIZE)
  test_print_trc "pagesize=$count!"
  # fake trace
  trace="temp.trace"
  times=10
  [[ -f $trace ]] && rm $trace

  for i in $(seq "$count"); do
    echo -n "a" >> $trace
  done
  sync
  sync
  sleep 1
  trace_generate_simple $trace
  ch="b"
  for i in $(seq $times); do
    echo -n $ch >> $trace
  done
  sync
  sync
  sleep 1
  trace_generate_simple $trace


  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/$dev_id-gth/outputs/${dev_id}_flush
  echo 0 > $SYSFS_PATH/$DEV_POINT/active

  test_print_trc "get/decode/check trace!"

  trace_capture

  if [ -s $lfile ]; then
    [[ -d "$DEV_POINT" ]] && rm $DEV_POINT -rf
    mkdir $DEV_POINT
    npktool -v decode -p -o $DEV_POINT $lfile
    trace_end_times=$(grep -o $ch "$DEV_POINT"/stp* | wc -l)
  fi
  test_print_trc "trace_end_times=$trace_end_times"
  if [[ $flag -eq 1 ]]; then
    [[ $trace_end_times -eq $times ]] || die "trace count cannnot match!"
  fi
  if [[ $flag -eq 0 ]]; then
    [[ $trace_end_times -eq 0 ]] || die "trace $ch is not equal 0 in unwrap test!"
  fi
}


sink_negtive_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu_sink"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  if [[ $SOURCE = "console" ]]; then
    MODULE_NAME="stm_console"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  elif [[ $SOURCE = "ftrace" ]]; then
    MODULE_NAME="stm_ftrace"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  elif [[ $SOURCE =~ "heartbeat" ]]; then
    MODULE_NAME="stm_heartbeat"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  fi
  dev_id=${DEV_POINT:0:1}

  test_print_trc "start make policy!"
  if [[ $PROFILE = "basic" ]]; then
    MODULE_NAME="stm_p_basic"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
    policy_name="$dev_id-sth:p_basic.test_policy"
  elif [[ $PROFILE = "mipi" ]]; then
    MODULE_NAME="stm_p_sys-t"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
    policy_name="$dev_id-sth:p_sys-t.test_policy"
  fi
  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE/masters | cut -d' ' -f2)

  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/$DEV_POINT/port)
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/0
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/32
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/$m_max
  fi

  if [[ $SOURCE != "default" ]]; then
    test_print_trc "set $dev_id-sth with $SOURCE!"
    echo $dev_id-sth > /sys/class/stm_source/$SOURCE/stm_source_link
  fi


  sink_nowrap "$SYSFS_PATH/$DEV_POINT"
  should_fail "rmmod intel_th_msu_sink"
  sleep 1

}


sink_w_others_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu_sink"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  if [[ $SOURCE = "console" ]]; then
    MODULE_NAME="stm_console"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  elif [[ $SOURCE = "ftrace" ]]; then
    MODULE_NAME="stm_ftrace"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  elif [[ $SOURCE =~ "heartbeat" ]]; then
    MODULE_NAME="stm_heartbeat"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
  fi
  dev_id=${DEV_POINT:0:1}

  test_print_trc "start make policy!"
  if [[ $PROFILE = "basic" ]]; then
    MODULE_NAME="stm_p_basic"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
    policy_name="$dev_id-sth:p_basic.test_policy"
  elif [[ $PROFILE = "mipi" ]]; then
    MODULE_NAME="stm_p_sys-t"
    load_unload_module.sh -c -d $MODULE_NAME || \
      load_unload_module.sh -l -d $MODULE_NAME
    policy_name="$dev_id-sth:p_sys-t.test_policy"
  fi
  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE/masters | cut -d' ' -f2)

  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/$DEV_POINT/port)
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/0
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/32
  echo $port > $SYSFS_PATH/$dev_id-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/$dev_id-gth/masters/$m_max
  fi

  if [[ $SOURCE != "default" ]]; then
    test_print_trc "set $dev_id-sth with $SOURCE!"
    echo $dev_id-sth > /sys/class/stm_source/$SOURCE/stm_source_link
  fi

  ###set as sink then back to single/multi -> unload msu-sink -> check single/multi status -> back to sink
  sink_nowrap "$SYSFS_PATH/$DEV_POINT"
  single_nowrap "$SYSFS_PATH/$DEV_POINT"
  sleep 1
  do_cmd "rmmod intel_th_msu_sink"
  trace_test 2
  do_cmd "modprobe intel_th_msu_sink"
  sink_nowrap "$SYSFS_PATH/$DEV_POINT"
  trace_test 2
  multi_nowrap "$SYSFS_PATH/$DEV_POINT"
  sleep 1
  do_cmd "rmmod intel_th_msu_sink"
  trace_test 2
  do_cmd "modprobe intel_th_msu_sink"
  sink_nowrap "$SYSFS_PATH/$DEV_POINT"
  trace_test 2
}


sink_multi_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_pci"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu_sink"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME

  MODULE_NAME="stm_console"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME

  SOURCE="console"
  test_print_trc "start make policy!"

  MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  policy_name="0-sth:p_basic.test_policy"

  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat $CONFIG_PATH/stp-policy/$policy_name/$SOURCE/masters | cut -d' ' -f2)



  if [[ $SOURCE != "default" ]]; then
    test_print_trc "set 0-sth with $SOURCE!"
    echo 0-sth > /sys/class/stm_source/$SOURCE/stm_source_link
  fi



  ###set as sink to 0-msc0 and then 0-msc1
  ####set as 0-msc0
  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/0-msc0/port)
  echo $port > $SYSFS_PATH/0-gth/masters/0
  echo $port > $SYSFS_PATH/0-gth/masters/32
  echo $port > $SYSFS_PATH/0-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/0-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/0-gth/masters/$m_max
  fi
  echo sink > $SYSFS_PATH/0-msc0/mode
  echo 32,32,32,32 > $SYSFS_PATH/0-msc0/nr_pages
  echo 0 > $SYSFS_PATH/0-msc0/wrap
  sleep 1
  test_print_trc "start trace!"
  echo 1 > $SYSFS_PATH/0-msc0/active

  # fake trace
  times=100
  trace_end_times=0

  for i in $(seq $times); do
    echo "<0>intel_th_1_dmesg" > /dev/kmsg
  done


  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/0-gth/outputs/0_flush
  echo 0 > $SYSFS_PATH/0-msc0/active

  test_print_trc "get/decode/check trace!"
  # decode and get trace count
  DEV_POINT="0-msc0"
  trace_capture

  if [ -s $lfile ]; then
    [[ -d "0-msc0" ]] && rm 0-msc0 -rf
    mkdir 0-msc0
    npktool -v decode -p -o 0-msc0 $lfile
    trace_end_times=$(grep -rn "intel_th_1_dmesg" 0-msc0 | grep -c "output")
  fi
  test_print_trc "msc0 trace_end_times=$trace_end_times!"
  [[ $trace_end_times -eq $times ]] || die "msc0 trace count cannnot match!"

  ####set as 0-msc1
  test_print_trc "start set gth!"
  port=$(cat $SYSFS_PATH/0-msc1/port)
  echo $port > $SYSFS_PATH/0-gth/masters/0
  echo $port > $SYSFS_PATH/0-gth/masters/32
  echo $port > $SYSFS_PATH/0-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo $port > $SYSFS_PATH/0-gth/masters/256+
  else
    echo $port > $SYSFS_PATH/0-gth/masters/$m_max
  fi
  echo sink > $SYSFS_PATH/0-msc1/mode
  echo 32,32,32,32 > $SYSFS_PATH/0-msc1/nr_pages
  echo 0 > $SYSFS_PATH/0-msc1/wrap
  sleep 1
  test_print_trc "start trace!"
  echo 1 > $SYSFS_PATH/0-msc1/active

  # fake trace
  times=100
  trace_end_times=0

  for i in $(seq $times); do
    echo "<0>intel_th_2_dmesg" > /dev/kmsg
  done


  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/0-gth/outputs/0_flush
  echo 0 > $SYSFS_PATH/0-msc1/active

  test_print_trc "get/decode/check trace!"
  # decode and get trace count
  DEV_POINT="0-msc1"
  trace_capture

  if [ -s $lfile ]; then
    [[ -d "0-msc1" ]] && rm 0-msc1 -rf
    mkdir 0-msc1
    npktool -v decode -p -o 0-msc1 $lfile
    trace_end_times=$(grep -rn "intel_th_2_dmesg" 0-msc1 | grep -c "output")
  fi
  test_print_trc "msc1 trace_end_times=$trace_end_times!"
  [[ $trace_end_times -eq $times ]] || die "msc1 trace count cannnot match!"

  ###msc0 log could not be in msc1, msc1 log could not be msc0

  grep -rn "intel_th_2_dmesg" 0-msc0
  [[ $? -eq 0 ]] && die "msc1 trace log is in msc0!"

  grep -rn "intel_th_1_dmesg" 0-msc1
  [[ $? -eq 0 ]] && die "msc0 trace log is in msc1!"
}

gth_remove_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_pci"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu_sink"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="stm_console"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  do_cmd "rmmod intel_th_gth"
  do_cmd "modprobe intel_th_gth"
}

gth_sysfs_test() {
  ids=$(ls $SYSFS_PATH/0-gth/masters/  | xargs)
  for id in $ids; do
    do_cmd "cat $SYSFS_PATH/0-gth/masters/$id"
  done
  ids=$(ls $SYSFS_PATH/0-gth/outputs/ | grep -v flush| xargs)
  for id in $ids; do
    do_cmd "cat $SYSFS_PATH/0-gth/outputs/$id"
  done
}

msu_sysfs_check_test() {
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  ids=$(ls -l $SYSFS_PATH/0-msc0/ | grep -v drw | grep -v lrw | grep -v total | grep -v win_switch| awk '{print $9}' | xargs )
  for id in $ids; do
    do_cmd "cat $SYSFS_PATH/0-msc0/$id"
  done
  do_cmd "echo 32,32,32,32 > $SYSFS_PATH/0-msc0/nr_pages"
  do_cmd "echo 1 > $SYSFS_PATH/0-msc0/win_switch"
}

pci_remove_test() {
  do_cmd "modprobe intel_th_pci"
  do_cmd "cat /proc/interrupts"
  do_cmd "rmmod intel_th_pci"
  do_cmd "modprobe intel_th_pci"
}

pti_sysfs_test() {
  MODULE_NAME="intel_th_pti"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  for device in "0-lpp" "0-pti"; do
    if [ -d $SYSFS_PATH/$device ]; then
      ids=$(ls -l $SYSFS_PATH/$device/ | grep -v drw | grep -v lrw | grep -v total | grep -v port | awk '{print $9}' | xargs)
      for id in $ids; do
        do_cmd "cat $SYSFS_PATH/$device/$id"
        val=$(cat $SYSFS_PATH/$device/$id | sed 's/\[//g' | sed 's/\]//g' )
        if [[ $id = "clock_divider" ]]; then
          val="4"
        fi
        if [[ $id = "lpp_dest" ]]; then
          val="pti"
        fi
        do_cmd "echo $val > $SYSFS_PATH/$device/$id"
      done
    fi
  done
}

stm_sysfs_test() {
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  MODULE_NAME="stm_console"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  sleep 1
  ids=$(ls -l /sys/class/stm/0-sth/ | grep -v drw | grep -v lrw | grep -v total | awk '{print $9}' | xargs)
  for id in $ids; do
    do_cmd "cat $SYSFS_PATH/0-sth/stm/0-sth/$id"
  done
  do_cmd "cat $SOURCE_PATH/console/stm_source_link"
}

sink_full_test() {
  test_print_trc "start to test!"
  SOURCE="default"
  test_print_trc "start to load modules!"
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu_sink"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  dev_id=${DEV_POINT:0:1}
  test_print_trc "start make policy!"
  MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  policy_name="$dev_id-sth:p_basic.test_policy"
  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE"/masters | cut -d' ' -f2)
  test_print_trc "start set gth!"
  port=$(cat "$SYSFS_PATH"/"$DEV_POINT"/port)
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/0
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/32
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/256+
  else
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/"$m_max"
  fi
  echo sink > "$SYSFS_PATH"/"$DEV_POINT"/mode
  echo 2,2,2,2 > "$SYSFS_PATH"/"$DEV_POINT"/nr_pages
  echo 1 > "$SYSFS_PATH"/"$DEV_POINT"/wrap
  sleep 1
  echo 1 > "$SYSFS_PATH"/"$DEV_POINT"/active
  count=$(getconf PAGESIZE)
  test_print_trc "pagesize=$count!"
  # fake trace
  trace="temp.trace"
  times=10
  [[ -f $trace ]] && rm $trace
  for i in $(seq "$count"); do
    echo -n "a" >> $trace
  done
  sync
  sync
  sleep 1
  trace_generate_simple $trace
  ch="b"
  for i in $(seq $times); do
    echo -n $ch >> $trace
  done
  sync
  sync
  sleep 1
  trace_generate_simple $trace
  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/$dev_id-gth/outputs/${dev_id}_flush
  echo 0 > $SYSFS_PATH/$DEV_POINT/active
  test_print_trc "get/decode/check trace!"
  trace_capture
  if [ -s $lfile ]; then
    [[ -d "$DEV_POINT" ]] && rm $DEV_POINT -rf
    mkdir $DEV_POINT
    npktool -v decode -p -o $DEV_POINT $lfile
    trace_end_times=$(grep -o $ch "$DEV_POINT"/stp* | wc -l)
  fi
  test_print_trc "trace_end_times=$trace_end_times"
  [[ $trace_end_times -eq $times ]] || die "trace count cannnot match!"
}

policy_sysfs_test() {
  MODULE_NAME="dummy_stm"
  policy_name="dummy_stm.0:p_sys-t.test_policy"
  load_unload_module.sh -c -d $MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  PROTOCOL_MODULE_NAME="stm_p_sys-t"
  load_unload_module.sh -c -d $PROTOCOL_MODULE_NAME || \
    do_cmd "load_unload_module.sh -l -d $PROTOCOL_MODULE_NAME"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ids=$(ls -l /sys/kernel/config/stp-policy/dummy_stm.0\:p_sys-t.test_policy | grep -v drw | grep -v lrw | grep -v total | awk '{print $9}' | xargs)
  test_print_trc "******************ids=$ids"
  for id in $ids; do
    do_cmd "cat /sys/kernel/config/stp-policy/dummy_stm.0\:p_sys-t.test_policy/$id"
  done
  ids=$(ls -l /sys/kernel/config/stp-policy/dummy_stm.0\:p_sys-t.test_policy/default | grep -v drw | grep -v lrw | grep -v total | awk '{print $9}' | xargs)
  test_print_trc "******************ids 2=$ids"
  for id in $ids; do
    do_cmd "cat /sys/kernel/config/stp-policy/dummy_stm.0\:p_sys-t.test_policy/default/$id"
    val=$(cat /sys/kernel/config/stp-policy/dummy_stm.0\:p_sys-t.test_policy/default/$id | sed 's/\[//g' | sed 's/\]//g' )
    do_cmd "echo $val > /sys/kernel/config/stp-policy/dummy_stm.0\:p_sys-t.test_policy/default/$id "
  done
}

npktool_test() {
  test_print_trc "start to test!"
  flag=$1
  SOURCE="default"
  test_print_trc "start to load modules!"
  MODULE_NAME="intel_th_sth"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  MODULE_NAME="intel_th_msu"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  dev_id=${DEV_POINT:0:1}
  test_print_trc "start make policy!"
  MODULE_NAME="stm_p_basic"
  load_unload_module.sh -c -d $MODULE_NAME || \
    load_unload_module.sh -l -d $MODULE_NAME
  policy_name="$dev_id-sth:p_basic.test_policy"
  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE"/masters | cut -d' ' -f2)
  test_print_trc "start set gth!"
  port=$(cat "$SYSFS_PATH"/"$DEV_POINT"/port)
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/0
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/32
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/256+
  else
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/"$m_max"
  fi
  echo multi > $SYSFS_PATH/$DEV_POINT/mode
  echo 32,32 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 1 > $SYSFS_PATH/$DEV_POINT/wrap
  sleep 1
  echo 1 > "$SYSFS_PATH"/"$DEV_POINT"/active
  count=10
  # fake trace
  trace="temp.trace"
  times=10
  [[ -f $trace ]] && rm $trace
  for i in $(seq "$count"); do
    echo -n "a" >> $trace
  done
  sync
  sync
  sleep 1
  trace_generate_simple $trace
  test_print_trc "stop trace!"
  sleep 1
  echo 1 > $SYSFS_PATH/$dev_id-gth/outputs/${dev_id}_flush
  echo 0 > $SYSFS_PATH/$DEV_POINT/active
  test_print_trc "test npktool!"
  if [[ $flag -eq 1 ]]; then
    do_cmd "npktool mem -t 0 -b 0 -m 0"
    do_cmd "npktool mmap output"
  fi

  if [[ $flag -eq 2 ]]; then
    do_cmd "npktool mem -t 0 -b 0 -m 0; npktool mem -t 1000 -b 0 -m 0"
    do_cmd "npktool mmap output"
  fi
}

ioctl_set_test() {
  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  policy_enable "0-sth.test"
  [[ -d $CONFIG_PATH/stp-policy/0-sth.test/th_test ]] || mkdir $CONFIG_PATH/stp-policy/0-sth.test/th_test
  th_test 1
  val=$?
  test_print_trc "result = $val"
  [[ $val = 0 ]] || die "policy ID set fail"
}

32_bin_test() {
  load_unload_module.sh -c -d intel_th_sth || \
    do_cmd "load_unload_module.sh -l -d intel_th_sth"
  policy_enable "0-sth.test"
  [[ -d $CONFIG_PATH/stp-policy/0-sth.test/th_test_32 ]] || mkdir $CONFIG_PATH/stp-policy/0-sth.test/th_test_32
  th_test_32 2
  val=$?
  test_print_trc "result = $val"
  [[ $val = 0 ]] || die "policy ID set fail"
}

policy_remove_test() {
  policy_name="dummy_stm.0.test"
  load_unload_module.sh -c -d dummy_stm || \
    do_cmd "load_unload_module.sh -l -d dummy_stm"
  load_unload_module.sh -c -d stm_p_basic || \
    do_cmd "load_unload_module.sh -l -d stm_p_basic"
  policy_enable $policy_name
  ls $CONFIG_PATH/stp-policy/ | grep $policy_name
  [[ $? -ne 0 ]] && die "policy with dummy_stm not created after load dummy_stm!"
  policy_source_set $policy_name "default"
  do_cmd "mkdir $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME/$SOURCE_NAME"
  do_cmd "rmdir $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME/$SOURCE_NAME"
  do_cmd "rmdir $CONFIG_PATH/stp-policy/$policy_name/$SOURCE_NAME"
  do_cmd "rmdir $CONFIG_PATH/stp-policy/$policy_name"
}

ftrace_write_test() {
  test_print_trc "start to load modules!"
  for module in "intel_th_sth" "intel_th_msu" "stm_p_basic" "stm_ftrace"; do
    load_unload_module.sh -c -d $module || \
      load_unload_module.sh -l -d $module
  done
  dev_id=${DEV_POINT:0:1}
  test_print_trc "start make policy!"
  policy_name="$dev_id-sth:p_basic.test_policy"
  test_print_trc "policy_name=$policy_name!"
  policy_enable $policy_name
  policy_source_set $policy_name $SOURCE
  m_max=$(cat "$CONFIG_PATH"/stp-policy/"$policy_name"/"$SOURCE"/masters | cut -d' ' -f2)
  test_print_trc "start set gth!"
  port=$(cat "$SYSFS_PATH"/"$DEV_POINT"/port)
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/0
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/32
  echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/64
  if [[ m_max -ge 256 ]]; then
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/256+
  else
    echo "$port" > "$SYSFS_PATH"/"$dev_id"-gth/masters/"$m_max"
  fi
  echo $dev_id-sth > /sys/class/stm_source/$SOURCE/stm_source_link
  echo multi > $SYSFS_PATH/$DEV_POINT/mode
  echo 32,32 > $SYSFS_PATH/$DEV_POINT/nr_pages
  echo 1 > $SYSFS_PATH/$DEV_POINT/wrap
  sleep 1
  echo 1 > "$SYSFS_PATH"/"$DEV_POINT"/active
  dpath=$(mount | grep debugfs | awk '{print $3}')
  echo function > $dpath/tracing/current_tracer
  echo 1 > $dpath/tracing/tracing_on
  sleep 5
  echo 0 > $dpath/tracing/tracing_on
  echo 0 > "$SYSFS_PATH"/"$DEV_POINT"/active
  trace_capture
  [[ -s $lfile ]] || die "ftrace log size is 0!"
}

protocol_mipi_clocksync_test() {
  for module in "stm_p_basic" "intel_th_pci" "intel_th_sth" "intel_th_msu" "stm_p_sys-t"; do
    load_unload_module.sh -c -d $module || \
      do_cmd "load_unload_module.sh -l -d $module"
  done
  policy_name="0-sth:p_sys-t.test"
  policy_enable $policy_name
  policy_source_set $policy_name "default"
  ls $CONFIG_PATH/stp-policy/$policy_name | grep default
  [[ $? -ne 0 ]] && die "policy for default source is created failure!"
  val=$(cat $CONFIG_PATH/stp-policy/$policy_name/default/clocksync_interval)
  do_cmd "echo 1 > $CONFIG_PATH/stp-policy/$policy_name/default/clocksync_interval"
  do_cmd "echo $val > $CONFIG_PATH/stp-policy/$policy_name/default/clocksync_interval"
}

host_n_test() {
  id=$1
  should_fail "ls -d /sys/bus/platform/devices/INTC* | grep $id"
  load_unload_module.sh -u -d intel_th_pci
  module="intel_th_acpi"
  load_unload_module.sh -c -d $module || \
    do_cmd "load_unload_module.sh -l -d $module"
  should_fail "ls $SYSFS_PATH | grep 0"
  load_unload_module.sh -u -d $module
}

target_n_test(){
  should_fail "lspci -vvv -d ::1300 | grep 1300"
  load_unload_module.sh -u -d intel_th_acpi
  module="intel_th_pci"
  load_unload_module.sh -c -d $module || \
    do_cmd "load_unload_module.sh -l -d $module"
  should_fail "ls $SYSFS_PATH | grep 0"
  load_unload_module.sh -u -d $module
}

dmesg_check() {
  should_fail "extract_case_dmesg | grep BUG"
  should_fail "extract_case_dmesg | grep 'Call Trace'"
}

intel_th_test() {
  if [[ $IOMMU = "disable" ]]; then
    test_print_trc "********************This case need disable IOMMU, please disable IOMMU********************"
    sleep 1
  fi
  case $TEST_SCENARIO in
    dummy_stm)
      dummy_stm_test
      ;;
    sth_dev)
      sth_dev_test
      ;;
    stm_source_console)
      stm_source_test "stm_console" "console"
      ;;
    stm_source_ftrace)
      stm_source_test "stm_ftrace" "ftrace"
      ;;
    stm_source_heartbeat)
      stm_source_test "stm_heartbeat" "heartbeat"
      ;;
    stm_source_console_dummy)
      stm_source_dummy_test "stm_console" "console"
      ;;
    stm_source_ftrace_dummy)
      stm_source_dummy_test "stm_ftrace" "ftrace"
      ;;
    stm_source_heartbeat_dummy)
      stm_source_dummy_test "stm_heartbeat" "heartbeat.0"
      ;;
    stm_source_all_dummy)
      stm_source_all_dummy_test
      ;;
    stm_policy_dummy)
      stm_policy_dummy_test
      ;;
    stm_policy_sth)
      stm_policy_sth_test
      ;;
    stm_policy_set)
      stm_policy_set_test
      ;;
    mth)
      mth_test
      ;;
    mth_cpu)
      mth_cpu_test
      ;;
    protocol_basic)
      protocol_basic_test
      ;;
    protocol_mipi)
      protocol_mipi_test
      ;;
    protocol_basic_w_policy)
      protocol_basic_w_policy_test
      ;;
    protocol_mipi_w_policy)
      protocol_mipi_w_policy_test
      ;;
    protocol_n)
      protocol_n_test
      ;;
    protocol_basic_mipi)
      protocol_basic_mipi_test
      ;;
    protocol_basic_w_default)
      protocol_basic_w_default_test
      ;;
    protocol_mipi_w_default)
      protocol_mipi_w_default_test
      ;;
    msu)
      msu_test
      ;;
    msu_sysfs)
      msu_sysfs_test
      ;;
    msu_enable_disable)
      msu_enable_disable_test
      ;;
    host_mode)
      host_mode_test
      ;;
    host_module)
      host_module_test
      ;;
    msu_trace)
      msu_trace_test
      ;;
    output_basic)
      output_basic_test
      ;;
    output_msc)
      output_with_msc_test
      ;;
    ioctl_set)
      ioctl_set_test
      ;;
    ioctl_get)
      ioctl_get_test
      ;;
    port_sys)
      port_sys_test
      ;;
    wrap)
      wrap_test 1
      ;;
    unwrap)
      wrap_test 0
      ;;
    mmap)
      mmap_test
      ;;
    sink_negtive)
      sink_negtive_test
      ;;
    sink_w_others)
      sink_w_others_test
      ;;
    sink_multi)
      sink_multi_test
      ;;
    gth_remove)
      gth_remove_test
      ;;
    gth_sysfs)
      gth_sysfs_test
      ;;
    msu_sysfs_check)
      msu_sysfs_check_test
      ;;
    pci_remove)
      pci_remove_test
      ;;
    pti_sysfs)
      pti_sysfs_test
      ;;
    stm_sysfs)
      stm_sysfs_test
      ;;
    policy_sysfs)
      policy_sysfs_test
      ;;
    sink_full)
      sink_full_test
      ;;
    npktool_one)
      npktool_test 1
      ;;
    npktool_two)
      npktool_test 2
      ;;
    32_bin)
      32_bin_test
      ;;
    policy_remove)
      policy_remove_test
      ;;
    ftrace_write)
      ftrace_write_test
      ;;
    protocol_mipi_clocksync)
      protocol_mipi_clocksync_test
      ;;
    host_n)
      host_n_test "INTC1001"
      ;;
    host_n_cpu)
      host_n_test "INTC1000"
      ;;
    target_n)
      target_n_test
      ;;
    target_n_cpu)
      target_n_test
      ;;
    ioctl_n)
      ioctl_n_test
      ;;
    esac
  dmesg_check
  return 0
}

while getopts :t:d:s:p:o:i:m:c:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    s)
      SOURCE=$OPTARG
      ;;
    d)
      DEV_POINT=$OPTARG
      ;;
    p)
      PROFILE=$OPTARG
      ;;
    o)
      OUTPUT=$OPTARG
      ;;
    i)
      IOMMU=$OPTARG
      ;;
    m)
      LPOWER=$OPTARG
      ;;
    c)
      CON=$OPTARG
      ;;
    H)
      usage && exit 0
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
teardown_handler="th_teardown"
th_teardown
intel_th_test
# Call teardown for passing case
exec_teardown
