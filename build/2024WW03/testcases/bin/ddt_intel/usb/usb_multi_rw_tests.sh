#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 1, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Zhang Chao <chaox.zhang@intel.com>
#
# History:
#             Feb. 11, 2018 - (Zhang Chao)Creation

# @desc This script verify usb storage device (3.1/3.2) stress read/write function
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"
dir="/mnt/test"

usage() {
  cat << EOF
  usage: ${0##*/}
    -p  protocol type, such as 3.1 3.2"
    -t  device type, such as flash uas"
    -b  block size, as parameter pass to dd command"
    -c  block count, as parameter pass to dd command"
    -n  thread/process count
    -m  msc count
    -H  show this"
EOF
}

# run stress msc , default times 1000
stress_msc(){
  local usb_device_node=$1
  if [[ -n "$COUNT_MSC" ]]; then
    do_cmd "rw_test_with_msc $usb_device_node $COUNT_MSC"
    wait
    test_print_trc "finish MSC $COUNT_MSC round test."
  fi
}

calculate_space(){
  local usb_device_node=$1
  free_space=$(df -h|grep -E "/$"| awk '{print $4}')
  final=${free_space: -1}
  free_space=${free_space%?}
  device=$(lsblk "$usb_device_node" | awk '{print $4}' |sed -n '2p')
  final_device=${device: -1}
  free_device=${device%?}
  if [[ "$final" == "$final_device" ]]; then
    value=$(echo "$free_device < $free_space" | bc )
    [ "$value" == 1 ] && free_space=$free_device
  fi
  swap=$(free -g |awk '{print $4}' |tail -n2 |awk '{sum+=$1}END{print sum}')G
  final_swap=${swap: -1}
  free_swap=${swap%?}
  if [[ "$final" == "$final_swap" ]]; then
    value=$(echo "$free_swap < $free_space" | bc )
    [ "$value" == 1 ] && free_space=$free_swap
  fi

  blk_size=${BLOCK_SIZE%?}
  while [ "$blk_count" -lt 1 ]; do
    if [[ $final = "G" ]]; then
      blk_total=$(echo "scale=3;$free_space / $COUNT_THREAD * 1000" | bc)
    elif [[ $final = "M" ]]; then
      blk_total=$(echo "scale=3;$free_space / $COUNT_THREAD" | bc)
    fi
    val_blk=$(echo "$blk_total >= 1" |bc)
    [ "$val_blk" == 1 ] || die "disk space too small"
    blk_count=$(echo "$blk_total / (2 * $blk_size)" | bc)
    [ "$blk_count" -lt 1 ] && blk_size=$((blk_size/10))
  done
  test_print_trc "blk_count=$blk_count"
  test_print_trc "blk_size=$blk_size"
  [ "$blk_count" -lt "$BLOCK_COUNT" ] && BLOCK_COUNT=$blk_count
  [ "$blk_size" -lt "${BLOCK_SIZE%?}" ] && BLOCK_SIZE=${blk_size}M
  test_print_trc "BLOCK COUNT is $BLOCK_COUNT"
  test_print_trc "BLOCK SIZE is $BLOCK_SIZE"
}

# run multi-threads stress test, default sum_threads 1000
stress_multi_threads(){
  local usb_device_node=$1
  local test_file=""
  local blk_count=0
  calculate_space "$usb_device_node"
  for((i=0;i<"$COUNT_THREAD";i++)); do
  {
    if [[ -n "$dir" ]]; then
      test_file=$(generate_test_file "$BLOCK_SIZE" "$BLOCK_COUNT" "$TEMP_DIR" "$i")
      [[ -n "$test_file" ]] || block_test "fail to generate random file!"
      test_print_trc "temporary file: $test_file"
      [ ! -e "$dir/$i" ] && touch "$dir/$i"
      write_test_with_file "$dir/$i" "$test_file" "$BLOCK_COUNT"
      read_test_with_file "$dir/$i" "$test_file" "$BLOCK_COUNT"
    fi
  }&
  done
  wait
}

main() {
  local usb_device_node=""
  check_test_env
  if [[ -z "$PROTOCOL_TYPE" || -z "$DEVICE_TYPE" ]]; then
    block_test "protocol type or device type info not provided!"
  fi
  # Get usb storage device node, such as: /dev/sdb
  usb_device_node=$(find_usb_storage_device "$PROTOCOL_TYPE" \
                                            "$DEVICE_TYPE" \
                                            "$BLOCK_SIZE" \
                                            "$BLOCK_COUNT" \
                                            "$USBHUB_NUM")
  [[ -n "$usb_device_node" ]] || block_test "fail to find usb storage device!"
  test_print_trc "usb storage device found: $usb_device_node"
  stress_msc "$usb_device_node"
  mount_dir "$usb_device_node" "$dir"
  stress_multi_threads "$usb_device_node"
  umount_dir "$dir"
}

while getopts :p:t:b:c:m:n:H arg; do
  case $arg in
    p)
      PROTOCOL_TYPE=$OPTARG
      ;;
    t)
      DEVICE_TYPE=$OPTARG
      ;;
    b)
      BLOCK_SIZE=$OPTARG
      ;;
    c)
      BLOCK_COUNT=$OPTARG
      ;;
    n)
      COUNT_THREAD=$OPTARG
      ;;
    m)
      COUNT_MSC=$OPTARG
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
exit 0
