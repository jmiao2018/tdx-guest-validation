#!/bin/bash
###############################################################################
# Copyright (C) 2019, Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################

############################ CONTRIBUTORS #####################################
# @Author   Hongyu, Ning <hongyu.ning@intel.com>
#
# Jan, 17, 2019. Hongyu, Ning <hongyu.ning@intel.com>
#     - Initial version, defination of smbus test parameters

############################ DESCRIPTION ######################################
# @desc     This script defined all smbus common test parameters,
#           to be sourced by each smbus test script
# @returns
# @history  2019-01-17: First version

############################# FUNCTIONS #######################################

source "common.sh"
source "smbus_common.sh"
source "st_log.sh"

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-r case_name CASE] [-h Help]
  -r case_name   CASE to run
  -h Help        print this usage
EOF
}


declare -a bus_addr_array
#unset it to get register addr of new SMBus addr
declare -a valid_reg_addr_array
declare bus_number

# function to check smbus driver status
smbus_drv_chk() {
  #check kconfig setting first
  local koption1
  local koption2
  koption1=$(get_kconfig ${I2C_SMBUS})
  koption2=$(get_kconfig ${I2C_I801})
  if [[ ${koption2} = "m" ]]; then
    test_print_trc "kconfig option ${I2C_I801} is set to 'm'"
    modprobe ${SMBUS_MOD} || die "failed to modprobe module ${SMBUS_MOD}"
  elif [[ ${koption2} = "y" ]]; then
    test_print_trc "kconfig option ${I2C_I801} is set to 'y'"
  else
    die "kconfig option ${I2C_I801} is not set to 'm' or 'y', cannot do further test"
  fi

  if [[ ${koption1} = "m" ]]; then
    test_print_trc "kconfig option ${I2C_SMBUS} is set to 'm'"
  elif [[ ${koption1} = 'y' ]]; then
    test_print_trc "kconfig option ${I2C_SMBUS} is set to 'y'"
  else
    die "kconfig option ${I2C_SMBUS} is not set to 'm' or 'y', cannot do further test"
  fi
  #check module loading status
  lsmod | grep -i ${SMBUS_MOD} || \
    die "module ${SMBUS_MOD} not loaded, cannot do further test"
  #driver path check
  ls ${SMBUS_DRV} > /dev/null 2>&1 || die "SMBus driver check failed"
  test_print_trc "SMBus driver check PASS"
}

# function to get SMBus host controller bus number
smbus_host_ctrller_num() {
  local bus_num
  i2cdetect -l | grep -i ${HOST_CTRLLER} > /dev/null 2>&1 || \
    die "cannot find smbus host controller device"
  bus_num=$(i2cdetect -l | grep -i ${HOST_CTRLLER} | awk '{print $1}' | cut -d '-' -f 2)
  if [[ -n ${bus_num} ]]; then
    echo "${bus_num}"
  else
    die "failed to find SMBus host controller bus number"
  fi
}

# function to check SMBus host controller functionality
smbus_host_ctrller_func() {
  local bus_num=$1
  test_print_trc "Start to check SMBus host controller functionality"
  do_cmd "i2cdetect -F ${bus_num}"
  i2cdetect -F ${bus_num} | grep "I2C" | awk '{print $1,$2}' | grep "I2C no" || \
    die "SMBus host controller functionality check FAIL"
  test_print_trc "SMBus host controller functionality check PASS"
}

# function to get SMBus host controller address
smbus_host_ctrller_addr() {
  local bus_num=$1
  test_print_trc "Start to get SMBus host controller address"
  i=1
  while [ $i -le 17 ]; do
    bus_addr_tmp=$(i2cdetect -y -r ${bus_num} | awk '{print $i}' i=$i | grep -v "\-\-")
    (( i++ ))
    for j in ${bus_addr_tmp}; do
      case "$j" in
        [0-9])
          ;;
        [a-z])
          ;;
        *)
          if [[ $j = *: ]];then
            test_print_trc "Non SMBus addr: $j, ignore it"
          elif [[ "0x$j" -eq "0x31" ]]; then
            test_print_trc "Invalid SMBus addr: $j, ignore it"
          else
            test_print_trc "Found SMBus host controller addr: $j, adding it to bus_addr_array"
            bus_addr_array=("${bus_addr_array[@]}" "0x$j")
          fi
          ;;
      esac
    done
  done
  if [[ ${#bus_addr_array[@]} != 0 ]]; then
    for k in "${bus_addr_array[@]}"; do
      test_print_trc "SMBus host controller addr: $k"
    done
  else
    die "Fail to find any SMBus host controller addr"
  fi
}

# function to get an invalid address of SMBus host controller
smbus_invalid_addr() {
  local invalid_addr
  local valid_addr
  for invalid_addr in "${SMBUS_ADDR_ARRAY[@]}"; do
    for valid_addr in "${bus_addr_array[@]}"; do
      if [[ "${invalid_addr}" != "${valid_addr}" ]];then
        echo "$invalid_addr"
        return 0
      fi
    done
    die "Fail to find an invalid address of SMBus host controller"
  done
}

# function to get SMBus register address
smbus_reg_addr() {
  local bus_num=$1
  local valid_addr=$2
  test_print_trc "Start to get SMBus register address"
  for i in "${REG_ADDR_ARRAY[@]}"; do
    i2cget -y "${bus_num}" "${valid_addr}" "$i" > /dev/null 2>&1 && \
      valid_reg_addr_array=("${valid_reg_addr_array[@]}" $i)
  done
  if [[ ${#valid_reg_addr_array[@]} != 0 ]]; then
    test_print_trc "Get valid register address succeed"
  else
    test_print_wrg "Do not get valid register address for SMBus addr ${valid_addr}"
  fi
}

# function to get SMBus PCI node
smbus_pci_node() {
  local pci_node
  lspci | grep -i 'smbus' > /dev/null 2>&1 || die "Failed to find SMBus on pci"
  pci_node=$(lspci | grep -i 'smbus' | awk '{print $1}')
  if [[ -n ${pci_node} ]]; then
    echo "${pci_node}"
  else
    die "Fail to find pci_node of SMBus host controller"
  fi
}

# function to check and return if platform support runtime PM for SMBus PCI device
smbus_runtime_PM() {
  #echo 0 if support runtime PM and 1 if not support
  local support_runtime_PM=1
  local pci_node
  pci_node=$(smbus_pci_node)
  if (lspci -s "${pci_node}" -vvv | grep -i "Power Management"); then
    support_runtime_PM=0
    echo "${support_runtime_PM}"
  else
    support_runtime_PM=1
    echo "${support_runtime_PM}"
  fi
}

################################ DO THE WORK ##################################
source "common.sh"
source "smbus_common.sh"
source "st_log.sh"

while getopts :r:h arg; do
  case $arg in
    r)
      TESTCASE=$OPTARG
      ;;
    h)
      usage && exit 0
      ;;
    :)
      test_print_err "Must supply an argument to -$OPTARG."
      usage && exit 1
      ;;
    \?)
      test_print_err "Invalid Option -$OPTARG ignored."
      usage && exit 1
      ;;
  esac
done

# modprobe $SMBUS_MOD when CONFIG_I2C_I801 is set to m in case it's not probed during boot-up
koption=$(get_kconfig ${I2C_I801})
if [[ ${koption} = "m" ]]; then
  test_print_trc "kconfig option ${I2C_I801} is set to 'm'"
  modprobe ${SMBUS_MOD} || die "failed to modprobe module ${SMBUS_MOD}"
elif [[ ${koption} = "y" ]]; then
  test_print_trc "kconfig option ${I2C_I801} is set to 'y'"
else
  block_test "kconfig option ${I2C_I801} is not set to 'm' or 'y', cannot do further test"
fi
# check if $SMBUS_MOD is probed correctly
lsmod | grep -i ${SMBUS_MOD} || \
  block_test "module ${SMBUS_MOD} not loaded, cannot do further test"

bus_number=$(smbus_host_ctrller_num)
test_print_trc "SMBus host controller bus number: ${bus_number}"
smbus_host_ctrller_addr "${bus_number}"

case $TESTCASE in
  DRV_CHECK)
    test_print_trc "Start SMBUS_XS_FUNC_DRV_CHECK test"
    smbus_drv_chk
    ;;
  DEV_CHECK)
    test_print_trc "Start SMBUS_XS_FUNC_DEV_CHECK test"
    dev_node="00:1f.4"
    dev_id=$(lspci -nn | grep -w ${dev_node} | awk -F : '{print $4}' | awk -F ] '{print $1}')
    test_print_trc "SMBus host controller device id: ${dev_id}"
    i2cdetect -l | grep -i ${HOST_CTRLLER} || \
      die "Fail to find SMBus host controller device"
    test_print_trc "Find SMBus host controller device, check PASS"
    ;;
  GET_FUNCTIONALITY)
    test_print_trc "Start SMBUS_XS_FUNC_GET_FUNCTIONALITY test"
    smbus_host_ctrller_func "${bus_number}"
    ;;
  SMBUS_ADDR_DETECT)
    test_print_trc "Start SMBUS_XS_FUNC_SLAVE_ADDR_DETECT test"
    unset bus_addr_array
    smbus_host_ctrller_addr "${bus_number}"
    test_print_trc "Find all SMBus host controller address as above, check PASS"
    ;;
  VALID_ADDR_REG_RD)
    test_print_trc "Start SMBUS_XS_FUNC_POS_VALID_ADDR_REG_RD test"
    for valid_addr in "${bus_addr_array[@]}"; do
      smbus_reg_addr "${bus_number}" "${valid_addr}"
      test_print_trc "Start to read SMBus on valid addr ${valid_addr}"
      for valid_reg_addr in "${valid_reg_addr_array[@]}"; do
        if ( i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" b > /dev/null 2>&1 ); then
          i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" b > /dev/null 2>&1 && \
            test_print_trc "Succeed to read SMBus addr ${valid_addr} on register ${valid_reg_addr} with 'read byte' protocol"
          i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" w > /dev/null 2>&1 && \
            test_print_trc "Succeed to read SMBus addr ${valid_addr} on register ${valid_reg_addr} with 'read word' protocol"
          i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" c > /dev/null 2>&1 && \
            test_print_trc "Succeed to read SMBus addr ${valid_addr} on register ${valid_reg_addr} with 'write byte/read byte' protocol"
          i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" bp > /dev/null 2>&1 && \
            test_print_trc "Succeed to read SMBus addr ${valid_addr} on register ${valid_reg_addr} with 'read byte+PEC' protocol"
          i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" wp > /dev/null 2>&1 && \
            test_print_trc "Succeed to read SMBus addr ${valid_addr} on register ${valid_reg_addr} with 'read word+PEC' protocol"
          i2cget -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" cp > /dev/null 2>&1 && \
            test_print_trc "Succeed to read SMBus addr ${valid_addr} on register ${valid_reg_addr} with 'write byte/read byte+PEC' protocol"
          unset valid_reg_addr_array
          test_print_trc "Read on a valid SMBus addr: ${valid_addr} succeed, check PASS"
          exit 0
        else
          unset valid_reg_addr_array
          break
        fi
      done
      unset valid_reg_addr_array
      test_print_wrg "Not possible to check read on a valid SMBus addr: ${valid_addr}"
    done
    die "Fail to check read on valid SMBus addr"
    ;;
  INVALID_ADDR_REG_RD)
    test_print_trc "Start SMBUS_XS_FUNC_NEG_INVALID_ADDR_REG_RD test"
    invalid_addr=$(smbus_invalid_addr)
    i2cget -y "${bus_number}" "${invalid_addr}" "0x10" && \
      die "Fail to check read on an invalid SMBus addr ${invalid_addr}"
    test_print_trc "Read on an invalid SMBus addr: ${invalid_addr} check PASS"
    exit 0
    ;;
  VALID_ADDR_DUMP)
    test_print_trc "Start SMBUS_XS_FUNC_VALID_ADDR_DUMP test"
    for valid_addr in "${bus_addr_array[@]}"; do
      i2cdump -y ${bus_number} ${valid_addr} b || \
        die "Fail to dump SMBus addr ${valid_addr} with 'read byte' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" w > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'read word' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" W > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'read word on even register addr' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" s > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'block read' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" i > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'i2c block read' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" c > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'consecutive byte' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" bp > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'read byte+PEC' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" wp > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'read word+PEC' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" Wp > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'read word on even register addr+PEC' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" sp > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'block read+PEC' protocol"
      i2cdump -y "${bus_number}" "${valid_addr}" cp > /dev/null 2>&1 && \
        test_print_trc "Succeed to dump SMBus addr ${valid_addr} with 'consecutive byte+PEC' protocol"
    done
    test_print_trc "SMBus addr dump check PASS on all valid addresses"
    ;;
  VALID_ADDR_REG_WR)
    test_print_trc "Start SMBUS_XS_FUNC_POS_VALID_ADDR_REG_WR test"
    for valid_addr in "${bus_addr_array[@]}"; do
      smbus_reg_addr "${bus_number}" "${valid_addr}"
      for valid_reg_addr in "${valid_reg_addr_array[@]}"; do
        if ( i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" b > /dev/null 2>&1 ); then
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" c > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write byte no value' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" w > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write word' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" i > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write i2c block data' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" s > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write block data' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" cp > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write byte no value+PEC' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" bp > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write byte+PEC' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" wp > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write word+PEC' protocol"
          i2cset -y "${bus_number}" "${valid_addr}" "${valid_reg_addr}" "0xfe" sp > /dev/null 2>&1 && \
            test_print_trc "Succeed to write on a valid SMBus addr:${valid_addr} with 'write block data+PEC' protocol"
          unset valid_reg_addr_array
          test_print_trc "Write on a valid SMBus addr: ${valid_addr} succeed, check PASS"
          exit 0
        else
          unset valid_reg_addr_array
          break
        fi
      done
      unset valid_reg_addr_array
      test_print_wrg "Not possible to check write on a valid SMBus addr: ${valid_addr}"
    done
    die "Fail to check write on valid SMBus addr"
    ;;
  INVALID_ADDR_REG_WR)
    test_print_trc "Start SMBUS_XS_FUNC_NEG_INVALID_ADDR_REG_WR test"
    invalid_addr=$(smbus_invalid_addr)
    i2cset -y "${bus_number}" "${invalid_addr}" "0x10" "0xfe" b && \
      die "Fail to check write on an invalid SMBus addr ${invalid_addr}"
    test_print_trc "Write on an invalid SMBus addr: ${invalid_addr} check PASS"
    exit 0
    ;;
  RT_PM_CHECK)
    test_print_trc "Start SMBUS_XS_FUNC_RUNTIME_PM_SUPPORT_CHECK test"
    support_runtime_PM=$(smbus_runtime_PM)
    if [[ ${support_runtime_PM} = 1 ]]; then
      test_print_trc "Platform does not support runtime PM for SMBus PCI device"
    else
      test_print_trc "Platform support runtime PM for SMBus PCI device"
      test_print_trc "To check PM status change between D3 and D0 in TC: SMBUS_XS_FUNC_RUNTIME_PM_AUTO_SUSPENDED"
    fi
    ;;
  RT_PM_AUTO_SUSPENDED)
    test_print_trc "Start SMBUS_XS_FUNC_RUNTIME_PM_AUTO_SUSPENDED test"
    support_runtime_PM=$(smbus_runtime_PM)
    pci_bus=$(lspci | grep -i smbus | awk -F ':' '{print $1}')
    [ ${#pci_bus} -eq 4 ] && \
      pci_bus=$(lspci | grep -i smbus | awk -F ':' '{print $2}')
    pci_sub_node=$(lspci | grep -i smbus | awk -F ':' '{print $2}' | awk '{print $1}')
    [ ${#pci_sub_node} -eq 2 ] && \
      pci_sub_node=$(lspci | grep -i smbus | awk -F ':' '{print $3}' | awk '{print $1}')
    if [[ -z ${pci_bus} ]] || [[ -z ${pci_sub_node} ]]; then
      die "Fail to get pci_bus or pci_sub_node value for SMBus PCI device"
    fi
    for valid_addr in "${bus_addr_array[@]}"; do
      i2cdump -y -r "0x0-0x7f" "${bus_number}" "${valid_addr}" b || \
        die "Fail to dump SMBus addr ${valid_addr}"
      if (grep . /sys/bus/pci/devices/0000\:${pci_bus}\:${pci_sub_node}/power/* | grep "runtime_status:active"); then
        test_print_trc "SMBus PCI device switched to runtime_status: active as expected"
      else
        die "Runtime PM status not change to active, not expected"
      fi
      test_print_trc "Wait for 1 second and check the runtime_status again"
      sleep 3
      if (grep . /sys/bus/pci/devices/0000\:${pci_bus}\:${pci_sub_node}/power/* | grep "runtime_status:suspended"); then
        test_print_trc "SMBus PCI device switched to runtime_status: suspended as expected"
      else
        die "Runtime PM status not switch to suspended, not expected"
      fi
    done
    if [[ $support_runtime_PM = 0 ]]; then
      for valid_addr in "${bus_addr_array[@]}"; do
        i2cdump -y -r "0x0-0x7f" "${bus_number}" "${valid_addr}" b || \
          die "Fail to dump SMBus addr ${valid_addr}"
        if (lspci -s "${pci_node}" -vvv | grep -i "Status: D0"); then
          test_print_trc "SMBus PCI device switched to D0 status, as expected"
        else
          die "SMBus PCI device not switched to D0 status, not expected"
        fi
        test_print_trc "Wait for 1 second and check the PM status again"
        sleep 3
        if (lspci -s "${pci_node}" -vvv | grep -i "Status: D3"); then
          test_print_trc "SMBus PCI device switched to D3 status, as expected"
        else
          die "SMBus PCI device not switched to D3 status, not expected"
        fi
      done
    fi
    ;;
  :)
    test_print_err "Must specify the test case option by [-r case_name]"
    usage && exit 1
    ;;
  \?)
    test_print_err "Input test case option $TESTCASE is not supported"
    usage && exit 1
    ;;
esac
