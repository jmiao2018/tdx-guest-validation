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
# File:         tbt_ssd_read_write.sh
#
# Description:  tbt connect device read write test for Intel thunderbolt test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      August 7 2017 - created - Pengfei Xu

# @desc check the device connected by tbt read/write, speed and correction
# @returns Fail if return code is non-zero

source "tbt_common.sh"

IOMMU_FILE=""
IOZONE_FILE=""
IOMMU_MODE=""
IOMMU_NB="iommu_nb"
IOMMU_NBS="iommu_nbs"
IOMMU_BOUNCE="iommu_bounce"
IOMMU="iommu"
NB_KEY="No bounce buffer"
NBS_KEY="Disable batched IOTLB flush"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-t SCENARIO][-h]
  -p  Protocol type like ssd 2.0 3.0 which connected with thunderbolt
  -d  Device tp like flash or uas
  -b  Block size such as 1MB 10MB
  -c  Block count such as 1 10 100
  -t  Times want to execute such as 1 10
  -m  mode for perf test
  -h  show This
__EOF
}

# Verify iommu 3 different modes
# Input: NA
# Verify IOMMU mode and save mode into IOMMU_MODE
verify_iommu_mode() {
  local nb="nobounce"
  local nbs="nobounce,strict"
  local cmd_line=""
  local key_verify=""

  cmd_line=$(cat /proc/cmdline)
  KEY_WORD=$PASS

  if [[ "$cmd_line" == *"$nbs"* ]]; then
    key_verify=$(dmesg | grep -i "$NBS_KEY")
    [[ -n "$key_verify" ]] || {
      test_print_wrg "No $NBS_KEY in dmesg:$key_verify"
      KEY_WORD=$FAIL
    }
    test_print_trc "$IOMMU $nbs mode"
    IOMMU_MODE="$IOMMU_NBS"
  elif [[ "$cmd_line" == *"$nb"* ]]; then
    key_verify=$(dmesg | grep -i "$IOMMU" | grep -i "$NB_KEY")
    [[ -n "$key_verify" ]] || {
      test_print_wrg "No $NB_KEY in dmesg:$key_verify"
      KEY_WORD=$FAIL
    }
    test_print_trc "$IOMMU $nb mode"
    IOMMU_MODE="$IOMMU_NB"
  else
    key_verify=$(dmesg | grep -i "$IOMMU" | grep -i "$NB_KEY")
    [[ -z "$key_verify" ]] || {
      test_print_wrg "Contain $NB_KEY in dmesg:$key_verify"
      KEY_WORD=$FAIL
    }
    test_print_trc "$IOMMU_BOUNCE mode"
    IOMMU_MODE="$IOMMU_BOUNCE"
  fi
}

main() {
  local test_file=""
  local iozone_bin=""

  # Prepare stage
  check_auto_connect
  check_test_env
  check_free_partition "$BLOCK_SIZE" "$BLOCK_COUNT"

  # Block rw test in dp only mode
  check_security_mode
  if [ "$SECURITY" == "dponly" ]; then
    block_test "dponly mode, could not read write test"
  fi

  # Enable authorized, find device connected by thunderbolt
  enable_authorized
  sleep 5
  find_tbt_device "$BLOCK_SIZE" "$BLOCK_COUNT" "$PROTOCOL_TYPE" "$DEVICE_TP"
  [ -n "$DEVICE_NODE" ] || die "No $PROTOCOL_TYPE $DEVICE_TP node:$DEVICE_NODE"

  case $MODE in
    NA|downstream)
      if [[ "$MODE" == "downstream" ]]; then
        # CLE equal to 0 means Cleware could work, other value:no Cleware or nok
        if [[ "$CLE" -eq 0 ]]; then
          plug_out_check
          plug_in_tbt
          test_dmesg_check "USB bus registered" "$CONTAIN"
        else
          test_print_wrg "No Cleware: CLE:$CLE is not 0"
        fi
      fi
      # Generate test folder and test file
      [[ -e "$TEMP_DIR" ]] || block_test "fail to create temporary directory!"
      test_print_trc "TEMP_DIR: $TEMP_DIR"
      test_file=$(generate_test_file "$BLOCK_SIZE" "$BLOCK_COUNT" "$TEMP_DIR")

      mount_dev "$DEVICE_NODE" "$MOUNT_FOLDER"

      # Read write test in request times
      for ((i=1; i <= TIME; i++)); do
        test_print_trc "------------------------$i times read write test:"
        write_test_with_file "$RW_FILE" "$test_file" \
          "$BLOCK_SIZE" "$BLOCK_COUNT"
        read_test_with_file "$RW_FILE" "$test_file" \
          "$BLOCK_SIZE" "$BLOCK_COUNT"
      done
      rm -rf "$TEMP_DIR"
      ;;
    perf)
      verify_iommu_mode
      IOMMU_FILE="${LOG_PATH}/${IOMMU_MODE}_${PROTOCOL_TYPE}.txt"
      tbt_perf_test "$NODE" "$IOMMU_FILE"
      ;;
    summary)
      local nb="${LOG_PATH}/${IOMMU_NB}_${PROTOCOL_TYPE}.txt"
      local nbs="${LOG_PATH}/${IOMMU_NBS}_${PROTOCOL_TYPE}.txt"
      local bounce="${LOG_PATH}/${IOMMU_BOUNCE}_${PROTOCOL_TYPE}.txt"
      local info="cmdline intel_iommu=nobounce or intel_iommu=nobounce,strict"

      [[ -e "$nb" ]] || block_test "no $nb file, test 2 other $info"
      [[ -e "$nbs" ]] || block_test "no $nbs file, test 2 other $info"
      [[ -e "$bounce" ]] || block_test "no $bounce file, please enable iommu"
      verify_perf_result "$nb" "$nbs" "$bounce" "$PROTOCOL_TYPE"
      ;;
    iozone)
      verify_iommu_mode
      IOZONE_FILE="${LOG_PATH}/iozone_${IOMMU_MODE}.txt"
      [[ -e "$IOZONE_FOLDER" ]] || do_cmd "mkdir $IOZONE_FOLDER"

      do_cmd "mke2fs -Elazy_itable_init=0,lazy_journal_init=0 /dev/$NODE"
      do_cmd "mount /dev/$NODE $IOZONE_FOLDER"
      if mountpoint -q "$IOZONE_FOLDER"; then
        do_cmd "umount $IOZONE_FOLDER"
      fi
      do_cmd "mount /dev/$NODE $IOZONE_FOLDER"
      iozone_bin=$(which iozone)
      do_cmd "cp -rf $iozone_bin $IOZONE_FOLDER"
      do_cmd "cd $IOZONE_FOLDER"
      do_cmd "iozone  +u -az -y 1 -i 0 -i 1 -i 2 -I > $IOZONE_FILE"
      do_cmd "cat $IOZONE_FILE"
      ;;
    *)
      usage
      die "Invalid MODE:$MODE"
      ;;
  esac

  fail_dmesg_check
}

# Default size 1MB
: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}
: ${TIME:="2"}
: ${DEVICE_TP:="device"}
: ${MODE:="NA"}

while getopts :p:d:b:c:t:m:h arg
do
  case $arg in
    p)
      PROTOCOL_TYPE=$OPTARG
      ;;
    d)
      DEVICE_TP=$OPTARG
      ;;
    b)
      BLOCK_SIZE=$OPTARG
      ;;
    c)
      BLOCK_COUNT=$OPTARG
      ;;
    t)
      TIME=$OPTARG
      ;;
    m)
      MODE=$OPTARG
      ;;
    h)
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

main
exec_teardown
