#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for CXL(Compute eXpress Link) common functions
#

source "common.sh"
source "dmesg_functions.sh"

readonly NULL="null"
readonly CONTAIN="contain"
readonly PCIE_CHECK_TOOL="pcie_check"
readonly CXL_PCI="CXL PCI"
readonly CXL_PATH="/sys/bus/cxl"
readonly CXL_DEV_PATH="${CXL_PATH}/devices"
readonly ISOLATION="isolation"
readonly MEM_ISO="mem_isolation_enable"
readonly MEM_TIMEOUT="mem_timeout_enable"
readonly MEM_INT="interrupt_enable"
readonly MEM_AER="aer_enable"
readonly DISABLED="disabled"
readonly ENABLED="enabled"
readonly DECODER="decoder"
readonly CREATE_DC_REGION="create_dc_region"
readonly DVSEC_INFO="Designated Vendor-Specific"
readonly CXL_LIST_FILE="/tmp/cxl_list.log"
readonly CXL3_LIST_FILE="/tmp/cxl3_list.log"
readonly DEL_REGION="delete_region"
readonly CONTAIN="contain"
readonly NULL="null"

export CEDT_PATH="/sys/firmware/acpi/tables/CEDT"
export LIST_CXL_DONE=0
export CXL3_PCIES=""
export CXL_PCIES=""
export teardown_handler="cxl_teardown"

TARGET_REGION=""
CXL_PCIS=""
CXLS=""
RESULT=""
MATCH="Match"
CXL_DPORTS=""
CXL_ISO_DPORTS=""

cxl_teardown() {
  [[ -z "$TARGET_REGION" ]] || {
    test_print_trc "echo $TARGET_REGION > ${CXL_DEV_PATH}/${DECODER}0.0/${DEL_REGION}"
    echo "$TARGET_REGION" > ${CXL_DEV_PATH}/${DECODER}0.0/${DEL_REGION}
    # Check all the cxl sysfs info after teardown
    grep -H . ${CXL_DEV_PATH}/${DECODER}0.0/*
    # Avoid above command ret 2 and cause all CXL case failed.
    echo "$?"
  }
}

lspci_check() {
  local pcis=$1
  local keyword=$2
  local pci=""
  local result=""
  local num=0

  for pci in $pcis; do
    result=""
    result=$(lspci -vvv -s "$pci" | grep "$keyword")
    [[ -n "$result" ]] || {
      test_print_wrg "CXL PCI $pci doesn't have $keyword capbility"
      ((num+=1))
      continue
    }
    test_print_trc "CXL PCI $pci supports $keyword capbility"
  done
  [[ "$num" -eq 0 ]] || die "There is $num unexpected warning in pci check"
}

list_cxl_pcie() {
  local pcie_list=""
  local pcie=""
  local is_cxl=""
  local is_cxl3=""

  if [[ -e "$CXL3_LIST_FILE" && "$LIST_CXL_DONE" -eq 1 ]]; then
    test_print_trc "LIST_CXL_DONE:$LIST_CXL_DONE and found $CXL3_LIST_FILE"
    cat "$CXL_LIST_FILE"
    do_cmd "cat $CXL3_LIST_FILE"
    return 0
  fi

  [[ -e "$CXL_LIST_FILE" ]] && mv "$CXL_LIST_FILE" "${CXL_LIST_FILE}_old"
  [[ -e "$CXL3_LIST_FILE" ]] && mv "$CXL3_LIST_FILE" "${CXL3_LIST_FILE}_old"
  cat /dev/null > "$CXL_LIST_FILE"
  cat /dev/null > "$CXL3_LIST_FILE"
  # CXL3.0 spec 8.1.3 PCIe DVSEC for CXL Devices page374: DVSEC ID for CXL:1E98h
  pcie_list=$(lspci -v | grep -i -B 50 "Specific: Vendor=1e98" | grep "^[0-9]" | cut -d " " -f 1)

  for pcie in $pcie_list; do
    is_cxl=$(lspci -v -s "$pcie" | grep -i "$DVSEC_INFO")
    if [[ -z "$is_cxl" ]]; then
      continue
    else
      echo "$pcie" >> "$CXL_LIST_FILE"
    fi
    is_cxl3=$(lspci -v -s "$pcie" | grep -i "$DVSEC_INFO" | grep -i "Rev=2")
    if [[ -n "$is_cxl3" ]]; then
      echo "$pcie" >> "$CXL3_LIST_FILE"
    fi
  done

  test_print_trc "CXL PCIe list in $CXL_LIST_FILE:"
  cat "$CXL_LIST_FILE"
  CXL3_PCIES=$(cat "$CXL_LIST_FILE")
  test_print_trc "CXL3.0 PCIe list in $CXL3_LIST_FILE:"
  # Show each CXL3 PCIe in one line
  cat "$CXL3_LIST_FILE"
  CXL3_PCIES=$(cat "$CXL3_LIST_FILE")
  LIST_CXL_DONE=1
}

check_dmesg_keywords() {
  # $CONTAIN or $NULL
  local exist=$1
  # Sample: One key word with space like "XX with xx"
  local str=$1
  # Optional, some times it needs "XX XX" with several keywords like "ID: 12"
  local keywords=$2
  local command=""
  local dmsg_sh="/tmp/dmesg_filter.sh"
  local word=""
  local filter_info=""

  if [[ -z "$keywords" ]]; then
    command="dmesg"
  else
    command="dmesg | grep -i \"$keywords\""
  fi
  for word in $str; do
    command="${command} | grep -i $word"
  done

  is_boot_dmesg_included || test_print_wrg "Dmesg didn't start with 0.00"
  test_print_trc "$command"
  echo "$command" > "$dmsg_sh"
  chmod 755 "$dmsg_sh"

  filter_info=$($dmsg_sh)
  if [[ -z "$filter_info" ]]; then
    if [[ "$exist" == "$CONTAIN" ]]; then
      die "No matched filter info: |$str|$keywords| found:$filter_info"
    elif [[ "$exist" == "$NULL" ]]; then
      test_print_trc "No filter info as expected:|$str|$keywords|:$filter_info"
    else
      die "Invalid parm exist:$exist"
    fi
  else
    if [[ "$exist" == "$CONTAIN" ]]; then
      test_print_trc "Found filter info: |$str|$keywords|:$filter_info"
    elif [[ "$exist" == "$NULL" ]]; then
      die "Contain filer unexpectedly:|$str|$keywords|:$filter_info"
    else
      die "Invalid parm exist:$exist"
    fi
  fi
}

# Check whether there is cxl PCI exist in dmesg log
# Input:
#   $1: key word
# Output: return 0 for true, otherwise for false
cxl_dmesg_check() {
  local cxl_keyword=$1
  local cxl_dmesg_path="/tmp/cxl_dmesg.txt"
  local result=""

  is_boot_dmesg_included || test_print_wrg "Dmesg didn't start with 0.00"
  dump_dmesg "$cxl_dmesg_path"
  result=$(cat "$cxl_dmesg_path" | grep "$cxl_keyword")
  if [[ -n "$result" ]]; then
    test_print_trc "There is cxl keyword \"$cxl_keyword\":$result"
  else
    test_print_trc "There is no cxl keyword \"$cxl_keyword\":$result"
    return 1
  fi
}

# Check where it's legacy capability pci or cxl pci in lspci
# Input: none
cxl_lspci_check() {
  local cxl_key="CXL"
  local legacy_pci_info="Designated Vendor-Specific"
  local pcis=""
  local pci=""
  local result=""
  local cxl_num=0
  local cxl_info_path="/tmp/cxl.info"

  result=$(lspci -vv -s  "*:*" | grep "$legacy_pci_info")
  cat /dev/null > "$cxl_info_path"

  pcis=$(lspci | cut -d ' ' -f 1)
  for pci in $pcis; do
    result=""
    result=$(lspci -vv -s "$pci" | grep "$cxl_key")
    [[ -z "$result" ]] || {
      test_print_trc "pci $pci support CXL"
      CXL_PCIS="$CXL_PCIS ""$pci"
      echo "PCI $pci" >> "$cxl_info_path"
      echo "$result" >> "$cxl_info_path"
      ((cxl_num+=1))
    }
  done
  if [[ "$cxl_num" -eq 0 ]]; then
    die "Could not find cxl supported pci in lspci"
  else
    test_print_trc "Found $cxl_num support cxl:"
    cat "$cxl_info_path"
  fi
}

fill_sysfs() {
  local filled_item=$1
  local sysfs=$2
  local expected=$3
  local result=""

  [[ -e "$sysfs" ]] || die "No sysfs file:$sysfs found."
  do_cmd "echo $filled_item > $sysfs"
  result=$(cat "$sysfs")
  if [[ "$result" != "$expected" ]]; then
    die "Set $sysfs to $sysfs, result:$result not expected:$expected"
  fi
}

# Check whether there is matched info in cxl tool tests
# Input:
#   $1: test tool name
#   $2: test tool parameter
#   $3: test result filter key word
# Output: return 0 for true, otherwise for false
cxl_tool_test() {
  local bin_name=$1
  local parm=$2
  local filter=$3
  local log_file="/tmp/cxl_tool.log"
  local result=""
  local path=""

  [[ -n "$bin_name" ]] || block_test "tool name should not be null:$bin_name"
  path=$(which "$bin_name")
  [[ -e "$path" ]] || block_test "no $path file"
  do_cmd "$bin_name $parm > $log_file"
  result=$(cat "$log_file" | grep "$filter")
  if [[ -z "$result" ]]; then
    test_print_trc "There is no $filter in $log_file"
    return 1
  else
    test_print_trc "There is $filter in $log_file: $result"
    return 0
  fi
}

# Find all CXL PCIE and save it in to CXLS
# Input: NA
# Output: return 0 for true, otherwise for false
find_cxl_pcie()
{
  CXLS=""
  CXLS=$(pcie_check x 4 16 1e98 \
      | grep "^Find" \
      | grep "$CXL_PCI" \
      | cut -d ' ' -f 5)
  if [[ -z "$CXLS" ]]; then
    die "No CXLS:$CXLS found"
  else
    test_print_trc "Find CXLS:$CXLS"
  fi
}

# Execute test tool and save it into requested log file and show results
# Input:
#   $1: test tool
#   $2: cxl check parameter
#   $2: saved log file name
# Output: return 0 for true, otherwise for false
cxl_reg_check()
{
  local test_tool=$1
  local test_parm=$2
  local log_file="/tmp/$3"

  $test_tool $test_parm > "$log_file"
  test_print_trc "log_file:$log_file"
  cat "$log_file"
}

# Verify requested log file contain the expected register or not
# Input:
#   $1: cxl PCIe
#   $2: saved log file name
# Output: return 0 otherwise for die
cxl_verify()
{
  local cxl_pci=$1
  local log_file="/tmp/$2"
  local exist="as expected"
  local not_exist="not"
  local result_exist=""
  local result_not_exist=""

  result_exist=$(cat "$log_file" | grep "$cxl_pci" | grep "$exist")
  result_not_exist=$(cat "$log_file" | grep "$cxl_pci" | grep "$not_exist")

  if [[ -n "$result_exist" ]]; then
    [[ -n "$result_not_exist" ]] && die "Both $exist & $not_exist in $log_file"
    test_print_trc "$cxl_pci contain $2 register"
    RESULT=1
  else
    [[ -n "$result_not_exist" ]] ||
      die "$cxl_pci no exist and not exist both in $log_file"
    test_print_trc "$cxl_pci didn't conatain $2 register"
    RESULT=0
  fi
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
  test_print_trc "key:$key in dmesg info:$dmesg_result"
  case $par in
    $CONTAIN)
      [[ -n "$dmesg_result" ]] || die "No $key in dmesg:$dmesg_result"
      ;;
    $NULL)
      [[ -z "$dmesg_result" ]] \
        || die "Should not contain $key in dmesg:$dmesg_result"
      ;;
    *)
      block_test "Invalid par:$par"
      ;;
  esac
}

# Check aer_inject module is enabled or not, if it's not enabled, will enable
# Input: NA
# Output: return 0 otherwise for die
aer_inject_support()
{
  local aer_inject="aer_inject"

  if (load_unload_module.sh -c -d "$aer_inject"); then
    test_print_trc "contain module $aer_inject"
    return 0
  else
      test_print_trc "load module $aer_inject"
      load_unload_module.sh -l -d "$aer_inject"
  fi
  load_unload_module.sh -c -d "$aer_inject" \
    || block_test "Could not load module $aer_inject"
  return 0
}

# Verify cxl memory block base address is not 0
# Input:
#   $1: cxl register offset
# Output: return 0 otherwise for die
cxl_mem_check() {
  local offset=$1
  local result=""
  local cxl_tool=""

  cxl_tool=$(which $PCIE_CHECK_TOOL)
  test_print_trc "$cxl_tool x 20 32 | grep '$CXL_PCI'"
  result=$($cxl_tool x $offset 32 \
          | grep "$CXL_PCI" \
          | awk -F 'reg_value:' '{print $2}' \
          | cut -d ',' -f 1 \
          | cut -d '.' -f 1)
  if [[ "$result" == "0" ]]; then
    die "cxl memory offset $1 result:$result, which should not 0."
  else
    test_print_trc "cxl memory offset $1 result:$result is not 0, pass."
  fi
}

# Verify requested cxl pcie could check error injection correctly
# Input:
#   $1: cxl rcec type
# Output: return 0 otherwise for die
cxl_rcec_test()
{
  local type=$1
  local cxl_pcie=""
  local cxl_bus=""
  local rcec_pci=""

  aer_inject_support
  cxl_pcie=$(pcie_check x 6 16 380 \
            | grep "$MATCH" \
            | grep "$CXL_PCI" \
            | cut -d ' ' -f 5 \
            | head -n 1)
  [[ -n "$cxl_pcie" ]] || block_test "No CXL PCIE:$cxl_pcie found"
  cxl_bus=$(echo $cxl_pcie | cut -d ':' -f 1)
  rcec_pci=$(pcie_check v 07 9 8 $cxl_bus \
            | grep "$MATCH" \
            | cut -d ' ' -f 5 \
            | head -n 1)
  if [[ -z "$rcec_pci" ]]; then
    test_print_wrg "No matched rcec PCI:$rcec_pci found for cxl pcie:$cxl_pcie"
  else
    test_print_trc "Found cxl pcie:$cxl_pcie matched rcec:$rcec_pci"
  fi
  type=$(which $type)
  do_cmd "aer-inject -s $cxl_pcie $type"
  dmesg_check "$rcec_pci: AER" "$CONTAIN"
  dmesg_check "$cxl_pcie" "$CONTAIN"
}

find_cxl_mem_dport() {
  local cxl_ports=""
  local cxl_port=""
  local has_dport=""
  local cxl_dport=""

  cxl_ports=$(ls "$CXL_DEV_PATH" | grep "port")
  for cxl_port in $cxl_ports; do
    has_dport=""
    has_dport=$(ls "$CXL_DEV_PATH"/"$cxl_port" | grep ^dport)
    if [[ -z "$has_dport" ]]; then
      continue
    else
      CXL_DPORTS=" ${CXL_DEV_PATH}/${cxl_port}/${has_dport}"
    fi
  done

  if [[ -z "$CXL_DPORTS" ]]; then
    block_test "No CXL MEM dport $CXL_DEV_PATH/port*/dport*/ found:$CXL_DPORTS"
  else
    test_print_trc "Find CXL MEM dport:"
    for cxl_dport in $CXL_DPORTS; do
      test_print_trc "$cxl_dport PCI:$(ls -l $cxl_dport | awk -F '/' '{print $NF}')"
      test_print_trc "  - Related PCI:$(ls -l ${cxl_dport}/ | grep "000" | awk -F " " '{print $NF}')"
    done
  fi
}

check_cxl_mem_dport_isolation() {
  local cxl_dport=""
  local dport_iso=""

  find_cxl_mem_dport
  for cxl_dport in $CXL_DPORTS; do
    dport_iso=""
    dport_iso=$(ls -l "$cxl_dport"/ | grep "$ISOLATION")
    if [[ -n "$dport_iso" ]]; then
      test_print_trc "Find $dport_iso in $cxl_dport:$(ls -l $cxl_dport | awk -F '/' '{print $NF}')"
      CXL_ISO_DPORTS="$CXL_ISO_DPORTS $cxl_dport"
    fi
  done
  # CXL_ISO_DPORTS: /sys/bus/cxl/devices/port2/dport0/
  [[ -n "$CXL_ISO_DPORTS" ]] || block_test "No CXL MEM $ISOLATION dport found:$CXL_ISO_DPORTS"
}

enable_cxl_mem_isolation() {
  local dport_path=$1

  test_print_trc "grep -H . ${dport_path}/${ISOLATION}/*"
  grep -H . "${dport_path}/${ISOLATION}/"*
  fill_sysfs "0" "${dport_path}/${ISOLATION}/${MEM_TIMEOUT}" "$DISABLED"
  fill_sysfs "0" "${dport_path}/${ISOLATION}/${MEM_ISO}" "$DISABLED"
  fill_sysfs "1" "${dport_path}/${ISOLATION}/${MEM_ISO}" "$ENABLED"
  fill_sysfs "1" "${dport_path}/${ISOLATION}/${MEM_TIMEOUT}" "$ENABLED"
  grep -H . "${dport_path}/${ISOLATION}/"*
}

enable_cxl_mem_interrupt() {
  local dport_path=$1

  fill_sysfs "0" "${dport_path}/${ISOLATION}/${MEM_AER}" "$DISABLED"
  fill_sysfs "0" "${dport_path}/${ISOLATION}/${MEM_INT}" "$DISABLED"
  fill_sysfs "1" "${dport_path}/${ISOLATION}/${MEM_INT}" "$ENABLED"
  fill_sysfs "1" "${dport_path}/${ISOLATION}/${MEM_AER}" "$ENABLED"
  grep -H . "${dport_path}/${ISOLATION}/"*
}

cxl_dcd_region() {
  local ret=""

  [[ -e "${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION}" ]] || {
    die "${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION} doesn't exist!"
  }

  TARGET_REGION=$(cat ${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION})
  # Below command will be failed as expected, and just show the cmd and info
  test_print_trc "grep -H . ${CXL_DEV_PATH}/${DECODER}0.0/*"
  grep -H . ${CXL_DEV_PATH}/${DECODER}0.0/*
  [[ -z "$TARGET_REGION" ]] && die "${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION}:$TARGET_REGION is null"

  echo "$TARGET_REGION" > "${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION}"
  ret=$?
  grep -H . ${CXL_DEV_PATH}/${DECODER}0.0/*

  if [[ "$ret" == "0" ]]; then
    test_print_trc "echo $TARGET_REGION > ${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION}, ret:$ret, pass."
  else
    die "echo $TARGET_REGION > ${CXL_DEV_PATH}/${DECODER}0.0/${CREATE_DC_REGION}, ret:$ret, fail."
  fi
}

create_cxl_dcd_region() {
  local granular="256"
  local size="0x400000000"

  cxl_dcd_region
  grep -H . "${CXL_DEV_PATH}/${DECODER}0.0/${TARGET_REGION}/"*
  do_cmd "echo $granular > ${CXL_DEV_PATH}/${DECODER}0.0/${TARGET_REGION}/interleave_granularity"
  do_cmd "echo 1 > ${CXL_DEV_PATH}/${DECODER}0.0/${TARGET_REGION}/interleave_ways"
  do_cmd "echo $size > ${CXL_DEV_PATH}/${DECODER}0.0/${TARGET_REGION}/size"
  # No target0, will check further in cxl dcd part code
  #do_cmd "echo decoder1.0 > ${CXL_DEV_PATH}/${DECODER}0.0/${TARGET_REGION}/target0"
  # Below step will fail in dmr simics, check further
  do_cmd "echo 1 > ${CXL_DEV_PATH}/${DECODER}0.0/${TARGET_REGION}/commit"
  # bind will fail in dmr simics
  do_cmd "echo $TARGET_REGION > ${CXL_PATH}/drivers/cxl_region/bind"
}

install_tool_pkg() {
  local tool_name=$1
  local pkg_name=$2
  local cxl_tool_path=""

  cxl_tool_path=$(which "$tool_name" 2>/dev/null)
  if [[ -z "$cxl_tool_path" ]]; then
    test_print_trc "No $tool_name tool, install it: yum -y install $pkg_name"
    yum -y install "$pkg_name"
  else
    return 0
  fi

  cxl_tool_path=$(which "$tool_name" 2>/dev/null)
  [[ -n "$cxl_tool_path" ]] || {
    block_test "Still no $tool_name tool after yum -y install $pkg_name"
  }
}

check_cxl_tool() {
  install_tool_pkg "cxl" "cxl-cli.x86_64"
  install_tool_pkg "numactl" "numactl.x86_64"
  install_tool_pkg "daxctl" "daxctl.x86_64"
}

cxl_driver_test()
{
  local drv_name=$1
  local drv_path=""
  local dev_mod=""

  drv_path=$(which "$drv_name")
  dev_mod=$(echo "$dev_name" | cut -d '.' -f 1)
  [[ $(lsmod | grep "$dev_mod") ]] && {
    test_print_trc "$dev_mod is loaded, rmmod $dev_mod first"
    do_cmd "rmmod $drv_path"
  }
  do_cmd "insmod $drv_path"
  sleep 1
  do_cmd "rmmod $drv_path"
}
