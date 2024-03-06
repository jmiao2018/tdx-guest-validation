#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Author:
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Dec. 23, 2019 - (Ammy Yi)Creation


# @desc This script verify telemetry test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
source "dmesg_functions.sh"

: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

SYSFS_PATH="/sys/class/intel_pmt"
WATCHER_SYSFS_PATH="/sys/class/intel_pmt/"
CRASHLOG_SYSFS_PATH="/sys/class/intel_pmt/"
TEL_COUNT=0
FREQ=38400000

telem_sysfs_test() {
  do_cmd "ls $SYSFS_PATH | grep telem"
}

telem_dev_test() {
  do_cmd "ls $SYSFS_PATH | grep telem"
}

telem_sysfs_common_test() {
  ids=$(ls $SYSFS_PATH | xargs)
  [[ -z $ids ]] && die "No telemetry device found!"
  for id in $ids; do
    do_cmd "cat $SYSFS_PATH/$id/guid"
    do_cmd "cat $SYSFS_PATH/$id/size"
    do_cmd "ls $SYSFS_PATH/$id | grep device"
    should_fail "echo 0 > $SYSFS_PATH/$id/guid"
    should_fail "echo 0 > $SYSFS_PATH/$id/size"
  done
}

telem_data_test() {
  offset=$1
  bin=$2
  tel_bin="telemetry_tests"
  [[ $bin -eq 32 ]] && tel_bin="telemetry_tests_32"
  ids=$(ls $SYSFS_PATH | grep telem)
  [[ -z $ids ]] && die "No telemetry device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    size=$(cat $SYSFS_PATH/$id/size)
    let size=size-1
    do_cmd "ls $SYSFS_PATH/$id/telem"
    do_cmd "$tel_bin 1 $SYSFS_PATH/$id/telem $size $offset"
  done
}

get_frequency_server() {
  index=$(read_pmt_telemetry $id 0 | awk -v FS="" '{print $11}')
  case $index in
    0)
      FREQ=24000000
      ;;
    4)
      FREQ=19200000
      ;;
    8)
      FREQ=38400000
      ;;
    c)
      FREQ=25000000
      ;;
  esac
}

get_frequency() {
  file=$1
  mode=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  index=$(grep "0x4=" $file | awk '{print $4}')
  test_print_trc "frequency_id_bin=$index!"
  ((index=2#$index))
  test_print_trc "frequency_id=$index!"
  test_print_trc "mode=$mode!"
  case $mode in
    140)
      case $index in
        0)
          FREQ=24000000
          ;;
        1)
          FREQ=19200000
          ;;
        2)
          FREQ=38400000
          ;;
        3)
          FREQ=25000000
          ;;
      esac
      ;;
    151)
      case $index in
        0)
          FREQ=24000000
          ;;
        1)
          FREQ=19200000
          ;;
        2)
          FREQ=38400000
          ;;
        3)
          FREQ=25000000
          ;;
      esac
      ;;
  esac
  test_print_trc "frequency=$FREQ!"
}

get_tel_count() {
  size=$1
  start_add=$2
  file=$3
  count=0
  test_print_trc "size=$size start_add=$start_add file=$file!"
  for((i=7;i>=0;i--)); do
    let addr=start_add+i
    addr_16=$(echo "obase=16;$addr" |bc | tr 'A-Z' 'a-z')
    val=$(grep "0x${addr_16}=" $file | awk '{print $4}')
    test_print_trc "addr=$addr addr_16=$addr_16 count=$val!"
    count=$count$val
  done
  test_print_trc "count_total=$count!"
  ((count=2#$count))
  TEL_COUNT=$count
}

get_c2_residency() {

  file=$1
  stepping=${CPU_STEPPING}
  test_print_trc "stepping=$stepping!"
  mode=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  case $mode in
    140)
      case $stepping in
        "B0")
          start_add=0x318
          ;;
        *)
          start_add=0x318
          ;;
      esac
      ;;
    151)
      case $stepping in
        *)
          start_add=0x1e8
          ;;
      esac
      ;;
    154)
      start_add=0x1e8
      ;; 
    183)
      start_add=0x270
      ;;
    170)
      start_add=0x50
      ;;
  esac
  test_print_trc "start_add=$start_add!"
  get_tel_count 7 $start_add $file
  test_print_trc "TEL_COUNT=$TEL_COUNT!"
}

get_c2_counts() {
  file=$1
  stepping=${CPU_STEPPING}
  test_print_trc "stepping=$stepping!"
  read_pmt_telemetry $id 129 > $aaa
  test_print_trc "read_pmt_telemetry aaa=$aaa!"
  platform=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  case $platform in
    140)
      case $stepping in
      "B0")
        start_add=0x668
        ;;
      *)
        start_add=0x668
        ;;
        esac
      ;;
    151)
      case $stepping in
      *)
        start_add=0x658
        ;;
        esac
      ;;
    154)
      start_add=0x1e0
      ;;
      esac
  test_print_trc "start_add=$start_add!"
  get_tel_count 3 $start_add $file
  test_print_trc "TEL_COUNT=$TEL_COUNT!"
}

get_guid() {
  platform=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  case $platform in
    170)
      guid=13067102
      ;;
      esac
}

telem_data_c2_residency_test() {
  offset=$1
  tel_log="telem.log"
  ids=$(ls $SYSFS_PATH | grep telem)
  model=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  if [[ $model -eq 151 ]] || [[ $model -eq 154 ]]; then
    ids=$(ls $SYSFS_PATH | grep telem | head -1)
  fi
  load_unload_module.sh -c -d msr || \
    do_cmd "load_unload_module.sh -l -d msr"
  [[ -z $ids ]] && die "No telemetry device found!"
  ids="telem4"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    size=$(cat $SYSFS_PATH/$id/size)
    let size=size-1
    sleep 1
    model=$(cat /proc/cpuinfo | grep model | awk '{print $3}' | head -1)

    if [[ $model -eq 143 ]]; then
      TEL_COUNT=$(read_pmt_telemetry $id 209 | cut -d "x" -f2)
      get_frequency_server
    else
      if [[ $model -eq 171 ]]; then
        test_print_trc "************MTL*************!"
        TEL_COUNT=$(read_pmt_telemetry $id 50 | cut -d "x" -f2); msr_count=$(rdmsr 0x60d)
        get_frequency_server
      else
        telemetry_tests 1 "$SYSFS_PATH/$id/telem" $size $offset > "$tel_log"; msr_count=$(rdmsr 0x60d)
        get_frequency $tel_log
        get_c2_residency $tel_log
        [[ -s $tel_log ]] || die "telemetry date got failed!"
      fi
    fi
    base_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/base_frequency)
    test_print_trc "base_freq=$base_freq XTAL_FREQ=$FREQ TEL_COUNT=$TEL_COUNT!"
    let tel_count_tsc=base_freq*1000/FREQ*TEL_COUNT
    test_print_trc "tel_count_tsc=$tel_count_tsc!"
    test_print_trc "msr_count_16=$msr_count"
    ((msr_count=16#$msr_count))
    test_print_trc "msr_count=$msr_count"
    let delta=msr_count-tel_count_tsc
    let raf=tel_count_tsc*5/100
    test_print_trc "delta=$delta raf=$raf"
    [[ $TEL_COUNT -eq 0 ]] && die "telemetry is 0!"
    [[ $delta -le $raf ]] || die "telemetry date cannot match with msr count!"
  done
}

telem_data_c2_counts_test() {
  offset=$1
  tel_log="telem.log"
  ids=$(ls $SYSFS_PATH | grep telem)
  [[ -z $ids ]] && die "No telemetry device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    size=$(cat $SYSFS_PATH/$id/size)
    let size=size-1
    telemetry_tests 1 $SYSFS_PATH/$id/telem $size $offset > $tel_log
    [ -s $tel_log ] || die "telemetry date got failed!"
    get_c2_counts $tel_log
    count_1=$TEL_COUNT
    test_print_trc "count_1=$count_1"
    [[ $count_1 = 0 ]] && die "telemetry c2 counts is 0!"
    sleep 5
    get_c2_counts $tel_log
    count_2=$TEL_COUNT
    test_print_trc "count_2=$count_2"
    [[ $count_2 > $count_1 ]] || die "telemetry c2 counts no change!"
  done
}

telem_data_c1c0_residency_test() {
  tel_log="telem.log"
  #run stress
  stress-ng --cpu 200 &
  sleep 5
  # get c0/c1 count
  tel_id=$(ls /sys/class/intel_pmt/ | grep tel |  sed '2,$d')
  model=$(cat /proc/cpuinfo | grep model | awk '{print $3}' | head -1)
  if [[ $model -eq 173 ]]; then
    tel_id=telem3
    read_pmt_telemetry $tel_id 2 > $tel_log
  fi
  tel_value=$(cat $tel_log)
  test_print_trc "tel_value=$tel_value"
  c1_count=$(echo ${tel_value:0-16:8})
  c1_count=$(echo $c1_count | sed 's/x//g')
  test_print_trc "c1_count=$c1_count"
  c0_count=$(echo ${tel_value:0-8:8})
  test_print_trc "c0_count=$c0_count"
  sleep 5
  #check if c1 no change and c0 change
  test_print_trc "Get C0/C1 counter during stress-ng!"
  if [[ $model -eq 173 ]]; then
    tel_id=telem3
    read_pmt_telemetry $tel_id 2 > $tel_log
  fi
  tel_value=$(cat $tel_log)
  test_print_trc "tel_value=$tel_value"
  c1_count_end=$(echo ${tel_value:0-16:8})
  c1_count_end=$(echo $c1_count_end | sed 's/x//g')
  test_print_trc "c1_count_end=$c1_count_end"
  c0_count_end=$(echo ${tel_value:0-8:8})
  test_print_trc "c0_count_end=$c0_count_end"
  pid=$(ps | grep "stress-ng" | awk '{print $1}')
  kill -9 $pid
  [[ $c1_count_end = $c1_count ]] || die "telemetry c1 counts changed during stress-ng!"
  [[ $c0_count_end != $c0_count ]] || die "telemetry c0 counts no change during stress-ng!"
}

smplr_data_test() {
  offset=$1
  ids=$(ls $WATCHER_SYSFS_PATH | grep smplr)
  [[ -z $ids ]] && die "No smplr device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    size=$(cat $SYSFS_PATH/$id/size)
    do_cmd "telemetry_tests 1 /dev/$id $size $offset"
  done
}

watcher_sysfs_test() {
  do_cmd "ls $WATCHER_SYSFS_PATH | grep $1"
}

watcher_sysfs_common_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep $1 | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/guid"
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/size"
    should_fail "echo 0 > $WATCHER_SYSFS_PATH/$id/guid"
    should_fail "echo 0 > $WATCHER_SYSFS_PATH/$id/size"
  done
}

watcher_sysfs_mode_set_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep $1 | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo periodic > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo oneshot > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
  done
}

watcher_sysfs_period_us_set_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep $1 | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo 10 > $WATCHER_SYSFS_PATH/$id/period_us"
    do_cmd "echo periodic > $WATCHER_SYSFS_PATH/$id/mode"
    should_fail "echo 10 > $WATCHER_SYSFS_PATH/$id/period_us"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo oneshot > $WATCHER_SYSFS_PATH/$id/mode"
    should_fail "echo 10 > $WATCHER_SYSFS_PATH/$id/period_us"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
  done
}

trcr_sysfs_destination_set_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep trcr | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    for val in "trace_hub" "oob" "irq"; do
      do_cmd "echo $val > $WATCHER_SYSFS_PATH/$id/destination"
    done
    do_cmd "echo periodic > $WATCHER_SYSFS_PATH/$id/mode"
    for val in "trace_hub" "oob" "irq"; do
      should_fail "echo $val > $WATCHER_SYSFS_PATH/$id/destination"
    done
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo oneshot > $WATCHER_SYSFS_PATH/$id/mode"
    for val in "trace_hub" "oob" "irq"; do
      should_fail "echo $val > $WATCHER_SYSFS_PATH/$id/destination"
    done
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
  done
}

watcher_sysfs_vector_set_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep $1 | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/vector"
    do_cmd "echo 111111 > $WATCHER_SYSFS_PATH/$id/vector"
    do_cmd "cat $WATCHER_SYSFS_PATH/$id/vector_length"
    should_fail "echo 1 > $WATCHER_SYSFS_PATH/$id/vector_length"
    do_cmd "echo periodic > $WATCHER_SYSFS_PATH/$id/mode"
    should_fail "echo 111111 > $WATCHER_SYSFS_PATH/$id/vector"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo oneshot > $WATCHER_SYSFS_PATH/$id/mode"
    should_fail "echo 111111 > $WATCHER_SYSFS_PATH/$id/vector"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
  done
}

crashlog_sysfs_test() {
  do_cmd "ls $CRASHLOG_SYSFS_PATH | grep crashlog"
}

pci_test() {
  do_cmd "lspci -knnv | grep -c intel_vsec"
}

pre_unload_driver() {
  rmmod intel_pmc_core
  rmmod intel_tpmi_pem
  rmmod intel_tpmi_pem_core
  rmmod intel_rapl_tpmi
  rmmod isst_tpmi
  rmmod isst_tpmi_core
  rmmod intel_uncore_frequency_tpmi
  rmmod intel_vsec_tpmi
}

driver_test() {
  module=$1
  pre_unload_driver
  load_unload_module.sh -c -d $module && \
    do_cmd "load_unload_module.sh -u -d $module"
  do_cmd "load_unload_module.sh -l -d $module"
  sleep 5
  pre_unload_driver
  do_cmd "load_unload_module.sh -u -d $module"
  do_cmd "load_unload_module.sh -l -d $module"
}

crashlog_sysfs_tri_test() {
  test_v=$1
  ids=$(ls $CRASHLOG_SYSFS_PATH | grep crashlog)
  [[ -z $ids ]] && die "No crashlog device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    do_cmd "echo 0 > $CRASHLOG_SYSFS_PATH/$id/enable"
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/enable"
    if [[ $test_v -eq 0 ]]; then
      val=$(cat $CRASHLOG_SYSFS_PATH/$id/trigger)
      [[ $val -eq 0 ]] || die "crashlog should be 0!"
    elif [[ $test_v -eq 1 ]]; then
      do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/trigger"
      val=$(cat $CRASHLOG_SYSFS_PATH/$id/trigger)
      [[ $val -eq 1 ]] || die "crashlog should be 1!"
    fi
  done
}

crashlog_sysfs_tri_w_test() {
  ids=$(ls $CRASHLOG_SYSFS_PATH | grep crashlog)
  [[ -z $ids ]] && die "No crashlog device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    do_cmd "echo 0 > $CRASHLOG_SYSFS_PATH/$id/enable"
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/enable"
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/trigger"
    do_cmd "echo 0 > $CRASHLOG_SYSFS_PATH/$id/trigger"
    val=$(cat $CRASHLOG_SYSFS_PATH/$id/trigger)
    [[ $val -eq 0 ]] || die "crashlog should be 0!"
  done
}

crashlog_data_test() {
  offset=$1
  bin=$2
  tel_bin="telemetry_tests"
  size=1024
  [[ $bin -eq 32 ]] && tel_bin="telemetry_tests_32"
  ids=$(ls $CRASHLOG_SYSFS_PATH | grep crashlog)
  [[ -z $ids ]] && die "No crashlog device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    do_cmd "$tel_bin 1 /$CRASHLOG_SYSFS_PATH/$id/crashlog $size $offset"
  done
}

crashlog_data_verify_test() {
  offset=$1
  bin=$2
  tel_bin="telemetry_tests"
  size=1024
  init_data="crashlog_init.data"
  end_data="crashlog_end.data"
  [[ $bin -eq 32 ]] && tel_bin="telemetry_tests_32"
  ids=$(ls $CRASHLOG_SYSFS_PATH | grep crashlog)
  [[ -z $ids ]] && die "No crashlog device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    hexdump /$CRASHLOG_SYSFS_PATH/$id/crashlog > $init_data
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/enable"
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/trigger"
    hexdump /$CRASHLOG_SYSFS_PATH/$id/crashlog > $end_data
    val=$(diff $init_data $end_data)
    [[ $val -eq 0 ]] && die "No crashlog genegrated after trigger!"
  done
}

crashlog_data_clear_test() {
  offset=$1
  bin=$2
  tel_bin="telemetry_tests"
  size=1024
  init_data="crashlog_init.data"
  end_data="crashlog_end.data"
  [[ $bin -eq 32 ]] && tel_bin="telemetry_tests_32"
  ids=$(ls $CRASHLOG_SYSFS_PATH | grep crashlog)
  [[ -z $ids ]] && die "No crashlog device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    hexdump /$CRASHLOG_SYSFS_PATH/$id/crashlog > $init_data
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/enable"
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/trigger"
    hexdump /$CRASHLOG_SYSFS_PATH/$id/crashlog > $end_data
    val=$(diff $init_data $end_data)
    [[ $val -eq 0 ]] && die "No crashlog genegrated after trigger!"
    do_cmd "echo 0 > $CRASHLOG_SYSFS_PATH/$id/trigger"
    hexdump /$CRASHLOG_SYSFS_PATH/$id/crashlog > $end_data
    val=$(diff $init_data $end_data)
    [[ $val -eq 0 ]] || die "crashlog is not cleared!"
  done
}

crashlog_data_disable_test() {
  ids=$(ls $CRASHLOG_SYSFS_PATH | grep crashlog)
  [[ -z $ids ]] && die "No crashlog device found!"
  test_print_trc "ids=$ids!"
  for id in $ids; do
    test_print_trc "id=$id!"
    do_cmd "echo 0 > $CRASHLOG_SYSFS_PATH/$id/enable"
    do_cmd "echo 1 > $CRASHLOG_SYSFS_PATH/$id/trigger"
    val=$(cat $CRASHLOG_SYSFS_PATH/$id/trigger)
    [[ $val -eq 0 ]] || die "crashlog should be 0!"
  done
}

pch_telemetry_test() {
  guid="0x2625030"
  tel_v="71902fb7"
  ids=$(ls $SYSFS_PATH | grep telem)
  for id in $ids; do
    t_guid=$( cat $SYSFS_PATH/$id/guid)
    if [[ $guid = $t_guid ]]; then
      test_print_trc "t_guid=$t_guid equal to $guid!"
      do_cmd "xxd -e -c4 -g4 $SYSFS_PATH/$id/telem | grep $tel_v"
    fi    
  done
}

dmesg_check() {
  should_fail "extract_case_dmesg | grep BUG"
  should_fail "extract_case_dmesg | grep 'Call Trace'"
  should_fail "extract_case_dmesg | grep error"
}

watcher_periodic_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep watcher | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo periodic > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
  done  
}

watcher_shared_test() {
  ids=$(ls $WATCHER_SYSFS_PATH |grep watcher | xargs)
  [[ -z $ids ]] && die "No watcher device found!"
  for id in $ids; do
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo periodic > $WATCHER_SYSFS_PATH/$id/mode"
    do_cmd "echo off > $WATCHER_SYSFS_PATH/$id/mode"
  done  
}

watcher_data_test() {
  tel_log="tel.log"
  watcher_log="watcher.log"
  SYSFS_PATH="/sys/class/intel_pmt"
  do_cmd "echo off > $WATCHER_SYSFS_PATH/watcher1/mode"
  do_cmd "echo 1000 > $WATCHER_SYSFS_PATH/watcher1/enable_vector"
  enable_list=$(cat $WATCHER_SYSFS_PATH/watcher1/enable_list)
  do_cmd "echo oneshot > $WATCHER_SYSFS_PATH/watcher1/mode"
  xxd -e -c8 -g8 $WATCHER_SYSFS_PATH/watcher1/watcher | head -15 > $tel_log \
    && xxd -e -c8 -g8 $SYSFS_PATH/telem1/telem | head -15 > $watcher_log
  watcher_val=$(cat $watcher_log | grep 00000060 | awk '{print $2}')
  tel_val=$(cat $tel_log | grep 00000048 | awk '{print $2}')
  test_print_trc "tel_val = $tel_val, watcher_val=$watcher_val"
  do_cmd "echo off > $WATCHER_SYSFS_PATH/watcher1/mode"
  
  [[ $watcher_val = $tel_val ]] || die "watcher value not equal to telemetry!"
  [[ $enable_list -eq 12 ]] || die "enable_list is not correct!"
}

watcher_guid_test() {
  guid1=$(cat $WATCHER_SYSFS_PATH/watcher1/guid)
  guid2=$(cat $WATCHER_SYSFS_PATH/watcher2/guid)
  [[ $guid1 = $guid2 ]] && die "watcher guid is same!"
}

watcher_limit_ne_test() {
  should_fail "echo 1 >  $WATCHER_SYSFS_PATH/watcher1/enable_id_limit"
}


telemetry_test() {
  case $TEST_SCENARIO in
    telem_sysfs)
      telem_sysfs_test
      ;;
    telem_dev)
      telem_dev_test
      ;;
    telem_sysfs_common)
      telem_sysfs_common_test
      ;;
    telem_data)
      telem_data_test 0
      ;;
    crashlog_sysfs)
      crashlog_sysfs_test
      ;;
    trcr_sysfs)
      watcher_sysfs_test trcr
      ;;
    trcr_sysfs_common)
      watcher_sysfs_common_test trcr
      ;;
    trcr_sysfs_mode_set)
      watcher_sysfs_mode_set_test trcr
      ;;
    trcr_sysfs_period_us_set)
      watcher_sysfs_period_us_set_test trcr
      ;;
    trcr_sysfs_destination_set)
      trcr_sysfs_destination_set_test
      ;;
    trcr_sysfs_vector_set)
      watcher_sysfs_vector_set_test trcr
      ;;
    smplr_sysfs)
      watcher_sysfs_test watcher
      ;;
    smplr_sysfs_common)
      watcher_sysfs_common_test watcher
      ;;
    smplr_sysfs_mode_set)
      watcher_sysfs_mode_set_test watcher
      ;;
    smplr_sysfs_period_us_set)
      watcher_sysfs_period_us_set_test watcher
      ;;
    smplr_sysfs_vector_set)
      watcher_sysfs_vector_set_test watcher
      ;;
    smplr_data)
      smplr_data_test 0
      ;;
    telem_data_c2_residency)
      telem_data_c2_residency_test 0
      ;;
    telem_data_c2_counts)
      telem_data_c2_counts_test 0
      ;;
    pci)
      pci_test
      ;;
    telem_driver)
      driver_test "pmt_telemetry"
      ;;
    crashlog_driver)
      driver_test "pmt_crashlog"
      ;;
    watcher_driver)
      driver_test "pmt_watcher"
      ;;
    telem_data_32)
      telem_data_test 0 32
      ;;
    pci_driver)
      driver_test "intel_vsec"
      ;;
    crashlog_sysfs_tri_0)
      crashlog_sysfs_tri_test 0
      ;;
    crashlog_sysfs_tri_1)
      crashlog_sysfs_tri_test 1
      ;;
    crashlog_sysfs_tri_W_0)
      crashlog_sysfs_tri_w_test
      ;;
    crashlog_data)
      crashlog_data_test 0
      ;;
    crashlog_data_32)
      crashlog_data_test 0 32
      ;;
    crashlog_data_disable)
      crashlog_data_disable_test
      ;;
    telem_data_c1c0_residency)
      telem_data_c1c0_residency_test
      ;;
    crashlog_data_verify)
      crashlog_data_verify_test
      ;;
    crashlog_data_clear)
      crashlog_data_clear_test
      ;;
    watcher_periodic)
      watcher_periodic_test
      ;;
    watcher_data)
      watcher_data_test
      ;;
    watcher_shared)
      watcher_shared_test
      ;;
    watcher_guid)
      watcher_guid_test
      ;;
    watcher_limit_ne)
      watcher_limit_ne_test
      ;;
    pch_telemetry)
      pch_telemetry_test
      ;;
    esac
  dmesg_check
  return 0
}

while getopts :t:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
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

telemetry_test
# Call teardown for passing case
exec_teardown
