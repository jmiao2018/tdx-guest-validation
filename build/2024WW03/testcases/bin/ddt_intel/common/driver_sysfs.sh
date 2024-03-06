#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2017, Intel - http://www.intel.com
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

# @Author   Juan Carlos Alonso <juan.carlos.alonso@intel>
#
# Jun, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Initial draft.
#     - Added an 'if' statement to skip check if $DRV_MOD_NAME
#       is loaded/unloaded when it is null.
#     - Update 'check_drv_sysfs()' function to test correct devices if they
#       are symbolic link.
# Jul, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Replace 'lsmod' commands with 'load_unload_module.sh -c' function
#       calls to check if driver module is loaded/unloaded.
#     - Remove 'do_cmd' when 'load_unload_module.sh -c' is called.
#     - Add 'is_kmodule_loaded()' function to improve logic and save code. This
#       function executes other scripts to load/unload kernel module drivers.
#     - Add 'is_kmodule_builtin()' function call to skip the logic executed
#       when driver is configured as module.
# Aug,2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Add 'enumeration_device_id' function to check if the enumeration id of
#       any device and kernel module in use is correct
#     - Update 'check_drv_sysfs()' function to test different attributes from devices
#       with and without symlinks option
# Jan, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Fix 'is_kmodule_loaded()' function to handle correctly the return
#       value from 'load_unload_module.sh -c -d ${kmodule}'.
# Oct, 29, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Add function spi_spi_nor_driver_check()
# Nov, 09, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Revised to seperate platform icl-u-rvp and other non spi specific platforms
# Apr, 25, 2019. Hongyu Ning <hongyu.ning@intel.com>
#     - Revised to support OSE_SPI_XS_BAT_DRV_CHECK test

############################ DESCRIPTION ######################################

# @desc     Test the sysfs attributes of all the wdt devices under /sys/class/
# @returns  0 if the execution was finished succesfully, else 1
# @history  2017-06-15: First version
# @history  2017-06-27: Added an 'if' statement to skip check $DRV_MOD_NAME.
#                       Update 'check_drv_sysfs()'.
# @history 2017-07-05: Added 'load_unload_module.sh -c' functiona call.
# @history 2017-07-06: Remove 'do_cmd' to 'load_unload_module.sh -c call.
# @history 2017-07-12: Add 'is_kmodule_loaded()' function call.
#                      Add 'is_kmodule_builtin()' function.
# @history 2018-01-30: Fix 'is_kmodule_loaded()'
# @history 2018-10-29: Add function spi_spi_nor_drver_check()
# @history 2018-11-09: Revise to seperate support icl-u-rvp and other non spi specific plf
# @history 2019-01-16: Revise spi_spi_nor_drver_check() to fix driver check error on cfl-h plf
# @history 2019-04-25: Revise to support OSE_SPI_XS_BAT_DRV_CHECK test for ehl pltf ose spi test

############################# FUNCTIONS #######################################
usage() {
cat <<-EOF
  usage: ./${0##*/} [-d DRIVER] [-p PRECONDITIONS] [-s "a|h"] [-h Help]
    -d DRIVER       Driver in test
    -p PRECONDITION check preconditions and kconfigs
    -s a|h          check device sysfs a=without symlinks, h=with symlinks
    -e ENUMERATION  check for enumeration device ID
    -h Help         print this usage
EOF
}

check_drv_sysfs() {
  symlink=$1
  driver_sys_path=$2

  do_cmd "cd ${driver_sys_path}"
  if [[ "$symlink" == "a" ]]; then
    for attr in "${ATTRIBUTE[@]}"; do
      check_file "${attr}" "${driver_sys_path}" || return 1
      test_print_trc "Testing ${attr} sysfs"
    done
  elif [[ "$symlink" == "h" ]]; then
    for device in *; do
      if [[ -h "${driver_sys_path}/${device}" ]]; then
        test_print_trc "==========================================================="
        test_print_trc "Testing ${device} sysfs"
        test_print_trc "==========================================================="
        for attr in "${ATTRIBUTE[@]}"; do
          check_file "${attr}" "${driver_sys_path}/${device}" || return 1
          test_print_trc "Testing ${attr} sysfs"
        done
      fi
    done
  fi
  do_cmd "cd -"
  return 0
}

is_kmodule_loaded() {
  local kmodule=$1
  local unload=$2

  test_print_trc "Check if \"${kmodule}\" is loaded"
  if ! load_unload_module.sh -c -d "${kmodule}"; then
    test_print_trc "\"${kmodule}\" is NOT loaded. Proceed to load"
    do_cmd "load_unload_module.sh -l -d ${kmodule}"
    DRVS_LOADED+=("${kmodule}")
  else
    test_print_trc "\"${kmodule}\" is loaded"
    if [[ -n "${unload}" ]]; then
      test_print_trc "Proceed to unload"
      do_cmd "load_unload_module.sh -u -d ${kmodule}"
      DRVS_UNLOADED+=("${kmodule}")
    fi
  fi
}

enumeration_device_id() {
  if [[ -n "$KD" ]] && [[ -n "$ENUM_DEVICE" ]]; then
    if [[ "$OS" = "android"  ]]; then
      do_cmd "lspci -k| grep \"$KD\""
      test_print_trc "Kernel driver in use: $KD and Enumeration Device ID: $ENUM_DEVICE are correct"
    else
      do_cmd "lspci -d \"$ENUM_DEVICE\" -vv | grep \"$KD\""
      test_print_trc "Kernel driver in use: $KD and Enumeration Device ID: $ENUM_DEVICE are correct"
    fi
  else
      die "Kernel driver in use or Enumeration Device information is missing"
  fi
}

#spi pci driver status check function
spi_pci_driver_check() {
  device_type=$1
  spi_pci_driver_path=$2
  spi_pci_node_name=$3
  if [[ -n "${spi_pci_driver_path}" ]] && [[ -n "${spi_pci_node_name}" ]]; then
    if [[ -d "${spi_pci_driver_path}/${spi_pci_node_name}" ]]; then
      test_print_trc \
        "${device_type}'s pci driver has been registered on node ${spi_pci_node_name}, check succeeded!"
    else
      test_print_trc \
        "${device_type}'s pci driver has not been registered on node ${spi_pci_node_name}, check failed!"
      return 1
    fi
  elif [[ -z "${spi_pci_driver_path}" ]]; then
    die "No spi_pci_driver_path defined, can't do test"
  elif [[ -z "${spi_pci_node_name}" ]]; then
    die "No spi_pci_node_name defined, can't do test"
  else
    die "Wrong logic in spi_pci_driver_check function, please check"
  fi
}

spi_spi_nor_driver_check() {
  [[ $# -ne 1 ]] && die "spi_spi_nor_driver_check(): 1 and only 1 argument is required"
  dev_type=$1

  case "${dev_type}" in
    spi)
      if [[ -n "${SPI_DRV_PATH}" ]]; then
        if [[ "$OS" != "android" ]]; then
          modprobe ${DRV_MOD_NAME_1} || die "failed to probe module ${DRV_MOD_NAME_1}"
        fi
        if [[ -d "${SPI_DRV_PATH}" ]]; then
          test_print_trc "${dev_type}'s driver has been registered, check succeeded!"
        else
          test_print_trc "${dev_type}'s driver has not been registered, check failed!"
          return 1
        fi
      fi

      spi_pci_driver_check "${dev_type}" "${SPI_PCI_DRV_PATH}" "${SPI_PCI_NODE}"

      if [[ -n "${SPI_PXA_DRV_PATH}" ]]; then
        if [[ "$OS" != "android" ]]; then
          modprobe ${DRV_MOD_NAME} || die "failed to probe module ${DRV_MOD_NAME}"
        fi
        if [[ -d "${SPI_PXA_DRV_PATH}" ]]; then
          test_print_trc "${dev_type}'s pxa2xx driver has been registered, check succeeded!"
          return 0
        else
          test_print_trc "${dev_type}'s pxa2xx driver has not been registered, check failed!"
          return 1
        fi
      fi
      ;;
    ose_spi)
      if [[ -n "${OSE_SPI_PCI_DRV_PATH}" ]]; then
        if [[ "${OS}" != "android" ]]; then
          modprobe ${DRV_MOD_NAME_1} || die "failed to probe module ${DRV_MOD_NAME_1}"
        fi
        test_print_trc "Start driver test on ose spi host controller_0"
        spi_pci_driver_check "${dev_type}" "${OSE_SPI_PCI_DRV_PATH}" "${OSE_SPI_PCI_NODE_0}"
        test_print_trc "Start driver test on ose spi host controller_1"
        spi_pci_driver_check "${dev_type}" "${OSE_SPI_PCI_DRV_PATH}" "${OSE_SPI_PCI_NODE_1}"
        test_print_trc "Start driver test on ose spi host controller_2"
        spi_pci_driver_check "${dev_type}" "${OSE_SPI_PCI_DRV_PATH}" "${OSE_SPI_PCI_NODE_2}"
        test_print_trc "Start driver test on ose spi host controller_3"
        spi_pci_driver_check "${dev_type}" "${OSE_SPI_PCI_DRV_PATH}" "${OSE_SPI_PCI_NODE_3}"
      fi
      ;;
    spi_nor)
      if [[ -n "${SPI_NOR_PCI_DRV_PATH}" ]] && [[ -n "${SPI_NOR_PCI_NODE}" ]]; then
        if [[ -d "${SPI_NOR_PCI_DRV_PATH}/${SPI_NOR_PCI_NODE}" ]]; then
          test_print_trc "${dev_type}'s driver has been registered, check succeeded!"
          return 0
        else
          test_print_trc "${dev_type}'s driver has not been registered, check failed!"
          return 1
        fi
      fi
      ;;
    *)
      test_print_trc "Invalid device type: ${dev_type}, please check!"
      return 1
      ;;
  esac
}

################################ DO THE WORK ##################################

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

source "common.sh"
source "functions.sh"
export -f is_kmodule_builtin

while getopts :d:ps:eh arg; do
  case $arg in
    d)  DRIVER=$OPTARG ;;
    p)  CONFIG=1 ;;
    s)  SYSFS=$OPTARG;;
    e)  ENUM=1 ;;
    h)  usage && exit 0;;
    :)  test_print_err "Must supply an argument to -$OPTARG."
        usage && exit 1
        ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage && exit 1
        ;;
  esac
done

: ${CONFIG:='0'}
: ${ENUM:='0'}

# SOURCE SPECIFIC DRIVER COMMON SCRIPT
if [[ -n "${DRIVER}" ]]; then
  if [[ "${DRIVER}" != "spi" ]] && [[ "${DRIVER}" != "ose_spi" ]]; then
    source "${DRIVER}_common.sh" || die "${DRIVER}_common.sh does not exists"
  else
    if [[ "${SPI_BAT}" == "true" ]] && [[ "${DRIVER}" == "spi" ]]; then
      source "${DRIVER}_common.sh" || die "${DRIVER}_common.sh does not exists"
    elif [[ "${OSE_SPI_BAT}" == "true" ]] && [[ "${DRIVER}" == "ose_spi" ]]; then
      source "${DRIVER}_common.sh" || die "${DRIVER}_common.sh does not exists"
    else
      source "${DRIVER}_origin_common.sh" || die "${DRIVER}_origin_common.sh does not exists"
    fi
  fi
else
  die "Error. Must supply driver name in test"
fi

if [[ "${CONFIG}" -eq 1 ]]; then
# CHECK DRIVER REGISTRATION for SPI and SPI-NOR
  if [[ "${DRIVER}" == "spi" ]] || \
    [[ "${DRIVER}" == "spi-nor" ]] || \
    [[ "${DRIVER}" == "ose_spi" ]]; then
    test_print_trc "Start to check driver registration status"
    spi_spi_nor_driver_check "${DRIVER}" || die "Driver registration check FAIL for ${DRIVER}"
    test_print_trc "Driver registration check succeeded"
  fi
# CHECK PRECONDITIONS
  test_print_trc "Start to check driver kernel configurations"
  for config in "${!DRV_HASH[@]}"; do
    value=$(get_kconfig "${config}")
    if [[ "${value}" == "m" ]]; then
      test_print_trc "${config} is configured as module = ${value}"
      is_kmodule_loaded "${DRV_HASH[$config]}" "unload"
    elif [[ "${value}" == "y" ]]; then
      test_print_trc "${config} is configured as builtin = ${value}"
      test_print_trc "Nothing to do"
    fi
  done
  test_print_trc "Finished to check driver kernel configurations"


# CHECK DRIVER SYSFS
elif [[ -n "${SYSFS}" ]]; then
  if [[ -n "${DRV_MOD_NAME}" ]]; then
    if is_kmodule_builtin "${DRV_MOD_NAME}"; then
      test_print_trc "\"${DRV_MOD_NAME}\" is configured as builtin. Pass."
    else
      is_kmodule_loaded "${DRV_MOD_NAME}"
    fi
  fi
  check_drv_sysfs "$SYSFS" "$DRV_SYS_PATH" || die "Error on sysfs for ${DRV_MOD_NAME}"

  if [[ -n "${DRV_MOD_NAME_1}" ]]; then
    if is_kmodule_builtin "${DRV_MOD_NAME_1}"; then
      test_print_trc "\"${DRV_MOD_NAME_1}\" is configured as builtin. Pass."
    else
      is_kmodule_loaded "${DRV_MOD_NAME_1}"
    fi
  fi
  if [[ -n "${DRV_SYS_PATH_1}" ]]; then
    check_drv_sysfs "$SYSFS" "$DRV_SYS_PATH_1" || die "Error on sysfs for ${DRV_MOD_NAME_1}"
  fi

  if [[ -n "${DRV_MOD_NAME_2}" ]]; then
    if is_kmodule_builtin "${DRV_MOD_NAME_1}"; then
      test_print_trc "\"${DRV_MOD_NAME_2}\" is configured as builtin. Pass."
    else
      is_kmodule_loaded "${DRV_MOD_NAME_2}"
    fi
  fi
  if [[ -n "${DRV_SYS_PATH_2}" ]]; then
    check_drv_sysfs "$SYSFS" "$DRV_SYS_PATH_2" || die "Error on sysfs for ${DRV_MOD_NAME_2}"
  fi

  if [[ -n "${DRV_MOD_NAME_3}" ]]; then
    if is_kmodule_builtin "${DRV_MOD_NAME_3}"; then
      test_print_trc "\"${DRV_MOD_NAME_3}\" is configured as builtin. Pass."
    else
      is_kmodule_loaded "${DRV_MOD_NAME_3}"
    fi
  fi
  if [[ -n "${DRV_SYS_PATH_3}" ]]; then
    check_drv_sysfs "$SYSFS" "$DRV_SYS_PATH_3" || die "Error on sysfs for ${DRV_MOD_NAME_3}"
  fi
fi

# CHECK ENUMERATION DEVICE ID AND THE KERNEL MODULE RELATED
if [[ "${ENUM}" -eq 1 ]]; then
   enumeration_device_id || die "Error on device ID or kernel in use"
fi

# UNLOAD KMODULES IF THEY WERE LOADED
for driver in "${DRVS_LOADED[@]}"; do
  test_print_trc "Unload \"${driver}\""
  do_cmd "load_unload_module.sh -u -d ${driver}"
done

# LOAD KMODULES IF THEY WERE UNLOADED
for driver in "${DRVS_UNLOADED[@]}"; do
  test_print_trc "Load \"${driver}\""
  do_cmd "load_unload_module.sh -l -d ${driver}"
done
