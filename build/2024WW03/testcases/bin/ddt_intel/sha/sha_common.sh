#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 1,                                                                ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         sha_common.sh
#
# Description:  Common file for Intel SHA Test
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      July 4 2017 - Created - Pengfei Xu

# @desc provide common functions for sha
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"
source "dmesg_functions.sh"

CPU_PATH="/sys/devices/system/cpu/cpu0/cpufreq"
CPU0_GOVERNOR_ORIGINAL=$(cat ${CPU_PATH}/scaling_governor)

# Set the performance CPU
function set_performance_cpu()
{
  echo "performance" > ${CPU_PATH}/scaling_governor || \
  die "Set performance cpu failed!"
}

# Check sha1 and 256 used sha_ni or not
# Input: test name like sha1
# Return: 0 for true, otherwise print warning or die
test_shani() {
  local sha_name=$1
  local tcrypt_num=""
  local sha_speed=""
  local ni="ni"
  local ni_content=""
  local dmesg_path=""

  case $sha_name in
    sha1)
      tcrypt_num="303"
      ;;
    sha256)
      tcrypt_num="304"
      ;;
  esac

  # tcrypt test will return 1 as default, return 0 will give warnning to check
  modprobe tcrypt mode=$tcrypt_num
  [[ $? -eq 0 ]] && test_print_wrg "modprobe tcrypt mode=$tcrypt_num return 0"

  sleep 1
  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] || {
    test_print_wrg "No dmesg file:$LOG_PATH/$dmesg_path exist"
    return 1
  }
  sha_speed=$(< "$LOG_PATH"/"$dmesg_path" grep "testing speed of" | tail -n 1 )
  test_print_trc "$sha_name sha_speed:$sha_speed; dmesg:$LOG_PATH/$dmesg_path"
  [[ -n "$sha_speed" ]] || die "sha_speed was null in dmesg:$sha_speed"
  ni_content=$(echo "$sha_speed" | grep "$ni")
  if [[ -z "$ni_content" ]]; then
    test_print_wrg "$sha_name tcrypt $tcrypt_num didn't found $ni"
  else
    test_print_trc "$sha_name tcrypt $tcrypt_num contain $ni"
  fi
}

# Execute sha checksums action many times and caculate finished time
# Input:
#   $1: checksum command need execute
#   $2: execute checksum times
# Return:
#   True if stress test no error or warning, false otherwise
function sha_checksum_test()
{
  local sha_checksum=$1
  local checksum_times=$2
  local start_time
  start_time=$(date "+%s.%N")
  # Execute this many times, only print failed cases
  for ((i=0;i<checksum_times;i++)); do
    echo "Test checksums with string like this: $checksum_times" | \
    $sha_checksum > /dev/null || die "Test $sha_checksum failed!"
  done
  local end_time
  end_time=$(date "+%s.%N")
  local interval_time
  interval_time=$(echo "$end_time - $start_time" | bc)
  test_print_trc "$sha_checksum used $interval_time seconds in $i times checksums."
}

# Test sha256 and 512 decode speed in different bytes blocks.
# Input: none
# Return:
#   true if generate speed result ok, false otherwise
function test_sha_speed()
{
  echo "performance" > "$CPU_PATH"/scaling_governor
  sleep 1
  do_cmd "openssl speed sha256 sha512"
  if [ $? -eq 0 ]; then
    test_print_trc "Test sha256 sha512 speed pass!"
    return 0
  else
    return 1
  fi
}

# Check sha1 256 512 mulit buffer installed or not, if no, install it
# Input:
#   $1 sha1/256/512_mb
#   $2 like CONFIG_CRYPTO_SHA1_MB
# Return:
#   true(0) means installed ok, otherwise failed
function check_type_install()
{
  local module=$1
  local config=$2
  local sha_config
  sha_config=$(get_kconfig "$config")
  if [ "$sha_config" == "m" ]; then
    test_print_trc "$config=m pass!"
    load_unload_module.sh -l -d "$module"
    if [ $? -eq 0 ]; then
      test_print_trc "Install $module ok."
      return 0
    else
      die "Install $module failed!"
    fi
  elif [ "$sha_config" == "y" ]; then
    skip_test "$config set y, no need modprobe."
  else
    block_test "$config does not set to y or m, block multi buffer test!"
  fi
  return 0
}

# Compare the numbers, previous one +1 should greater or equal than next one
# Input:  more than 2 number
# Return: 0 for true, otherwise false
is_decreasing() {
  [ "$#" -gt 1 ] || die "2 or more argument is required!"
  local pre=$1
  for cur in "$@"; do
    if [ $((pre+1)) -ge "$cur" ]; then
      pre=$cur
    else
      test_print_wrg "$pre + 1 should not less than $cur"
      return 1
    fi
  done
  return 0
}

# Get the cycles/byte in old linux version before 4.15.0, if newer than 4.15.0
# linux version, will get the cycles/byte in new way
# Input: $1, get the test times number
# Output: the cycles/byte result
get_cycles_byte() {
  local test_num=$1
  local cycles_byte=""
  local cycles=""
  local bytes=""

  cycles_byte=$(dmesg | grep "$test_num" | tail -n 1 \
        | awk -F 'operation,' '{print $2}' \
        | awk -F ' cycles' '{print $1}' \
        | awk -F ' ' '{print $NF}')

  # new way to get the cycles/byte, if old way could not get result
  if [[ -z $cycles_byte ]]; then
    cycles=$(dmesg | grep "$test_num" | tail -n 1 \
              | awk -F 'operation in ' '{print $2}' \
              | awk -F ' cycles' '{print $1}')
    bytes=$(dmesg | grep "$test_num" | tail -n 1 \
              | awk -F '(' '{print $NF}' \
              | awk -F ' bytes' '{print $1}')
    cycles_byte=$(echo "$cycles"/"$bytes" | bc)
  fi
  echo "$cycles_byte"
}

# Test sha1 256 512 multi buffer and without multi buffer cycle per byte
# Multi buffer should less cycles than without mulit buffer in 8192 bytes block
# Input:
#   $1 sha1/256/512_mb
# Return:
#   true(0) multi buffer less cycles than no multi buffer in 8192 bytes block
#   false otherwise
function test_sha_mb() {
  local module=$1
  local CPU_MAX_FREQ
  CPU_MAX_FREQ=$(cat "$CPU_PATH"/scaling_max_freq)
  local CPU_ORIGINAL_FREQ
  CPU_ORIGINAL_FREQ=$(cat "$CPU_PATH"/scaling_cur_freq)
  local TEST_RESULT=0
  local t0="test  0"
  local t2="test  2"
  local t5="test  5"
  local t8="test  8"
  local t12="test 12"
  local t16="test 16"
  local t21="test 21"
  local dmesg_path=""

  test_print_trc "This platform CPU max freq: $CPU_MAX_FREQ"
  test_print_trc "Original CPU GOVERNOR mode: $CPU0_GOVERNOR_ORIGINAL"
  test_print_trc "Original CPU0 freq: $CPU_ORIGINAL_FREQ"

  if [ "$CPU0_GOVERNOR_ORIGINAL" != "performance" ]; then
    echo "performance" > "$CPU_PATH"/scaling_governor
    sleep 2
    test_print_trc "After set perf CPU freq: $(cat "$CPU_PATH"/scaling_cur_freq)"
  fi

  if [ "$module" == "sha1_mb" ]; then
    SHA_NAME="SHA1"
    SHA_MB_MODE=422   #sha1_mb multi buffer
    SHA_MODE=303      #sha1 without multi buffer
  elif [ "$module" == "sha256_mb" ]; then
    SHA_NAME="SHA256"
    SHA_MB_MODE=423   #sha256_mb multi buffer
    SHA_MODE=304      #sha256 without multi buffer
  elif [ "$module" == "sha512_mb" ]; then
    SHA_NAME="SHA512"
    SHA_MB_MODE=424   #sha512_mb multi buffer
    SHA_MODE=306      #sha512 without multi buffer
  fi

  # sha_mb multi buffer test, tcrypt test will return 1 as default
  # due to new upstream in linux kernel, need set num_mb=8 as default
  # linux before 4.15.0, num_mb=8 not used and didn't impact result, and
  # hard code multi buffer number is 8
  test_print_trc "modprobe tcrypt mode=$SHA_MB_MODE num_mb=8"
  modprobe tcrypt mode=$SHA_MB_MODE num_mb=8
  [[ $? -eq 0 ]] && test_print_wrg "mb mode=$tcrypt_num num_mb=8 return 0"

  sleep 2
  SHA_MB_CHECK=$(dmesg \
                  | grep "testing speed of" \
                  | tail -n 1 \
                  | grep "multibuffer" \
                  | grep -i "mb")
  SHA_MB_SPEED=$(dmesg | grep "testing speed of" | tail -n 1 )

  if [ "$SHA_MB_CHECK" == "" ]; then
    test_print_wrg "modprobe tcrypt mode=$SHA_MB_MODE result: $SHA_MB_SPEED"
    test_print_trc "Could not find $module in above result, didn't support $module mod!"
    test_print_trc "The result is not precise and result most possible failed!"
    ((TEST_RESULT+=1))
  fi

  shamb_t0_cycle_byte=$(get_cycles_byte "$t0")
  shamb_t2_cycle_byte=$(get_cycles_byte "$t2")
  shamb_t5_cycle_byte=$(get_cycles_byte "$t5")
  shamb_t8_cycle_byte=$(get_cycles_byte "$t8")
  shamb_t12_cycle_byte=$(get_cycles_byte "$t12")
  shamb_t16_cycle_byte=$(get_cycles_byte "$t16")
  shamb_t21_cycle_byte=$(get_cycles_byte "$t21")

  #sha without multi buffer test, return 1 as default, return 0 will warnning
  test_print_trc "modprobe tcrypt mode=$SHA_MODE"
  modprobe tcrypt mode=$SHA_MODE
  [[ $? -eq 0 ]] && test_print_wrg "generic tcrypt mode=$SHA_MODE return 0"

  sleep 2
  SHA_SPEED=$(dmesg | grep "testing speed of" | tail -n 1 )
  shaavx_t0_cycle_byte=$(get_cycles_byte "$t0")
  shaavx_t2_cycle_byte=$(get_cycles_byte "$t2")
  shaavx_t5_cycle_byte=$(get_cycles_byte "$t5")
  shaavx_t8_cycle_byte=$(get_cycles_byte "$t8")
  shaavx_t12_cycle_byte=$(get_cycles_byte "$t12")
  shaavx_t16_cycle_byte=$(get_cycles_byte "$t16")
  shaavx_t21_cycle_byte=$(get_cycles_byte "$t21")

  test_print_trc "$SHA_MB_SPEED"
  SHA_MB_RESULT=$(printf "Cycle per byte| t0: %-8s t2: %-8s t5: %-8s \
t8: %-8s t12: %-8s t16: %-8s t21: %-8s\n" "$shamb_t0_cycle_byte" \
                "$shamb_t2_cycle_byte" "$shamb_t5_cycle_byte" \
                "$shamb_t8_cycle_byte" "$shamb_t12_cycle_byte" \
                "$shamb_t16_cycle_byte" "$shamb_t21_cycle_byte")

  SHA_RESULT=$(printf "Cycle per byte| t0: %-8s t2: %-8s t5: %-8s \
t8: %-8s t12: %-8s t16: %-8s t21: %-8s\n" "$shaavx_t0_cycle_byte"  \
                "$shaavx_t2_cycle_byte" "$shaavx_t5_cycle_byte" \
                "$shaavx_t8_cycle_byte" "$shaavx_t12_cycle_byte" \
                "$shaavx_t16_cycle_byte" "$shaavx_t21_cycle_byte")

  test_print_trc "$SHA_MB_RESULT"
  test_print_trc "$SHA_SPEED"
  test_print_trc "$SHA_RESULT"

  is_decreasing "$shamb_t0_cycle_byte" "$shamb_t2_cycle_byte" \
                "$shamb_t5_cycle_byte" "$shamb_t8_cycle_byte" \
                "$shamb_t12_cycle_byte" "$shamb_t16_cycle_byte" \
                "$shamb_t21_cycle_byte"

  is_decreasing "$shaavx_t0_cycle_byte" "$shaavx_t2_cycle_byte" \
                "$shaavx_t5_cycle_byte" "$shaavx_t8_cycle_byte" \
                "$shaavx_t12_cycle_byte" "$shaavx_t16_cycle_byte" \
                "$shaavx_t21_cycle_byte"

  test_print_trc "Compare number for $SHA_NAME multibuffer"
  is_decreasing "$shamb_t0_cycle_byte" "$shamb_t8_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shamb_t0_cycle_byte" "$shamb_t12_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shamb_t0_cycle_byte" "$shamb_t21_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shamb_t2_cycle_byte" "$shamb_t16_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shamb_t5_cycle_byte" "$shamb_t21_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  test_print_trc "Compare number for $SHA_NAME without multibuffer"
  is_decreasing "$shaavx_t0_cycle_byte" "$shaavx_t8_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shaavx_t0_cycle_byte" "$shaavx_t12_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shaavx_t0_cycle_byte" "$shaavx_t21_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shaavx_t2_cycle_byte" "$shaavx_t16_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  is_decreasing "$shaavx_t5_cycle_byte" "$shaavx_t21_cycle_byte"
  [ "$?" -eq 0 ] || ((TEST_RESULT+=1))

  if [ "$shamb_t21_cycle_byte" -gt "$shaavx_t21_cycle_byte" ]; then
    test_print_trc "Unexpect result in $SHA_NAME test!"
    test_print_trc "multi buffer t21: $shamb_t21_cycle_byte"
    test_print_trc "bigger than no multi buffer t21: $shaavx_t21_cycle_byte"
    ((TEST_RESULT+=1))
  fi

  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] \
    || test_print_wrg "No dmesg file:$LOG_PATH/$dmesg_path exist"
  test_print_trc "dmesg log:$LOG_PATH/$dmesg_path"

  echo "$CPU0_GOVERNOR_ORIGINAL" > "$CPU_PATH"/scaling_governor
  test_print_trc "TEST_RESULT: $TEST_RESULT"
  if [ $TEST_RESULT -eq 0 ];  then
    test_print_trc "$SHA_NAME test passed!"
    return 0
  else
    test_print_trc "$SHA_NAME test failed!"
    return 1
  fi
}
