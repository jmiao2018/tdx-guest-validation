#!/bin/bashy
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
# File:         tbt_common.sh
#
# Description:  common file for Intel thunderbolt test
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      August 1 2017 - created - Pengfei Xu
#
# @history 2018-05-14: add tbt rtd3 test functions
#
# @desc provide common functions for thunderbolt
# @returns Fail if return code is non-zero (value set not found)

source "common.sh"
source "dmesg_functions.sh"

readonly POWER_DISK_NODE="/sys/power/disk"
readonly POWER_STATE_NODE="/sys/power/state"
readonly POWER_MEM_SLEEP="/sys/power/mem_sleep"
readonly POWER_PM_TEST_NODE="/sys/power/pm_test"
readonly NVM_PATH="ddt_intel/tbt"
readonly NVM_VERIFY="nvm_authenticate"
readonly REGEX_ITEM="-"
readonly TBT_ROOT="tbt_root"
readonly IOZONE_FOLDER="/iozone"
DOMAINX=$(ls /sys/bus/thunderbolt/devices/ \
          | grep "-" \
          | grep -v "\-0" \
          | head -n1 \
          | cut -c1)
[[ -n "$DOMAINX" ]] || DOMAINX="0"
TBT_HOST_PATH="/sys/bus/thunderbolt/devices/${DOMAINX}-0"

readonly NVMEM="${TBT_HOST_PATH}/nvm_non_active0/nvmem"
readonly NVM_VERSION="nvm_version"
readonly ORIGIN_VERSION="${NVM_PATH}/version_before_downgrade.txt"
readonly DOWNGRADE_VERSION="${NVM_PATH}/version_downgrade.txt"
readonly UPGRADE_VERSION="${NVM_PATH}/version_upgrade.txt"
readonly NVM_OLD="${NVM_PATH}/cfl-s_cnl-h_old.bin"
readonly NVM_NEW="${NVM_PATH}/cfl-s_cnl-h_new.bin"
readonly EP_OLD="${NVM_PATH}/TR_EP_4C_C1_rev10_NOSEC_sign.bin"
readonly EP_NEW="${NVM_PATH}/TR_EP_4C_C1_rev11_NOSEC_sign.bin"
readonly VERIFY_SUCCESS="0x0"
readonly TBTADM="tbtadm"
readonly TBT_NVM_FILE="/tmp/tbt_nvm.bin"
readonly PMC_CNT_FILE="/sys/kernel/debug/pmc_core/substate_residencies"
readonly MOUNT_FOLDER="/folder_for_test"
readonly RW_FILE="${MOUNT_FOLDER}/test_target_file"
readonly NULL="null"
readonly CONTAIN="contain"
readonly ACM0="/dev/ttyACM0"
readonly LANES="lanes"
readonly MARGIN="margin"
readonly RESULTS="results"
readonly RUN="run"
readonly MOD_TBT_DMA="thunderbolt_dma_test"
readonly CLX_OUTPUT="/tmp/clx_output.txt"
readonly DISK_TIME=90

export TBT_DEV_IDS=""

TBT_DBG="/sys/kernel/debug/thunderbolt"
TBT_MRG=""
MOD_NAME="thunderbolt"
MOD_NET_NAME="thunderbolt_net"
MOD_TIME="9000000"
MOD_NET_TIME="9000000"
TBT_PATH="/sys/bus/thunderbolt/devices"
TBT_MONITOR_FILE=""
REGEX_DOMAIN="domain"
ITEM_FILES="authorized device device_name link_speed link_width \
            nvm_authenticate nvm_version uevent \
            unique_id vendor vendor_name power/control power/runtime_status"
DOMAIN_FILES="security uevent"
AUTHORIZE_FILE="authorized"
KEY_FILE="key"
KEY_PATH="$HOME/keys"
AUTHOR_PATH="/sys/bus/thunderbolt/devices/*/authorized"
DEVICE_NODE=""
NODE=""
TEMP_DIR=""
FREE_SPACE=$(df -Ph /tmp | tail -1 | awk '{print $4}')
FREE_SPACE_ROOT=$(df -Ph /root | tail -1 | awk '{print $4}')
DEVICES=""
DEV_FILE="/tmp/tbt_dev"
FTDI_LIB_PATH="ftdi/lib"
TBT_DEVICES=""
TBT_PCI=""
DEVICE_TYPE=""
FAIL="fail"
PASS="pass"
FAIL_ORIGIN=$(dmesg | grep -i $MOD_NAME | grep -i $FAIL)
FAIL_FINAL=""
ACL_FILE="/sys/bus/thunderbolt/devices/domain${DOMAINX}/boot_acl"
ACL_DEFAULT=",,,,,,,,,,,,,,,"
ADM_ACL="/var/lib/thunderbolt/acl"
HOST_EXCLUDE="\-0"
HID="hiddev"
HID_CONTENT=$(lsusb | grep "Cleware")
EP_VENDOR="0x8086"
VENDOR="vendor"
ON="on"
AUTO="auto"
PCI_PATH="/sys/bus/pci/devices"
POWER_CONTROL="power/control"
RUNTIME_STATUS="power/runtime_status"
FIRM_POWER="firmware_node/real_power_state"
PORT_POWER="firmware_node/power_state"
PCI_LOG="/tmp/pci_info.log"
HOST_POWER="$TBT_HOST_PATH/power/control"
D0="D0"
D3="D3"
TBT="tbt"
XHCI="xhci"
AHCI="ahci"
TOPO_FILE="/tmp/tbt_topo.txt"
TBT_DMA_FILE="/sys/bus/thunderbolt/devices/domain0/iommu_dma_protection"
ENABLE="1"
SIZE="size"
KEY_WORD=""
DMESG_VERIFY="dmesg_verify"
DOMAIN0="domain0"
DOMAIN1="domain1"
RP0="0-0"
RP1="1-0"
SECURITY=""
SYS_PATH=""
TBT_ROOT_PCI=""
TBT_PCIS=""
PMC_PREV=0
PMC_NOW=0
PMC_INCREASE_NUM=0
# CLE equal to 0 means Cleware could work, otherwise no Cleware or not work
CLE=0
SWAP_PARTITION=""
PLUG_IN=0

# For original configuration record
# MOD_STATE: 0 means didn't install the mod, 1 means installed mod
MOD_STATE=1
MOD_NET_STATE=0
MEM_STATE=""
MEM_RESULT=""
MEM_STATE=$(cat $POWER_MEM_SLEEP | cut -d '[' -f 2 | cut -d ']' -f 1)
load_unload_module.sh -c -d ${MOD_NAME} && MOD_STATE=1
load_unload_module.sh -c -d ${MOD_NET_NAME} && MOD_NET_STATE=1
# For FTDI hot plug thunderbolt device
export LD_LIBRARY_PATH=$FTDI_LIB_PATH

teardown_handler="tbt_teardown"
tbt_teardown() {
  [[ -d "$MOUNT_FOLDER" ]] && umount -f $MOUNT_FOLDER 2>/dev/null
  [ -z "$DEVICES" ] || {
    DEVICES=""
    test_print_trc "set null for DEVICES"
  }

  [ -z "$DEVICE_TYPE" ] || {
    DEVICE_TYPE=""
    test_print_trc "set null for DEVICE_TYPE"
  }

  [ -z "$FAIL_ORIGIN" ] || {
    FAIL_ORIGIN=""
    test_print_trc "set null for FAIL_ORIGIN"
  }

  [ -z "$FAIL_FINAL" ] || {
    FAIL_FINAL=""
    test_print_trc "set null for FAIL_FINAL"
  }

  if [ ${MOD_NET_STATE} -eq 0 ]; then
    lsmod | grep -q -w -e "^$MOD_NET_NAME" && {
      test_print_trc "Unloading ${MOD_NET_NAME}"
      modprobe -r ${MOD_NET_NAME}
      sleep 2
      test_print_trc "Loading ${MOD_NAME}"
      modprobe ${MOD_NAME}
      sleep 5
    }
  else
    lsmod | grep -q -w -e "^$MOD_NET_NAME" || {
      test_print_trc "Loading ${MOD_NET_NAME}"
      modprobe ${MOD_NET_NAME}
      sleep 1
    }
  fi

  if [ ${MOD_STATE} -eq 0 ]; then
    lsmod | grep -q -w -e "^$MOD_NAME" && {
      test_print_trc "Unloading ${MOD_NAME}"
      modprobe -r ${MOD_NAME}
      sleep 1
    }
  else
    lsmod | grep -q -w -e "$MOD_NAME" || {
      test_print_trc "Loading ${MOD_NAME}"
      modprobe ${MOD_NAME}
      sleep 5
    }
  fi

  if mountpoint -q "$IOZONE_FOLDER"; then
    test_print_trc "umount $IOZONE_FOLDER"
    umount $IOZONE_FOLDER
  fi

  MEM_RESULT=$(cat $POWER_MEM_SLEEP | cut -d '[' -f 2 | cut -d ']' -f 1)
  [ "$MEM_STATE" == "$MEM_RESULT" ] || {
    echo "$MEM_STATE" > $POWER_MEM_SLEEP
    test_print_trc "Set $MEM_STATE in $POWER_MEM_SLEEP"
  }

  [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR" && test_print_trc "rm -rf $TEMP_DIR"
  [ -z "$TEMP_DIR" ] || {
    TEMP_DIR=""
    test_print_trc "set null for TEMP_DIR"
  }

  [ -z "$DEVICE_NODE" ] || {
    DEVICE_NODE=""
    test_print_trc "set null for DEVICE_NODE"
  }

  [[ -e "$TBT_NVM_FILE" ]] && {
    test_print_trc "delete $TBT_NVM_FILE"
    rm -rf $TBT_NVM_FILE
  }

  [[ -z "$SWAP_PARTITION" ]] || {
    SWAP_PARTITION=$(swapon | grep dev | cut -d " " -f 1 2>/dev/null)
    if [[ -z "$SWAP_PARTITION" ]]; then
      test_print_trc "swap node:$SWAP_PARTITION, try swapon -a"
      swapon -a
    else
      test_print_trc "no swap node:$SWAP_PARTITION, try swapon -a"
      swapon -a
    fi
  }

  if [[ -e "$HOST_POWER" ]]; then
    [[ "$AUTO" == "$(cat $HOST_POWER)" ]] || {
      test_print_trc "set $AUTO in $HOST_POWER"
      echo "$AUTO" > "$HOST_POWER"
    }
  else
    test_print_trc "No $HOST_POWER exist in tbt teardown"
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

  if [[ "$verify" == "$FAIL" ]]; then
    if [[ -z "$result" ]]; then
      test_print_trc "No $content find when this case test"
    else
      test_print_wrg "Find $content in dmesg:$result"
      die "Find $content in dmesg $dmesg_file."
    fi
  elif [[ "$verify" == "$PASS" ]]; then
    if [[ -z "$result" ]]; then
      die "Not find $content in dmesg $dmesg_file."
    else
      test_print_trc "Find $content in dmesg:$result"
    fi
  else
    block_test "Invalid verify content:$verify"
  fi
}

# Check new fail info in the dmesg log, and print fail info
# Input: none
# Return: Print warning and fail info to check whether it's an issue
fail_dmesg_check() {
  local dmesg_path=""
  local hidden="partially hidden"
  local bridge_unusable="devices behind bridge are unusable"
  local call_trace="Call Trace"

  FAIL_FINAL=$(dmesg | grep -i $MOD_NAME | grep -i $FAIL)
  if [[ "$FAIL_ORIGIN" == "$FAIL_FINAL" ]]; then
    test_print_trc "check dmesg log pass, no fail info in last case test"
  else
    test_print_wrg "Found new fail info, fail_origin:$FAIL_ORIGIN"
    test_print_wrg "fail_final:$FAIL_FINAL"
    FAIL_ORIGIN=$FAIL_FINAL
  fi

  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] || {
    test_print_wrg "No case dmesg:$LOG_PATH/$dmesg_path exist"
    return 1
  }
  dmesg_check "$LOG_PATH/$dmesg_path" "$hidden" "$FAIL"
  dmesg_check "$LOG_PATH/$dmesg_path" "$bridge_unusable" "$FAIL"
  dmesg_check "$LOG_PATH/$dmesg_path" "$call_trace" "$FAIL"
}

# Check thunderbolt or thunderbolt_net driver init time less than 10s
# Input: thunderbolt or thunderbolt_net
# Return: 0 for true otherwise false or die.
mod_time_check() {
  local mod=$1
  local dmesg_path=""
  local init_info=""
  local init_time=""

  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] || {
    test_print_wrg "No case dmesg:$LOG_PATH/$dmesg_path exist"
    return 1
  }

  init_info=$(cat $LOG_PATH/$dmesg_path \
              | grep "\[$mod\]" | tail -n 2)
  init_time=$(cat $LOG_PATH/$dmesg_path \
              | grep "\[$mod\]" \
              | tail -n 1 \
              | awk -F 'after ' '{print $2}' \
              | awk -F ' usecs' '{print $1}')
  [[ -n "$init_info" ]] \
    || die "No $mod init time in $LOG_PATH/$dmesg_path"
  test_print_trc "$mod init info:$init_info"
  [[ -n "$init_time" ]] \
    || die "No $mod detail time in $LOG_PATH/$dmesg_path"

  case $mod in
    $MOD_NET_NAME)
      if [[ "$init_time" -le "$MOD_NET_TIME" ]]; then
        test_print_trc "Check $LOG_PATH/$dmesg_path, $mod used $init_time usec"
      else
        test_print_wrg "$LOG_PATH/$dmesg_path: $init_info"
        die "$mod used $mod $init_time usecs, more than $MOD_NET_TIME usecs"
      fi
      ;;
    $MOD_NAME)
      if [[ "$init_time" -le "$MOD_TIME" ]]; then
        test_print_trc "Check $LOG_PATH/$dmesg_path, $mod used $init_time usec"
      else
        test_print_wrg "$LOG_PATH/$dmesg_path: $init_info"
        die "$mod used $init_time usecs, more than $MOD_TIME usecs"
      fi
      ;;
    *)
      block_test "invalid parm:$mod in mod_time_check"
      ;;
  esac
}

# Check dmesg log in test duration, result should contain or not contain keyword
# Input:
# $1: key word
# $2: par, 'null' means should not contain key word, 'contain' means
#     contain key word
# $3: key2 word, it's optional, and it will not impact legacy function.
# Return: 0 for true, otherwise false or die
test_dmesg_check() {
  local key=$1
  local par=$2
  local key2=$3
  local dmesg_path=""
  local dmesg_info=""
  local dmesg_result=""

  dmesg_path=$(extract_case_dmesg -f)
  [[ -e "$LOG_PATH/$dmesg_path" ]] \
    || die "No case dmesg:$LOG_PATH/$dmesg_path exist"
  dmesg_info=$(cat "$LOG_PATH"/"$dmesg_path")
  dmesg_result=$(echo "$dmesg_info" | grep -i "$key" | grep -i "$key2")
  case $par in
    $CONTAIN)
      test_print_trc "key:$key & $key2 should in dmesg info:$dmesg_result"
      [[ -n "$dmesg_result" ]] || die "No $key & $key2 in dmesg"
      ;;
    $NULL)
      test_print_trc "key:$key & $key2 should not exist in dmesg:$dmesg_result"
      if [[ -z "$dmesg_result" ]]; then
        test_print_trc "No $key & $key2 in dmesg:$dmesg_result"
      else
        die "Should not contain $key & $key2 in dmesg:$dmesg_result"
      fi
      ;;
    *)
      block_test "Invalid par:$par"
      ;;
  esac
}

# Check BIOS setting by dmesg info check, due to some dmesg info
# was contained in boot stage, will not use extract_case_dmesg function
# No input
# Return: 0 for true otherwise false or die
bios_setting_check() {
  local native_info=""
  local dmesg_head=""
  local hotplug="pciehotplug"
  local not="not"
  local control="control"
  local reconfig="reconfiguring"
  local reconfig_info=""
  local tr_ids="0x15e7 0x15e8 0x15ea 0x15eb 0x15ef"
  local tr_id=""
  local is_tr=""

  dmesg_head=$(dmesg | head -n 1|  grep "^\[    0.0")
  native_info=$(dmesg | grep -i "$hotplug")
  reconfig_info=$(dmesg | grep -i "$reconfig")
  if [[ -n "$dmesg_head" ]]; then
    [[ -n "$native_info" ]] \
      || die "No PCIeHotplug in thunderbolt platform"
  fi

  if [[ "$native_info" == *"$not"* ]]; then
    test_print_trc "ACPI -> native PCIE disable, legacy dmesg:$native_info"
    if [[ -n "$reconfig_info" ]]; then
      test_print_wrg "Reconfig found:$reconfig_info"
      test_print_wrg "BIOS: TBT config->SW SMI on TBT hotplug <disabled>"
      block_test "Native mode conflict Legay mode, please check BIOS"
    else
      test_print_trc "No reconfig found, pass!"
    fi
  fi

  if [[ "$native_info" == *"$control"* ]]; then
    test_print_trc "ACPI -> native PCIE enable, native mode dmesg:$native_info"

    for tr_id in $tr_ids; do
      is_tr=$(lspci | grep "tr_id")
      [[ -z "$is_tr" ]] || {
        test_print_trc "Found TR PCI id:$is_tr"
        break
      }
    done
    [[ -z "$is_tr" ]] && {
      skip_test "there is no TR TBT PCI found will not check TR tbt host flow"
    }
    if [[ -z "$reconfig_info" ]]; then
      test_print_wrg "no reconfig found:$reconfig_info"
      test_print_wrg "BIOS: TBT config->SW SMI on TBT hotplug <enabled>"
      block_test "Legacy mode conflict Native mode, please check BIOS"
    else
      test_print_trc "Reconfig found:$reconfig_info. Pass!"
    fi
  fi
}

# Check CONFIG_THUNDERBOLT should set to m
config_tbt_check() {
  local config_tbt="CONFIG_THUNDERBOLT"
  local config_tbt_net="CONFIG_THUNDERBOLT_NET"
  local config_usb4="CONFIG_USB4"

  test_kconfigs "m" "$config_usb4" || {
    test_kconfigs "m" "$config_tbt" || \
      die "$config_usb4 and $config_tbt is not set m"
    test_kconfigs "m" "$config_tbt_net" || \
      die "$config_usb4 and $config_tbt_net is not set m"
    test_print_trc "Check $config_tbt and $config_tbt_net passed"
    return 0
  }
  test_print_trc "Check $config_usb4 passed"
  return 0
}

# Show thunderbolt basic sysfs file info
# No input
# Return: 0 for true otherwise false or die
tbt_sysfs_info() {
  local tbt_info=""

  tbt_info=$(grep -H . ${TBT_PATH}/*/* 2>/dev/null)
  if [ -n "$tbt_info" ]; then
    test_print_trc "tbt syfs info:$tbt_info"
  else
    die "There is no any tbt sysfs info:$tbt_info"
  fi
}

# Show thunderbolt pci info
# No input
# Return: 0 for true otherwise false or die
tbt_pci_info() {
  local tbt_pci=""

  tbt_pci=$(lspci | grep -i "$MOD_NAME")
  if [ -n "$tbt_pci" ]; then
    test_print_trc "tbt pci info:$tbt_pci"
  else
    die "No thunderbolt pci detect:$tbt_pci"
  fi
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

# Set 1 for authorized file
enable_authorize_file() {
  local authorize_file=$1
  local authorize_info=""
  if [ -e "$authorize_file" ]; then
    authorize_info=$(cat ${authorize_file})
    if [ "$authorize_info" -eq 0 ]; then
      test_print_trc  "Change 0 to 1: $authorize_file"
      eval "echo 1 > $authorize_file" 2>/dev/null
      sleep 5
    else
      test_print_trc "$authorize_file: $authorize_info"
    fi
  fi
}

# Check TBT authorized file and try to set 1
# No input
# Result: 0 for true, otherwise false
enable_authorized() {
  local aim_folders=""
  local authorize_info=""
  local check_result=""
  local aim_folder=""
  aim_folders=$(ls -1 ${TBT_PATH} \
              | grep "$REGEX_ITEM" \
              | grep -v ":" \
              | awk '{ print length(), $0 | "sort -n" }' \
              | cut -d ' ' -f 2)
  [[ -n "$aim_folders" ]] || die "Device folder is not exist"
  # Should set authorized to 1 less than 10 round
  for ((i = 1; i <= 10; i++)); do
    check_result=$(cat ${AUTHOR_PATH} | grep 0)
    if [ -z "$check_result" ]; then
      test_print_trc "All authorized set to 1"
      break
    else
      test_print_trc "$i round set 1 to authorized:"
      for aim_folder in ${aim_folders}; do
        enable_authorize_file "${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}"
      done
    fi
  done
  if [ "$i" -ge 10 ]; then
    die "Set 1 to authorized with 10 round, should not reach 10 round. i:$i"
  fi
  # Avoid fake failure, wait 3s to check all device should be recognized next
  sleep 3
}

# Check the device sysfs files
# $1: To filter the target folders string
# $2: Check the aim file in the target folders
# Result: 0 for true, otherwise false
check_device_sysfs() {
  local regex_target=$1
  local aim_file=$2
  local aim_folders=""
  local file_info=""
  test_print_trc "__________________Now Checking ${aim_file}__________________"
  aim_folders=$(ls "$TBT_PATH" | grep "$regex_target")
  [[ -n "$aim_folders" ]] || {
    tbt_sysfs_info
    die "AIM floder is not exist:$aim_folders"
  }
  for aim_folder in ${aim_folders}; do
    if [ -e "${TBT_PATH}/${aim_folder}/${aim_file}" ];then
      file_info=$(cat ${TBT_PATH}/${aim_folder}/${aim_file})
      if [ -n "$file_info" ]; then
        test_print_trc "${TBT_PATH}/${aim_folder}/${aim_file}:  |$file_info"
      else
        die "TBT file ${TBT_PATH}/${aim_folder}/${aim_file} should not be null"
      fi
    else
      # Should not fail the case, titan ridge card no nvm file, should a warning
      test_print_wrg "${aim_file} is not found on ${TBT_PATH}/${aim_folder}"
    fi
  done
  return 0
}

# None mode test, all authorized file should be set to 1 automatically
# Input: none
# Result: 0 for true, otherwise false
none_mode_test() {
  local check_result=""
  check_tbt_sysfs
  check_result=$(cat ${AUTHOR_PATH} | grep 0)
  if [ -z "$check_result" ]; then
    test_print_trc "All authorized set to 1 as default in none/dp mode, pass."
  else
    tbt_sysfs_info
    die "Some authorized file still 0 in none or dp mode, fail."
  fi
}

# Check key file is exist and 32bytes, which TBT need 32bytes password
# Input : $1 key file path
# Result: 0 for true, othewise false
check_32bytes_key() {
  local key_file=$1
  local key_content=""
  local key_len=""
  local key_number=64

  if [ -e "$key_file" ]; then
    test_print_trc "$key_file already exist"
    key_content=$(cat ${key_file})
    key_len=${#key_content}
    if [ "$key_len" -eq "$key_number" ]; then
      test_print_trc "$key_file length is 64, ok"
      return 0
    else
      test_print_trc "$key_file length is not 64:$key_content"
      test_print_trc "Key length wrong, regenerate $key_file"
      openssl rand -hex 32 > $key_file
      return 2
    fi
  else
    test_print_trc "No key file, generate $key_file"
    openssl rand -hex 32 > $key_file
    return 1
  fi
}

# Fill the source key password into destination path key file
# Input:
# $1: Source key file
# $2: Destination path, which path contain key file
# Result: 0 for true, otherwise false
fill_key() {
  local source_key=$1
  local aim_folder=$2
  local home_key=""
  local verify_key=""
  cat ${KEY_PATH}/${source_key} > ${TBT_PATH}/${aim_folder}/${KEY_FILE}
  home_key=$(cat ${KEY_PATH}/${source_key})
  verify_key=$(cat ${TBT_PATH}/${aim_folder}/${KEY_FILE})
  test_print_trc "${KEY_PATH}/${source_key}:$home_key"
  test_print_trc "${TBT_PATH}/${aim_folder}/${KEY_FILE}:$verify_key"
}

# Generate available wrong password and use wrong password to test
# Input: none
# Result: 0 for true, otherwise false
wrong_password_check() {
  local key_file="key"
  local aim_folder=$1
  local error_key="error.key"
  local compare=""
  local author_result=""

  if [ -e "${TBT_PATH}/${aim_folder}/${key_file}" ];then
    if [ -e "${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}" ]; then
      author_result=$(cat ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE})
      if [ "$author_result" -ne 0 ]; then
        test_print_trc "${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}:$author_result"
        test_print_trc "authorized already passed, skip"
        author_result=""
        return 0
      else
        author_result=""
      fi
    fi

    check_32bytes_key "${KEY_PATH}/${error_key}"
    if [ -e "${KEY_PATH}/${aim_folder}.key" ]; then
      compare=$(diff ${KEY_PATH}/${error_key} ${KEY_PATH}/${aim_folder}.key)
      if [ -z "$compare" ]; then
        test_print_trc "${KEY_PATH}/${error_key} the same as correct one, regenerate"
        openssl rand -hex 32 > ${KEY_PATH}/${error_key}
      fi
    fi
    fill_key "$error_key" "$aim_folder"
    test_print_trc "fill 2 into ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}:"
    eval "echo 2 > ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}" 2>/dev/null
    sleep 2
    author_result=$(cat ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE})
    if [ "$author_result" -eq 0 ]; then
      test_print_trc "${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}:$author_result passed"
    else
      die "${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}:$author_result, failed"
    fi
  else
    test_print_trc "File key is not found on $TBT_PATH/$aim_folder"
  fi
}

# Wrong password test in secure mode,
wrong_password_test() {
  local aim_folder=""
  local aim_folders=""

  test_print_trc "Secure mode wrong password test next:"
  aim_folders=$(ls -1 ${TBT_PATH} \
              | grep "$REGEX_ITEM" \
              | grep -v "$HOST_EXCLUDE" \
              | awk '{ print length(), $0 | "sort -n" }' \
              | cut -d ' ' -f 2)
  [ -z "$aim_folders" ] && die "Aim floder is not exist"
  [ -d "$KEY_PATH" ] || mkdir "$KEY_PATH"

  for aim_folder in ${aim_folders}; do
    wrong_password_check "$aim_folder"
  done
}

# Fill the right key password and verify in secure mode
# $1: Right key folder name, and correct source key named with folder_name.key
# Result: 0 for true, otherwise false
verify_key_file() {
  local aim_folder=$1
  local return_result=""
  local author_result=""

  if [ -e "${TBT_PATH}/${aim_folder}/${KEY_FILE}" ];then
    check_32bytes_key "${KEY_PATH}/${aim_folder}.key"
    return_result=$?
    if [ $return_result -ne 0 ]; then
      test_print_trc "Return_result: $return_result"
      fill_key "${aim_folder}.key" "$aim_folder"
      eval "echo 1 > ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}" 2>/dev/null
      sleep 3
    else
      fill_key "${aim_folder}.key" "$aim_folder"
      test_print_trc "fill 2 into ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}:"
      eval "echo 2 > ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}" 2>/dev/null
      sleep 3
      author_result=$(cat ${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE})
      test_print_trc "${TBT_PATH}/${aim_folder}/${AUTHORIZE_FILE}:$author_result"
    fi
  else
    test_print_trc "File key is not found on $TBT_PATH/$aim_folder"
  fi
}

# Verify correct password test in secure mode
# Input: none
# Result: 0 for true, otherwise false
secure_mode_test() {
  local aim_folder=""
  local aim_folders=""
  local time=5
  local result=""
  local check_result=""

  test_print_trc "Secure mode verify correct password test next:"
  aim_folders=$(ls -1 ${TBT_PATH} \
              | grep "$REGEX_ITEM" \
              | grep -v "$HOST_EXCLUDE" \
              | awk '{ print length(), $0 | "sort -n" }' \
              | cut -d ' ' -f 2)
  [ -z "$aim_folders" ] && test_print_trc "AIM floder is not exist" && return 1
  [ -d "$KEY_PATH" ] || mkdir "$KEY_PATH"

  for((i=1; i<=time; i++)); do
    result=$(grep -H . ${AUTHOR_PATH} 2>/dev/null |awk -F ':' '{print $NF}' | grep 0)
    if [ -z "$result" ]; then
      test_print_trc "authorized all ok"
      break
    else
      test_print_trc "$i round set 2 to authorized for secure mode:"
      for aim_folder in ${aim_folders}; do
        verify_key_file "$aim_folder"
        if [ $? -ne 0 ]; then
          test_print_trc "Action result abnormal, please check the detail log"
        fi
      done
    fi
  done
  if [ $i -ge $time ]; then
    test_print_wrg "Need check log carefully i reach $i"
    test_print_trc "It's better unplug and plug the TBT devices and test again!"
    enable_authorized
  fi
  check_result=$(cat ${AUTHOR_PATH} | grep 0)
  if [ -z "$check_result" ]; then
    test_print_trc "All authorized not 0, test secure mode pass."
  else
    die "Test secure mode fail, some authorized still 0"
  fi
  # Avoid fake failure, wait 3s to check all device should be recognized next
  sleep 3
}

serial_cmd() {
  local command=$1
  local cmd_file=""
  local escape="escape.txt"
  local esc_file=""
  local usb4switch_log="/tmp/capture.txt"


  esc_file=$(which $escape 2>/dev/null)
  cmd_file=$(which $command 2>/dev/null)
  test_print_trc "escape:$esc_file, cmd_file:$cmd_file"
  {
    sleep 1
    cat $esc_file
  } | minicom -b 9600 -D /dev/ttyACM0 -S $cmd_file -C $usb4switch_log
}

usb4switch_plugin() {
  local plug_state=""

  plug_state=$(serial_cmd "status" | grep "PORTF: 0x12" 2>/dev/null)
  if [[ -n "$plug_state" ]]; then
    test_print_trc "Already connected port 1 for USB4 switch:$plug_state"
  else
    test_print_trc "plug_state:$plug_state not 0x12, will connect port1"
    serial_cmd "superspeed"
    serial_cmd "port1"
  fi
}

usb4switch_plugout() {
  local plug_state=""

  plug_state=$(serial_cmd "status" | grep "PORTF: 0x70" 2>/dev/null)
  if [[ -n "$plug_state" ]]; then
    test_print_trc "Already disconnected port 1 for USB4 switch:$plug_state"
  else
    test_print_trc "plug_state:$plug_state not 0x70, will disconnect."
    serial_cmd "superspeed"
    serial_cmd "port0"
  fi
}

# Thunderbolt devices plug in by cleware power on tbt
# No input
# Return: 0 for true, otherwise false or die
plug_in_tbt() {
  boltctl forget -a

  if [[ -n "$HID_CONTENT" ]]; then
    # plug in thunderbolt devices action
    test_print_trc "Plug in tbt by cleware power on......"
    do_cmd "cleware 1"
    # need time to wait all thunderbolt devices ready to do next step
    do_cmd "sleep 25"
  elif [[ -e "$ACM0" ]]; then
    local state=""
    state=$(serial_cmd "status" | grep "PORTF" 2>/dev/null)
    if [[ -z "$state" ]]; then
      CLE=1
      test_print_wrg "No USB4 switch 3141 or cleware:$state"
      return 1
    else
      test_print_trc "Used USB4 switch 3141 tool, state:$state"
    fi
    usb4switch_plugin
    # need time to wait all thunderbolt devices ready to do next step
    do_cmd "sleep 25"
  else
    CLE=1
    test_print_wrg "No Cleware:$HID_CONTENT or USB4 switch:$ACM0 for plug in"
  fi
}

# Security file should be exist and show its content
check_security_mode() {
  local domain="domain${DOMAINX}/security"

  if [[ -e "${TBT_PATH}/${domain}" ]]; then
    SECURITY=$(cat ${TBT_PATH}/${domain})
  else
    die "${TBT_PATH}/${domain} is not exist"
  fi
  [[ -n "$SECURITY" ]] || die "SECURITY:$SECURITY is null."
}

# Approve thunderbolt all devices access in each mode
# Input: none
# Return: 0 for true, otherwise false or die
approve_access() {
  local secure="secure"

  if [[ -e "${TBT_PATH}/domain0/security" ]]; then
    test_print_trc "domain0 security exist"
  else
    plug_in_tbt
    check_security_mode
    enable_authorized
  fi
  if [ "$SECURITY" == "$secure" ]; then
    secure_mode_test
  else
    enable_authorized
  fi
}

# Check the tbt sysfs default files
check_tbt_sysfs() {
  local item_file=""
  local domain_file=""
  for item_file in ${ITEM_FILES}; do
    check_device_sysfs "$REGEX_ITEM" "$item_file" || die "Check item files fail"
  done

  for domain_file in ${DOMAIN_FILES}; do
    check_device_sysfs "$REGEX_DOMAIN" "$domain_file" || die "Check domain fail"
  done
  do_cmd "lsblk"
}

# Check user mod, and authority set to 1
check_user_authority() {
  check_security_mode
  if [ "$SECURITY" == "user" ]; then
  enable_authorized
  fi
}

# Check necessary command workable
check_test_env() {
    which du &> /dev/null
    [ $? -eq 0  ] || die "du is not in current environment!"
    which dd &> /dev/null
    [ $? -eq 0  ] || die "dd is not in current environment!"
    which diff &> /dev/null
    [ $? -eq 0  ] || die "diff is not in current environment!"
    which fdisk &> /dev/null
    [ $? -eq 0  ] || die "fdisk is not in current environment!"
}

# This function check need used space should smaller than free space
# Input:
#       $1: free space size
#       $2: block size of the file, with unit
#       $3: block count
# Return:
#       0: needed size < free space, could test read and write
#       1: needed size > free space and block test
check_free_space() {
  local free_size=$1
  local block_size=$2
  local block_count=$3
  local need_size=""
  local free_bytes_size=""
  local double_count=""
  double_count=$(( block_count * 2 ))

  need_size=$(caculate_size_in_bytes "$block_size" "$double_count")
  free_bytes_size=$(caculate_size_in_bytes "$free_size" 1)
  test_print_trc "Needed size:$need_size, free space size:$free_bytes_size"
  if [ "$need_size" -ge "$free_bytes_size" ]; then
    test_print_wrg "No enough free space to test read/write!"
    return 1
  fi
  return 0
}

# Check /tmp contain enough space, othewise will check /root free space
# Input:
#  $1: block size of the file
#  $2: block count
# Return:
#  0: find enough free space partition and create random temporary folder
#     otherwise block test due to no enough partition find
check_free_partition() {
  local block_size=$1
  local block_cnt=$2
  local tmp_folder=""

  check_free_space "$FREE_SPACE" "$block_size" "$block_cnt"
  if [[ $? -eq 0 ]]; then
    test_print_trc "/tmp has enough space to test read/write file"
    TEMP_DIR=$(mktemp -d)
  else
    test_print_trc "/tmp no enough space, will have a try in /root"
    check_free_space "$FREE_SPACE_ROOT" "$block_size" "$block_cnt"
    [[ $? -eq 0 ]] || block_test "no enought space in /root"
    tmp_folder=$(cat /dev/urandom | head -n 10 | md5sum | head -c 10)
    TEMP_DIR="/root/${tmp_folder}"
    if [[ -d "$TEMP_DIR" ]]; then
      test_print_wrg "$TEMP_DIR was already exist"
    else
      do_cmd "mkdir $TEMP_DIR"
    fi
  fi
}

# Detect the DEVICE connected by thunderbolt and not system disk
# Return 0 if true, otherwise false
check_tbt_connect() {
  local dev_node=$1
  local pci_tbt=$2
  local pci_dev=""
  local sys_disk=""
  test_print_trc "Check the device node: $dev_node"
  # Return 2 if system disk with this device
  sys_disk=$(df -Ph /boot | tail -1 | awk '{print $1}')
  if [[ "$sys_disk" == *"$dev_node"* ]]; then
    test_print_trc "Node $dev_node is system disk, will not test on it!"
    return 2
  fi
  # Check device connected with thunderbolt, return non-zero if not
  # due to ICL desgin changed, just check top level 2 pci match is enough
  pci_dev=$(udevadm info --attribute-walk --name=/dev/"$dev_node" \
          | grep "KERNEL" \
          | tail -n 2 \
          | awk -F '==' '{print $NF}')
  if [ "$pci_tbt" == "$pci_dev" ]; then
    test_print_trc "tbt pci path the same as $dev_node pci path"
    return 0
  else
    test_print_trc "device not connect by thunderbolt, tbt pci path:$pci_tbt"
    test_print_trc "device pci path:$pci_dev"
    return 1
  fi
}

# Check node size should be bigger than read/write block need size
# Return 0 for true, otherwise false
check_test_size() {
  local device_node=$1
  local block_size=$2
  local block_count=$3
  local needed_size=""
  local actual_size=""
  actual_size=$(fdisk -l "$device_node" 2> /dev/null \
              | grep "$device_node" \
              | grep bytes \
              | awk '{print $5}')
  needed_size=$(caculate_size_in_bytes "$block_size" "$block_count")

  # Due to large file tests, if free space smaller than request,
  # use all free space to test and just warn it and didn't return 1
  [[ "$actual_size" -gt "$needed_size" ]] || {
    # actual_size is caculated as bytes, possible round-off, so -10 bytes
    actual_size=$((actual_size - 10))
    test_print_wrg "$device_node free < $needed_size, free-10:$actual_size Bytes"
    BLOCK_SIZE=$actual_size
    BLOCK_COUNT=1
  }
}

# Check all proper type usb node saved in DEVICES
# Input:
# $1: node, $2: speed
# Return 0 for true, otherwise false or block test
protocol_check() {
  local dev_node=$1
  local speed=$2
  local speed_count=0
  local controller_count=0
  local j=0

  controller_count=$(udevadm info --attribute-walk --name=/dev/"$dev_node" \
                     | grep -C 5 speed \
                     | grep -C 5 "$speed" \
                     | awk -v RS="@#$j" '{print gsub(/Controller/,"&")}')

  speed_count=$(udevadm info --attribute-walk --name=/dev/"$dev_node" \
                | grep -C 5 speed \
                | grep -C 5 "$speed" \
                | awk -v RS="@#$j" '{print gsub(/speed/,"&")}')

  if [[ "$speed_count" -gt "$controller_count" ]]; then
    test_print_trc "Find $dev_node for speed $speed"
  else
    return 1
  fi
}

# Detect requested device type node
# Input:
# $1: node,  $2: device type like uas or flash
# Return 0 for true, otherwise false or block test
device_check() {
  local dev_node=$1
  local type=$2
  local driver=""

  case $type in
    flash) driver="usb-storage" ;;
    uas) driver="uas" ;;
    *) block_test "bad device type:$type" ;;
  esac

  udevadm info --attribute-walk --name=/dev/"$dev_node" \
                                | grep DRIVERS \
                                | grep -q $driver
  return $?
}

# This function find all nodes for matched speed
# Input:
# $1: speed like 480 5000
# $2: device type like flash or uas
# Return 0 for true, otherwise false or block test
protocol_type() {
  local speed=$1
  local device_tp=$2
  local device_nodes=""
  local node=""

  device_nodes=$(ls /dev/sd[a-z] | awk -F '/' '{print $NF}')
  [ -n "$device_nodes" ] || block_test "No nodes find:$device_nodes"

  for node in $device_nodes
  do
    protocol_check "$node" "$speed" || continue
    device_check "$node" "$device_tp" || continue
    DEVICES="$DEVICES $node"
  done
}

# get specific sys path for ICL/TGL
# Input: NA
# Return 0 for true, otherwise false or block test
get_specific_sys_path() {
  local tbt_dev=""

  tbt_dev=$(ls ${TBT_PATH} \
              | grep "$REGEX_ITEM" \
              | grep -v "$HOST_EXCLUDE" \
              | awk '{ print length(), $0 | "sort -n" }' \
              | cut -d ' ' -f 2 \
              | head -n1)

  case ${tbt_dev} in
    0-1)
      SYS_PATH="$dev_path/0000:00:07.0"
      ;;
    0-3)
      SYS_PATH="$dev_path/0000:00:07.1"
      ;;
    1-1)
      SYS_PATH="$dev_path/0000:00:07.2"
      ;;
    1-3)
      SYS_PATH="$dev_path/0000:00:07.3"
      ;;
    *)
      block_test "Invalid tbt_dev:$tbt_dev, maybe tbt device not connect"
      ;;
  esac
}

# Integrated TBT root PCI will be changed so need to verify and find it
# Input: $1 TBT_ROOT_PCI
# Return 0 for true, otherwise false or block_test
verify_tbt_root_pci() {
  local root_pci=$1
  local dev_path="/sys/devices/pci0000:00"
  local result=""
  local pf=""
  local pf_name=""
  local tbt_dev=""

  tbt_dev=$(ls ${TBT_PATH} \
              | grep "$REGEX_ITEM" \
              | grep -v "$HOST_EXCLUDE" \
              | awk '{ print length(), $0 | "sort -n" }' \
              | cut -d ' ' -f 2 \
              | head -n1)

  pf=$(dmidecode --type bios \
            | grep Version \
            | cut -d ':' -f 2)
  pf_name=$(echo ${pf: 1: 4})

  result=$(ls -1 $dev_path/$root_pci | grep "0000" | grep "07")
  if [[ -z "$result" ]]; then
    [[ "$tbt_dev" == *"-1"* ]] && {
      [[ "$root_pci" == *"0d.2" ]] && TBT_ROOT_PCI="0000:00:07.0"
      [[ "$root_pci" == *"0d.3" ]] && TBT_ROOT_PCI="0000:00:07.2"
    }
    [[ "$tbt_dev" == *"-3"* ]] && {
      [[ "$root_pci" == *"0d.2" ]] && TBT_ROOT_PCI="0000:00:07.1"
      [[ "$root_pci" == *"0d.3" ]] && TBT_ROOT_PCI="0000:00:07.3"
    }
    SYS_PATH="$dev_path/$TBT_ROOT_PCI"
    test_print_trc "Discrete or FW CM on $pf_name,root:$TBT_ROOT_PCI, $SYS_PATH"
  elif [[ "$tbt_dev" == *"-1"* ]]; then
    # for TBT SW CM mode
    TBT_ROOT_PCI=$(ls -1 $dev_path/$root_pci \
                  | grep "0000" \
                  | grep "07" \
                  | head -n 2 \
                  | head -n 1 \
                  | awk -F "pci:" '{print $2}')
    # for TBT FW CM mode
    [[ -z "$TBT_ROOT_PCI" ]] && {
      TBT_ROOT_PCI=$(ls -1 $dev_path/$root_pci \
                    | grep "0000" \
                    | grep "07" \
                    | head -n 2 \
                    | head -n 1 \
                    | awk -F ":pci" '{print $1}')
    }
    SYS_PATH="$dev_path/$TBT_ROOT_PCI"
    test_print_trc "Integrated on $pf_name, $tbt_dev $root_pci -> $TBT_ROOT_PCI"
  elif [[ "$tbt_dev" == *"-3"* ]]; then
    # for TBT SW CM mode
    TBT_ROOT_PCI=$(ls -1 $dev_path/$root_pci \
                  | grep "0000" \
                  | grep "07" \
                  | head -n 2 \
                  | tail -n 1\
                  | awk -F "pci:" '{print $2}')
    # for TBT FW CM mode
    [[ -z "$TBT_ROOT_PCI" ]] && {
      TBT_ROOT_PCI=$(ls -1 $dev_path/$root_pci \
                    | grep "0000" \
                    | grep "07" \
                    | head -n 2 \
                    | head -n 1 \
                    | awk -F ":pci" '{print $1}')
    }
    SYS_PATH="$dev_path/$TBT_ROOT_PCI"
    test_print_trc "Integrated on $pf_name, $tbt_dev $root_pci -> $TBT_ROOT_PCI"
  elif [[ -z "$tbt_dev" ]]; then
    [[ "$root_pci" == *"0d.2" ]] && TBT_ROOT_PCI="0000:00:07.0"
    [[ "$root_pci" == *"0d.3" ]] && TBT_ROOT_PCI="0000:00:07.2"
    SYS_PATH="$dev_path/$TBT_ROOT_PCI"
  else
    die "Invalid tbt device sysfs:$tbt_dev"
  fi
  test_print_trc "TBT ROOT:$TBT_ROOT_PCI SYS_PATH:$dev_path/$TBT_ROOT_PCI"
}

# check that whether cleware or usb4 swich is plugged in status
# No input
# Return: 0 for true, otherwise false or die
check_plugin() {
  local plug_state=""
  PLUG_IN=0

  if [[ -n "$HID_CONTENT" ]]; then
    PLUG_IN=$(cleware s | grep status | head -n 1 | awk -F "=" '{print $NF}')
    [[ -z "$PLUG_IN" ]] && PLUG_IN=0
    test_print_trc "Cleware PLUG_IN:$PLUG_IN"
  elif [[ -e "$ACM0" ]]; then
    plug_state=$(serial_cmd "status" | grep "PORTF: 0x12" 2>/dev/null)
    if [[ -n "$plug_state" ]]; then
      test_print_trc "Already connected port1 for USB4 switch:$plug_state"
      PLUG_IN=1
    fi
    test_print_trc "USB4 switch 3141 PLUG_IN:$PLUG_IN"
  else
    test_print_wrg "No Cleware:$HID_CONTENT or USB4 switch:$ACM0 for plug out"
    CLE=1
  fi
}

# check security status, if no security status, will try power on cleware
# No input
# Return: 0 for true, otherwise false or die
check_auto_connect() {
  local tbt=""
  local result=""

  if [[ -e "${TBT_PATH}/domain0/security" ]]; then
    check_security_mode
    test_print_trc "It's $SECURITY mode"
  else
    test_print_trc "Could not detect tbt mode"
  fi

  # due to multi domains, need exclude all domains X-0
  tbt=$(ls "$TBT_PATH" | grep "$REGEX_ITEM" | grep -v "$HOST_EXCLUDE")

  if [ -n "$tbt" ]; then
    test_print_trc "Found tbt device"
  else
    check_plugin
    if [[ "$PLUG_IN" -eq 1 ]]; then
      test_print_trc "Cleware or usb4 switch is already connected:$PLUG_IN"
    else
      plug_in_tbt
      # sleep 20, wait all tbt device ready
      do_cmd "sleep 20"
    fi
  fi
}

# Get the tbt root port pci and save it in TBT_PCI
# Input: null
# Return 0 for true, otherwise false or block_test
get_tbt_pci() {
  local domain_file=""
  local dev_path="/sys/devices/pci0000:00"
  local pf_name=""

  pf_name=$(dmidecode --type bios \
            | grep Version \
            | cut -d ':' -f 2)

  # due to ICL/TGL design change, hard code for different root port pci
  case $pf_name in
    *ICL*)
      test_print_trc "ICL platform"
      check_auto_connect
      get_specific_sys_path
      ;;
    *TGL*)
      test_print_trc "TGL platform"
      check_auto_connect
      get_specific_sys_path
      ;;
    *)
      domain_file=$(ls ${TBT_PATH} | grep ${REGEX_DOMAIN}${DOMAINX} | head -n 1)
      SYS_PATH="${TBT_PATH}/${domain_file}"
      ;;
  esac

  TBT_ROOT_PCI=$(udevadm info --attribute-walk --path=${SYS_PATH} \
                | grep "KERNEL" \
                | tail -n 2 \
                | grep -v pci0000 \
                | cut -d "\"" -f 2)
  verify_tbt_root_pci "$TBT_ROOT_PCI"

  TBT_PCI=$(udevadm info --attribute-walk --path=${SYS_PATH} \
            | grep "KERNEL" \
            | tail -n 2 \
            | awk -F '==' '{print $NF}')

  [[ -n "$TBT_PCI" ]] || die "TBT_PCI is null:$TBT_PCI"
  test_print_trc "tbt top 2 pci path:$TBT_PCI"
}

# This function detect the device node connected by tbt
# Input:
# $1: block size
# $2: block count
# $3: protocol type like ssd, 2.0, 3.0, 3.1
# $4: device type like flash, uas
# Return 0 for true, otherwise false or block_test
find_tbt_device() {
  local block_size=$1
  local block_count=$2
  local protocol=$3
  local device_tp=$4
  local speed=""
  local device=""
  local dev_node=""
  local device_size=""
  local dmesg_log=""

  # clean old DEVICE_NODE and NODE if one case use this function twice
  DEVICE_NODE=""
  NODE=""

  get_tbt_pci

  case $protocol in
    2.0)
      speed="480"
      protocol_type "$speed" "$device_tp"
      ;;
    3.0)
      speed="5000"
      protocol_type "$speed" "$device_tp"
      ;;
    3.1)
      speed="10000"
      protocol_type "$speed" "$device_tp"
      ;;
    ssd)
      # Detect all SSD node
      DEVICES=$(lsblk -d -o name,rota | grep sd | grep 0 | awk '{print $1}')
      ;;
    nvme)
      # Detect all nvme node
      DEVICES=$(lsblk -d -o name,rota | grep nvme | grep 0 | awk '{print $1}')
      ;;
    *)
      block_test "Bad device type:$protocol $device_tp"
      ;;
  esac

  if [ -z "$DEVICES" ]; then
    dmesg_log=$(extract_case_dmesg -f)
    block_test "No nodes for $protocol $device_tp, dmesg:$LOG_PATH/$dmesg_log"
  else
    test_print_trc "Find nodes for $protocol $device_tp:"
    test_print_trc "$DEVICES"
  fi
  # Detect devices connected by thunderbolt
  for device in ${DEVICES}; do
    check_tbt_connect "$device" "$TBT_PCI" || continue
    check_test_size "/dev/$device" "$block_size" "$block_count" || continue
    device_size=$(fdisk -l "/dev/$device" 2> /dev/null \
             | grep "/dev/$device" \
             | grep bytes \
             | awk '{print $5}')
    test_print_trc "Find tbt device $device, size: $device_size"
    dev_node="$device"
    break
  done
  [ -n "$dev_node" ] || block_test "Not find $protocol $device_tp connect with tbt"
  test_print_trc "Find $protocol $device_tp connect with tbt: $dev_node"
  NODE="$dev_node"
  DEVICE_NODE="/dev/$dev_node"
  return 0
}

# This function generate request size test file to read and write
# Input:
#       $1: block size of the file, with unit
#       $2: block count of the file
#       $3: where the file will be created
# Output:
#       Return path of the created file on success, fail return null
generate_test_file() {
  local block_size=$1
  local block_count=$2
  local dir=$3
  local if="/dev/random"
  local of=""
  of="${dir}/test.$(date +%Y%m%d%H%M%S)"
  dd if="$if" of="$of" bs="$block_size" count="$block_count" &> /dev/null
  if [ $? -eq 0 ] && [ -e "$of" ]; then
    echo "$of"
  else
    echo
  fi
}

# This function perform write test on usb device
# Input:
#       $1: device to be performed test on
#       $2: data source
#       $3: bs block size
#       $4: bc block count
# Return: Write with dd command, 0 for true, otherwise false
write_test_with_file() {
  local of=$1
  local if=$2
  local bs=$3
  local bc=$4
  local if_size=""
  if_size=$(du -b "$if" | awk '{print $1}')
  test_print_trc "size of $if is $if_size"
  if [[ -z "$bc" ]]; then
    do_cmd "dd if=$if of=$of bs=$if_size count=1"
  else
    do_cmd "dd if=$if of=$of"
  fi
  return $?
}

# This function perform read test on usb device
# Input:
#       $1: device to be performed test on
#       $2: original file, to be compared with the read out data
#       $3: bs, block size
#       $4: bc, block count
# Return: Read with dd command, 0 for true, otherwise false
read_test_with_file() {
  local if=$1
  local test_file=$2
  local bs=$3
  local bc=$4
  local of="${test_file}.copy"
  local file_size=""

  file_size=$(du -b "$test_file" | awk '{print $1}')
  test_print_trc "size of $test_file is $file_size"
  if [[ -z "$bc" ]]; then
    do_cmd "dd if=$if of=$of bs=$file_size count=1"
  else
    do_cmd "dd if=$if of=$of"
  fi
  test_print_trc "Check diff for files: $test_file and $of"
  do_cmd "diff $test_file $of"
  if [ $? -eq 0 ]; then
    test_print_trc "diff test pass"
    return 0
  else
    die "diff $test_file $of test failed"
  fi
}

# Devices connect by thunderbolt read write test
# Input:
# $1: block size like 100M
# $2: block counter like 5
# $3: protocol type like flash,uas,ssd
# $4: Device type like 2.0, 3.0
# Return 0 for true, otherwise false or die
tbt_device_rw_test() {
  local block_size=$1
  local block_count=$2
  local protocol=$3
  local device_tp=$4

  # Prepare stage
  check_test_env
  check_free_partition "$block_size" "$block_count"

  # Block rw test in dp only mode
  check_security_mode
  if [ "$SECURITY" == "dponly" ]; then
    block_test "dponly mode, could not read write test"
  fi

  # Enable authorized, find ssd connected by thunderbolt
  enable_authorized
  sleep 5
  find_tbt_device "$block_size" "$block_count" "$protocol" "$device_tp"
  [ -n "$DEVICE_NODE" ] || die "No $ssd node:$DEVICE_NODE"

  # Generate test folder and test file
  [ -e "$TEMP_DIR" ] || block_test "fail to create temporary directory!"
  test_print_trc "TEMP_DIR: $TEMP_DIR"
  test_file=$(generate_test_file "$block_size" "$block_count" "$TEMP_DIR")

  mount_dev "$DEVICE_NODE" "$MOUNT_FOLDER"
  write_test_with_file "$RW_FILE" "$test_file" "$block_size" "$block_count"
  read_test_with_file "$RW_FILE" "$test_file" "$block_size" "$block_count"
  rm -rf "$TEMP_DIR"
}

# Add tbt device name for each device and show it
# Input:
# $1: for tbt device domain like 0 or 1
# $2: for tbt device branch like 1 or 3
# Return 0 for true, otherwise false or die
topo_name() {
  local tbt_sys=$1
  local devs_file=$2
  local tbt_file=""
  local dev_name="device_name"
  local device_topo=""
  local file_topo=""

  [ -n "$tbt_sys" ] || {
    test_print_trc "No tbt device in tbt_sys:$tbt_sys"
    return 1
  }

  # Get last file
  last=$(echo "$tbt_sys" | awk '{print $NF}')

  # Last file not add <-> in the end
  for tbt_file in ${tbt_sys}; do
    device_file=""
    if [ "$tbt_file" == "$last" ]; then
      device_file=$(cat ${TBT_PATH}/${tbt_file}/${dev_name} 2>/dev/null)
      device_topo=${device_topo}${device_file}
      file_topo=${file_topo}${tbt_file}
    else
      device_file=$(cat ${TBT_PATH}/${tbt_file}/${dev_name} 2>/dev/null)
      [[ -n "$device_file" ]] || device_file="no_name"
      # For alignment for such as 0-0 and device name, device name is longer
      device_file_num=${#device_file}
      tbt_file_num=${#tbt_file}
      if [[ "$device_file_num" -gt "$tbt_file_num" ]]; then
        gap=$((device_file_num - tbt_file_num))
        device_topo=${device_topo}${device_file}" <-> "
        file_topo=${file_topo}${tbt_file}
        for ((c=1; c<=gap; c++)); do
          file_topo=${file_topo}" "
        done
        file_topo=${file_topo}" <-> "
      else
        device_topo=${device_topo}${device_file}" <-> "
        file_topo=${file_topo}${tbt_file}" <-> "
      fi
    fi
  done
  test_print_trc "device_topo: $device_topo"
  echo "device_topo: $device_topo" >> "$devs_file"
  test_print_trc "file_topo  : $file_topo"
  echo "file_topo  : $file_topo" >> "$devs_file"
}

# This function will view request domain and request tbt branch devices
# and will write the topo result into $TOPO_FILE
# Inuput:
#   $1: domain num, 0 for domain0, 1 for domain1
#   $2: branch num, 1 for domainX-1, 3 for domainX-3
# Return: 0 for true, otherwise false or die
topo_view() {
  local domainx=$1
  local tn=$2
  local tbt_sys_file="/tmp/tbt_sys.txt"
  local tbt_devs=""
  local device_num=""
  local dev_item=""
  local check_point=""

  ls -l ${TBT_PATH}/${domainx}*${tn} 2>/dev/null \
    | grep "-" \
    | awk -F "${REGEX_DOMAIN}${domainx}/" '{print $2}' \
    | awk '{ print length(), $0 | "sort -n" }' \
    | grep -v ":" \
    | grep -v "_" \
    | cut -d ' ' -f 2 \
    | tr '/' ' ' \
    > $tbt_sys_file
  # need tbt devices in order
  tbt_devs=$(ls ${TBT_PATH} 2>/dev/null \
    | grep "-" \
    | grep -v ":" \
    | grep "^${domainx}" \
    | grep "${tn}$" \
    | awk '{ print length(), $0 | "sort -n" }' \
    | cut -d ' ' -f 2)
  device_num=$(ls ${TBT_PATH} \
    | grep "^${domainx}" \
    | grep -v ":" \
    | grep "${tn}$" \
    | wc -l)
  test_print_trc "$domainx-$tn contains $device_num tbt devices."
  echo "$domainx-$tn contains $device_num tbt devices." >> "$TOPO_FILE"
  cat /dev/null > "${DEV_FILE}_${domainx}_${tn}"
  cp -rf "$tbt_sys_file" "${DEV_FILE}_${domainx}_${tn}"
  for tbt_dev in $tbt_devs; do
    dev_item=""
    dev_item=$(cat "$tbt_sys_file" | grep "${tbt_dev}$")
    [[ -z "$dev_item" ]] && {
      test_print_wrg "dev_item is null for tbt_dev:$tbt_dev"
      continue
    }
    check_point=$(cat "$tbt_sys_file" \
      | grep -v "${dev_item}$" \
      | grep "${dev_item}" \
      | head -n 1)
    [[ -z "$check_point" ]] && {
      #test_print_trc "check_point for ${dev_item} is null"
      continue
    }
    sed -i "/${check_point}$/d" "${DEV_FILE}_${domainx}_${tn}"
    sed -i "s/${dev_item}$/${check_point}/g" "${DEV_FILE}_${domainx}_${tn}"
  done
  while IFS= read -r line
  do
    topo_name "$line" "$TOPO_FILE"
  done < "${DEV_FILE}_${domainx}_${tn}"
}

# This function will check how many tbt device connected and
# show the tbt devices how to connect, which one connect with which one
# Inuput: NA
# Return: 0 for true, otherwise false or die
topo_tbt_check(){
  # tbt spec design tbt each domain will seprate to like 0-1 or 0-3 branch
  local t1="1"
  local t3="3"
  local domains=""
  local domain=""
  local topo_result=""

  domains=$(ls $TBT_PATH/ \
            | grep "$REGEX_DOMAIN" \
            | grep -v ":" \
            | awk -F "$REGEX_DOMAIN" '{print $2}' \
            | awk -F "->" '{print $1}')

  do_cmd "cat /dev/null > $TOPO_FILE"

  for domain in ${domains}; do
    topo_view "$domain" "$t1"
    topo_view "$domain" "$t3"
  done
  topo_result=$(cat $TOPO_FILE)
  [[ -n "$topo_result" ]] || die "tbt $TOPO_FILE is null:$topo_result"
}


# Compare topo before test action and after test action, should same
# Input:
# $1: tbt topo info before test action
# return: 0 for true, otherwise false or die
topo_compare() {
  origin_topo=$1
  final_topo=""

  topo_tbt_check
  final_topo=$(cat $TOPO_FILE)
  if [ "$origin_topo" == "$final_topo" ]; then
    test_print_trc "topo comapre pass"
    test_print_trc "origin topo:$origin_topo"
    # add one more space, make topo info alignment, easy to check
    test_print_trc "final  topo:$final_topo"
  else
    die "topo compare fail, origin:$origin_topo,final:$final_topo"
  fi
}

# Execute suspend test
# Input $1: suspend type like freeze, s2idle
# Output: 0 for true, otherwise false or die
suspend_test() {
  local suspend_type=$1
  local rtc_time=30
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
      rtcwake -m $suspend_type -s $rtc_time
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
    deep)
      test_print_trc "set $suspend_type in $POWER_MEM_SLEEP"
      echo "$suspend_type" > $POWER_MEM_SLEEP
      test_print_trc "rtcwake -m $mem -s $rtc_time"
      rtcwake -m "$mem" -s "$rtc_time"
      [ "$?" -eq 0 ] || die "fail to resume from $suspend_type!"
      ;;
    disk)
      test_print_trc "rtcwake -m $suspend_type -s $DISK_TIME"
      rtcwake -m "$suspend_type" -s "$DISK_TIME"
      [ "$?" -eq 0 ] || die "fail to resume from $suspend_type!"
      ;;
    *)
      die "suspend_type: $suspend_type not support"
      ;;
  esac
  sleep 10
}

# Check tbt exist after suspend test, all tbt device could display normally
# Input: $1 suspend type
# Output: 0 for true, otherwise false or die
tbt_suspend_test() {
  local suspend_type=$1
  local origin_state=""
  local result_state=""
  local origin_pci=""
  local result_pci=""

  topo_tbt_check
  origin_pci=$(lspci -t)
  origin_state=$(cat $TOPO_FILE)
  suspend_test "$suspend_type"
  topo_tbt_check
  result_state=$(cat $TOPO_FILE)
  result_pci=$(lspci -t)
  if [[ "$origin_state" == "$result_state" ]]; then
    test_print_trc "$suspend_type passed, origin:$origin_state"
    test_print_trc "After resume, result:$result_state"
  else
    die "$suspend_type failed, origin:$origin_state, result:$result_state"
  fi

  if [[ "$origin_pci" == "$result_pci" ]]; then
    test_print_trc "After $suspend_type, origin and result pci same:$origin_pci"
  else
    die "$suspend_type failed, origin pci:$origin_pci, result pci:$result_pci"
  fi

  check_tbt_sysfs
}

# Check ssd connect with thunderbolt rw function
# 0 for true, other wise false or die
tbt_ssd_rw_test() {
  local test_file=""
  local block_size="1MB"
  local block_count=1
  local ssd="ssd"

  # Prepare stage
  check_test_env
  check_free_partition "$block_size" "$block_count"

  # Block rw test in dp only mode
  check_security_mode
  if [ "$SECURITY" == "dponly" ]; then
    block_test "dponly mode, could not read write test"
  fi

  # Enable authorized, find ssd connected by thunderbolt
  enable_authorized
  sleep 5
  find_tbt_device "$block_size" "$block_count" "$ssd"
  [ -n "$DEVICE_NODE" ] || die "No $ssd node:$DEVICE_NODE"

  # Generate test folder and test file
  [ -e "$TEMP_DIR" ] || block_test "fail to create temporary directory!"
  test_print_trc "TEMP_DIR: $TEMP_DIR"
  test_file=$(generate_test_file "$block_size" "$block_count" "$TEMP_DIR")

  mount_dev "$DEVICE_NODE" "$MOUNT_FOLDER"
  write_test_with_file "$RW_FILE" "$test_file" "$block_size" "$block_count"
  read_test_with_file "$RW_FILE" "$test_file" "$block_size" "$block_count"
  rm -rf "$TEMP_DIR"
}

# Check thunderbolt monitor connected or not
# No input
# Return TBT_MONITOR_FILE if tbt monnitor exist, otherwise false or die
tbt_monitor_check() {
  local tbt_monitor=""

  tbt_monitor=$(grep -H . /sys/bus/thunderbolt/devices/*/* 2>/dev/null \
                | grep device_name \
                | grep 5K)
  if [ -n "$tbt_monitor" ]; then
    test_print_trc "tbt monitor found:$tbt_monitor"
  else
    die "There was no tbt monitor found:$tbt_monitor"
  fi

  TBT_MONITOR_FILE=$(grep -H . /sys/bus/thunderbolt/devices/*/* 2>/dev/null \
                      | grep device_name \
                      | grep 5K \
                      | awk -F '/' '{print $(NF-1)}')
  [ "$?" -eq 0 ] || die "Fail to check tbt monitor file"
  if [ -n "$TBT_MONITOR_FILE" ]; then
    test_print_trc "tbt monitor file:$TBT_MONITOR_FILE"
  else
    die "Could not find tbt monitor file:$TBT_MONITOR_FILE"
  fi
}

# Input:
#   $1: authorzied file
#   $2: expect result, if 2 means not zero
# Return: 0 for true, other wise false or die
check_authorize() {
  local tbt_monitor_file=$1
  local expect_result=$2
  local result=""

  result=$(cat ${TBT_PATH}/${tbt_monitor_file}/${AUTHORIZE_FILE})
  test_print_trc "$tbt_monitor_file authorized:$result"
  if [ "$expect_result" == "2" ]; then
    [ "$result" != "0" ] \
      || die "${tbt_monitor_file} authorized should not 0:$result"
  else
    [ "$result" == "$expect_result" ] \
      || die "${tbt_monitor_file} authorized:$result, not expect:$expect_result"
  fi
}

# Thunderbolt nvm flash
# Input:
#   $1: nvm source file path
#   $2: nvm file fill in target path
#   $3: device path which will be flashed
# Return: 0 for true, otherwise false or die
nvm_flash() {
  local nvm_source=$1
  local nvm_target=$2
  local nvm_device=$3
  local verify_result=""

  [ -e "$nvm_source" ] || block_test "No $nvm_source to flash"
  [ -e "$nvm_target" ] || block_test "No nvm target file:$nvm_target"

  # Check nvm_authenticate state before NVM flash
  verify_result=$(cat "$nvm_device/$NVM_VERIFY")
  if [ "$verify_result" == "$VERIFY_SUCCESS" ]; then
    test_print_trc "NVM authenticate normal before flash:$verify_result"
  else
    test_print_wrg "NVM authenticate is not '0x0' before nvm:$verify_result"
  fi

  # Execute NVM flash
  do_cmd "dd if=$nvm_source of=$nvm_target"
  sleep 2
  do_cmd "echo 1 > $nvm_device/$NVM_VERIFY"
  sleep 120
  verify_result=$(cat "$nvm_device/$NVM_VERIFY")
  [ "$verify_result" == "$VERIFY_SUCCESS" ] || sleep 180
  verify_result=$(cat "$nvm_device/$NVM_VERIFY")
  if [ "$verify_result" == "$VERIFY_SUCCESS" ]; then
    test_print_trc "NVM flash $nvm_source successful!"
  else
    die "NVM flash $nvm_source fail, $nvm_device/$NVM_VERIFY:$verify_result"
  fi
}

# Thunderbolt prepare stage, check file exist before NVM flash
# Input:
#   $1: nvm source file path
#   $2: nvm file fill in target path
#   $3: device path which will be flashed
# Return: 0 for true, otherwise false or die
tbt_nvm_prepare() {
  local nvm_source=$1
  local nvm_target=$2
  local nvm_device=$3

  [ -d "$NVM_PATH" ] || do_cmd "mkdir $NVM_PATH"
  [ -e "$nvm_device/$NVM_VERSION" ] \
    || block_test "No nvm_version file:$nvm_device/$NVM_VERSION"
  [ -e "$nvm_source" ] || block_test "No file:$nvm_source to flash"
  [ -e "$nvm_target" ] || block_test "No nvm target file:$nvm_target"
}

# Thunderbolt NVM downgrade test
# Input:
#   $1: nvm source file path
#   $2: nvm file fill in target path
#   $3: device path which will be flashed
# Return: 0 for true, otherwise false or die
tbt_downgrade() {
  local nvm_source=$1
  local nvm_target=$2
  local nvm_device=$3
  local version_origin=""
  local version_downgrade=""

  tbt_nvm_prepare "$nvm_source" "$nvm_target" "$nvm_device"
  version_origin=$(cat "$nvm_device/$NVM_VERSION")
  test_print_trc "Origin NVM version:$version_origin"
  do_cmd "echo $version_origin > $ORIGIN_VERSION"
  nvm_flash "$nvm_source" "$nvm_target" "$nvm_device"
  version_downgrade=$(cat "$nvm_device/$NVM_VERSION")
  test_print_trc "Downgrade NVM version:$version_downgrade"
  if [ "$version_origin" == "$version_downgrade" ]; then
    test_print_wrg "Downgrade version is same as origin version:$version_origin"
  else
    test_print_trc "Origin:$version_origin, downgrade:$version_downgrade, pass"
  fi
}

# Thunderbolt NVM upgrade test
# Input:
#  $1: nvm source file path
#  $2: nvm file fill in target path
#  $3: device path which will be flashed
# Return: 0 for true, otherwise false or die
tbt_upgrade() {
  local nvm_source=$1
  local nvm_target=$2
  local nvm_device=$3
  local version_origin=""
  local version_upgrade=""

  tbt_nvm_prepare "$nvm_source" "$nvm_target" "$nvm_device"
  version_origin=$(cat "$ORIGIN_VERSION")
  nvm_flash "$nvm_source" "$nvm_target" "$nvm_device"
  version_upgrade=$(cat "$nvm_device/$NVM_VERSION")
  if [ "$version_origin" == "$version_upgrade" ]; then
    test_print_trc "Upgrade version is same as origin:$version_origin, pass"
  else
    test_print_wrg "Upgrade version is not same, origin:$version_origin, upgrade:$version_upgrade"
  fi
}

# Find end point tbt device
# No input
# Return: find ep path, otherwise false or die
find_ep() {
  tbt_devices=""
  tbt_device=""
  device_vendor=""

  tbt_devices=$(ls -1 $TBT_PATH \
                | grep "$REGEX_ITEM" \
                | grep -v "$HOST_EXCLUDE")

  for tbt_device in ${tbt_devices}; do
    device_vendor=$(cat $TBT_PATH/$tbt_device/$VENDOR)
    [[ "$device_vendor" == "$EP_VENDOR" ]] && {
      echo "$TBT_PATH/$tbt_device"
      return 0
    }
  done
  return 1
}

# Find tbt device nvmem path
# Input:
#  $1: tbt device path
# return tbt device nvmem path
find_nvmem() {
  tbt_path=$1
  nvm_non="nvm_non_active"
  tbt_nvmem=""
  nvmem="nvmem"

  tbt_nvmem=$(ls "$tbt_path/$nvm_non"*/"$nvmem" | tail -n 1)
  [[ -n "$tbt_nvmem" ]] || die "Could not find nvmem for $tbt_path"
  echo "$tbt_nvmem"
}

# Thunderbolt end point device downgrade
# Input:
#  $1: EP device flash nvm file, old for downgrade, new for upgrade
# Return: 0 for true, otherwise false or die
ep_nvm_flash() {
  local ep_source=$1
  local ep_device=""
  local ep_nvmem=""

  ep_device=$(find_ep)
  [[ -z "$ep_device" ]] && die "didn't find ep device:$ep_device"
  ep_nvmem=$(find_nvmem "$ep_device")
  test_print_trc "device:$ep_device, nvmem:$ep_nvmem"

  case ${ep_source} in
    $EP_OLD)
      tbt_downgrade "$EP_OLD" "$ep_nvmem" "$ep_device"
      ;;
    $EP_NEW)
      tbt_upgrade "$EP_NEW" "$ep_nvmem" "$ep_device"
      ;;
    *)
      block_test "Invalid ep_source:$ep_source"
      ;;
  esac
}

# Thunderbolt devices plug out function
# No input
# Return: 0 for true, otherwise false or die
plug_out_tbt() {
  local bolt_info=""
  local bolt=""
  local bolt_path="/var/lib/boltd/devices"

  if [[ -n "$HID_CONTENT" ]]; then
    # plug out thunderbolt devices action
    do_cmd "cleware 0"
  elif [[ -e "$ACM0" ]]; then
    local state=""
    state=$(serial_cmd "status" | grep "PORTF" 2>/dev/null)
    if [[ -z "$state" ]]; then
      CLE=1
      test_print_wrg "No USB4 switch or cleware:$state for plug out"
      return 1
    else
      test_print_trc "Used USB4 switch 3141 tool, state:$state"
    fi
    usb4switch_plugout
  else
    test_print_wrg "No Cleware:$HID_CONTENT or USB4 switch:$ACM0 for plug out"
    CLE=1
  fi

  # ubuntu 18.04 add auto authorized function, which impact tbt authorize test
  sleep 2
  bolt_info=$(boltctl 2>/dev/null | grep uuid | awk -F "uuid:" '{print $2}')
  for bolt in $bolt_info; do
    if [[ -e "${bolt_path}/${bolt}" ]]; then
      # due to boltctl is not supported in old linux os, do_cmd will not use
      test_print_trc "Stop auto authorize tbt $bolt"
      boltctl forget "$bolt" 2>/dev/null
    fi
  done
  boltctl forget -a
}

# Check tbt connect or not, if connect will plug out tbt devices
# No input
# Return: 0 for true, otherwise false or die
plug_out_check() {
  local tbt_device=""

  tbt_device=$(ls $TBT_PATH | grep -v "$REGEX_DOMAIN" | grep -v "$HOST_EXCLUDE")

  if [[ -z "$tbt_device" ]]; then
    test_print_trc "No tbt devices connected:$(ls $TBT_PATH)"
  else
    plug_out_tbt
    # due to legacy mode: BIOS deteact tbt devices, need time to detect plug out
    do_cmd "sleep 20"
    tbt_device=""
    tbt_device=$(ls "$TBT_PATH" | grep "$REGEX_ITEM" | grep -v "$HOST_EXCLUDE")
    [ -z "$tbt_device" ] \
      || die "Plug out, file still exist in $TBT_PATH:$tbt_device"
  fi
}

# Thunderbolt user mode plug in original status check
# Input: $1: zero for authorized value 0, non-zero for non-zero
# Return: 0 for true, otherwise false or die
authorized_check() {
  local expect_authorized=$1
  local tbt_authorized=""
  local tbt_device=""

  test_print_trc "Expect authorized:$expect_authorized"
  # Except host tbt module, check tbt device connected
  tbt_device=$(grep -H . $AUTHOR_PATH 2>/dev/null \
                | grep "$AUTHORIZE_FILE" \
                | grep -v "$HOST_EXCLUDE")
  if [ -z "$tbt_device" ]; then
    block_test "No connect tbt device detect: $tbt_device"
  else
    test_print_trc "tbt devices authorized: $tbt_device"
  fi

  case $expect_authorized in
    zero)
      # Check connected tbt device, authorized should be 0 after plug in
      # except TBT HOST
      tbt_authorized=$(grep -H . $AUTHOR_PATH 2>/dev/null \
                        | grep "$AUTHORIZE_FILE" \
                        | grep -v "$HOST_EXCLUDE" \
                        | cut -d ':' -f 2 \
                        | grep -v "0")
      ;;
    non-zero)
      # Check connected tbt device, authorized should be not 0 after plug in
      # except HOST
      tbt_authorized=$(grep -H . $AUTHOR_PATH 2>/dev/null \
                        | grep "$AUTHORIZE_FILE" \
                        | grep -v "$HOST_EXCLUDE" \
                        | cut -d ':' -f 2 \
                        | grep "0")
      ;;
    *)
      block_test "Invalid expect_authorized:$expect_authorized"
      ;;
  esac
  if [ -n "$tbt_authorized" ]; then
    check_tbt_sysfs
    die "tbt authorized expect:$expect_authorized, but detect:$tbt_authorized"
  else
    test_print_trc "authorized content check pass"
  fi
}

# fill file with request string, return expected result or not
# Input:
# $1: which file will be filled in
# $2: value will be filled in
# $3: except result is pass or fail
# Return if pass, should return 0, if fail should return non-zero, otherwise die
fill_file_in() {
  local file=$1
  local value=$2
  local expect_result=$3
  local result=""

  test_print_trc "set $value into $file"
  case $expect_result in
    pass)
      echo "$value" > "$file" || die "fill $value in $file failed"
      ;;
    fail)
      eval "echo \"$value\" > \"$file\"" 2>/dev/null \
        && die "fill $value in $file pass but expected fail"
      ;;
    *)
      block_test "invalid expect_result: $expect_result"
      ;;
  esac
}

# fill authorized with value, check result non-zero or not
# Input:
# $1: value will be filled in
# $2: except result is pass or fail
# Return if pass, should return 0, if fail should return non-zero, otherwise die
fill_authorized() {
  local value=$1
  local expect_result=$2
  local result=""
  local authorized_files=""
  local authorized_file=""

  test_print_trc "Expect result: $expect_result"
  authorized_files=$(grep -H . $AUTHOR_PATH 2>/dev/null \
                      | grep "$AUTHORIZE_FILE" \
                      | grep -v "$HOST_EXCLUDE" \
                      | cut -d ":" -f 1 \
                      | awk '{print length(), $0 | "sort -n"}' \
                      | cut -d ' ' -f 2 )
  [ -z "$authorized_files" ] && block_test "no tbt authorized:$authorized_files"
  for authorized_file in ${authorized_files}; do
    fill_file_in "$authorized_file" "$value" "$expect_result"
  done
}

# Secure mode tested, update key password function
# Input: none
# Return: 0 for true, otherwise false or die
secure_key() {
  local parm=$1
  local tbt_device=""
  local tbt_devices=""
  local key=""
  local pass="pass"

  # generated the new password for key file
  tbt_devices=$(ls -1 ${TBT_PATH} \
          | grep "$REGEX_ITEM" \
          | grep -v "$HOST_EXCLUDE" \
          | awk '{ print length(), $0 | "sort -n" }' \
          | cut -d ' ' -f 2)
  [ -n "$tbt_devices" ] || die "No file in $TBT_PATH:$tbt_devices"
  [ -d "$KEY_PATH" ] || mkdir "$KEY_PATH"

  for tbt_device in ${tbt_devices}; do
    [ -e "${TBT_PATH}/${tbt_device}/${KEY_FILE}" ] \
      || die "No $tbt_device key file found in $TBT_PATH"
    case ${parm} in
      update)
        key=$(openssl rand -hex 32)
        test_print_trc "Update key for $tbt_device:$key"
        echo "$key" > "$KEY_PATH"/"$tbt_device".key
        fill_key "${tbt_device}.key" "$tbt_device"
        ;;
      verify)
        [ -e "$KEY_PATH/$tbt_device.key" ] || die "No file $KEY_PATH/$tbt_device.key"
        fill_key "${tbt_device}.key" "$tbt_device"
        ;;
      *)
        block_test "Invalid parm:$parm in secure_key function"
        ;;
    esac
  done

  case ${parm} in
    update)
      # update new key should work
      fill_authorized "1" "$pass"
      ;;
    verify)
      # verify saved key should work
      fill_authorized "2" "$pass"
      ;;
    *)
      block_test "Invalid parm:$parm in secure_key function"
      ;;
  esac
}

# Thunderbolt plug in origin status error value fill in authorized check
# No input
# Return: 0 for true, otherwise false or die
authorized_error() {
  local random_num=""
  local random_str=""
  local negative="-1"
  local fail="fail"

  # generate 6 character string
  random_str=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)
  # generate 2-10001 random number
  random_num=$((RANDOM%10000+2))
  fill_authorized "$random_str" "$fail"
  fill_authorized "$random_num" "$fail"
  fill_authorized "$negative" "$fail"
}

# Thunderbolt plug in and access approve test, set 1 to authorized
# No input
# Return: 0 for true, otherwise false or die
user_access_check() {
  local pass="pass"
  local tbt_pci=""
  local nonzero="non-zero"
  fill_authorized "1" "$pass"
  sleep 15
  tbt_pci=$(lspci | grep -i "$MOD_NAME")
  [ -n "$tbt_pci" ] || die "no thunderbolt in lspci:$tbt_pci"

  authorized_check "$nonzero"
  check_tbt_sysfs
  sleep 1
  tbt_ssd_rw_test
}

# Plug out when transfer file to 2.0/3.0/ssd connected with thunderbolt
# Input: $1: protocol type,  $2: device type
# Return: 0 for true, otherwise false or die
po_transfer_file() {
  local protocol=$1
  local device_type=$2
  local block_size="100M"
  local block_count="6"
  local test_file=""
  local origin_state=""

  approve_access
  sleep 5
  topo_tbt_check
  origin_state=$(cat $TOPO_FILE)
  find_tbt_device "$block_size" "$block_count" "$protocol" "$device_type"

  check_free_partition "$block_size" "$block_count"
  [ -e "$TEMP_DIR" ] || block_test "fail to create temporary directory!"
  test_print_trc "TEMP_DIR: $TEMP_DIR"
  test_file=$(generate_test_file "$block_size" "$block_count" "$TEMP_DIR")

  do_cmd "dd if=$test_file of=$DEVICE_NODE bs=$block_size count=$block_count"
  sleep 1
  plug_out_check
  plug_in_tbt
  do_cmd "sleep 15"
  rm -rf "$TEMP_DIR"

  # After plugged in the tbt devcies, should authorize the tbt devices again.
  enable_authorized
  do_cmd "sleep 10"
  check_tbt_sysfs

  test_print_trc "After plug out tbt when transfer file to $protocol topo check"
  topo_compare "$origin_state"

  do_cmd "lsblk"
  # After negative plug out/in check again transfer files pass or not
  tbt_device_rw_test "$block_size" "$block_count" "$protocol" "$device_type"
}

# Plug out and in stress test
# Input: $1 plug out/in times
# Return: 0 for true, otherwise false or die
po_stress_test() {
  local num=$1
  local j=""
  local origin_state=""
  local result_state=""

  topo_tbt_check
  origin_state=$(cat $TOPO_FILE)
  test_print_trc "origin_state:$origin_state!!!"
  for ((j = 1; j <= num; j++)); do
    test_print_trc "***$j round plug out/in thunderbolt test:"
    plug_out_check
    do_cmd "sleep 10"
    plug_in_tbt
    do_cmd "sleep 15"
    check_security_mode
    case $SECURITY in
      none)
        none_mode_test
        #tbt_pci_info
        # check all tbt topo is the same as before hotplug
        topo_compare "$origin_state"
        ;;
      user)
        check_tbt_sysfs
        enable_authorized
        do_cmd "sleep 10"
        topo_compare "$origin_state"
        ;;
      secure)
        secure_mode_test
        enable_authorized
        do_cmd "sleep 10"
        check_tbt_sysfs
        topo_compare "$origin_state"
        ;;
      dponly)
        # dp mode still could use none mode to check
        none_mode_test
        enable_authorized
        check_tbt_sysfs
        topo_compare "$origin_state"
        # dp mode only display port is tunneled, no PCIe tbt, so no lspci check
        ;;
      *)
        die "Error secure mode detect:$SECURITY"
        ;;
    esac

    fail_dmesg_check
  done
}

# thunderbolt add pre boot acl function, check preboot acl file format is right
# Input: none
# Output: 0 for true, otherwise false or die
preboot_acl_check() {
  local regex=","
  local acl_content=""

  [[ -e "$ACL_FILE" ]] || die "No preboot acl file exist:$ACL_FILE"
  acl_content=$(< $ACL_FILE grep $regex)
  if [[ -z "$acl_content" ]]; then
    die "grep $regex is null in $ACL_FILE:$(< $ACL_FILE)"
  else
    test_print_trc "acl content:$acl_content"
  fi
}

# thunderbolt clean boot_acl
# Input: none
# Output: 0 for true, otherwise false or die
acl_clean() {
  local acl_check=""

  [[ -e "$ACL_FILE" ]] || die "No preboot acl file exist:$ACL_FILE"
  acl_check=$(< $ACL_FILE grep $ACL_DEFAULT)
  [[ -n "$acl_check" ]] || do_cmd "echo $ACL_DEFAULT > $ACL_FILE"
  acl_check=$(< $ACL_FILE grep $ACL_DEFAULT)
  [[ -n "$acl_check" ]] || die "clear acl $ACL_FILE fail:$(< $ACL_FILE)"
}

# thunderbolt acl clean, and after plug and unplug, check tbt device status
# Input: none
# Output: 0 for true, otherwise false or die
acl_clean_plug() {
  local zero="zero"
  local nonzero="non-zero"

  acl_clean
  plug_out_check
  plug_in_tbt
  check_security_mode
  case $SECURITY in
    none)
      authorized_check "$nonzero"
      ;;
    user)
      authorized_check "$zero"
      ;;
    secure)
      authorized_check "$zero"
      ;;
    dponly)
      authorized_check "$nonzero"
      ;;
    *)
      block_test "Invalid tbt security mode:$SECURITY"
      ;;
  esac
}

# fill in incorrect string into pre boot acl file
# Input: none
# Output: 0 for true, otherwise false or die
acl_wrong_set() {
  local random_num=""
  local random_str=""
  local negative="-1"
  local error_sample1=",,,,,,,,,,,,,,"
  local error_sample2=",,,,,,,,,,,,,,,,"
  local error_sample3="asfl,,sfa,,asf0"
  local fail="fail"

  random_str=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6)
  random_num=$((RANDOM%10000+2))

  fill_file_in "$ACL_FILE" "$random_num" "$fail"
  fill_file_in "$ACL_FILE" "$random_str" "$fail"
  fill_file_in "$ACL_FILE" "$negative" "$fail"
  fill_file_in "$ACL_FILE" "$error_sample1" "$fail"
  fill_file_in "$ACL_FILE" "$error_sample2" "$fail"
  fill_file_in "$ACL_FILE" "$error_sample3" "$fail"
}

# fill in acl with first one tbt device unique id
# Input: none
# Output: 0 for true, otherwise false or die
acl_set_first() {
  local first_tbt=""
  local first_tbt_uuid=""
  local acl_result=""

  first_tbt=$(ls $TBT_PATH/0-?/unique_id | grep -v "$HOST_EXCLUDE" | tail -1)
  first_tbt_uuid=$(cat "$first_tbt")
  do_cmd "echo '$first_tbt_uuid,,,,,,,,,,,,,,,' > $ACL_FILE"
  acl_result=$(< $ACL_FILE grep "$first_tbt_uuid,,,,,,,,,,,,,,,")
  [[ -n "$acl_result" ]] || die "Set $ACL_FILE fail:$(< $ACL_FILE)"
}

# fill in acl with all tbt device unique id
# Input: none
# Output: 0 for true, otherwise false or die
acl_set_all() {
  local tbt_sys=""
  local device_path=""
  local uuid=""
  local acl_content=""
  local tbt_num=0
  local total=15
  local left=""
  local num=0


  tbt_sys=$(ls -1 ${TBT_PATH} \
            | grep -v "$HOST_EXCLUDE" \
            | grep "$REGEX_ITEM" \
            | awk '{ print length(), $0 | "sort -n" }' \
            | cut -d ' ' -f 2)

  # Reserved for wrong order
  # all_tbt=$(ls $TBT_PATH/0-*/unique_id | grep -v "$HOST_EXCLUDE")
  for device_path in ${tbt_sys}; do
    uuid=$(< "$TBT_PATH"/"$device_path"/unique_id)
    [[ -n "$uuid" ]] || die "uuid is null:$TBT_PATH/$device_path/unique_id"
    acl_content=${acl_content}${uuid}","
    (( tbt_num++ ))
  done
  left=$(( total - tbt_num - 1 ))
  for ((num=1; i <= left; i++)); do
    acl_content=${acl_content}","
  done
  do_cmd "echo $acl_content > $ACL_FILE"
}

# test tbt tools and saved logs
# Input:
#  $1: test_tool name
#  $2: test_tool parameter
# Output:
#  Return saved log path, otherwise false or die
tbt_tool_cmd() {
  local tool=$1
  local par=$2
  local par_name=""

  [ -n "$tool" ] || die "File $tool was not exist"
  [ -n "$par" ] || die "parameter: $par was null"

  par_name=$(echo "$par" | tr ' ' '_')
  if [ "$par_name" == "null" ]; then
    ${tool} > ${LOG_PATH}/${tool}_${par_name}.log
    [[ $? -eq 0 ]] || die "${tool} executed failed"
  else
    ${tool} ${par} > ${LOG_PATH}/${tool}_${par_name}.log
    [[ $? -eq 0 ]] || die "${tool} ${par} executed failed"
  fi
  echo "${LOG_PATH}/${tool}_${par_name}.log"
}

# test tbtadm topolog and check result is as expect
# Input: NA
# Output: Return 0, otherwise false or die
adm_topo_check() {
  local log_path=""
  local topo="topology"
  local key1="Controller"
  local key2="Security"
  local key3="Route-string"

  log_path=$(tbt_tool_cmd "$TBTADM" "$topo")
  [[ $? -eq 0 ]] || block_test "$TBTADM executed failed"
  test_print_trc "$log_path: $(cat "$log_path")"
  grep -q "$key1" "$log_path" || die "No $key1 in $log_path"
  grep -q "$key2" "$log_path" || die "No $key2 in $log_path"
  grep -q "$key3" "$log_path" || die "No $key3 in $log_path"
}

# test tbtadm approve-all and check result is as expect
# Input: NA
# Ouput: Return 0, otherwise false or die
adm_approve_all() {
  local log_path=""
  local approveall="approve-all"
  local nonzero="non-zero"

  log_path=$(tbt_tool_cmd "$TBTADM" "$approveall")
  [[ $? -eq 0 ]] || block_test "$TBTADM executed failed"
  test_print_trc "$log_path: $(cat "$log_path")"
  authorized_check "$nonzero"
}

# test tbtadm devices and check result is as expect
# Input: NA
# Output: Return 0, otherwise false or die
adm_devices() {
  local log_path=""
  local devices="devices"
  local tbt_devices=""
  local tbt_device=""

  log_path=$(tbt_tool_cmd "$TBTADM" "$devices")
  [[ $? -eq 0 ]] || block_test "$TBTADM executed failed"
  test_print_trc "$log_path: $(cat "$log_path")"
  tbt_devices=$(ls -1 $TBT_PATH \
                | grep "$REGEX_ITEM" \
                | grep -v "$HOST_EXCLUDE")

  for tbt_device in ${tbt_devices}; do
    grep -q "$tbt_device" "$log_path" || die "No $tbt_device in $log_path"
  done
  test_print_trc "check $TBTADM $devices pass"
}

# test tbtadm acl and check result is as expect
# Input: NA
# Output: Return 0, otherwise false or die
adm_acl() {
  local log_path=""
  local acl="acl"
  local tbt_devices=""
  local uuid=""
  local unique="unique_id"

  log_path=$(tbt_tool_cmd "$TBTADM" "$acl")
  [[ $? -eq 0 ]] || block_test "$TBTADM executed failed"
  test_print_trc "$log_path: $(cat "$log_path")"
  tbt_devices=$(ls -1 $TBT_PATH \
                | grep "$REGEX_ITEM" \
                | grep -v "$HOST_EXCLUDE")

  for tbt_device in ${tbt_devices}; do
    uuid=$(cat $TBT_PATH/$tbt_device/$unique)
    grep -q "$uuid" "$log_path" || die "No $tbt_device in $log_path"
  done
  test_print_trc "check $TBTADM $acl pass"
}

# test tbtadm remove 0-1 and check result is as expect
# Input: NA
# Output: Return 0, otherwise false or die
adm_remove_first() {
  local log_path=""
  local first=""
  local rm_first=""
  local uuid=""
  local acl_list=""
  local unique="unique_id"

  first=$(ls -1 ${TBT_PATH} \
          | grep "-" \
          | grep -v "$HOST_EXCLUDE" \
          | awk '{ print length(), $0 | "sort -n" }' \
          | head -n 1 \
          | cut -d ' ' -f 2)
  [[ -z "$first" ]] && die "first in ${TBT_PATH} is null:$first"
  rm_first="remove $first"
  log_path=$(tbt_tool_cmd "$TBTADM" "$rm_first")
  [[ $? -eq 0 ]] || block_test "$TBTADM executed failed"
  test_print_trc "$log_path: $(cat "$log_path")"
  uuid=$(cat $TBT_PATH/$first/$unique)
  if [[ -d "$ADM_ACL" ]]; then
    acl_list=$(ls $ADM_ACL | grep $uuid)
  else
    test_print_trc "Platform or mode not support ACL, no $ADM_ACL folder exist"
  fi
  [[ -z "$acl_list" ]] || die "remove first fail, acl_list exist:$acl_list"
}

# test tbtadm remove all and check result is as expect
# Input: NA
# Output: Return 0, otherwise false or die
adm_remove_all() {
  local log_path=""
  local rm_all="remove-all"

  log_path=$(tbt_tool_cmd "$TBTADM" "$rm_all")
  [[ $? -eq 0 ]] || block_test "$TBTADM executed failed"
  test_print_trc "$log_path: $(cat "$log_path")"
  # /var/lib/thunderbolt/acl folder should be removed after remove all
  if [[ -e "$ADM_ACL" ]]; then
    die "remove all, folder still exist:$ADM_ACL"
  fi
}

# check tbt host controller power control should be set to auto automatically
# Input: NA
# Output: Return 0, otherwise false or die
rtd3_init(){
  host_power_content=""

  [[ -e "$HOST_POWER" ]] || block_test "No $HOST_POWER exist"
  host_power_content=$(cat $HOST_POWER)
  if [[ "$host_power_content" == "$AUTO" ]]; then
    test_print_trc "$HOST_POWER set to $AUTO, correct"
  else
    die "$HOST_POWER state was not auto:$host_power_content"
  fi
}

# check pci is related tbt or not, and show type, power control, runtime status
# and present real status
# Input:
# $1: tbt root pci bus to check pci is related with tbt
# $2: par if set "all" show all pci, else will only show tbt pci info
# Output: Return 0, otherwise false or die
pci_tbt_check() {
  local root_pci=$1
  local par=$2
  local tbt=""
  local pci_list=""
  local pci=""
  local pci_info=""
  local control=""
  local run_status=""
  local pci_type=""
  local real_status=""
  local port_status=""
  local pci_content=""

  # clear old PCI_LOG before fill new PCI_LOG
  cat "/dev/null" > $PCI_LOG
  pci_list=$(ls $PCI_PATH)

  # tbt root pci status will be impacted by lspci, so check it first
  root_real_status=$(cat "$PCI_PATH"/"$root_pci"/"$FIRM_POWER" 2>/dev/null)
  root_port_status=$(cat "$PCI_PATH"/"$root_pci"/"$PORT_POWER" 2>/dev/null)
  root_run_status=$(cat "$PCI_PATH"/"$root_pci"/"$RUNTIME_STATUS")
  root_control=$(cat "$PCI_PATH"/"$root_pci"/"$POWER_CONTROL")
  test_print_trc "root pci $root_pci real status:$root_real_status"

  for pci in ${pci_list}; do
    # real_status need init to null in loop to avoid wrong judgement
    real_status=""
    port_status=""
    # set non-tbt as default in for loop for each pci check
    tbt="non-tbt"

    if [[ "$pci" == "$root_pci" ]]; then
      real_status="$root_real_status"
      port_status="$root_port_status"
      run_status="$root_run_status"
      control="$root_control"
    else
      [[ -e "${PCI_PATH}/${pci}/${POWER_CONTROL}" ]] \
        && control=$(cat "$PCI_PATH"/"$pci"/"$POWER_CONTROL")
      [[ -e "${PCI_PATH}/${pci}/${RUNTIME_STATUS}" ]] \
        && run_status=$(cat "$PCI_PATH"/"$pci"/"$RUNTIME_STATUS")

      # due to if D3 cold, could not get the correct status.
      # so need check $PCI_PATH/pci_busXX:XX/power/firmware_node/power_state
      [[ -e "${PCI_PATH}/${pci}/${FIRM_POWER}" ]] && {
        real_status=$(cat "$PCI_PATH"/"$pci"/"$FIRM_POWER" 2>/dev/null)
        port_status=$(cat "$PCI_PATH"/"$pci"/"$PORT_POWER" 2>/dev/null)
      }
      [[ "$real_status" == "$port_status" ]] || \
        test_print_wrg "root pci D3 different,real:$real_status, port:$port_status"

      # if could not get real_status, then check lspci way to get status
      [[ -z "$real_status" ]] \
          && real_status=$(lspci -vv -s "$pci" 2> /dev/null \
                            | grep Status \
                            | grep "PME-" \
                            | cut -d ' ' -f 2)
    fi
    pci_type=$(lspci -v -s "$pci" 2> /dev/null \
                 | grep "Kernel driver in use:" \
                 | awk -F "in use: " '{print $2}')

    pci_content=$(ls -ltra "$PCI_PATH"/"$pci")
    # check pci which contain root_pci pci
    if [[ -n "$root_pci" ]]; then
      # check pci_content which contain root_pci, which is related with tbt
      [[ "$pci_content" == *"$root_pci"* ]] && tbt="tbt"
      # if $pci is the same as root_pci, which confirm it's root tbt pci
      [[ "$pci" == "$root_pci" ]] && tbt="tbt_root"
    else
      block_test "root_pci is null:$root_pci"
    fi

    if [[ "$par" == "all" ]]; then
      test_print_trc "Show all pci info in $PCI_LOG"
    else
      [[ "$tbt" == "non-tbt" ]] && continue
    fi

    # fill in NA if could not get value in some special pci
    [[ -z "$pci_type" ]] && pci_type="NA"
    [[ -z "$control" ]] && control="NA"
    [[ -z "$run_status" ]] && run_status="NA"
    [[ -z "$real_status" ]] && real_status="NA"

    # use printf to set formular format, could not change line
    pci_info=$(printf "$pci->%-8s TYPE:%-18s CONTROL:%-12s runtime_status:%-12s real_status:%-12s\n" \
                "$tbt" "$pci_type" "$control" "$run_status" "$real_status")
    echo "$pci_info" >> $PCI_LOG

    # set auto for root_pci power control
    if [[ -n "$root_pci" ]]; then
      [[ "$pci" == "$root_pci" ]] \
        && echo "$AUTO" > "$PCI_PATH"/"$pci"/"$POWER_CONTROL"
    fi
    # tbt xhci and ahci could not set power control to auto as default
    # so set auto for tbt related pci xhci and ahci power control
    if [[ "$control" == "on" ]]; then
      [[ "$tbt" == "tbt" ]] && {
        [[ "$pci_type" == *"hci"* ]] \
          && echo "$AUTO" > "$PCI_PATH"/"$pci"/"$POWER_CONTROL"
      }
    fi
  done
  do_cmd "cat $PCI_LOG"
}

# tbt device plugged, host controller power control should be access
# in D3 after idle 25s
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_host_d3() {
  local root_pci=$1
  local tbt_host_power=""
  local tbt_host_state=""

  rtd3_init
  if [[ -e "$ACL_FILE" ]]; then
    do_cmd "cat $ACL_FILE"
    do_cmd "lspci -t"
  else
    do_cmd "echo $ON > $HOST_POWER"
    do_cmd "echo $AUTO > $HOST_POWER"
    do_cmd "lspci -t"
  fi
  test_print_trc "sleep 25"
  sleep 25

  pci_tbt_check "$root_pci"
  [[ -e "$PCI_LOG" ]] || die "No file $PCI_LOG exist"

  tbt_host_power=$(cat $PCI_LOG | grep "$TBT_ROOT")
  [[ -z "$tbt_host_power" ]] \
    && die "pci $MOD_NAME not set auto:$tbt_host_power"

  tbt_host_state=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D3")
  test_print_trc "host idle 25s, tbt_host_state:$tbt_host_state"
  [[ -n "$tbt_host_state" ]] || die "pci $TBT_ROOT not in $D3 after idle 25s"
}

# make tbt host in busy state, host pci should in D0, after idle 25s,
# host pci should be back to D3
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_host_busy() {
  local root_pci=$1
  local tbt_host_state=""

  rtd3_init
  do_cmd "echo '$ON' > '$HOST_POWER'"
  pci_tbt_check "$root_pci"
  tbt_host_state=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D0")
  test_print_trc "host busy, tbt_host_state:$tbt_host_state"
  do_cmd "echo '$AUTO' > '$HOST_POWER'"
  [[ -n "$tbt_host_state" ]] || die "host busy, $TBT_ROOT not in $D0"
  rtd3_host_d3 "$root_pci"
}

# set tbt power control to on, host pci should always in D0, set back auto
# for tbt power control, host pci could be in D3 after idle 25s
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_host_on() {
  local root_pci=$1
  local tbt_host_state=""

  rtd3_init
  do_cmd "echo '$ON' > '$HOST_POWER'"
  sleep 25
  pci_tbt_check "$root_pci"
  tbt_host_state=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D0")
  test_print_trc "host on, tbt_host state:$tbt_host_state"
  [[ -n "$tbt_host_state" ]] || die "host $TBT_ROOT set on, not in $D0"

  do_cmd "echo '$AUTO' > '$HOST_POWER'"
  rtd3_host_d3 "$root_pci"
}

# set tbt host xhci bus to auto, xhci tbt bus should in D3 after 25s idle
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_xhci() {
  local root_pci=$1
  local xhci=""
  local xhci_state=""

  rtd3_init
  enable_authorized
  sleep 2

  # set tbt xhci power control to auto
  pci_tbt_check "$root_pci"
  sleep 25
  # check xhci power state after idle 25s
  pci_tbt_check "$root_pci"
  xhci=$(cat $PCI_LOG | grep "$TBT" | grep "$XHCI")
  [[ -z "$xhci" ]] && skip_test "No tbt xhci exist in $root_pci"

  xhci_state=$(cat $PCI_LOG | grep "$TBT" | grep "$XHCI" | grep "$D3")
  test_print_trc "xhci state:$xhci_state"
  [[ -n "$xhci_state" ]] || die "tbt xhci not in D3 state"
}

# unload thunderbolt driver, tbt host should be in D0
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_host_unload_driver() {
  local root_pci=$1
  local tbt_host_pci=""
  local tbt_host_d0=""

  rtd3_init
  pci_tbt_check "$root_pci"
  load_unload_module.sh -c -d "$MOD_NET_NAME" \
    && load_unload_module.sh -u -d "$MOD_NET_NAME"
  load_unload_module.sh -c -d "$MOD_NAME" \
    && load_unload_module.sh -u -d "$MOD_NAME"
  pci_tbt_check "$root_pci"
  tbt_host_d0=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D0")
  test_print_trc "Unload $MOD_NAME, tbt_host:$tbt_host_d0"
  [[ -n "$tbt_host_d0" ]] \
    || die "unload $MOD_NAME, host not in $D0:$tbt_host_d0"
}

# load thunderbolt driver, tbt host should be in D0 at first, after load tbt
# ready and idle 25s later, tbt host should be in D3
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_host_load_driver() {
  local root_pci=$1
  local tbt_host_pci=""
  local tbt_host_state=""

  rtd3_init
  pci_tbt_check "$root_pci"
  load_unload_module.sh -c -d "$MOD_NET_NAME" \
    && load_unload_module.sh -u -d "$MOD_NET_NAME"
  load_unload_module.sh -c -d "$MOD_NAME" \
    && load_unload_module.sh -u -d "$MOD_NAME"
  sleep 5
  load_unload_module.sh -l -d "$MOD_NAME"
  sleep 2
  pci_tbt_check "$root_pci"
  tbt_host_state=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D0")
  test_print_trc "Load $MOD_NAME, tbt_host_state:$tbt_host_state"
  [[ -n "$tbt_host_state" ]] \
    || die "load $MOD_NAME, host not in $D0:$tbt_host_d0"
  sleep 5
  rtd3_host_d3 "$root_pci"
}

# tbt host resume from freeze/mem/disk, should be in D0 first, then in D3
# after idle 25s
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_host_sleep() {
  local root_pci=$1
  local sleep_type=$2
  local rtc_time=30
  local tbt_host_state=""
  local deep="deep"

  case $sleep_type in
    freeze)
      do_cmd "rtcwake -m $sleep_type -s $rtc_time"
      ;;
    mem)
      test_print_trc "set $sleep_type in $POWER_MEM_SLEEP"
      do_cmd "echo '$deep' > $POWER_MEM_SLEEP"
      do_cmd "rtcwake -m $sleep_type -s $rtc_time"
      ;;
    disk)
      do_cmd "rtcwake -m $sleep_type -s $DISK_TIME"
      ;;
    *)
      block_test "Invalid parameter for sleep_type:$sleep_type"
      ;;
  esac
  sleep 1
  pci_tbt_check "$root_pci"
  tbt_host_state=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D0")
  test_print_trc "$sleep_type sleep, tbt_host_state:$tbt_host_state"
  [[ -n "$tbt_host_state" ]] \
    || test_print_wrg "after $sleep_type 1s, host not in $D0:$tbt_host_d0"
  sleep 5
  rtd3_host_d3 "$root_pci"
}

# tbt host shoud be in D0 when plug in tbt device moment
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_plugin_host() {
  local root_pci=$1
  local tbt_host_state=""

  pci_tbt_check "$root_pci"
  tbt_host_state=$(cat $PCI_LOG | grep "$TBT_ROOT" | grep "$D0")
  test_print_trc "Plug in tbt_host_state:$tbt_host_state"
  [[ -n "$tbt_host_state" ]] \
    || die "plug in tbt moment, host not in $D0:$tbt_host_d0"
}

# set ahci auto save power mode, after plug/unplug ahci in tbt will set back
# default power on mode, so no need teardown
# Input:
#   $1: set n seconds ilde then auto in D3, like 15
#   $2: which disk ahci need set, like sdb which is ahci device
# Output: Return 0, otherwise false or die
set_ahci_power_auto() {
  local timeout=$1
  local disk=$2
  # Max every 10 minutes flush dirty pages
  local flush=600
  local sata_pci=""
  local scsi_host="/sys/class/scsi_host"
  local power_policy="link_power_management_policy"
  local min="min_power"
  local pci_devices="/sys/bus/pci/devices"
  local block="/sys/block"
  local delay_file="device/power/autosuspend_delay_ms"
  local writeback="/proc/sys/vm/dirty_writeback_centisecs"
  local expire="/proc/sys/vm/dirty_expire_centisecs"
  local laptop_mode="/proc/sys/vm/laptop_mode"

  sata_pci=$(lspci -D | grep "SATA controller" | cut -f 1 -d ' ')
  # See Documentation/laptops/laptop-mode.txt for more information about the
  # following tunables.
  do_cmd "echo $((flush * 100)) > $writeback"
  do_cmd "echo $((flush * 100)) > $expire"
  # Enable laptop mode
  do_cmd "echo 5 > $laptop_mode"

  # Enable link power management for all SATA links
  for host in $scsi_host/host*; do
    if [ -e "$host/$power_policy" ]; then
      do_cmd "echo '$min' > $host/$power_policy"
    fi
  done

  for host in $sata_pci; do
    # Enable runtime PM for all ports
    for port in $pci_devices/$host/ata*; do
      do_cmd "echo '$AUTO' > $port/power/control"
    done
    # The for the host
    do_cmd "echo '$AUTO' > $pci_devices/$host/power/control"
  done

  # And last for the disk
  do_cmd "echo '$AUTO' > $block/$disk/device/power/control"
  do_cmd "echo $((timeout * 1000)) > $block/$disk/$delay_file"
  test_print_trc "Enabled autosuspend for $disk ready!"
}


# plug in ahci in tbt, set auto power control, ahci should in D3 after
# idle 30s, when transfer file to ahci in tbt, it will be in D0
# Input: tbt root_pci bus
# Output: Return 0, otherwise false or die
rtd3_plugin_ahci() {
  local root_pci=$1
  local block_size="1MB"
  local block_count=1
  local ssd="ssd"
  local timeout="15"
  local test_file=""
  local ahci=""
  local ahci_state=""

  # Block rw test in dp only mode
  check_security_mode
  if [[ "$SECURITY" == "dponly" ]]; then
    block_test "dponly mode, could not read write test"
  fi

  enable_authorized
  sleep 2
  # find sata device connected with tbt
  find_tbt_device "$block_size" "$block_count" "$ssd"

  set_ahci_power_auto "15" "$NODE"
  do_cmd "sleep 25"
  pci_tbt_check "$root_pci"
  ahci=$(cat $PCI_LOG | grep "$AHCI")
  [[ -n "$ahci" ]] || die "Could not detect ahci:$ahci"

  ahci_state=$(cat $PCI_LOG | grep "$AHCI" | grep "$D3")
  test_print_trc "ahci_state:$ahci_state"
  [[ -n "$ahci_state" ]] || die "ahci not in $D3"

  # skip rw test in dp only mode
  check_security_mode
  if [[ "$SECURITY" == "dponly" ]]; then
    test_print_trc "dponly mode, skip read write ahci D0 check"
  else
    tbt_ssd_rw_test
    # check set auto ahci, if transfer file it will goes to D0
    pci_tbt_check "$root_pci"
    ahci=$(cat $PCI_LOG | grep "$AHCI")
    [[ -n "$ahci" ]] || die "Could not detect ahci:$ahci"

    ahci_state=$(cat $PCI_LOG | grep "$AHCI" | grep "$D0")
    test_print_trc "Transfer file, ahci_state:$ahci_state"
    [[ -n "$ahci_state" ]] || die "transfer file, ahci not in $D0"
  fi
  # after transfer finished 45s later, ahci should be back to D3
  sleep 45
  pci_tbt_check "$root_pci"
  ahci=$(cat $PCI_LOG | grep "$AHCI")
  [[ -n "$ahci" ]] || die "Could not detect ahci:$ahci"

  ahci_state=$(cat $PCI_LOG | grep "$AHCI" | grep "$D3")
  test_print_trc "Transfer to idle 30s, ahci_state:$ahci_state"
  [[ -n "$ahci_state" ]] || die "ahci not in $D3"
}

# Check usb docking only mode, security should be set as usbonly
usb_basic_check()
{
  local usbonly="usbonly"

  check_security_mode
  if [[ "$SECURITY" == "$usbonly" ]]; then
    test_print_trc "It's $SECURITY mode, pass"
  esle
    die "It's $SECURITY mdoe, should set to $usbonly to test usb only mode"
  fi
}

# Find ssd connected by tbt, and save NODE and DEVICE_NODE
# Input: null
# Return 0 for true, otherwise return 1
find_tbt_ssd() {
  local device=""
  local dev_node=""

  DEVICES=$(lsblk -d -o name,rota | grep sd | grep 0 | awk '{print $1}')
  test_print_trc "Find ssd:$DEVICES, next check them connect with tbt"

  for device in ${DEVICES}; do
    get_tbt_pci
    check_tbt_connect "$device" "$TBT_PCI" || continue
    dev_node="$device"
    break
  done
  [ -n "$dev_node" ] || {
    test_print_trc "No ssd connect with tbt found"
    return 1
  }
  test_print_trc "Find ssd connect with tbt: $dev_node"
  NODE="$dev_node"
  DEVICE_NODE="/dev/$dev_node"
  return 0
}

# Transfer storage connected by tbt
# Input:
#   $1: block_size like 1MB/100MB
#   $2: block_count like 100
#   $3: protocol type like 2.0/3.0/ssd
#   $4: device type like flash/uas
# Return 0 for true, otherwise return 1
tbt_transfer() {
  local block_size=$1
  local block_count=$2
  local protocol_type=$3
  local device_type=$4

  check_auto_connect
  check_test_env
  check_free_partition "$block_size" "$block_count"

  check_security_mode
  [[ "$SECURITY" == "dponly" ]] \
    && block_test "dponly mode, could not read write test"
  enable_authorized
  sleep 5
  find_tbt_device "$block_size" "$block_count" "$protocol_type" "$device_type"
  [[ -n "$DEVICE_NODE" ]] \
    || die "No $protocol_type $device_type node:$DEVICE_NODE"

  [[ -e "$TEMP_DIR" ]] || block_test "fail to create temporary directory!"
  test_print_trc "TEMP_DIR: $TEMP_DIR"
  test_file=$(generate_test_file "$block_size" "$block_count" "$TEMP_DIR")

  mount_dev "$DEVICE_NODE" "$MOUNT_FOLDER"
  write_test_with_file "$RW_FILE" "$test_file" "$block_size" "$block_count"
  read_test_with_file "$RW_FILE" "$test_file" "$block_size" "$block_count"
  rm -rf "$TEMP_DIR"
}

# Check tbt support VT-d function or not on this platform
# Input: NA
# Return 0 for true, means support, otherwise return 1
vtd_support_check() {
  local result=""

  [[ -e "$TBT_DMA_FILE" ]] || {
    test_print_trc "old platform, no file $TBT_DMA_FILE, not support tbt vtd"
    return 1
  }
  result=$(cat $TBT_DMA_FILE)
  if [[ "$result" == "$ENABLE" ]]; then
    test_print_trc "Support tbt VT-d"
    return 0
  else
    test_print_trc "Not support tbt VT-d"
    return 1
  fi
}

# Check user/secure mode, tbt VT-d, user mdoe will be auto authorized
# Input: NA
# Return 0 for true, otherwise false or die
vtd_auto_authorized() {
  nonzero="non-zero"

  plug_out_check
  check_auto_connect
  authorized_check "$nonzero"
}

# Check dmesg log contain matached content or not
# Input: $1 enable for iommu enble, disable for iommu disable
# Return 0 for true, otherwise false or die
dmesg_verify() {
  local state="$1"
  local file_path="/tmp/tbt_whole_dmesg.txt"
  local swcm_info="ICM not supported"
  local new_swcm_info="OS controls USB3"
  local iommu_enable="DMAR: IOMMU enabled"
  local iommu_disable="DMAR: IOMMU disabled"
  local iommu="DMAR: IOMMU"
  local iommu_state=""
  local iommu_key="DMAR: Intel(R) Virtualization Technology for Directed I/O"
  local iommu_act="iommu: Adding device"
  local check_info=""

  do_cmd "dmesg > $file_path"
  case ${state} in
    vtd_enable)
      dmesg_check "$file_path" "$iommu_enable" "$PASS"
      dmesg_check "$file_path" "$iommu_key" "$PASS"
      dmesg_check "$file_path" "$iommu_act" "$PASS"
      ;;
    iommu_verify)
      iommu_state=$(cat $file_path | grep "$iommu")
      [[ -n "$iommu_state" ]] || block_test "Didn't find $iommu in $file_path"
      iommu_state=$(cat $file_path | grep "$iommu_enable")
      if [[ -n "$iommu_state" ]]; then
        test_print_trc "iommu enabled"
        dmesg_check "$file_path" "$iommu_key" "$PASS"
        dmesg_check "$file_path" "$iommu_act" "$PASS"
      else
        test_print_trc "iommu disabled"
        dmesg_check "$file_path" "$iommu_disable" "$PASS"
        dmesg_check "$file_path" "$iommu_key" "$FAIL"
        dmesg_check "$file_path" "$iommu_act" "$FAIL"
      fi
      ;;
    swcm_verify)
      check_info=$(cat $file_path | grep -i "$swcm_info")
      if [[ -z "$check_info" ]]; then
        check_info=""
        check_info=$(cat $file_path \
                    | grep -i "USB4" \
                    | grep -i "$new_swcm_info")
        if [[ -z "$check_info" ]]; then
          die "No $swcm_info and $new_swcm_info in dmesg, not SWCM mode!"
        else
          test_print_trc "Dmesg contains $new_swcm_info:$check_info, pass."
        fi
      else
        test_print_trc "Dmesg contains $swcm_info:$check_info, pass."
      fi
      ;;
    *)
      block_test "Invalid state:$state"
      ;;
  esac
}

# test tbt storage by msc tool
# Input: $1 dev node for target test
#        $2 save result into target file
# Return 0 for true, otherwise false or die
tbt_perf_test() {
  local dev=$1
  local file=$2
  local temp_file="$LOG_PATH/temp.txt"
  local msc_bin="ddt_intel/usb/msc"
  local test_size="1 2 3 5 31 61 64 127 512 523"
  local test="test"
  local prime=""
  local node="/dev/$dev"
  local size=""

  # backup exist file, if execute command unexpectedly in second time
  [[ -e "$file" ]] && do_cmd "cp -rf $file ${file}_bak"
  do_cmd "cat /dev/null > $file"
  do_cmd "cat /dev/null > $temp_file"
  for prime in $test_size; do
    do_cmd "$msc_bin -t 0 -s ${prime}k -c 1024 -o $node -n >> $temp_file"
  done

  do_cmd "cat $temp_file | awk -F $test '{print \$NF}' > $file"
  size=$(lsblk | grep "$dev" | awk -F ' ' '{print $4}')
  echo "Kernel:$(uname -r)" >> $file
  echo "${SIZE}:${size}" >> $file
  echo "${file}:$DMESG_VERIFY:$KEY_WORD" >> $file
  do_cmd "cat $file"
}

# verify tbt perf nobounce better than nobounce strict, and bounce performance
# otherwise faile the case, and gave the average gap percentage
# Input: $1 nobounce data
#        $2 nobounce and strict data
#        $3 bounce data
#        $4 2.0/3.0/ssd
# Generate CSV file, return 0 for true, otherwise false or die
verify_perf_result() {
  local nb=$1
  local nbs=$2
  local bounce=$3
  local tp=$4
  local infos=""
  local info=""
  local rb_value=""
  local rnb_value=""
  local rnbs_value=""
  local wb_value=""
  local wnb_value=""
  local wnbs_value=""
  local rb_total=0
  local rnb_total=0
  local rnbs_total=0
  local wb_total=0
  local wnb_total=0
  local wnbs_total=0
  local rnb_gap=""
  local rb_gap=""
  local rnb_gap_rate=""
  local rb_gap_rate=""
  local wb_gap=""
  local wnb_gap=""
  local wnb_gap_rate=""
  local rb_gap_rate=""
  local head=""
  local read_file="${LOG_PATH}/read_iommu_${tp}.CSV"
  local write_file="${LOG_PATH}/write_iommu_${tp}.CSV"
  local num=0
  local read_line=""
  local write_line=""
  local block=""
  local block_info=""
  local read="read"
  local mb="MB"
  local write="write"
  local result=""
  local size_info=""
  local max="0.05"
  local min="-0.1"

  infos=$(cat $nb \
         | awk -F 'sent' '{print $2}' \
         | awk -F 'MB' '{print $1}')

  size_info=$(cat $nb | grep "$SIZE")

  do_cmd "echo $(uname -r) > $read_file"
  do_cmd "echo $(uname -r) > $write_file"
  head="${tp}:${size_info}, nobounce\(MB/s\), nobounce_strict\(MB/s\), bounce\(MB/s\)"
  do_cmd "echo $head >> $read_file"
  do_cmd "echo $head >> $write_file"

  for info in ${infos}; do
    num=$((num+1))
    block="${info}k*1024"
    block_info=" $info MB"
    rb_value=$(cat $bounce \
              | grep "$block_info" \
              | awk -F $read '{print $2}' \
              | awk -F $mb '{print $1}')
    rnb_value=$(cat $nb \
              | grep "$block_info" \
              | awk -F $read '{print $2}' \
              | awk -F $mb '{print $1}')
    rnbs_value=$(cat $nbs \
                | grep "$block_info" \
                | awk -F $read '{print $2}' \
                | awk -F $mb '{print $1}')
    read_line=""
    read_line=$(printf "%-13s  read,%-10s, %-9s, %14s" \
                "$block" "$rnb_value" "$rnbs_value" "$rb_value")
    rb_total=$(printf "%.2f" $(echo "scale=2;$rb_total + $rb_value" | bc))
    rnb_total=$(printf "%.2f" $(echo "scale=2;$rnb_total + $rnb_value" | bc))
    rnbs_total=$(printf "%.2f" $(echo "scale=2;$rnbs_total + $rnbs_value" | bc))
    echo "$read_line" >> $read_file

    wb_value=$(cat $bounce \
              | grep "$block_info" \
              | awk -F $write '{print $2}' \
              | awk -F $mb '{print $1}')
    wnb_value=$(cat $nb \
              | grep "$block_info" \
              | awk -F $write '{print $2}' \
              | awk -F $mb '{print $1}')
    wnbs_value=$(cat $nbs \
                | grep "$block_info" \
                | awk -F $write '{print $2}' \
                | awk -F $mb '{print $1}')
    write_line=""
    write_line=$(printf "%-13s write,%-10s, %-9s, %14s" \
                  "$block" "$wnb_value" "$wnbs_value" "$wb_value")
    wb_total=$(printf "%.2f" $(echo "scale=2;$wb_total + $wb_value" | bc))
    wnb_total=$(printf "%.2f" $(echo "scale=2;$wnb_total + $wnb_value" | bc))
    wnbs_total=$(printf "%.2f" $(echo "scale=2;$wnbs_total + $wnbs_value" | bc))
    echo "$write_line" >> $write_file
  done

  test_print_trc "sample num:$num"
  rb_total=$(printf "%.3f" $(echo "scale=3;$rb_total/$num" | bc))
  rnb_total=$(printf "%.3f" $(echo "scale=3;$rnb_total/$num" | bc))
  rnbs_total=$(printf "%.3f" $(echo "scale=3;$rnbs_total/$num" | bc))

  rb_gap=$(printf "%.3f" $(echo "scale=3;$rb_total - $rnb_total" | bc))
  rb_gap_rate=$(printf "%.4f" $(echo "scale=4;$rb_gap/$rnb_total" | bc))

  rnb_gap=$(printf "%.3f" $(echo "scale=3;$rnbs_total - $rnb_total" | bc))
  rnb_gap_rate=$(printf "%.4f" $(echo "scale=4;$rnb_gap/$rnb_total" | bc))

  echo "$tp read nobounce        average MB/s:$rnb_total" >> $read_file
  echo "$tp read nobounce strict average MB/s:$rnbs_total" >> $read_file
  echo "$tp read bounce          average MB/s:$rb_total" >> $read_file
  echo "$tp read nobounce and nb strict gap rate: $rnb_gap_rate" >> $read_file
  echo "$tp read nobounce and bounce gap rate:$rb_gap_rate" >> $read_file

  wb_total=$(printf "%.3f" $(echo "scale=3;$wb_total/$num" | bc))
  wnb_total=$(printf "%.3f" $(echo "scale=3;$wnb_total/$num" | bc))
  wnbs_total=$(printf "%.3f" $(echo "scale=3;$wnbs_total/$num" | bc))

  wb_gap=$(printf "%.3f" $(echo "scale=3;$wb_total - $wnb_total" | bc))
  wb_gap_rate=$(printf "%.4f" $(echo "scale=4;$wb_gap/$wnb_total" | bc))

  wnb_gap=$(printf "%.3f" $(echo "scale=3;$wnbs_total - $wnb_total" | bc))
  wnb_gap_rate=$(printf "%.4f" $(echo "scale=4;$wnb_gap/$wnb_total" | bc))

  echo "$tp write nobounce        average MB/s:$wnb_total" >> $write_file
  echo "$tp write nobounce strict average MB/s:$wnbs_total" >> $write_file
  echo "$tp write bounce          average MB/s:$wb_total" >> $write_file
  echo "$tp write nobounce and nb strict gap rate: $wnb_gap_rate" >> $write_file
  echo "$tp write nobounce and bounce gap rate:$wb_gap_rate" >> $write_file

  do_cmd "cat $read_file"
  do_cmd "cat $write_file"

  result=$(echo "$rb_gap_rate <= $max " | bc)
   [[ "$result" -eq 1 ]] || die "rb_gap_rate greater than $max:$rb_gap_rate"
  result=$(echo "$rb_gap_rate > $min " | bc)
  [[ "$result" -eq 1 ]] || die "rb_gap_rate loss more than $min:$rb_gap_rate"

  result=$(echo "$wb_gap_rate <= $max " | bc)
  [[ "$result" -eq 1 ]] || die "wb_gap_rate greater than $max:$wb_gap_rate"
  result=$(echo "$wb_gap_rate > $min " | bc)
  [[ "$result" -eq 1 ]] || die "wb_gap_rate loss more than $min:$wb_gap_rate"
}

# verify tbt nvmem content could be read and copied, and nvmem content
# should be the same after read and copied
# Input: NA
# Return 0 for true, otherwise false or die
tbt_nvmem_check() {
  local tbt_rp_nvm="/sys/bus/thunderbolt/devices/0-0/nvm_active0/nvmem"
  local origin_sha=""
  local tmp_sha=""
  local nvm_file=""

  nvm_file=$(ls ${TBT_HOST_PATH} | grep nvm)
  [[ -n "$nvm_file" ]] \
    || skip_test "Skip nvmem check due to sw cm mode, no nvm file:$nvm_file"
  do_cmd "dd if=$tbt_rp_nvm  of=$TBT_NVM_FILE"
  origin_sha=$(sha256sum $tbt_rp_nvm | cut -d ' ' -f 1)
  tmp_sha=$(sha256sum $TBT_NVM_FILE | cut -d ' ' -f 1)

  if [[ "$origin_sha" == "$tmp_sha" ]]; then
    test_print_trc "$tbt_rp_nvm read passed, sha256sum same:$origin_sha"
  else
    die "$tbt_rp_nvm:$origin_sha was not same as $TBT_NVM_FILE:$tmp_sha"
  fi
}

# Veirify tbt sysfs folder exist in /sys/bus/thunderbolt/devices/
# Input: NA
# Return 0 for true, otherwise false or die
check_tbt_dir() {
  local dir_name=$1

  [[ -d "$TBT_PATH/$dir_name" ]] \
    || die "$dir_name was not a folder or exist in $TBT_PATH"
  do_cmd "ls -ltrha $TBT_PATH/$dir_name"
}

# Veirify tbt matched domain and root port used same pci bus
# Input: NA
# Return 0 for true, otherwise false or die
dual_pci_verify() {
  local rp0_pci=""
  local domain0_pci=""
  local rp1_pci=""
  local domain1_pci=""

  domain0_pci=$(ls -ltrha $TBT_PATH/$DOMAIN0 \
              | awk -F '/'  '{print $(NF-1)}')
  rp0_pci=$(ls -ltrha $TBT_PATH/$RP0 \
          | awk -F '/' '{print $(NF-2)}')
  [[ "$domain0_pci" == "$rp0_pci" ]] \
    || die "$DOMAIN0:$domain0_pci and $RP0:$rp0_pci not same"

  domain1_pci=$(ls -ltrha $TBT_PATH/$DOMAIN1 \
              | awk -F '/'  '{print $(NF-1)}')
  rp1_pci=$(ls -ltrha $TBT_PATH/$RP1 \
          | awk -F '/' '{print $(NF-2)}')
  [[ "$domain1_pci" == "$rp1_pci" ]] \
    || die "$DOMAIN1:$domain1_pci and $RP1:$rp1_pci not same"
  test_print_trc "$RP0 PCI:$rp0_pci and $RP1 PCI:$rp1_pci pass"
}

# Check dual controller secure mode, and should set same secure mode
# Input: NA
# Return 0 for true, otherwise false or die
dual_secure_verify() {
  local domain0_secure=""
  local domain1_secure=""

  domain0_secure=$(cat $TBT_PATH/$DOMAIN0/security)
  domain1_secure=$(cat $TBT_PATH/$DOMAIN1/security)
  if [[ "$domain0_secure" == "$domain1_secure" ]]; then
    test_print_trc "Both controller security:$domain0_secure pass"
  else
    die "$DOMAIN0 security:$domain0_secure, $DOMAIN1 security:$domain1_secure"
  fi
}

# mound device node to target folder
# otherwise faile the case, and gave the average gap percentage
# Input: $1 device node like /dev/sdc
#        $2 mount target
# Return 0 for true, otherwise false or die
mount_dev() {
  local dev_name=$1
  local mount_folder=$2
  local mount_result=""
  local node=""

  [[ -n "$mount_folder" ]] || {
    test_print_trc "no mount_folder:$mount_folder set to $MOUNT_FOLDER"
    mount_folder=$mount_folder
  }
  [[ -n "$dev_name" ]] || {
    test_print_trc "no dev_name:$dev_name set to $DEVICE_NODE"
    dev_name=$DEVICE_NODE
  }

  [[ -d "$mount_folder" ]] || {
    test_print_trc "mount_folder $mount_folder is not exist, create it"
    do_cmd "rm -rf $mount_folder"
    do_cmd "mkdir -p $mount_folder"
  }

  node=$(echo "$dev_name" | awk -F '/' '{printf $NF}')
  [[ -n "$node" ]] || block_test "node is null:$node, dev_name:$dev_name"
  mount_result=$(lsblk | grep "$node" | grep "$mount_folder" 2>/dev/null)
  if [[ -n "$mount_result" ]]; then
    test_print_trc "node $node in $dev_name already mount to $mount_folder"
  else
    umount -f $mount_folder 2>/dev/null
    test_print_trc "mount $dev_name $mount_folder"
    mount $dev_name $mount_folder
    [[ $? -eq 0 ]] || {
      test_print_trc "Bad superblock on $dev_name, will format and remount"
      do_cmd "mkfs.ext4 -F $dev_name"
      do_cmd "mount $dev_name $mount_folder"
    }
  fi
  test_print_trc "$DEVICE_NODE"
  do_cmd "lsblk"
}

# Record the swap partition node and then swapoff swap partition
# Input: NA
# Return 0 for true, otherwise false or die
swapoff_partition() {
  SWAP_PARTITION=$(swapon | grep dev | cut -d " " -f 1 2>/dev/null)
  if [[ -z "$SWAP_PARTITION" ]]; then
    test_print_wrg "No swap partition node:$SWAP_PARTITION, will not swapoff -a"
  else
    do_cmd "swapoff -a"
  fi
}

# swapon swap partition by recorded swap partition node
# Input: NA
# Return 0 for true, otherwise false or die
swapon_partition() {
  local swap_check=""

  swap_check=$(swapon | grep dev | cut -d " " -f 1 2>/dev/null)

  if [[ -z "$SWAP_PARTITION" ]]; then
    test_print_wrg "No swap partition node:$SWAP_PARTITION, will swapon -a"
    [[ -z "$swap_check" ]] || test_print_wrg "Already exist swap:$swap_check"
    do_cmd "swapon -a"
  else
    [[ "$swap_check" == "$SWAP_PARTITION" ]] && {
      test_print_wrg "swap:SWAP_PARTITION already swapon, do nothing."
      return 0
    }
    do_cmd "swapon -a"
  fi
}

# Find tbt dbf marging folder in /sys/kernel/debug/thunderbolt
# Input: NA
# Return 0 for true, otherwise false or die
find_tbt_mrg() {
  [[ -d "$TBT_DBG" ]] || block_test "There is no tbt dbg:$TBT_DBG folder!"
  TBT_MRG=$(find "$TBT_DBG" -name margining | head -n 1)
  [[ -n "$TBT_MRG" ]] || die "No margining folder:$TBT_MRG in $TBT_DBG"
}

# Check tbt dbg margining sysfs with random value, should not trigger error.
# Input: $1 mrg sysfs
#        $2 random str or num
# Return 0 for true, otherwise false or die
test_mrg_random() {
  local mrg_sysfs=$1
  local input=$2
  local origin_content=""
  local check_content=""

  origin_content=$(cat $mrg_sysfs)
  test_print_trc "echo $input > $mrg_sysfs"
  echo $input > $mrg_sysfs 2>/dev/null
  check_content=$(cat $mrg_sysfs)
  if [[ "$origin_content" != "$check_content" ]]; then
    die "$mrg_sysfs content changed from $origin_content to $check_content"
  fi
}

# Check tbt dbg margining file should contain target keyword or should not null
# Input: $1 mrg sysfs
#        $2 mrg key word to check
# Return 0 for true, otherwise false or die
check_mrg_sysfs() {
  local mrg_sysfs=$1
  local mrg_check=$2
  local line=$3
  local exist=$4
  local mrg_content=""
  local mrg_line=""

  [[ -e "$mrg_sysfs" ]] || die "No tbt dbg margining sysfs file:$mrg_sysfs"
  mrg_content=$(cat "$mrg_sysfs")
  [[ -z "$mrg_content" ]] && die "TBT file:$mrg_sysfs is null:$mrg_content"
  test_print_trc "TBT file:$mrg_sysfs content:$mrg_content"

  if [[ -n "$mrg_check" ]]; then
    mrg_content=$(cat "$mrg_sysfs" | head -n $line \
                                   | tail -n 1 | grep "$mrg_check")
    if [[ "$exist" == "null" ]]; then
      if [[ -z "$mrg_content" ]]; then
        test_print_trc "$mrg_sysf didn't contain $mrg_check:$mrg_content as expected"
      else
        die "$mrg_sysf contained $mrg_check:$mrg_content. Pass."
      fi
    else
      if [[ -z "$mrg_content" ]]; then
        die "$mrg_sysf didn't contain $mrg_check:$mrg_content"
      else
        test_print_trc "$mrg_sysf contained $mrg_check:$mrg_content. Pass."
      fi
    fi
  fi
}

# Check tbt dbg margining file should contain target keyword or should not null
# Input: NA
# Return 0 for true, otherwise false or die
run_mrg_sysfs() {
  local mrg_content=""

  [[ -e "${TBT_MRG}/${RUN}" ]] || die "No tbt dbg $RUN sysfs:$mrg_sysfs"
  do_cmd "echo voltage > ${TBT_MRG}/test"

  do_cmd "echo 0 > ${TBT_MRG}/${LANES}"
  do_cmd "echo low > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"

  do_cmd "echo 1 > ${TBT_MRG}/${LANES}"
  do_cmd "echo low > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"

  do_cmd "echo 0 > ${TBT_MRG}/${LANES}"
  do_cmd "echo high > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"

  do_cmd "echo 1 > ${TBT_MRG}/${LANES}"
  do_cmd "echo high > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"
}

# Check tbt dbg time margining test
# Input: NA
# Return 0 for true, otherwise false or die
run_mrg_time() {
  local mrg_content=""

  [[ -e "${TBT_MRG}/${RUN}" ]] || die "No tbt dbg run sysfs:$mrg_sysfs"
  do_cmd "echo time > ${TBT_MRG}/test"

  do_cmd "echo 0 > ${TBT_MRG}/${LANES}"
  do_cmd "echo right > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"

  do_cmd "echo 1 > ${TBT_MRG}/${LANES}"
  do_cmd "echo right > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"

  do_cmd "echo 0 > ${TBT_MRG}/${LANES}"
  do_cmd "echo left > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"

  do_cmd "echo 1 > ${TBT_MRG}/${LANES}"
  do_cmd "echo left > ${TBT_MRG}/${MARGIN}"
  do_cmd "echo 1 > ${TBT_MRG}/${RUN}"
  check_mrg_sysfs "${TBT_MRG}/${RESULTS}" "0x00000000" "2" "null"
}

# Check tbt dbg with random value and should not contain exception error
# Input: NA
# Return 0 for true, otherwise false or die
run_mrg_random() {
  local ran_str=""
  local loop_time=5

  for((i=1; i<=loop_time; i++)); do
    ran_str=$(echo $RANDOM | md5sum | head -c 20; echo;)
    test_mrg_random "${TBT_MRG}/caps" "$ran_str"
    test_mrg_random "${TBT_MRG}/${LANES}" "$ran_str"
    test_mrg_random "${TBT_MRG}/${MARGIN}" "$ran_str"
    test_mrg_random "${TBT_MRG}/mode" "$ran_str"
    test_mrg_random "${TBT_MRG}/${RUN}" "$ran_str"
    test_mrg_random "${TBT_MRG}/test" "$ran_str"
    # Clean results first because any value will trigger clean results
    do_cmd "echo 0 > ${TBT_MRG}/${RESULTS}"
    test_mrg_random "${TBT_MRG}/${RESULTS}" "$ran_str"
  done
  fail_dmesg_check
}

# Loop cable and transfer data package for thunderbolt_dma test
# Input: NA
# Return 0 for true, otherwise false or die
loop_transfer_pkg() {
  local check_tbt_dma=""
  local tbt_debug_path="/sys/kernel/debug/thunderbolt"
  local dma1_folder=""
  local dma2_folder=""
  local check_send=""
  local check_receive=""
  local check_rcv_success=""
  local check_rcv_num=""
  local loop_num=0
  local secs="15"

  # Below step maybe already done and return non zero value so not use do_cmd
  mount -t debugfs none /sys/kernel/debug 2>/dev/null
  check_tbt_dma=$(lsmod | grep "$MOD_TBT_DMA")
  if [[ -z "$check_tbt_dma" ]]; then
    test_print_trc "No modprobe $MOD_TBT_DMA, modprobe $MOD_TBT_DMA"
    do_cmd "modprobe $MOD_TBT_DMA"
    check_tbt_dma=$(lsmod | grep "$MOD_TBT_DMA")
    if [[ -z "$check_tbt_dma" ]]; then
      block_test "No mod $MOD_TBT_DMA after loaded: $check_tbt_dma!"
    fi
  else
    test_print_trc "Mod $MOD_TBT_DMA exists will not load again:$check_tbt_dma"
  fi

  dma1_folder=$(find "$tbt_debug_path" -name dma_test | head -n 1)
  dma2_folder=$(find "$tbt_debug_path" -name dma_test | tail -n 1)
  [[ -z "$dma1_folder" ]] && block test "No dma1_folder:dma_test in $tbt_debug_path"
  [[ -z "$dma2_folder" ]] && block test "No dma2_folder:dma_test in $tbt_debug_path"
  if [[ "$dma1_folder" == "$dma2_folder" ]]; then
    block_test "dma1_folder:$dma1_folder is same as dma2_folder:$dma2_folder"
  else
    test_print_trc "Found dma1_folder:$dma1_folder and dma2_folder:$dma2_folder"
  fi

  # Prepare and do receive side
  cd "$dma1_folder" || {
    block_test "Access dma1_folder:$dma1_folder failed!"
  }
  do_cmd "echo 1000 > $dma1_folder/packets_to_receive"
  # Must use child pid for the receive side, because it needs to wait the send!
  do_cmd "echo 1 > $dma1_folder/test &"

  # Prepare and do send side
  cd "$dma2_folder" || {
    block_test "Access dma2_folder:$dma2_folder failed!"
  }
  do_cmd "echo 1000 > $dma2_folder/packets_to_send"
  do_cmd "echo 1 > $dma2_folder/test"
  sleep 5
  check_send=$(grep result "$dma2_folder"/status | grep success)
  [[ -z "$check_send" ]] && die "Send packages in $dma2_folder failed:$check_send"

  # Check received side
  cd "$dma1_folder" || {
    block_test "Access dma1_folder:$dma1_folder failed!"
  }

  for (( ; ; )); do
    ((loop_num++))
    test_print_trc "$loop_num round check dma1_folder:$dma1_folder/status:"
    # It needs more time like 3min, so set the timeout 2s for command
    check_receive=$(timeout 2s cat "$dma1_folder"/status &)
    if [[ -z "$check_receive" ]]; then
      test_print_trc "Check $dma1_folder/status is null:$check_receive, sleep $secs"
    else
      check_rcv_success=$(echo "$check_receive" | grep "success")
      if [[ -z "$check_rcv_success" ]]; then
        test_print_trc "No success in $check_receive, will check receive packages!"
        check_rcv_num=$(echo "$check_receive" \
                        | awk -F "received: " '{print $2}' \
                        | cut -d " " -f 1)
        if [[ "$check_rcv_num" -eq 0 ]]; then
          die "dma1:$dma1_folder/status received 0 packages, failed."
        else
          test_print_trc "dma1:$dma1_folder/status received $check_rcv_num packages, passed!"
        fi
        break
      else
        test_print_trc "Found success in $check_receive, pass!"
        break
      fi
    fi

    if [[ "$loop_num" -ge 36 ]]; then
      die "loop_num reached to $loop_num *15s and not finished, exit!"
      break
    fi
    sleep "$secs"
  done
}

check_clx() {
  local domain_port=$1
  local clx=$2
  local domain=""
  local port=""
  local clx_details=""

  tblink.sh
  if [[ "$domain_port" == *"-"* ]]; then
    test_print_trc "domain_port:$domain_port"
  elif [[ "$domain_port" == "auto" ]]; then
    domain_port=$(grep "tbt devices" "$CLX_OUTPUT" \
                | grep -v "contains 0 tbt" \
                | cut -d " " -f 1)
  else
    block_test "Invalid domain_port:$domain_port"
  fi

  domain=$(echo "$domain_port" | cut -d "-" -f 1)
  port=$(echo "$domain_port" | cut -d "-" -f 2)
  clx_details=$(grep "Domain $domain " "$CLX_OUTPUT" | grep "Port $port ")
  [[ -z "$clx_details" ]] && block_test "No $domain_port clx info:$clx_details"
  if [[ "$clx_details" == *"$clx"* ]]; then
    test_print_trc "$domain_port clx info:|$clx_details| contains $clx, pass"
  else
    die "$domain_port clx info:|$clx_details| doesn't contains $clx"
  fi
}

# Check tbt RTD3 works device should s0ix counter increase after s2idle sleep
# Input: NA
# Return 0 for true, otherwise false or die
check_pmc_counter() {
  local result=""
  local pmc_filter="S0i3.2"

  get_tbt_pci
  test_print_trc "TBT device root PCI:$TBT_ROOT_PCI"
  result=$(cat "$PMC_CNT_FILE" | grep "$pmc_filter" | awk -F ' ' '{print $NF}')
  if [[ "$result" -lt "$PMC_NOW" ]]; then
    die "ERROR: $PMC_CNT_FILE:$result is less than previous:$PMC_NOW"
  fi
  PMC_INCREASE_NUM=$((result - PMC_NOW))
  PMC_PREV="$PMC_NOW"
  PMC_NOW="$result"
  test_print_trc "PMC_PREV:$PMC_PREV + INCREASE:$PMC_INCREASE_NUM=NOW:$PMC_NOW"
}
