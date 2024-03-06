#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         cpu_common.sh
#
# Description:  common file for cpu features test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      August 14 2017 - created - Pengfei Xu

# @desc provide common functions for cpu features
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"
source "dmesg_functions.sh"

CPU_COMMON_SOURCED="1"
BYTE_NUM=""
SHIFT_RIGHT_NUM=""
SHIFT_LEFT_NUM=""

# Get file content
# $1: file path
# output: if exist print file content, otherwise print nothing
get_file_content() {
  local file_path=$1

  [ -e "$file_path" ] && cat "$file_path"
}

readonly INTEL_BM="/sys/devices/intel_bm"
readonly THRESHOLD_PATH="${INTEL_BM}/threshold"
readonly WINDOW_SIZE_PATH="${INTEL_BM}/window_size"
readonly LBR_FREEZE_PATH="${INTEL_BM}/lbr_freeze"
readonly GUEST_DISABLE_PATH="${INTEL_BM}/guest_disable"
readonly WINDOW_CNT_SEL_PATH="${INTEL_BM}/window_cnt_sel"
readonly CNT_AND_MODE_PATH="${INTEL_BM}/cnt_and_mode"
readonly MISPRED_EVT_CNT_PATH="${INTEL_BM}/mispred_evt_cnt"

readonly THRESHOLD=$(get_file_content "${INTEL_BM}/threshold")
readonly WINDOW_SIZE=$(get_file_content "${INTEL_BM}/window_size")
readonly LBR_FREEZE=$(get_file_content "${INTEL_BM}/lbr_freeze")
readonly GUEST_DISABLE=$(get_file_content "${INTEL_BM}/guest_disable")
readonly WINDOW_CNT_SEL=$(get_file_content "${INTEL_BM}/window_cnt_sel")
readonly CNT_AND_MODE=$(get_file_content "${INTEL_BM}/cnt_and_mode")
readonly MISPRED_EVT_CNT=$(get_file_content "${INTEL_BM}/mispred_evt_cnt")
readonly NULL="null"
readonly CONTAIN="contain"
readonly CET_DRIVER="cet_ioctl"
readonly SYNC_CORE_DRIVER="sync_core_timing"
readonly HP_FILE="/sys/kernel/mm/transparent_hugepage/enabled"
readonly HP_DEFRAG="/sys/kernel/mm/transparent_hugepage/defrag"
readonly HP_CONTENT=$(cat $HP_FILE \
                      | cut -d '[' -f 2 \
                      | cut -d ']' -f 1)
readonly HP_DEFRAG_CONTENT=$(cat $HP_DEFRAG \
                             | cut -d '[' -f 2 \
                             | cut -d ']' -f 1)

readonly POWER_DISK_NODE="/sys/power/disk"
readonly POWER_MEM_SLEEP="/sys/power/mem_sleep"
readonly POWER_PM_TEST_NODE="/sys/power/pm_test"
readonly BIG_CORE_FILE="/sys/devices/system/cpu/types/intel_core_1/cpulist"
readonly ATOM_CORE_FILE="/sys/devices/system/cpu/types/intel_atom_1/cpulist"
readonly THREAD_FEATURE="Thread_features\:"
readonly OFFLINE_FILE="/sys/devices/system/cpu/offline"

PID=""

teardown_handler="cpu_teardown"

# Reserve for taerdown, present no change for cpu test
cpu_teardown() {
  [ -z "$BYTE_NUM" ] || BYTE_NUM=""
  [ -z "$SHIFT_RIGHT_NUM" ] || SHIFT_RIGHT_NUM=""
  [ -z "$SHIFT_LEFT_NUM" ] || SHIFT_LEFT_NUM=""

  [ -z "$THRESHOLD" ] || {
    echo "$THRESHOLD" > "$THRESHOLD_PATH"
    test_print_trc "set origin value:$THRESHOLD in $THRESHOLD_PATH"
  }

  [ -z "$WINDOW_SIZE" ] || {
    echo "$WINDOW_SIZE" > "$WINDOW_SIZE_PATH"
    test_print_trc "set origin value:$WINDOW_SIZE in $WINDOW_SIZE_PATH"
  }

  [ -z "$LBR_FREEZE" ] || {
    echo "$LBR_FREEZE" > "$LBR_FREEZE_PATH"
    test_print_trc "set origin value:$LBR_FREEZE in $LBR_FREEZE_PATH"
  }

  [ -z "$GUEST_DISABLE" ] || {
    echo "$GUEST_DISABLE" > "$GUEST_DISABLE"
    test_print_trc "set origin value:$GUEST_DISABLE in $GUEST_DISABLE_PATH"
  }

  [ -z "$WINDOW_CNT_SEL" ] || {
    echo "$WINDOW_CNT_SEL" > "$WINDOW_CNT_SEL_PATH"
    test_print_trc "set origin value:$WINDOW_CNT_SEL in $WINDOW_CNT_SEL_PATH"
  }

  [ -z "$CNT_AND_MODE" ] || {
    echo "$CNT_AND_MODE" > "$CNT_AND_MODE_PATH"
    test_print_trc "set origin value:$CNT_AND_MODE in $CNT_AND_MODE_PATH"
  }

  [ -z "$MISPRED_EVT_CNT" ] || {
    echo "$MISPRED_EVT_CNT" > "$MISPRED_EVT_CNT_PATH"
    test_print_trc "set origin value:$MISPRED_EVT_CNT in $MISPRED_EVT_CNT_PATH"
  }

  [[ -z "$HP_CONTENT" ]] || echo "$HP_CONTENT" > "$HP_FILE"
  [[ -z "$HP_DEFRAG_CONTENT" ]] \
    || echo "$HP_DEFRAG_CONTENT" > "$HP_DEFRAG"

  lsmod | grep "$CET_DRIVER"
  [[ $? -ne 0 ]] || {
    test_print_trc "unload $CET_DRIVER"
    rmmod $CET_DRIVER
  }

  [[ -z "$PID" ]] || {
    CHECK_PID=$(ps -ef | grep "$PID" | grep -v "=auto")
    [[ -z "$CHECK_PID" ]] || {
      test_print_trc "Kill left unused PID:$PID"
      kill -9 $PID
    }
  }

  lsmod | grep "$SYNC_CORE_DRIVER"
  [[ $? -ne 0 ]] || {
    test_print_trc "unload $SYNC_CORE_DRIVER"
    rmmod $SYNC_CORE_DRIVER
  }
}

# Check this cpu could support the function which contain the parameter
# $1: Parameter should be support in cpuinfo
# Return: 0 for true, otherwise false
cpu_info_check() {
  local cpu_func=$1
  [ -n "$cpu_func" ] || die "cpu info check name is null:$cpu_func"
  grep -q "$cpu_func" /proc/cpuinfo || block_test "CPU not support:$cpu_func"
  test_print_trc "/proc/cpuinfo contain '$cpu_func'"
  return 0
}

online_all_cpu() {
  local off_cpu=""
  local cpu=""
  # cpu start
  local cpu_s=""
  # cpu end
  local cpu_e=""
  local i=""

  test_print_trc "Online all cpu"
  off_cpu=$(cat "$OFFLINE_FILE")
  if [[ -z "$off_cpu" ]]; then
    test_print_trc "No cpu offline:$off_cpu"
  else
    for cpu in $(echo "$off_cpu" | tr ',' ' '); do
      if [[ "$cpu" == *"-"* ]]; then
        cpu_s=""
        cpu_e=""
        i=""
        cpu_s=$(echo "$cpu" | cut -d "-" -f 1)
        cpu_e=$(echo "$cpu" | cut -d "-" -f 2)
        for((i=cpu_s;i<=cpu_e;i++)); do
          do_cmd "echo 1 | sudo tee /sys/devices/system/cpu/cpu${i}/online"
        done
      else
        do_cmd "echo 1 | sudo tee /sys/devices/system/cpu/cpu${cpu}/online"
      fi
    done
    off_cpu=""
    off_cpu=$(cat "$OFFLINE_FILE")
    if [[ -z "$off_cpu" ]]; then
      test_print_trc "No offline cpu:$off_cpu after online all cpu"
    else
      block_test "There is offline cpu:$off_cpu after online all cpu!"
    fi
  fi
}

# Check cpuid matched bit should be set to 1
# $1: The parameter which execute cpuid needed
# Return: 0 for ture, otherwise false or die
cpu_id_check() {
  local cpuid_parm=$1
  local big_cores=""
  local big_core=""
  local atom_cores=""
  local atom_core=""
  local cpu_check=""

  cpu_check=$(which cpuid_check)
  [[ -n "$cpuid_parm" ]] || die "cpu id parameter is null:$cpuid_parm"
  [[ -e "$ATOM_CORE_FILE" ]] && {
    atom_cores=$(cat $ATOM_CORE_FILE)
    atom_core=$(cat $ATOM_CORE_FILE \
            | cut -d '-' -f 1)
    test_print_trc "Will check ATOM core $atom_cores cpu_id $atom_core:"
    do_cmd "taskset -c $atom_core $cpu_check $cpuid_parm"
  }

  if [[ -e "$BIG_CORE_FILE" ]]; then
    big_cores=$(cat $BIG_CORE_FILE)
    big_core=$(cat $BIG_CORE_FILE \
            | cut -d '-' -f 1)
    test_print_trc "Will check big core $big_cores cpu_id $big_core:"
    do_cmd "taskset -c $big_core $cpu_check $cpuid_parm"
  else
    do_cmd "$cpu_check $cpuid_parm"
  fi

}

# Convert the number to binary and only get the low 8 bits
# Input: $1 the number which need convert
# Return low 8 bits with format "xxxx xxxx", otherwise false
convert_binary() {
  num=$1
  local gap=""
  local bin_num=""
  local bin_num_len=""
  local low_num=""
  local byte_num=""
  local i=0
  local j=0
  local end_point

  [ -n "$num" ] || die "Num is null:$num"
  bin_num=$(echo "obase=2;$num"|bc)
  bin_num_len=${#bin_num}
  if [ "$bin_num_len" -lt 4 ]; then
    low_num=${bin_num:0-$bin_num_len}
    end_point=$((4 - bin_num_len))
    for ((i=0; i<end_point; i++)); do
      low_num="0"${low_num}
    done
    byte_num="0000 "${low_num}
  elif [ "$bin_num_len" -lt 8 ]; then
    low_num=${bin_num:0-4}
    gap=$((bin_num_len-4))
    byte_num=${bin_num:0-$bin_num_len:$gap}" ""$low_num"
    end_point=$((4 - gap))
    for ((j=0; j<end_point; j++)); do
      byte_num="0"${byte_num}
    done
  else
    byte_num=${bin_num:0-8:4}" "${bin_num:0-4}
  fi
  test_print_trc "num:$num,binary:$bin_num,length:$bin_num_len,byte_num:$byte_num"
  BYTE_NUM="$byte_num"
}

# Input:
# $1: shift right num bits
# $2: the num need shift right
# Return shift right result low 8 bits with format "xxxx xxxx", otherwise false
shift_right() {
  local shift_num=$1
  local obj_num=$2
  local k=0

  for ((k=0;k<shift_num;k++));do
    obj_num=$(echo "$obj_num"/2|bc)
  done
  convert_binary "$obj_num"
  SHIFT_RIGHT_NUM=$BYTE_NUM
}

# Input:
# $1: shift left num bits
# $2: the num need shift left
# Return shift left result low 8 bits with format "xxxx xxxx", otherwise false
shift_left() {
  local shift_num=$1
  local obj_num=$2
  local n=0

  for ((n=0;n<shift_num;n++));do
    obj_num=$(echo "${obj_num} * 2" | bc)
  done
  convert_binary "$obj_num"
  SHIFT_LEFT_NUM=$BYTE_NUM
}

# Check vbmi test, instruction result is our expect.
# Input:
# $1: bin parameters
# $2: result log path
# Return: 0 for true, otherwise false or die
test_vbmi() {
  local parm=$1
  local log_path=$2
  local par1=""
  local par2=""
  local bin_par2=""
  local dec_par1=""
  local left_par1=""
  local dec_par2=""
  local part1=""
  local part2=""
  local expect_pp0=""
  local expect_pp1=""
  local gap=""

  par1=$(echo "$parm" | cut -d ' ' -f 1)
  par2=$(echo "$parm" | cut -d ' ' -f 2)
  dec_par1=$((0x$par1))
  dec_par2=$((0x$par2))
  convert_binary "$dec_par2"
  bin_par2="$BYTE_NUM"

  # part1 is checking high 3 bytes fill with 3 times bin_par2
  part1="$bin_par2"' '"$bin_par2"' '"$bin_par2"

  left_par1=$((dec_par1%64))
  if [ "$left_par1" -le 24 ]; then
    shift_right "$left_par1" "$dec_par2"
    part2="$SHIFT_RIGHT_NUM"
  elif [ "$left_par1" -lt 56 ]; then
    part2="0000 0000"
  else
    gap=$((64-left_par1))
    test_print_trc "shift_left gap:$gap, dec_par2:$dec_par2"
    shift_left "$gap" "$dec_par2"
    part2="$SHIFT_LEFT_NUM"
  fi
  test_print_trc "left_par1:$left_par1, dec_par1:$dec_par1, part2:$part2"
  expect_pp0="$part1"' '"$part2"
  test_print_trc "******expect_pp1[0](second half):$expect_pp0"
  expect_pp1="$part1"' '"$bin_par2"
  test_print_trc "******expect_pp1(first half):$expect_pp1"

  grep  "$expect_pp0" "$log_path" | grep -q "pp1\[0\]" \
    || die "Compare pp1[0] fail: not same as expect_pp0:$expect_pp0"
  test_print_trc "Check $log_path pass."
}

# Check dmesg log, result should contain or not contain key word
# Input:
# $1: key word
# $2: par, 'null' means should not contain key word, 'contain' means
#     contain key word
# Return: 0 for true, otherwise false or die
dmesg_check() {
  local key=$1
  local par=$2
  local dmesg_path=""
  local dmesg_info=""
  local dmesg_result=""

  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] \
    || die "No case dmesg:$LOG_PATH/$dmesg_path exist"
  dmesg_info=$(cat "$LOG_PATH"/"$dmesg_path")
  dmesg_result=$(echo "$dmesg_info" | grep -i "$key")
  case $par in
    $CONTAIN)
      test_print_trc "key:$key should in dmesg info:$dmesg_result"
      [[ -n "$dmesg_result" ]] || die "No $key in dmesg"
      ;;
    $NULL)
      test_print_trc "key:$key should not exist in dmesg info:$dmesg_result"
      if [[ -z "$dmesg_result" ]]; then
        test_print_trc "No $key in dmesg:$dmesg_result"
      else
        die "Should not contain $key in dmesg:$dmesg_result"
      fi
      ;;
    *)
      block_test "Invalid par:$par"
      ;;
  esac
}

# Check umip dmesg should executed expect instruction and then check
# expected GP exception is worked
# Input
# $1: instruction name: sgdt, sidt, sldt, smsw or str
# Return: 0 for true, otherwise false or die
umip_dmesg_check() {
  local ins_name=$1
  local exist=$2
  local gp="general protection"

  dmesg_check "$ins_name" "$CONTAIN"

  # Check #GP is already triggered
  [[ -n "$exist" ]] || exist=$CONTAIN
  dmesg_check "$gp" "$exist"
}

# Check test bin results should contain "RESULTS" and no "[fail]" in it
# Input: log path
# Return: 0 for true, otherwise false or die
log_common_check() {
  log=$1

  grep -q -i "\[FAIL\]" "$log" && die "$log contain [FAIL]"
  test_print_trc "Check $log pass, no [FAIL] in it"
}

# Show key test info in DDT log
# Input:
# $1: log path
# $2: filter key info in log, "all" for w/o filter, other for filter key name
# Return: 0 for true, otherwise false or die
show_test_info() {
  local log=$1
  local key=$2
  local all="all"
  local key_info=""

  test_print_trc "Show $key info in $log:"
  if [[ "$key" == "$all" ]]; then
    key_info=$(cat "$log")
  else
    key_info=$(cat "$log" | grep -i "$key")
  fi
  test_print_trc "$key_info"
  test_print_trc "$log end."
}

# Execute cpu function binary program test and check success or fail
# $1: Binary program name to execute
# $2: Parameter need for binary test
# $3: Function name
# $4: For umip other item check or reserved item
# Return: 0 for true, otherwise false or die
cpu_func_parm_test() {
  local bin_name=$1
  local bin_parm=$2
  local name=$3
  local reserve=$4
  local exist=$5
  local bin_parm_name=""
  local log_path="/tmp/$name"
  local fail="fail"
  local all="all"
  local log=""
  local key=""
  local call_trace="Call Trace"
  local seg="segfault"
  local err="error"
  local bp_add=""
  local sp=""
  local ssp=""
  local obj_log="/tmp/${bin_name}.txt"
  local bin=""
  local result=""
  local cet_key="control protection"
  local kibt_key="Missing ENDBR"
  local kshstk_key="control_protection"

  [ -n "$bin_name" ] || die "File $bin_name was not exist"
  [ -n "$bin_parm" ] || die "parameter: $bin_parm was null"
  [ -d "$log_path" ] || mkdir "$log_path"
  bin=$(which $bin_name)
  if [[ -e "$bin" ]]; then
    test_print_trc "Find bin:$bin"
  else
    die "bin:$bin does not exist"
  fi

  bin_parm_name=$(echo "$bin_parm" | tr ' ' '_')
  if [ "$bin_parm" == "null" ]; then
    log="${log_path}/${bin_name}_${bin_parm_name}.log"
    $bin > "$log"
  else
    log="${log_path}/${bin_name}_${bin_parm_name}.log"
    $bin ${bin_parm} > "$log"
  fi

  [ -e "$log" ] || die "No $log file"
  case $name in
    vbmi)
      show_test_info "$log" "$all"
      log_common_check "$log"
      test_vbmi "$bin_parm" "$log"
      ;;
    cet)
      show_test_info "$log" "$all"
      log_common_check "$log"
      dmesg_check "$cet_key" "$CONTAIN"
      dmesg_check "$call_trace" "$NULL"
      ;;
    cet_kmod_shstk)
      show_test_info "$log" "$all"
      log_common_check "$log"
      dmesg_check "$kshstk_key" "$CONTAIN"
      ;;
    cet_kmod_ibt)
      show_test_info "$log" "$all"
      log_common_check "$log"
      dmesg_check "$kibt_key" "$CONTAIN"
      ;;
    cet_pass)
      show_test_info "$log" "$all"
      log_common_check "$log"
      dmesg_check "$cet_key" "$NULL"
      dmesg_check "$call_trace" "$NULL"
      ;;
    cet_noseg)
      show_test_info "$log" "$all"
      dmesg_check "$cet_key" "$NULL"
      dmesg_check "$call_trace" "$NULL"
      dmesg_check "$seg" "$NULL"
      dmesg_check "$err" "$NULL"
      ;;
    cet_seg)
      show_test_info "$log" "$all"
      dmesg_check "$cet_key" "$NULL"
      dmesg_check "$seg" "$CONTAIN"
      ;;
    ibt32)
      show_test_info "$log" "$all"
      dmesg_check "$call_trace" "$NULL"
      ;;
    cet_legacy)
      show_test_info "$log" "$all"
      dmesg_check "$cet_key" "$NULL"
      dmesg_check "$call_trace" "$NULL"
      ;;
    cet_ssp)
      key="control protection"
      show_test_info "$log" "$all"
      dmesg_check "$key" "$NULL"
      dmesg_check "$call_trace" "$NULL"
      ssp=$(cat "$log" \
            | grep "ssp" \
            | tail -1 \
            | awk -F "*ssp=0x" '{print $2}' \
            | cut -d ' ' -f 1)
      bp_add=$(cat $log \
              | grep "ssp" \
              | tail -1 \
              | awk -F ":0x" '{print $2}' \
              | cut -d ' ' -f 1)
      [[ -n "$ssp" ]] || na_test "platform not support cet ssp check"
      do_cmd "objdump -d $bin > $obj_log"
      sp=$(cat $obj_log \
            | grep -A1  "<shadow_stack_check>$" \
            | tail -n 1 \
            | awk '{print $1}' \
            | cut -d ':' -f 1)
      if [[ "$ssp" == *"$sp"* ]]; then
        test_print_trc "sp:$sp is same as ssp:$ssp, pass"
      else
        test_print_wrg "sp:$sp is not same as ssp:$ssp"
        test_print_trc "clear linux compiler changed sp"
      fi
      if [[ "$bp_add" == "$ssp" ]] ; then
        test_print_trc "bp+1:$bp_add is same as ssp:$ssp, pass"
      else
        die "bp+1:$bp_add is not same as ssp:$ssp"
      fi
      ;;
    umip)
      show_test_info "$log" "$fail"
      log_common_check "$log"
      [[ -z "$reserve" ]] \
        || umip_dmesg_check "$reserve" "$exist"
      ;;
    rar)
      show_test_info "$log" "$all"
      log_common_check "$log"
      result=$(cat "$log" | grep -i "$fail")
      [[ -z "$result" ]] || die "There is fail info in $log:$result"
      dmesg_check "$call_trace" "$NULL"
      ;;
    xsave)
      show_test_info "$log" "$all"
      result=$(cat "$log" | grep -i "$fail")
      [[ -z "$result" ]] || die "There is fail info in $log:$result"
      dmesg_check "$call_trace" "$NULL"
      ;;
    *)
      show_test_info "$log" "$all"
      test_print_trc "No need extra check for $name"
      ;;
  esac
  return 0
}

# Check test used time cycles in log, and print 2 test logs gap rate
# $1: 1st test log file
# $2: 2nd test log file
# $3: test log folder path
# Return: 0 for true, otherwise false or die
cet_perf_compare() {
  local file1=$1
  local file2=$2
  local path=$3
  local key_word="RESULTS"
  local cycle1=""
  local cycle2=""
  local gap=""
  local gap_rate=""
  local result=""
  local gap_upper="0.6"
  local gap_lower="-2.0"

  cycle1=$(cat $path/$file1 | grep "$key_word" | cut -d ':' -f 4)
  cycle2=$(cat $path/$file2 | grep "$key_word" | cut -d ':' -f 4)
  test_print_trc "$file1 used cycles $cycle1"
  test_print_trc "$file2 used cycles $cycle2"
  gap=$(echo "$cycle1 - $cycle2" | bc)
  gap_rate=$(echo "scale=4;$gap/$cycle1" | bc)
  test_print_trc "$file1 and $file2 gap rate:$gap_rate"
  result=$(echo "$gap_rate > $gap_lower && $gap_rate < $gap_upper" | bc)
  [[ $result -eq 1 ]] || {
    test_print_wrg "gap: $gap_rate is not in the range:$gap_lower ~ $gap_upper"
    return 1
  }
}

# Execute cpu rop binary with perf and check result
# $1: Binary program name to execute
# $2: Parameter need for binary test
# $3: cpu module name
# $4: expected result
# Return: 0 for true, otherwise false or die
cpu_func_rop_test() {
  local bin_name=$1
  local bin_parm=$2
  local expect_result=$3
  local name=$4
  local actual_result=""
  local log_path="/tmp/$name"
  local log_detail=""

  [ -n "$bin_name" ] || die "File $bin_name was not exist"
  [ -n "$bin_parm" ] || die "parameter: $bin_parm was null"
  [ -n "$expect_result" ] || die "No expect result:$expect_result"

  [ -d "$log_path" ] || mkdir "$log_path"
  perf stat \
    -o ${log_path}/${bin_name}.log \
    -e $bin_parm "${bin_name}"
  [ -e "${log_path}/${bin_name}.log" ] \
    || die "No file ${log_path}/${bin_name}.log"

  log_detail=$(cat ${log_path}/${bin_name}.log)
  test_print_trc "${log_path}/${bin_name}.log:"
  test_print_trc "$log_detail"
  test_print_trc "${log_path}/${bin_name}.log end."
  [ -e "${log_path}/${bin_name}.log" ] \
    || die "No ${bin_name}.log file"

  [ -n "$expect_result" ] || die "expect_result is null:$expect_result"
  # use 1st part of bin_parm to filter test result, split by ' '
  bin_parm=$(echo "$bin_parm" | cut -d ' ' -f 1)
  actual_result=$(echo "$log_detail" \
                        | grep "$bin_parm" \
                        | tail -1 \
                        | awk -F ' ' '{print $1}')
  if [ "$expect_result" == "$actual_result" ]; then
    test_print_trc "$bin_name get expected $bin_parm num:$actual_result, pass"
  else
    die "$bin_name $bin_parm num, expect:$expect_result, acutal:$actual_result"
  fi
  return 0
}

# Check the result by filter matched content last line and 1st part value
# Input:
#   $1: log file path
#   $2: filter content for usefule result
#   $3: expected result value to compare
# Return: 0 for true, otherwise false or die
f1_result_check() {
  local log_file=$1
  local filter=$2
  local expect_result=$3
  local log_detail=""
  local actual_result=""

  [ -n "$log_file" ] || die "No log file:$log_file"
  [ -n "$filter" ] || die "No filter:$filter"
  [ -n "$expect_result" ] || die "No expect result:$expect_result"

  [ -s "$log_file" ] || die "Check log file:$log_file was not exist or empty"
  log_detail=$(cat $log_file)
  test_print_trc "$log_file:"
  test_print_trc "$log_detail"
  test_print_trc "$log_file end"
  actual_result=$(echo "$log_detail" \
                  | grep "$filter" \
                  | tail -1 \
                  | awk -F ' ' '{print $1}')
  if [ "$expect_result" == "$actual_result" ]; then
    test_print_trc "Check $log_file pass, expect:$expect_result actual:$actual_result"
  else
    die "Check $log_file fail, expect:$expect_result, acutal:$actual_result"
  fi
}

# Executed common command
# Inupt:
#   $1: common command need execute
#   $2: filter content to filter useful result value
#   $3: expected reuslt value
#   $4: function name to create log path and log file
#   $5: out put info, error means check error log, pass check pass log
# Return: 0 for true, otherwise false or die
common_cmd() {
  local cmd_name=$1
  local filter=$2
  local result=$3
  local func=$4
  local err_pass=$5
  local log_path="/tmp/$func"
  local log_file="${log_path}/${func}.log"

  [ -n "$cmd_name" ] || die "Command was not exist:$cmd_name"
  [ -n "$filter" ] || die "Filter content was not exist:$filter"
  [ -n "$result" ] || die "Expect result was not exist:$result"
  [ -n "$func" ] || die "function name was not exist:$func"

  [ -d "$log_path" ] || mkdir "$log_path"

  case $err_pass in
    error)
      ${cmd_name} 2> $log_file
      ;;
    *)
      ${cmd_name} > $log_file
      ;;
  esac

  [ -s "$log_file" ] || die "$cmd_name fail, $log_file was not exist or empty"

  case $func in
    rop)
      f1_result_check "$log_file" "$filter" "$result"
      ;;
    *)
      test_print_trc "No need extra check for $name"
      ;;
  esac
  do_cmd "rm -rf $log_file"
}


# Execute command and check result
# $1: command for cpu test
# $2: expect success or fail
# $3: expect result or null which means no need check result for fail result
# $4: cpu module name
# Return: 0 for true, otherwise false or die
cpu_cmd_test() {
  local cmd_name=$1
  local success_fail=$2
  local expect_result=$3
  local name=$4
  local log_path="/tmp/$name"
  local result_log="${log_path}/${name}.log"
  local log_content=""
  local error_return=""

  [ -e "${result_log}" ] && do_cmd "rm -rf ${result_log}"
  [ -n "$expect_result" ] || die "No expect result:$expect_result"
  [ -d "$log_path" ] || mkdir "$log_path"

  case $success_fail in
  success)
    $cmd_name > "$result_log"
    if [ $? -eq 0 ]; then
      test_print_trc "Executed $cmd_name pass."
    else
      do_cmd "cat $result_log"
      die "Execute $cmd_name fail, expected result should pass!"
    fi
    ;;
  fail)
    $cmd_name > "$result_log" 2>&1
    error_return=$?
    if [ "$error_return" -eq 0 ]; then
      cat $result_log
      die "Execute $cmd_name success, expected result should fail!"
    else
      test_print_trc "Fail as expected, return value:$error_return, pass"
    fi
    ;;
  *)
    die "Error: success_fail value is not success or fail:$success_fail"
    ;;
  esac

  log_content=$(cat "$result_log")
  if [ "$expect_result" == "null" ]; then
    test_print_trc "No need check content"
  else
    [[ "$log_content" == *"$expect_result"* ]] || \
      die "No $expect_result in log_content"
  fi
  return 0
}

# Check sysfs file content is our expect
# $1: sysfs file path
# $2: expected sysfs file content
# Return: 0 for true, otherwise false or die
sysfs_check() {
  local sysfs_path=$1
  local expect_result=$2
  local actual_result=""

  actual_result=$(cat "$sysfs_path")
  [ -n "$expect_result" ] || die "expect result is null:$expect_result"
  if [ "$actual_result" != "$expect_result" ]; then
    die "$sysfs_path content is not $expect_result:$actual_result"
  else
    test_print_trc "$sysfs_path:$actual_result, pass"
  fi
}

# Modify sysfs file
# $1: sysfs file need modfify, must contain '=': file_path=modify_content
# Output: 0 for true, otherwise false or die
modify_sysfs_file() {
  local content=$1
  local file_path=""
  local file_content=""

  [[ "$content" == *"="* ]] || die "No = in the modify content"
  file_path=$(echo "$content" | cut -d '=' -f 1)
  file_content=$(echo "$content" | cut -d '=' -f 2)
  [ -e "$file_path" ] || die "File not exist:$file_path"

  test_print_trc "Set $file_content in $file_path"
  echo "$file_content" > "$file_path"
  if [ "$?" -eq 0 ]; then
    return 0
  else
    test_print_trc "Set value:$file_content in $file_path failed!"
    return 1
  fi
}

# Set rop sysfs files as default value
# No input
# Return: 0 for true, otherwise false or die
set_rop_sysfs_default() {
  modify_sysfs_file "$THRESHOLD_PATH=127"
  [ $? -eq 0 ] || block_test "Set $THRESHOLD_PATH=0 fail"
  modify_sysfs_file "$WINDOW_SIZE_PATH=1023"
  [ $? -eq 0 ] || block_test "Set $WINDOW_SIZE_PATH=1023 fail"
  modify_sysfs_file "$LBR_FREEZE_PATH=0"
  [ $? -eq 0 ] || block_test "Set $LBR_FREEZE_PATH=0 fail"
  modify_sysfs_file "$GUEST_DISABLE_PATH=0"
  [ $? -eq 0 ] || block_test "Set $GUEST_DISABLE_PATH=0 fail"
  modify_sysfs_file "$WINDOW_CNT_SEL_PATH=0"
  [ $? -eq 0 ] || block_test "Set $WINDOW_CNT_SEL_PATH=0 fail"
  modify_sysfs_file "$CNT_AND_MODE_PATH=0"
  [ $? -eq 0 ] || block_test "Set $CNT_AND_MODE_PATH=0 fail"
  modify_sysfs_file "$MISPRED_EVT_CNT_PATH=0"
  [ $? -eq 0 ] || block_test "Set $MISPRED_EVT_CNT_PATH=0 fail"
}

# Check CET bin file could support SHSTK and IBT or not
# Input:
#   $1: bin name
#   $2: func name, cet for cet, legacy for wo cet and so on
# Return: 0 for true, otherwise false or die
elf_check() {
  local bin=$1
  local func=$2
  local shstk="SHSTK"
  local ibt="IBT"
  local bin_path="ddt_intel/cpu/$bin"
  local stk_check=""
  local ibt_check=""

  case $func in
    cet)
      # Check shadow stack should support in bin
      do_cmd "readelf -n $bin_path | grep -i $shstk"
      # Check indirect branch tracking should support in bin
      do_cmd "readelf -n $bin_path | grep -i $ibt"
      ;;
    shstk)
      do_cmd "readelf -n $bin_path | grep -i $shstk"
      ;;
    ibt)
      do_cmd "readelf -n $bin_path | grep -i $ibt"
      ;;
    legacy)
      stk_check=$(readelf -n "$bin_path" | grep -i "$shstk")
      ibt_check=$(readelf -n "$bin_path" | grep -i "$ibt")
      # legacy bin file should not contain shstk and ibt
      [[ -z "$stk_check" ]] || die "$bin should legacy but contain:$stk_check"
      [[ -z "$ibt_check" ]] || die "$bin should legacy but contain:$ibt_check"
      ;;
    *)
      test_print_wrg "Invalid func:$func for elf check, not cet/shstk/ibt."
      ;;
  esac
}

# Check bin file contain the instruction like endbr64 or not
# Input:
#   $1: bin name
#   $2: instruction name: endbr64 or endbr32 for ibt
# Return: 0 for true, otherwise false or die
obj_dump() {
  local bin=$1
  local ins=$2
  local bin_path="ddt_intel/cpu/$bin"

  do_cmd "objdump -d $bin_path | grep -i $ins"
}

# Load cet driver
# Input: NA
# Return: 0 for true, otherwise false or die
load_cet_driver() {
  local result=""
  local driver_file="ddt_intel/cpu/${CET_DRIVER}.ko"

  result=$(lsmod | grep "$CET_DRIVER")
  [[ -n "$result" ]] || {
    do_cmd "insmod $driver_file"
    sleep 1
    result=$(lsmod | grep "$CET_DRIVER")
  }
  [[ -n "$result" ]] || die "cet driver $CET_DRIVER load failed:$result"
  test_print_trc "Load $CET_DRIVER ok, lsmod:$result"
}

# Execute suspend test
# Input $1: suspend type like freeze, s2idle
# Output: 0 for true, otherwise false or die
suspend_test() {
  local suspend_type=$1
  local rtc_time=20
  local disk_time=50
  local mem="mem"

  # Clear Linux no /sys/power/disk and pm_test, add the judgement
  if [[ -e "$POWER_DISK_NODE" ]]; then
    do_cmd "echo platform > '$POWER_DISK_NODE'"
  else
    test_print_trc "No file $POWER_DISK_NODE exist"
  fi
  if [[ -e "$POWER_PM_TEST_NODE" ]]; then
    do_cmd "echo none > '$POWER_PM_TEST_NODE'"
  else
    test_print_trc "No file $POWER_PM_TEST_NODE exist"
  fi

  case $suspend_type in
    freeze)
      test_print_trc "rtcwake -m $suspend_type -s $rtc_time"
      rtcwake -m "$suspend_type" -s "$rtc_time"
      [ "$?" -eq 0 ] || die "fail to resume from $suspend_type!"
      sleep 10
      ;;
    s2idle)
      test_print_trc "set $suspend_type in $POWER_MEM_SLEEP"
      echo "$suspend_type" > $POWER_MEM_SLEEP
      test_print_trc "rtcwake -m $mem -s $rtc_time"
      rtcwake -m "$mem" -s "$rtc_time"
      [ "$?" -eq 0 ] || die "fail to resume from $suspend_type!"
      ;;
    s3|deep)
      suspend_type="deep"
      test_print_trc "set $suspend_type in $POWER_MEM_SLEEP"
      echo "$suspend_type" > $POWER_MEM_SLEEP
      test_print_trc "rtcwake -m $mem -s $rtc_time"
      rtcwake -m "$mem" -s "$rtc_time"
      [ "$?" -eq 0 ] || die "fail to resume from $suspend_type!"
      ;;
    s4|disk)
      suspend_type="disk"
      test_print_trc "rtcwake -m $suspend_type -s $disk_time"
      rtcwake -m "$suspend_type" -s "$disk_time"
      [ "$?" -eq 0 ] || die "fail to resume from $suspend_type!"
      ;;
    *)
      die "suspend_type: $suspend_type not support"
      ;;
  esac
  sleep 10
}

# check rdmsr result
# Input $1: like "0xcf 1" rdmsr 0xcf and check bit 1 is 1 or 0
#           check bit start from 0
# Output: 0 for true, otherwise false or die
msr_test() {
  local msr="msr"
  local content="$1"
  local addr=""
  local check_bit=""
  local result=""

  load_unload_module.sh -c -d "$msr" || {
    test_print_trc "load module $msr"
    load_unload_module.sh -l -d "$msr"
  }
  addr=$(echo "$content" | cut -d " " -f 1)
  check_bit=$(echo $content | cut -d " " -f 2)
  [[ -n "$addr" ]] || block_test "addr:$addr was null"
  [[ -n "$check_bit" ]] || block_test "check_bit:$check_bit was null"
  sleep 1
  msr_info=$(rdmsr $addr)
  [[ -n "$msr_info" ]] \
    || block_test "msr_info was null:$msr_info, could not read $addr"

  msr_info=$(echo $msr_info | head -n 1)
  result=$((16#$msr_info))
  test_print_trc "rdmsr $addr result: 0x$msr_info"

  for((i=0; i<$check_bit; i++)); do
    result=$((result/2))
  done
  result=$((result%2))
  if [[ "$result" -eq "1" ]]; then
    test_print_trc "msr_info:$msr_info contain bit $check_bit, return 0"
    return 0
  else
    test_print_trc "msr_info:$msr_info didn't match with check_bit:$check_bit"
    return 1
  fi
}

# check whole dmesg, which should contain key words
# Input $1: key word
# Output: 0 for true, otherwise false or die
full_dmesg_check() {
  local key_word=$1
  local dmesg_head=""
  local check_log=""

  dmesg_head=$(dmesg | grep "\[    0.000000\]" | head -n 1)
  [[ -n $dmesg_head ]] \
    || block_test "dmesg was not started from 0.000000, skip test"
  check_log=$(dmesg | grep -v "LTP" | grep "$key_word")
  if [[ -n "$check_log" ]]; then
    test_print_trc "Dmesg contain '$key_word':$check_log"
  else
    die "Dmesg didn't contain '$key_word':$check_log"
  fi
}

# check whole dmesg, which should not contain key words
# Input $1: key word
# Output: 0 for true, otherwise false or die
dmesg_not_contain() {
  local key_word=$1
  local check_log=""
  local dmesg_file=""
  local hostname=""
  local date=""

  hostname=$(hostname);
  date=$(date +%Y-%m-%d_%H_%M_%S);
  dmesg_file="/root/${hostname}_${date}.txt"
  check_log=$(dmesg | grep -i "$key_word")
  if [[ -n "$check_log" ]]; then
    do_cmd "dmesg > $dmesg_file"
    die "Dmesg $dmesg_file contained '$key_word':$check_log"
  else
    test_print_trc "Dmesg didn't contain '$key_word':$check_log"
  fi
}

# criu tool to dump and restore process test
# Input $1: test binary or script
# Output: 0 for true, otherwise false or die
criu_test() {
  local bin_name=$1
  local criu_path=""
  local criu_log_path="/tmp/criu"
  local bin_first_part=""
  local bin_left_part=""
  local olds=""
  local bin_pid=""
  local check_pid=""
  local bin_log=""

  # Check criu and bin name and ps -ef
  criu_path=$(which criu 2>/dev/null)
  [[ -n "$criu_path" ]] || block_test "No criu tool:$criu_path"
  if [[ "$bin_name" == *"_"* ]]; then
    bin_first_part=$(echo "$bin_name" | cut -d '_' -f 1)
    bin_left_part=$(echo "$bin_name" | cut -d '_' -f 2)
    olds=$(ps -ef \
          | grep "$bin_first_part" \
          | grep "$bin_left_part" \
          | grep -v "\-p" \
          | awk -F " " '{print $2}')
    for old in $olds; do
      test_print_trc "kill $bin_name:$old before test"
      do_cmd "kill -9 $old"
    done
    [[ -d "$criu_log_path" ]] || {
      test_print_trc "No folder:$criu_log_path, create it"
      rm -rf $criu_log_path
      do_cmd "mkdir -p $criu_log_path"
    }

    # Start test and avoid terminal affected by parent process, so use setsid
    do_cmd "setsid '$bin_name' < /dev/null &> ${criu_log_path}/test_${bin_name}.log &"
    bin_pid=$(ps -ef \
              | grep "$bin_first_part" \
              | grep "$bin_left_part" \
              | grep -v "\-p" \
              | head -n 1 \
              | awk -F " " '{print $2}')
    if [[ -n "$bin_pid" ]]; then
      test_print_trc "$bin_name:$bin_pid existed"
    else
      die "No $bin_name pid:$bin_pid at the beginning"
    fi
    sleep 2
    do_cmd "cd $criu_log_path"
    do_cmd "criu dump -t $bin_pid -vvv -o dump_${bin_name}.log"
    test_print_trc "Check dump_${bin_name}.log"
    cat dump_${bin_name}.log
    check_pid=""
    check_pid=$(ps -ef \
              | grep "$bin_first_part" \
              | grep "$bin_left_part" \
              | grep -v "\-p" \
              | awk -F " " '{print $2}')
    # After criu dump this process should be saved and didn't exist
    if [[ -z "$check_pid" ]]; then
      test_print_trc "criu dump $bin_name:$bin_pid didn't exist as expected"
    else
      die "criu dump $bin_name:$bin_pid still had:$check_pid"
    fi
    sleep 3
    do_cmd "criu restore -d -vvv -o ${criu_log_path}/restore_${bin_name}.log"
    check_pid=$(ps -ef \
              | grep "$bin_first_part" \
              | grep "$bin_left_part" \
              | grep -v "\-p" \
              | awk -F " " '{print $2}')
    if [[ -z "$check_pid" ]]; then
      die "criu restore, no $bin_name:$check_pid pid"
    else
      test_print_trc "criu restore, $bin_name resumed:$check_pid"
    fi
    sleep 3
    bin_log=$(tail -n 8 ${criu_log_path}/test_${bin_name}.log)
    [[ -n "$bin_log" ]] || {
      test_print_trc "${criu_log_path}/test_${bin_name}.log->test_show_date.log"
      bin_name="show_date"
      bin_log=$(tail -n 8 ${criu_log_path}/test_${bin_name}.log)
    }
    test_print_trc "${criu_log_path}/test_${bin_name}.log:$bin_log"

    dmesg_check "bad frame" "$NULL"
    dmesg_check "Call Trace" "$NULL"
  else
      block_test "No '_' in bin_name:$bin_name"
  fi

  # kill the test script or binary to resume the environment
  do_cmd "kill -9 $check_pid"
}

# Check each cpu with test binary, it should trigger key word in dmesg
# Input $1: test binary or script
#       $2: test binary parmeter
#       $3: key word in dmesg
# Output: 0 for true, otherwise false or die
all_cpu_test() {
  local bin_name=$1
  local parm=$2
  local key=$3
  local cpu_num=""
  local dmesg_prev=""
  local dmesg_present=""

  cpu_num=$(cat /proc/cpuinfo| grep "physical id"| wc -l)
  dmesg_prev=$(dmesg | grep "$key" | tail -n 1)
  for ((i=0; i<cpu_num; i++)); do
    sleep 1
    dmesg_present=""
    test_print_trc "taskset -c $i $bin_name $parm"
    taskset -c $i $bin_name $parm
    dmesg_present=$(dmesg | grep "$key" | tail -n 1)
    if [[ "$dmesg_prev" == "$dmesg_present" ]]; then
      die "${i}nd $bin_name $parm, prev:$dmesg_prev is same as $dmesg_present"
    else
      test_print_trc "${i}nd $bin_name $parm, pass present:$dmesg_present"
      dmesg_prev="$dmesg_present"
    fi
  done
  test_print_trc "All $cpu_num CPU thread passed $bin_name $parm test"
}

# Check all cpu msr value should match with expected value
# Input $1: rdmsr value
#       $2: rdmsr check high bit
#       $3: rdmsr check low bit
#       $4: rdmsr check expected value
# Output: 0 for true, otherwise false or die
check_msr() {
  local msr_value=$1
  local high_bit=$2
  local low_bit=$3
  local check_value=$4
  local value_exist=""
  local other_value=""

  # For some old version kernel, need to load msr module
  test_print_trc "modprobe msr"
  modprobe msr
  value_exist=$(rdmsr $msr_value --bitfield $high_bit:$low_bit -a \
              | grep $check_value)
  if [[ -n "$value_exist" ]]; then
    test_print_trc "rdmsr $msr_value $high_bit:$low_bit exist $check_value"
  else
    die "rdmsr $msr_value $high_bit:$low_bit doesn't exist $check_value"
  fi
  other_value=$(rdmsr $msr_value --bitfield $high_bit:$low_bit -a \
              | grep -v $check_value)
  if [[ -n "$other_value" ]]; then
    die "rdmsr $msr_value $high_bit:$low_bit contain other value:$other_value"
  else
    test_print_trc "rdmsr $msr_value $high_bit:$low_bit all $check_value pass"
  fi
}

basic_check_msr() {
  local msr_value=$1
  local check_value=""

  # For some old version kernel, need to load msr module
  test_print_trc "modprobe msr"
  modprobe msr
  do_cmd "rdmsr -a $msr_value"
  check_value=$(rdmsr -a "$msr_value")
  if [[ -z "$check_value" ]]; then
    die "rdmsr -a $msr_value result is null:$check_value"
  else
    test_print_trc "rdmsr -a $msr_value result:$check_value"
  fi
}

# Check legacy/shstk process, it contains shstk or not in /proc/pid/status
# Input $1: test binary which should contain at least one "_"
#       $2: parmeter shstk or null
# Output: 0 for true, otherwise false or die
check_arch_status() {
  local bin_name=$1
  local parm=$2
  local status="status"
  local shstk="shstk"
  local first_part=""
  local left_part=""
  local pid_info=""
  local check_shstk=""

  first_part=$(echo "$bin_name" | cut -d '_' -f 1)
  left_part=$(echo "$bin_name" | cut -d '_' -f 2)
  do_cmd "$bin_name &"
  PID=$(ps -ef | grep "$first_part" \
               | grep "$left_part" \
               | grep "$bin_name" \
               | grep -v "cet_func" \
               | grep -v "=auto" \
               | head -n 1 \
               | awk -F ' ' '{print $2}')
  pid_info=$(ps -ef | grep "$first_part" \
               | grep "$left_part" \
               | grep "$bin_name" \
               | grep -v "cet_func" \
               | grep -v "=auto" \
               | head -n 1)

  [[ -z "$PID" ]] && die "Could not get the pid for $bin_name"
  test_print_trc "Find $bin_name pid info:$pid_info"
  if [[ "$parm" != "$NULL" ]]; then
    check_shstk=$(cat /proc/${PID}/${status} \
                  | grep "$THREAD_FEATURE" \
                  | grep "$parm")
    if [[ -z "$check_shstk" ]]; then
      die "$bin_name /proc/${PID}/${status} is null:$check_shstk"
    else
      test_print_trc "$bin_name /proc/${PID}/${status} $check_shstk. Pass."
    fi
  else
    check_shstk=$(cat /proc/${PID}/${status} \
                  | grep "$THREAD_FEATURE" \
                  | grep -v "$shstk")
    if [[ -z "$check_shstk" ]]; then
      die "$bin_name /proc/${PID}/${status} $THREAD_FEATURE is not null"
    else
      test_print_trc "$bin_name /proc/${PID}/${status} $check_shstk null PASS."
    fi
  fi
}

driver_test() {
  local driver_name=$1
  local driver_file=""
  local mod_name=""
  local is_mod_load=""

  if [[ -e "ddt_intel/cpu/$driver_name" ]]; then
    driver_file="ddt_intel/cpu/$driver_name"
  else
    driver_file=$(which "$driver_name")
    [[ -n "$driver_file" ]] \
      || block_test "No $driver_name file:$driver_file found"
  fi
  mod_name=$(echo "$driver_name" | awk -F ".ko" '{print $1}')
  test_print_trc "Test mod:$mod_name"
  is_mod_load=$(lsmod | grep "$mod_name")
  [[ -z "$is_mod_load" ]] || {
    test_print_trc "mod $mod_name is loaded, rmmod it and then test it."
    do_cmd "rmmod $mod_name"
  }
  do_cmd "insmod $driver_file"
}
