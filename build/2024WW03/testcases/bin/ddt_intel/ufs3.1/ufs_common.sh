#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for UFS3.1(Universal Flash Storage) tests common functions
#

source "common.sh"
source "dmesg_functions.sh"

readonly UFS_DEVICE_IDS="9DFA 4B41 4B43 98FA 51FF 54FF 7E47 A847 7747 E447"
readonly PCI_INTEL_VENDOR="00: 86 80"
readonly UFS_PATH="/sys/bus/pci/drivers/ufshcd/"
readonly PCI_PATH="/sys/bus/pci/"
readonly INLINE="inlinecrypt"
readonly ENCRYPT_FOLDER="/ufs/encrypted/"
readonly ENCRYT_FILE="encrypt_write.fio"
readonly UFS_PCI_MOD="ufshcd_pci"

UFS_DEVICE_ID=""
UFS_NODE=""
UFS_DOMAIN=""
UFS_PCI=""
UFS_DOMAIN=""
UFS_SYS_PCI=""
UFS_NODE=""
UFS_FOLDER="/ufs"
TEST_FILE="file_in"
FILE_IN="/tmp/${TEST_FILE}"
FILE_OUT="/tmp/file_out"
NONE=""
FIO_RESULT=""
FIO_NUM=""
EXIST="exist"
NULL="null"
CALL_TRACE="Call Trace"

# Check ufs pci and save the ufs PCI in UFS_PCI|DOMAIN|SYS_PCI
# Sample:  UFS_DOMAIN:0000  UFS_PCI:00:12.7  UFS_SYS_PCI:0000:00:12.7
# Input: NA
# Return 0 for true, otherwise false or die
find_ufs_pci() {
  local ufs_domain=""
  local ufs_pci=""
  local is_intel=""

  for UFS_DEVICE_ID in $UFS_DEVICE_IDS; do
    ufs_pci=$(lspci \
            | grep -i "$UFS_DEVICE_ID" \
            | cut -d ' ' -f 1 \
            | head -n 1)
    if [[ -n "$ufs_pci" ]]; then
      test_print_trc "Find ufs_pci:$ufs_pci"
      break
    else
      continue
    fi
  done

  [[ -n "$ufs_pci" ]] || die "Could not find UFS PCI:$ufs_pci"

  is_intel=$(lspci -xxxx -s $ufs_pci | grep "$PCI_INTEL_VENDOR")
  [[ -n "$is_intel" ]] || die "ID $UFS_DEVICE_ID $ufs_pci is not intel vendor"

  ufs_domain=$(ls "$UFS_PATH" | grep "00" | cut -d ':' -f 1)
  [[ -n "$ufs_domain" ]] || die "ufs_domain is null in $UFS_PATH:$ufs_domain"

  UFS_DOMAIN=$ufs_domain
  UFS_PCI=$ufs_pci
  UFS_SYS_PCI=$(ls "$UFS_PATH" \
              | grep "$ufs_pci")
  test_print_trc "UFS_DOMAIN:$UFS_DOMAIN, UFS_PCI:$UFS_PCI, all:$UFS_SYS_PCI"
}

# Check ufs lspci info should same as system ufs pci info
# Input: NA
# Return 0 for true, otherwise false or die
ufs_pci_check() {
  local ufs_domain=""
  local ufs_pci=""
  local sys_pci=""

  find_ufs_pci
  sys_pci=$(ls "$UFS_PATH" \
    | grep "$UFS_DOMAIN" \
    | awk -F "${UFS_DOMAIN}:" '{print $NF}')

  test_print_trc "UFS_PCI:$UFS_PCI, domain:$UFS_DOMAIN, sys_pci:$sys_pci"
  if [[ "$sys_pci" == *"$UFS_PCI"* ]]; then
    test_print_trc "UFS_PCI:$UFS_PCI is contained in system ufs: $sys_pci, pass"
  else
    die "UFS_PCI:$UFS_PCI is not same or include in system ufs:$sys_pci"
  fi
}

# Check ufs version should match as expected value
# Input: $1 version value
# Return 0 for true, otherwise false or die
ufs_version_check() {
  local ufs_version=$1
  local ufs_pci=""
  local ufs_pci_num=""
  local result=""

  [[ -d "$UFS_PATH" ]] || die "No folder $UFS_PATH"
  ufs_pci_num=$(ls "$UFS_PATH" | grep "00" | wc -l)
  [[ "$ufs_pci_num" -eq 1 ]] || {
    test_print_wrg "$UFS_PATH PCI num is not 1"
  }
  ufs_pci=$(ls "$UFS_PATH" | grep "00" | head -n 1)
  result=$(cat $UFS_PATH/${ufs_pci}/device_descriptor/specification_version)
  if [[ "$result" == *"$ufs_version"* ]]; then
    test_print_trc "UFS version $result match as expected:$ufs_version, pass"
  else
    die  "UFS version $result didn't match as expected:$ufs_version, fail"
  fi
}

# Detect ufs device node and save first found ufs node in UFS_NODE
# Input: NA
# Return 0 for true, otherwise false or die
ufs_node_check() {
  local nodes=""
  local node=""
  local result=""

  find_ufs_pci
  nodes=$(ls -1 /dev/sd* | awk -F '/' '{print $NF}')
  for node in $nodes; do
    result=""
    result=$(find ${PCI_PATH}/devices/${UFS_SYS_PCI}/ -name $node)
    if [[ -z "$result" ]]; then
      continue
    else
      test_print_trc "Find UFS node:$node in $result"
      break
    fi
  done
  if [[ -z "$result" ]]; then
    test_print_trc "Didn't find UFS node on this platform:$result"
  else
    UFS_NODE=$node
  fi
}

# Mount related node to specific folder
# Input:
#   $1: device node
#   $2: specific folder
#   $3: encrypt type like inlinecrypt or optional NULL
# Return 0 for true, otherwise false or die
ufs_mount() {
  local node=$1
  local folder=$2
  local type=$3
  local result=""

  [[ -e "$node" ]] || die "$node is not exist"
  if [[ -d $folder ]]; then
    umount -f "$folder" 2> /dev/null
    do_cmd "rm -rf $folder/*"
  else
    do_cmd "rm -rf $folder; mkdir -p $folder"
  fi

  case $type in
    $INLINE)
      test_print_trc "mount $node $folder -o discard -o $INLINE"
      mount $node $folder -o discard -o $INLINE || {
        test_print_wrg "mount $node failed first time, mkfs.ext4 and try again"
        do_cmd "mkfs.ext4 -O encrypt -F $node"
        do_cmd "mount $node $folder -o discard -o $INLINE"
      }
      ;;
    *)
      test_print_trc "mount $node $folder -o discard"
      mount $node $folder -o discard || {
        test_print_wrg "mount $node failed first time, mkfs.ext4 and try again"
        do_cmd "mkfs.ext4 -O encrypt -F $node"
        do_cmd "mount $node $folder -o discard"
      }
      ;;
  esac
}

# Test ufs disk tranfer in and out file, output file should same as origin file
# Input:
#    $1: folder which will transfer file in and out
#    $2: block size like 1M 10M, which should not more than 20M!
#    $3: count for block size; like 50, 1024
# Return 0 for true, otherwise false or die
ufs_transfer_file() {
  local folder=$1
  local size=$2
  local cnt=$3
  local result=""

  [[ -e "$FILE_IN" ]] && do_cmd "rm -rf $FILE_IN"
  [[ -e "$FILE_OUT" ]] && do_cmd "rm -rf $FILE_OUT"

  do_cmd "dd if=/dev/urandom of=$FILE_IN bs=$size count=$cnt"
  do_cmd "dd if=$FILE_IN of=${folder}/${TEST_FILE} bs=$size count=$cnt"
  do_cmd "dd if=${folder}/${TEST_FILE} of=$FILE_OUT bs=$size count=$cnt"
  diff $FILE_IN $FILE_OUT
  result=$?
  if [[ $result -eq 0 ]]; then
    test_print_trc "Transfer $size*$cnt $FILE_IN in $folder, out $FILE_OUT pass."
  else
    die "$size*$cnt $FILE_IN and $FILE_OUT is different"
  fi
}

# Test ufs encryption fio write speed
# Input:
#    $1: encrypt type: inlinecrypt or none
# Return 0 for true, otherwise false or die
fio_encrypt_test() {
  local type=$1
  local test_file="test.txt"
  local key_sha=""
  local result=""
  local encrypt_file=""
  local result_file="/tmp/fio_result.txt"

  [[ -d "$ENCRYPT_FOLDER" ]] || {
    test_print_trc "No $ENCRYPT_FOLDER folder, create it"
    do_cmd "rm -rf $ENCRYPT_FOLDER"
    mkdir -p $ENCRYPT_FOLDER
  }

  [[ -e "$ENCRYPT_FOLDER/test" ]] && do_cmd "rm -rf $ENCRYPT_FOLDER/test"

  do_cmd "mkdir -p $ENCRYPT_FOLDER/test"
  [[ -e "$ENCRYPT_FOLDER/key" ]] && \
    do_cmd "mv $ENCRYPT_FOLDER/key $ENCRYPT_FOLDER/key_last"

  do_cmd "head -c 64 /dev/urandom > $ENCRYPT_FOLDER/key"
  key_sha=$(fscryptctl add_key $ENCRYPT_FOLDER/test < $ENCRYPT_FOLDER/key)
  do_cmd "fscryptctl set_policy $key_sha $ENCRYPT_FOLDER/test"
  do_cmd "fscryptctl get_policy $ENCRYPT_FOLDER/test"
  do_cmd "echo 12345 > $ENCRYPT_FOLDER/test/$test_file"
  result=$(ls $ENCRYPT_FOLDER/test | grep "$test_file")
  if [[ -n "$result" ]]; then
    test_print_trc "Could see $result in $ENCRYPT_FOLDER/test"
  else
    die "Could not see $test_file in $ENCRYPT_FOLDER/test:$result"
  fi
  encrypt_file=$(which $ENCRYT_FILE)
  do_cmd "fio $encrypt_file > $result_file"
  cat "$result_file"
  FIO_RESULT=$(cat "$result_file" \
              | grep WRITE \
              | cut -d '=' -f 2 \
              | cut -d ' ' -f 1)
  echo $FIO_RESULT | grep M || die "FIO_RESULT unit is not M:$FIO_RESULT!"
  FIO_NUM=$(echo $FIO_RESULT | cut -d 'M' -f 1)
  do_cmd "fscryptctl remove_key $key_sha $ENCRYPT_FOLDER"
  result=$(ls $ENCRYPT_FOLDER/test | grep "$test_file")
  if [[ -z "$result" ]]; then
    test_print_trc "Can't see $test_file in encrypted $ENCRYPT_FOLDER/test pass"
  else
    die "Still see $result in encrypted $ENCRYPT_FOLDER/test, fail"
  fi
}

# Check dmesg info contain matched content
# Input: $1 dmesg log path
#        $2 search content
#        $3 fail/pass: fail should not contain key word, pass should contain
# Return: 0 for not find, 1 for find and give the warning print
dmesg_check() {
  local dmesg_file="$1"
  local content="$2"
  local verify="$3"
  local result=""

  [[ -e "$dmesg_file" ]] || die "file $dmesg_file is not exist"

  result=$(grep -i "$content" "$dmesg_file")

  case $verify in
    $EXIST)
      if [[ -z "$result" ]]; then
        die "Not find $content in dmesg $dmesg_file."
      else
        test_print_trc "Find $content in dmesg:$result, pass"
      fi
      ;;
    $NULL)
      if [[ -z "$result" ]]; then
        test_print_trc "No $content find when this case test, pass"
      else
        test_print_wrg "Find $content in dmesg:$result"
        die "Find $content in dmesg $dmesg_file."
      fi
      ;;
    *)
      block_test "Invalid verify content:$verify"
      ;;
  esac
}

# Check new fail info in the dmesg log, and print fail info
# Input: none
# Return: Print warning and fail info to check whether it's an issue
basic_dmesg_check() {
  local dmesg_path=""

  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] || \
    block_test "No case duration dmesg:$LOG_PATH/$dmesg_path exist"

  dmesg_check "$LOG_PATH/$dmesg_path" "$CALL_TRACE" "$NULL"
}


# Check load and unload mod thunderbolt
# $1: mode name
# Result: 0 for true, otherwise false or die
load_unload_mod() {
  mod_name=$1

  load_unload_module.sh -l -d "$mod_name"
  sleep 2
  load_unload_module.sh -c -d "$mod_name" || die "Load $mod_name fail"

  load_unload_module.sh -u -d "$mod_name"
  sleep 2
  load_unload_module.sh -c -d "$mod_name" && die "Unload $mod_name fail"

  load_unload_module.sh -l -d "$mod_name"
  sleep 2
  load_unload_module.sh -c -d "$mod_name" || die "Load $mod_name fail"
}
