#!/usr/bin/env bash
###############################################################################
#
# Copyright (C) 2017 Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
###############################################################################

############################ CONTRIBUTORS #####################################

# Author: Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#
# Jun, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Replace previous script for this new one. This script is more smart
#       and the logic code was reduced.
#     - Added logic to bind/unbind GPIO driver to its controller.
#     - Added an 'if' statement to skip check if $DRV_MOD_NAME
#       is loaded/unloaded when it is null.
# Jul, 2017. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Replace 'lsmod' commands with 'load_unload_module.sh -c' function
#       calls to check if driver module is loaded/unloaded.
#     - Remove 'do_cmd' when 'load_unload_module.sh -c' is called.
#     - Declare $DRIVER_ID_LIST as an array to store multiple devices.
#     - Add 'is_kmodule_loaded()' function to improve logic and save code. This
#       function executes other scripts to load/unload kernel module drivers.
#     - Add 'is_kmodule_builtin()' function call to skip the logic executed
#       when driver is configured as module.
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@instel.com>
#     - Added logic to bind/unbind ITH driver and ITH devices to its controller.
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@instel.com>
#     - Added logic to bind/unbind LPC driver and LPC devices to its controller.
# Oct, 30, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Add ${DRIVER_DIR} and ${DRIVER_ID_LIST} for spi and spi_nor
# Nov, 09, 2018. Hongyu Ning <hongyu.ning@intel.com>
#     - Revised to seperatly support icl-u-rvp and non spi specific platform

############################ DESCRIPTION ######################################

# @desc    This script gets the driver directory and driver ID, so it bind/unbind
#          the driver to the controller.
# @params  [ $DRIVER ]
# @return
# @history 2017-06-15: Created an initial draft for this new version of script.
# @history 2017-06-27: Added logic to bind/unbind GPIO driver.
#                      Added an 'if' statement to skip check $DRV_MOD_NAME.
# @history 2017-07-05: Added 'load_unload_module.sh -c' functiona call.
# @history 2017-07-06: Remove 'do_cmd' to 'load_unload_module.sh -c call.
#                      Declare $DRIVER_ID_LIST as an array.
# @history 2017-07-12: Add 'is_kmodule_loaded()' function call.
#                      Add 'is_kmodule_builtin()' function.
# @history 2018-10-30: Add ${DRIVER_DIR} and ${DRIVER_ID_LIST} for spi and spi_nor
# @history 2018-11-01: Revisied to seperatly support icl-u-rvp and non spi specific pltf

############################# FUNCTIONS #######################################

bind_unbind() {
  local dir=$1
  local id=$2

  # UNBIND DRIVER AND CONTROLLER
  test_print_trc "Trying to unbind ${id}"
  do_cmd "echo ${dir}/${id} > unbind"

  # BIND DRIVER AND CONTROLLER
  test_print_trc "Trying to bind ${id}"
  do_cmd "echo ${dir}/${id} > bind"
}

is_kmodule_loaded() {

  kmodule=$1

  test_print_trc "Check if \"${kmodule}\" is loaded"
  load_unload_module.sh -c -d "${kmodule}"
  if [[ "$?" -eq 1 ]]; then
    test_print_trc "\"${kmodule}\" is NOT loaded. Proceed to load"
    do_cmd "load_unload_module.sh -l -d ${kmodule}"
    DRVS_LOADED+=("${kmodule}")
  else
    test_print_trc "\"${kmodule}\" is loaded"
  fi
}


############################ DO THE WORK ######################################

source "common.sh"

DRIVER=$1
declare -a DRIVER_ID_LIST

# SOURCE SPECIFIC DRIVER COMMON SCRIPT
if [[ -n "${DRIVER}" ]]; then
  if [[ "${DRIVER}" != "spi" ]]; then
    source "${DRIVER}_common.sh" || die "${DRIVER}_common.sh does not exists"
  else
    if [[ "${SPI_BAT}" == "true" ]] || [[ "${OSE_SPI_BAT}" == "true" ]]; then
      source "${DRIVER}_common.sh" || die "${DRIVER}_common.sh does not exists"
    else
      source "${DRIVER}_origin_common.sh" || die "${DRIVER}_origin_common.sh does not exists"
    fi
  fi
else
  die "Error. Must supply driver name in test"
fi

# CHECK IF KMODULE IS LOADED
if [[ -n "${DRV_MOD_NAME}" ]]; then
  if is_kmodule_builtin "${DRV_MOD_NAME}"; then
    test_print_trc "\"${DRV_MOD_NAME}\" is configured as builtin. Pass."
  else
    is_kmodule_loaded "${DRV_MOD_NAME}"
  fi
fi

if [[ -n "${DRV_MOD_NAME_1}" ]]; then
  if is_kmodule_builtin "${DRV_MOD_NAME_1}"; then
    test_print_trc "\"${DRV_MOD_NAME_1}\" is configured as builtin. Pass."
  else
    is_kmodule_loaded "${DRV_MOD_NAME_1}"
  fi
fi

if [[ -n "${DRV_MOD_NAME_2}" ]]; then
  if is_kmodule_builtin "${DRV_MOD_NAME_2}"; then
    test_print_trc "\"${DRV_MOD_NAME_2}\" is configured as builtin. Pass."
  else
    is_kmodule_loaded "${DRV_MOD_NAME_2}"
  fi
fi

if [[ -n "${DRV_MOD_NAME_3}" ]]; then
  if is_kmodule_builtin "${DRV_MOD_NAME_3}"; then
    test_print_trc "\"${DRV_MOD_NAME_3}\" is configured as builtin. Pass."
  else
    is_kmodule_loaded "${DRV_MOD_NAME_3}"
  fi
fi

# SET PATH AND DRIVER ID
case "${DRIVER}" in
  atkbd)
    DRIVER_DIR="${ATKBD_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${ATKBD_BUS_PATH}" | grep "atkbd"))
    ;;
  ec)
    DRIVER_DIR="${EC_ACPI_PATH}"
    DRIVER_ID_LIST=($(ls "${EC_ACPI_PATH}" | grep "PNP"))
    ;;
  gpio)
    DRIVER_DIR="${GPIO_PLTF_PATH}"
    DRIVER_ID_LIST=($(ls "${GPIO_PLTF_PATH}" | grep "INT"))
    ;;
  ith)
    DRIVER_DIR="${ITH_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${ITH_BUS_PATH}" | grep "0-gth"))
    ;;
  lpc_ich)
    DRIVER_DIR="${LPC_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${LPC_BUS_PATH}" | grep "0000"))
    ;;
  msc)
    DRIVER_DIR="${MSU_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${MSU_BUS_PATH}" | grep "0-msc0"))
    ;;
  psmouse)
    DRIVER_DIR="${PSMOUSE_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${PSMOUSE_BUS_PATH}" | grep "psmouse"))
    ;;
  pti)
    DRIVER_DIR="${PTI_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${PTI_BUS_PATH}" | grep "0-pti"))
    ;;
  pwm)
    DRIVER_DIR="${PWM_PCI_PATH}"
    DRIVER_ID_LIST=($(ls "${PWM_PCI_PATH}" | grep "0000"))
    ;;
  sdhci)
    DRIVER_DIR="${SDHCI_PCI_PATH}"
    DRIVER_ID_LIST=($(ls "${SDHCI_PCI_PATH}" | grep "0000"))
    ;;
  spi)
    DRIVER_DIR="${SPI_PXA_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${SPI_PXA_DRV_PATH}" | grep "pxa2xx"))
    DRIVER_DIR_1="${SPI_DRV_PATH}"
    DRIVER_ID_LIST_1=($(ls "${SPI_DRV_PATH}" | grep "spi"))
    DRIVER_DIR_2="${SPI_PCI_DRV_PATH}"
    DRIVER_ID_LIST_2=($(ls "${SPI_PCI_DRV_PATH}" | grep "${SPI_PCI_NODE}"))
    ;;
  ose_dma)
    DRIVER_DIR="${OSE_DMA_PCI_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${OSE_DMA_PCI_DRV_PATH}" | grep "${OSE_DMA_PCI_NODE_0}"))
    DRIVER_DIR_1="${OSE_DMA_PCI_DRV_PATH}"
    DRIVER_ID_LIST_1=($(ls "${OSE_DMA_PCI_DRV_PATH}" | grep "${OSE_DMA_PCI_NODE_1}"))
    DRIVER_DIR_2="${OSE_DMA_PCI_DRV_PATH}"
    DRIVER_ID_LIST_2=($(ls "${OSE_DMA_PCI_DRV_PATH}" | grep "${OSE_DMA_PCI_NODE_2}"))
    ;;
  ose_i2c)
    DRIVER_DIR="${OSE_I2C_PCI_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${OSE_I2C_PCI_DRV_PATH}" | grep "${OSE_I2C_PCI_NODE_0}"))
    DRIVER_DIR_1="${OSE_I2C_PCI_DRV_PATH}"
    DRIVER_ID_LIST_1=($(ls "${OSE_I2C_PCI_DRV_PATH}" | grep "${OSE_I2C_PCI_NODE_1}"))
    DRIVER_DIR_2="${OSE_I2C_PCI_DRV_PATH}"
    DRIVER_ID_LIST_2=($(ls "${OSE_I2C_PCI_DRV_PATH}" | grep "${OSE_I2C_PCI_NODE_2}"))
    ;;
  ose_pwm)
    DRIVER_DIR="${OSE_PWM_PCI_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${OSE_PWM_PCI_DRV_PATH}" | grep "${OSE_PWM_PCI_NODE}"))
    ;;
  ose_spi)
    DRIVER_DIR="${OSE_SPI_PCI_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${OSE_SPI_PCI_DRV_PATH}" | grep "${OSE_SPI_PCI_NODE_0}"))
    DRIVER_DIR_1="${OSE_SPI_PCI_DRV_PATH}"
    DRIVER_ID_LIST_1=($(ls "${OSE_SPI_PCI_DRV_PATH}" | grep "${OSE_SPI_PCI_NODE_1}"))
    DRIVER_DIR_2="${OSE_SPI_PCI_DRV_PATH}"
    DRIVER_ID_LIST_2=($(ls "${OSE_SPI_PCI_DRV_PATH}" | grep "${OSE_SPI_PCI_NODE_2}"))
    DRIVER_DIR_3="${OSE_SPI_PCI_DRV_PATH}"
    DRIVER_ID_LIST_3=($(ls "${OSE_SPI_PCI_DRV_PATH}" | grep "${OSE_SPI_PCI_NODE_3}"))
    ;;
  ose_uart)
    DRIVER_DIR="${OSE_UART_PCI_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${OSE_UART_PCI_DRV_PATH}" | grep "${OSE_UART_PCI_NODE_0}"))
    DRIVER_DIR_1="${OSE_UART_PCI_DRV_PATH}"
    DRIVER_ID_LIST_1=($(ls "${OSE_UART_PCI_DRV_PATH}" | grep "${OSE_UART_PCI_NODE_1}"))
    DRIVER_DIR_2="${OSE_UART_PCI_DRV_PATH}"
    DRIVER_ID_LIST_2=($(ls "${OSE_UART_PCI_DRV_PATH}" | grep "${OSE_UART_PCI_NODE_2}"))
    ;;
  spi_nor)
    DRIVER_DIR="${SPI_NOR_PCI_DRV_PATH}"
    DRIVER_ID_LIST=($(ls "${SPI_NOR_PCI_DRV_PATH}" | grep "${SPI_NOR_PCI_NODE}"))
    ;;
  sth)
    DRIVER_DIR="${STH_BUS_PATH}"
    DRIVER_ID_LIST=($(ls "${STH_BUS_PATH}" | grep "0-sth"))
    ;;
  wdt)
    DRIVER_DIR="${WDT_PLTF_PATH}"
    DRIVER_ID_LIST=("${DRV_MOD_NAME}")
    ;;
esac

# CHECK DRIVER SYSFS PATH
do_cmd "test -d ${DRIVER_DIR}"
if [[ -n "${DRIVER_DIR_1}" ]]; then
  do_cmd "test -d ${DRIVER_DIR_1}"
fi
if [[ -n "${DRIVER_DIR_2}" ]]; then
  do_cmd "test -d ${DRIVER_DIR_2}"
fi

# BIND/UNBIND DRIVER
for i in "${DRIVER_ID_LIST[@]}"; do
  bind_unbind "${DRIVER_DIR}" "${i}"
done

if [[ -n "${DRIVER_ID_LIST_1}" ]]; then
  for i in "${DRIVER_ID_LIST_1[@]}"; do
    bind_unbind "${DRIVER_DIR_1}" "${i}"
  done
fi

if [[ -n "${DRIVER_ID_LIST_2}" ]]; then
  for i in "${DRIVER_ID_LIST_2[@]}"; do
    bind_unbind "${DRIVER_DIR_2}" "${i}"
  done
fi

if [[ -n "${DRIVER_ID_LIST_3}" ]]; then
  for i in "${DRIVER_ID_LIST_3[@]}"; do
    bind_unbind "${DRIVER_DIR_3}" "${i}"
  done
fi

# UNLOAD KMODULES IF THEY WERE LOADED
for driver in "${DRVS_LOADED[@]}"; do
  test_print_trc "Unload \"${driver}\""
  do_cmd "load_unload_module.sh -u -d ${driver}"
done
