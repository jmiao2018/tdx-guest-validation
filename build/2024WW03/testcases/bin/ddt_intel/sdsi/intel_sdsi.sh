#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for intel_sdsi feature, which is supported beginning
# from EagleStream SapphireRapids platform
# SDSi:Software Defined Silicon, aka SoftSKU

# Authors:      wendy.wang@intel.com
# History:      Oct 13 2021 - Created - Wendy Wang
#               Mar 25 2022 - Updated - Wendy Wang
#               Dec 20 2022 - Add GNR HW real AKC/CAP files - Wendy Wang

source "common.sh"
source "dmesg_functions.sh"
TOOL="$LTPROOT/testcases/bin/ddt_intel/sdsi"

SDSI_DRIVER_PATH="/sys/module/intel_sdsi/drivers/auxiliary"
SDSI_MODULE="intel_sdsi"
SDSI_DRIVER_NODE_PATH="/sys/bus/auxiliary/devices"
[[ -n $SDSI_DRIVER_NODE_PATH ]] || block_test "SDSi driver node is not available."
SOCKET_NUM=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
[[ -n $SOCKET_NUM ]] || block_test "Socket number is not available."

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

sdsi_load_unload_module() {
  is_kmodule_builtin "$SDSI_MODULE" && skip_test
  dmesg -C

  load_unload_module.sh -c -d "$SDSI_MODULE" &&
    do_cmd "load_unload_module.sh -u -d $SDSI_MODULE"
  do_cmd "load_unload_module.sh -l -d $SDSI_MODULE -p dyndbg"
  do_cmd "load_unload_module.sh -u -d $SDSI_MODULE"
  do_cmd "load_unload_module.sh -l -d $SDSI_MODULE -p dyndbg"
}

sdsi_unbind_bind() {
  for ((i = 1; i <= "$SOCKET_NUM"; i++)); do
    sdsi_device=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$i,1p" 2>&1)
    [[ -n "$sdsi_device" ]] || block_test "sdsi device is not available by checking /sys/bus/auxiliary/devices"
    test_print_trc "Do $sdsi_device unbind"
    do_cmd "echo $sdsi_device > /sys/bus/auxiliary/drivers/intel_sdsi/unbind"
    test_print_trc "Do $sdsi_device bind"
    do_cmd "echo $sdsi_device > /sys/bus/auxiliary/drivers/intel_sdsi/bind"
  done
}

sdsi_driver_interface() {
  test_print_trc "Check Intel_SDSi driver interface:"

  [[ -d "$SDSI_DRIVER_PATH":intel_sdsi ]] ||
    die "intel sdsi driver sysfs does not exist!"

  lines=$(ls "$SDSI_DRIVER_PATH":intel_sdsi 2>&1)
  for line in $lines; do
    test_print_trc "$line"
  done
}

#Hex read SDSi sysfs attribute files:registers,state_certificate
#Meter_telemetry feature only supports on GNR and further platforms
sdsi_sysfs_attribute() {
  local attri=$1

  test_print_trc "Check how many sockets the system supports: $SOCKET_NUM"

  test_print_trc "Check Intel SDSi $attri sysfs:"
  for ((i = 1; i <= "$SOCKET_NUM"; i++)); do
    sdsi_device=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$i,1p" 2>&1)
    [[ -n "$sdsi_device" ]] || block_test "sdsi device is not available by checking /sys/bus/auxiliary/devices"
    attri=$(ls "$SDSI_DRIVER_NODE_PATH"/"$sdsi_device" | grep "$attri" 2>&1)
    if [[ "$attri" != "" ]]; then
      test_print_trc "The $attri file for $sdsi_device is available:"
      do_cmd "xxd $SDSI_DRIVER_NODE_PATH/$sdsi_device/$attri"
    else
      die "The $attri file for $sdsi_device is not available."
    fi
  done
}

sdsi_driver_node_per_socket() {
  local sdsi_node

  test_print_trc "Check how many socket the system supports: $SOCKET_NUM"
  sdsi_node=$(ls "$SDSI_DRIVER_NODE_PATH" | grep -c sdsi 2>&1)
  test_print_trc "Check Intel_SDSi driver node number: $sdsi_node"
  if [[ "$sdsi_node" = "$SOCKET_NUM" ]]; then
    test_print_trc "intel_sdsi driver node per socket exist!"
  else
    die "intel_sdsi driver node per socket does not exist!"
  fi

  lines=$(ls -A "$SDSI_DRIVER_NODE_PATH"/intel_vsec.sdsi.* 2>&1)
  for line in $lines; do
    test_print_trc "$line"
  done
}

available_sdsi_devices() {
  local sdsi_device

  sdsi_device=$(intel_sdsi -l)
  if [[ -n "$sdsi_device" ]]; then
    test_print_trc "Available SDSi devices:"
    test_print_trc "$sdsi_device"
  else
    die "Fails to get sdsi devices: $sdsi_device"
  fi
}

sdsi_ppin() {
  local read_reg
  local ppin

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    read_reg=$(intel_sdsi -d "$id" -i)
    if [[ $? -eq 0 ]]; then
      ppin=$(echo "$read_reg" | grep PPIN | awk -F ":" '{print $2}')
      test_print_trc "PPIN value: $ppin"
      if [[ -n "$ppin" ]]; then
        test_print_trc "SDSI PPIN is available: $ppin"
      else
        die "SDSI PPIN is not available: $ppin"
      fi
    else
      die "$read_reg"
    fi
  done
}

socket_id() {
  local read_reg
  local socket

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    read_reg=$(intel_sdsi -d "$id" -i)
    if [[ $? -eq 0 ]]; then
      socket=$(echo "$read_reg" | grep "Socket ID" | awk -F ":" '{print $2}')
      test_print_trc "Socket ID from reg: $socket"
      if [[ "$socket" =~ 15 ]]; then
        test_print_trc "SDSI socket ID for device $id is correct"
      else
        die "SDSI socket ID for device $id is not correct: $socket"
      fi
    else
      die "$read_reg"
    fi
  done
}

nvram_content_err() {
  local auth_info
  local auth_err

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    auth_info=$(intel_sdsi -d "$id" -i)
    test_print_trc "SDSi register info shows: $auth_info"
    if [[ $? -eq 0 ]]; then
      auth_err_lines=$(echo "$auth_info" | grep -c "Err Sts")
      for ((i = 1; i <= "$auth_err_lines"; i++)); do
        auth_err=$(echo "$auth_info" | grep "Err Sts" | awk -F ":" '{print $2}')
        test_print_trc "NVRAM Content Authorization Err Status: $auth_err"
        if [[ "$auth_err" =~ Error ]]; then
          die "NVRAM Content Authorization shows Error"
        else
          test_print_trc "Content Authorization Error Status shows Okay"
        fi
      done
    else
      die "$auth_info"
    fi
  done
}

feature_enable() {
  local auth_info
  local feature_enable
  local model

  #For Intel On Demard feature, SPR(CPU model: 143),
  #EMR(CPU mOdel: 207) are legacy platforms,on which
  #Only SDSi feature is supported.
  legacy_model_list="143 207"
  legacy_feature=SDSi
  status=Disabled

  model=$(sed -n '/model/p' /proc/cpuinfo | head -1 | awk '{print $3}' 2>&1)

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    auth_info=$(intel_sdsi -d "$id" -i)
    test_print_trc "SDSi register info shows: $auth_info"
    if [[ $? -eq 0 ]]; then
      for x in Attestation SDSi Telemetry; do
        feature_enable=$(echo "$auth_info" | grep "$x" | awk -F ":" '{print $2}')
        test_print_trc "Feature $x: $feature_enable"
        if [[ "$feature_enable" =~ $status ]] && [[ $legacy_model_list =~ $model ]] &&
          [[ $x =~ $legacy_feature ]]; then
          die "SDSi feature $x is Disabled."
        elif [[ "$feature_enable" =~ $status ]] && [[ $legacy_model_list =~ $model ]]; then
          test_print_trc "SDSi feature $x Disabled is expected for the legacy platform."
        elif [[ "$feature_enable" =~ $status ]]; then
          die "SDSi feature $x is Disabled."
        else
          test_print_trc "The SDSi feature $x is Enabled."
        fi
      done
    else
      die "$auth_info"
    fi
  done
}

read_meter_tele() {
  local read_tele

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    test_print_trc "Reading SDSi meter telemetry for socket $id"
    read_tele=$(intel_sdsi -d "$id" -m)
    if [[ $? -ne 0 ]]; then
      die "Failed to read SDSi meter telemetry for socket $id: $read_tele"
    else
      test_print_trc "$read_tele"
    fi
  done
}

# Funtion to read the telemetry MMRC (Master Meter Reference Counter) encoder
# MMRC counter is Actual Master Meter Reference Counter running value
read_tele_mmrc() {
  local read_tele

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    test_print_trc "Reading SDSi meter telemetry for socket $id"
    read_tele=$(intel_sdsi -d "$id" -m)
    [[ -n "$read_tele" ]] || die "Failed to read SDSi meter telemetry for socket $id: $read_tele"
    test_print_trc "$read_tele"
    mmrc_encoding=$(echo "$read_tele" | grep "MMRC encoding" | awk '{print $3}')
    mmrc_counter=$(echo "$read_tele" | grep "MMRC counter" | awk '{print $3}')
    uptime=$(uptime -p)
    test_print_trc "SUT Uptime: $uptime"
    updays=$(uptime -p | grep days | awk '{print $2}' 2>&1)
    if [[ "$mmrc_encoding" == 0 ]] && [[ "$mmrc_counter" == 0 ]] &&
      [[ -z "$updays" ]]; then
      block_test "Socket $id: SUT needs to up 24 hrs then check MMRC encoding and counter"
    elif
      [[ "$mmrc_encoding" == 0 ]] && [[ "$mmrc_counter" == 0 ]] &&
        [[ "$updays" -ge 1 ]]
    then
      die "Socket $id: MMRC encoding and MMRC counter is zero after 24 hrs updates."
    elif
      [[ "$mmrc_encoding" == MMRC ]] && [[ "$mmrc_counter" == 0 ]] &&
        [[ "$updays" -ge 1 ]]
    then
      die "Socket $id: MMRC encoding is okay, but MMRC counter is zero after 24 hrs updates"
    else
      test_print_trc "Socket $id:MMRC encoding and counter are Okay after 24 hrs updates!"
    fi
  done
}

# Funtion to read enabled feature counter in meter data block
read_tele_feature_counter() {
  local read_tele

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    test_print_trc "Reading SDSi meter telemetry for socket $id"
    read_tele=$(intel_sdsi -d "$id" -m)
    [[ -n "$read_tele" ]] || die "Failed to read SDSi meter telemetry for socket $id: $read_tele"
    test_print_trc "$read_tele"
    feature_counter=$(echo "$read_tele" | grep "Feature Counters" | awk '{print $3}')
    uptime=$(uptime -p)
    test_print_trc "SUT Uptime: $uptime"
    updays=$(uptime -p | grep days | awk '{print $2}' 2>&1)
    if [[ "$feature_counter" == 0 ]] && [[ -z "$updays" ]]; then
      block_test "Socket $id: SUT needs to up 24 hrs then check enabled feature counter"
    elif
      [[ "$feature_counter" == 0 ]] && [[ "$updays" -ge 1 ]]
    then
      die "Socket $id: enabled feature counter is zero after 24 hrs updates."
    else
      test_print_trc "Socket $id: enabled feature counter is updated:$feature_counter"
    fi
  done
}

# Function to check if meter_current updates for any 2 times reading
meter_current_update() {
  local sdsi_device
  local meter_current_bf
  local meter_current_af

  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    sdsi_device=$(ls /sys/bus/auxiliary/devices | grep sdsi | sed -n "$j,1p")
    [[ -n $sdsi_device ]] || block_test "SDSI device is not available."
    test_print_trc "Dump meter_current_bf content:"
    meter_current_bf=$(xxd /sys/bus/auxiliary/devices/"$sdsi_device"/meter_current)
    test_print_trc "$meter_current_bf"
    sleep 1
    test_print_trc "Dump meter_current_af content:"
    meter_current_af=$(xxd /sys/bus/auxiliary/devices/"$sdsi_device"/meter_current)
    test_print_trc "$meter_current_af"
    if [[ -z "$meter_current_bf" ]] && [[ -z "$meter_current_af" ]]; then
      block_test "$sdsi_device meter_current content is empty"
    elif [[ "$meter_current_bf" = "$meter_current_af" ]]; then
      die "$sdsi_device meter_current content does not change in two times reading."
    else
      test_print_trc "$sdsi_device meter_current content changes in two times reading."
    fi
  done
}

#Function to erase the License Key file
erase_akc_socket() {
  local akc_provision_sts
  local erase_akc
  local efile=$2
  local id=$1

  #Read License Key (AKC) Provisioned Status
  auth_info=$(intel_sdsi -d "$id" -i)
  test_print_trc "SDSi register info shows: $auth_info"
  if [[ $? -eq 0 ]]; then
    akc_provision_sts=$(echo "$auth_info" | grep 'Provisioned' | awk -F ":" '{print $2}')
    test_print_trc "The License Key (AKC) Provisioned is before erasing: $akc_provision_sts"
    if [[ "$akc_provision_sts" =~ Yes ]]; then
      test_print_trc "Will erase the provisioned License Key:"
      erase_akc=$(intel_sdsi -d "$id" -a "$TOOL"/"$efile")
      if [[ $? -ne 0 ]]; then
        die "SDSI provision failed: $erase_akc"
      else
        test_print_trc "Please do one cycle cold power after AKC erasing."
      fi
    else
      block_test "Does not support to erase the AKC as no provisioned state shows No"
    fi
  else
    die "$auth_info"
  fi
}

#Authentication Key Certificate (AKC), a key written to internal NVRAM that is
#used to authenticate a capability specific activation payload
provision_akc_socket() {
  local id=$1
  local akc=$2
  local read_reg_before
  local read_reg_after
  local provision_socket_akc
  local update_available_before
  local update_available_after
  local read_lic

  #Read SDSI reg before provisioning AKC file
  test_print_trc "Reading SDSi state registers for socket $id \
before provisioning Authentication Key Certificate file"
  read_reg_before=$(intel_sdsi -d "$id" -i)
  if [[ $? -ne 0 ]]; then
    die "Failed to read SDSi Registers before provisioning AKC: $read_reg_before"
  else
    test_print_trc "$read_reg_before"
    update_available_before=$(echo "$read_reg_before" | grep "Updates Available" | awk -F ":" '{print $2}')
    test_print_trc "The Updates Available before AKC provisioning is: $update_available_before"
  fi

  #Provision AKC file
  test_print_trc "Doing socket$1 provisioning with AKC file:"
  provision_socket_akc=$(intel_sdsi -d "$id" -a "$TOOL"/"$akc")
  if [[ $? -ne 0 ]]; then
    test_print_trc "Analyze the AKC provisioning failure reason:"
    read_lic=$(intel_sdsi -d "$id" -s)
    if [[ $? -ne 0 ]]; then
      die "Fails to read SDSI license for socket $id after provisioning \
AKC file: $read_lic"
    else
      lic_key=$(echo "$read_lic" | grep "License Key Revision ID" | awk -F ":" '{print $2}')
      if [[ "$lic_key" =~ 0x0 ]]; then
        test_print_trc "Provision failure is expected because prior AKC provisioning occurs."
      else
        die "SDSI AKC provisioning failed without observing License Key Revision ID updates: $lic_key"
      fi
    fi
    die "SDSI provision failed: $provision_socket_akc"
  else
    test_print_trc "$provision_socket_akc"
    read_reg_after=$(intel_sdsi -d "$id" -s)
    if [[ $? -ne 0 ]]; then
      die "SDSI reg read failed: $read_reg_after"
    else
      update_available_after=$(echo "$read_reg_after" | grep "Updates Available" | awk -F ":" '{print $2}')
      test_print_trc "SDSI reg information after AKC provisioning: $update_available_after"
      if [[ "$update_available_after" -lt "$update_available_before" ]]; then
        test_print_trc "SDSi reg Updates Available counter is PASS after AKC file provision!"
      else
        die "SDSi reg Updates Available update failed after AKC file provision!"
      fi
    fi
  fi

  #Read the SDSi State Certificate, containing the CPU configuration state
  test_print_trc "Reading SDSi state license for socket $id after provisioning AKC file"
  read_lic=$(intel_sdsi -d "$id" -s)
  if [[ $? -ne 0 ]]; then
    die "Fails to read SDSI license for socket $id after provisioning \
AKC file: $read_lic"
  else
    test_print_trc "SDSi license after AKC provisioning is: $read_lic"
    lic_rev=$(echo "$read_lic" | grep "License Key Revision ID" | awk -F ":" '{print $2}')
    if [[ "$lic_rev" =~ 0x0 ]]; then
      die "Provisioned AKC license key is not valid"
    else
      test_print_trc "Provisioned AKC license key is valid and \
License Key Revision ID is updated to: $lic_rev"
    fi
  fi
}

#Capability Activation Payload (CAP), a token authenticated using the AKC and
#applied to the CPU configuration to activate a new feature
provision_cap_socket() {
  local id=$1
  local cap=$2
  local read_reg_before
  local read_reg_after
  local provision_socket_cap
  local update_available_before
  local update_available_after
  local read_lic

  #Read SDSI reg before provisioning CAP file
  test_print_trc "Reading SDSi state registers for socket $id \
before provisioning Capability Activation Payload file"
  read_reg_before=$(intel_sdsi -d "$id" -i)
  if [[ $? -ne 0 ]]; then
    die "Failed to read SDSi Registers before provisioning CAP: $read_reg"
  else
    test_print_trc "$read_reg_before"
    update_available_before=$(echo "$read_reg_before" | grep "Updates Available" | awk -F ":" '{print $2}')
    test_print_trc "The Updates Available before CAP provisioning is: $update_available_before"
  fi

  #Provision CAP file
  test_print_trc "Doing socket $id provisioning with CAP file:"
  provision_socket_cap=$(intel_sdsi -d "$id" -c "$TOOL"/"$cap")
  if [[ $? -eq 0 ]]; then
    test_print_trc "$provision_socket_cap"
  else
    test_print_trc "Analyze the provisioning failure reason:"
    read_lic=$(intel_sdsi -d "$id" -s)
    if [[ $? -ne 0 ]]; then
      die "Fails to read SDSI license for socket $id after provisioning \
CAP file: $read_lic"
    else
      lic_val=$(echo "$read_lic" | grep "License is valid" | awk -F ":" '{print $2}')
      if [[ "$lic_val" =~ Yes ]]; then
        test_print_trc "CAP Provision failure is expected because prior CAP provisioning occurs."
      else
        die "SDSI CAP provisioning failed without observing the valid license file: $provision_socket_cap"
      fi
    fi
  fi

  #Read the SDSi State Certificate, containing the CPU configuration state
  test_print_trc "Reading SDSi state license for socket $id after provisioning CAP file"
  read_lic=$(intel_sdsi -d "$id" -s)
  if [[ $? -ne 0 ]]; then
    die "Fails to read SDSI license for socket $id after provisioning \
CAP file: $read_lic"
  else
    test_print_trc "The SDSi state_certificate shows after CAP provisioning: $read_lic"
    lic_val=$(echo "$read_lic" | grep "License is valid" | awk -F ":" '{print $2}')
    if [[ "$lic_val" =~ Yes ]]; then
      test_print_trc "Provisioned cap file is valid."
    else
      die "Provisioned cap file is not valid."
    fi
  fi
}

stress_read_reg() {
  local read_reg
  test_print_trc "Repeat reading SDSi register for 30 cycles:"
  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    for ((i = 1; i <= 30; i++)); do
      read_reg=$(intel_sdsi -d "$id" -i)
      if [[ $? -ne 0 ]]; then
        die "Repeat reading SDSi register for socket $id cycles $i Fails"
      else
        test_print_trc "Repeat reading SDSi register for socket $id cycle $i PASS"
      fi
    done
  done
  test_print_trc "$read_reg"
}

stress_read_lic() {
  local read_lic
  test_print_trc "Repeat reading SDSi state certificate for 30 cycles:"
  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    for ((i = 1; i <= 30; i++)); do
      read_lic=$(intel_sdsi -d "$id" -s)
      if [[ $? -ne 0 ]]; then
        die "Repeat reading SDSi license for socket $id cycle $i Fails"
      else
        test_print_trc "Repeat reading SDSi state certificate for socket $id cycle $i PASS"
      fi
    done
  done
  test_print_trc "$read_lic"
}

stress_read_tele() {
  local read_tele
  test_print_trc "Repeat reading SDSi meter telemetry for 30 cycles:"
  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    for ((i = 1; i <= 30; i++)); do
      read_tele=$(intel_sdsi -d "$id" -m)
      if [[ $? -ne 0 ]]; then
        die "Repeat reading SDSi meter telemetry for socket $id cycle $i Fails"
      else
        test_print_trc "Repeat reading meter telemetry for socket $id cycle $i PASS"
      fi
    done
  done
  test_print_trc "$read_tele"
}

add_root_key() {
  local add_rootkey
  local key=$1

  test_print_trc "Adding rootkey to prepare for the Attestation testing:"
  add_rootkey=$(intel_sdsi -k "$TOOL"/"$key")
  if [[ $? -eq 0 ]]; then
    test_print_trc "$add_rootkey"
    do_cmd "cat /proc/keys"
  else
    test_kconfigs "y" "CONFIG_CRYPTO_ECDSA"
    test_kconfigs "y" "CONFIG_CRYPTO_ECRDSA"
    test_kconfigs "y" "CONFIG_CRYPTO_SM2"
    test_kconfigs "y" "CONFIG_CRYPTO_CURVE25519"
    test_kconfigs "y" "CONFIG_CRYPTO_CURVE25519_X86"
    test_kconfigs "y" "CONFIG_CRYPTO_CRC32"
    die "$add_rootkey"
  fi
}

verify_spdm_authorization() {
  local spdm_auth

  for ((i = 1; i <= "$SOCKET_NUM"; i++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$i,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    test_print_trc "Verify SDPM Authorization for SDSi device $id:"
    spdm_auth=$(intel_sdsi -d "$id" -v 0)
    dmesg >spdm_authentication.log && test_print_trc "more debug logs refers to spdm_authentication.log"
    if [[ $? -eq 0 ]]; then
      test_print_trc "SDSI device $id spdm authorization PASS $spdm_auth"
    else
      do_cmd "dmesg | tail -20"
      die "SDSI device $id spdm authorization Failed $spdm_auth"
    fi
  done
}

spdm_measurement() {
  local type=$1
  local cycle=$2
  local measure_report

  test_print_trc "Doing Attestation SDPM Measurement:"
  for ((j = 1; j <= "$SOCKET_NUM"; j++)); do
    id=$(ls /sys/bus/auxiliary/devices | grep sdsi | awk -F "/" '{print $NF}' | sed -n "$j,1p" | awk -F "." '{print $NF}' 2>&1)
    [[ -n "$id" ]] || block_test "SDSI device $id is not available."
    for ((i = 1; i <= "$cycle"; i++)); do
      measure_report=$(intel_sdsi -d "$id" -M "$type")
      if [[ $? -eq 0 ]]; then
        test_print_trc "SDSI device $id spdm Measurement $type for cycle $i PASS $measure_report"
      else
        do_cmd "dmesg | tail -20"
        dmesg >spdm_measurement.log && test_print_trc "more debug logs refers to spdm_measurement.log"
        die "SDSI device $id spdm Measurement $type for cycle $i Failed $measure_report"
      fi
    done
  done
}

dmesg_check() {
  local dmesg_log

  dmesg_log=$(extract_case_dmesg)

  if echo "$dmesg_log" | grep -iE "fail|Call Trace|error|BUG"; then
    die "Kernel dmesg shows failure: $dmesg_log"
  else
    test_print_trc "Kernel dmesg shows Okay."
  fi
}

intel_sdsi_test() {
  case $TEST_SCENARIO in
  load_unload)
    sdsi_load_unload_module
    test_kconfigs m CONFIG_INTEL_SDSI ||
      block_test "INTEL_SDSI kconfig is not set"
    ;;
  driver_unbind_bind)
    sdsi_unbind_bind
    ;;
  sdsi_sysfs)
    sdsi_driver_interface
    ;;
  sdsi_per_socket)
    sdsi_driver_node_per_socket
    ;;
  sysfs_register_attri)
    sdsi_sysfs_attribute registers
    ;;
  sysfs_certificate_attri)
    sdsi_sysfs_attribute state_certificate
    ;;
  sysfs_telemetry_attri)
    sdsi_sysfs_attribute meter_certificate
    ;;
  sysfs_telemetry_current_attri)
    sdsi_sysfs_attribute meter_current
    ;;
  sdsi_devices)
    available_sdsi_devices
    ;;
  sdsi_ppin)
    sdsi_ppin
    ;;
  nvram_content_err_check)
    nvram_content_err
    ;;
  enable_status)
    feature_enable
    ;;
  sdsi_socket_id)
    socket_id
    ;;
  read_meter_telemetry)
    read_meter_tele
    ;;
  read_tele_mmrc_counter)
    read_tele_mmrc
    ;;
  read_tele_enabled_feature_counter)
    read_tele_feature_counter
    ;;
  verify_meter_current_update)
    meter_current_update
    ;;
  erase_akc_socket0)
    erase_akc_socket 0 EraseCertDebugBit0Request_signed.bin
    ;;
  erase_akc_socket1)
    erase_akc_socket 1 EraseCertDebugBit0Request_signed.bin
    ;;
  provision_akc_socket0)
    provision_akc_socket 0 AKC_SPR_PRX_debug_0_prod_0_rev_0x19000003_signed.bin
    ;;
  provision_akc_socket1)
    provision_akc_socket 1 AKC_SPR_PRX_debug_0_prod_0_rev_0x19000003_signed.bin
    ;;
  provision_cap_socket0)
    provision_cap_socket 0 socket-0-cap.bin
    ;;
  provision_cap_socket1)
    provision_cap_socket 1 socket-1-cap.bin
    ;;
  provision_cap_socket_negative)
    provision_cap_socket 1 socket-1-cap.bin
    ;;
  erase_akc_socket0_gnr)
    erase_akc_socket 0 erase_akc_gnr.bin
    ;;
  erase_akc_socket1_gnr)
    erase_akc_socket 1 erase_akc_gnr.bin
    ;;
  provision_akc_socket0_gnr)
    provision_akc_socket 0 socket_0_akc_base_gnr.bin
    ;;
  provision_cap_socket0_gnr_base)
    provision_cap_socket 0 socket_0_cap_base_gnr.bin
    ;;
  provision_cap_socket0_gnr_sgx512)
    provision_cap_socket 0 socket_0_cap_sgx512_gnr.bin
    ;;
  provision_cap_socket0_gnr_large)
    provision_cap_socket 0 socket_0_cap_large_gnr.bin
    ;;
  provision_akc_socket1_gnr)
    provision_akc_socket 1 socket_1_akc_base_gnr.bin
    ;;
  provision_cap_socket1_gnr_base)
    provision_cap_socket 1 socket_1_cap_base_gnr.bin
    ;;
  provision_cap_socket1_gnr_sgx512)
    provision_cap_socket 1 socket_1_cap_sgx512_gnr.bin
    ;;
  stress_reading_reg)
    stress_read_reg
    ;;
  stress_reading_lic)
    stress_read_lic
    ;;
  stress_reading_tele)
    stress_read_tele
    ;;
  attestation_adding_rootkey_gnr_simics)
    add_root_key gen_cert.der
    ;;
  attestation_adding_rootkey_gnr_preprod)
    add_root_key DICE_RootCA.cer
    ;;
  attestation_adding_rootkey_gnr_prod)
    add_root_key DICE_RootCA_PROD.cer
    ;;
  attestation_verify_spdm_authorization)
    verify_spdm_authorization
    ;;
  spdm_meassurement_state)
    spdm_measurement state 1
    ;;
  spdm_meassurement_signed_state)
    spdm_measurement state+ 1
    ;;
  spdm_meassurement_meter)
    spdm_measurement meter 1
    ;;
  spdm_meassurement_signed_meter)
    spdm_measurement meter+ 1
    ;;
  stress_spdm_meassurement_state)
    spdm_measurement state 30
    ;;
  stress_spdm_meassurement_signed_state)
    spdm_measurement state+ 30
    ;;
  stress_spdm_meassurement_meter)
    spdm_measurement meter 30
    ;;
  stress_spdm_meassurement_signed_meter)
    spdm_measurement meter+ 30
    ;;
  esac
  dmesg_check
  return 0
}

while getopts :t:H arg; do
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

intel_sdsi_test
