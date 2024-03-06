#!/bin/bash
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
###############################################################################

############################ CONTRIBUTORS #####################################

# @Author  Juan Pablo Gomez <juan.p.gomez@intel.com>
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#      -  Initial Version
#

############################ DESCRIPTION ######################################

# @desc     This script contains paths, names and variables for PCI tests
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################

source "common.sh"

PCI_SYSFS_PATH="/sys/bus/pci"
PCI_SYSFS_DEV_PATH="${PCI_SYSFS_PATH}/devices"
PCI_SYSFS_DRV_PATH="${PCI_SYSFS_PATH}/drivers"
PCI_SYSFS_SLOT_PATH="${PCI_SYSFS_PATH}/slots"

#Function: get_pci_speed
#Input: $1:dev_name $2:speed_type
#Output: speed
#Return: 0 success, 1 fail
get_pci_speed(){

  [ $# -ne 2 ] && die "Invalide argument for function: $FUNCNAME"
  dev_name="$1"
  speed_type="$2"
  if [[ ! "$dev_name" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]];then
    return 1
  fi
  speed=`lspci -d "$dev_name" -vv | grep -i "$speed_type" | grep -ioE "Speed [0-9\.]+GT/s" | cut -d' ' -f2 | cut -d'G' -f1`
  echo $speed
  [ "x$speed" != "x" ] && return 0 || return 1
}

#Function: get_pci_width
#Input: $1:dev_name $2:width_type
#Output: width
#Return: 0 success, 1 fail
get_pci_width(){

  [ $# -ne 2 ] && die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  width_type="$2"
  if [[ ! "$dev_name" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]];then
    return 1
  fi
  width=`lspci -d "$dev_name" -vv | grep -i "$width_type" | grep -ioE "Width x[0-9]+" | cut -d' ' -f2`
  echo $width
  [ "x$width" != "x" ] && return 0 || return 1
}

#Function: get_pci_drv_name
#Input: $1:dev_name
#Output: $drv_name
#Return: 0 sucess, 1 fail
get_pci_drv_name(){

  [ $# -eq 1 ] || die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  if [[ ! "$dev_name" =~ ^[0-9a-fA-F]{4}:[0-9a-fA-F]{4}$ ]];then
    die "Invalid pci device name"
  fi
#get driver name by lspci
  drv_name=`lspci -d $dev_name -vv | grep -i "Kernel driver in use" | head -1 | awk -F' ' '{print $NF}'`
  echo $drv_name
}

#Function: verify_pci_driver
#Input: $1:dev_name
#Output:N/A
#Return: 0 success, 1 fail
verify_pci_driver(){

  [ $# -eq 1 ] || die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  drv_name=`get_pci_drv_name "$dev_name"`
  if [ $? -eq 1 ];then
    die "Failed to get pci driver name"
  fi
  test_print_trc "Device $dev_name 's driver name is: $drv_name"
  if [ ! -d "$PCI_SYSFS_DRV_PATH/${drv_name}" ];then
    die "PCI drvier $drv_name does't exist in $PCI_SYSFS_DRV_PATH "
  fi
  test_print_trc "PCI driver $drv_name exists in $PCI_SYSFS_DRV_PATH"
  return 0
}

#Function: verify_pci_device
#Input: $1:dev_name
#Output:N/A
#Return: 0 success, 1 fail
verify_pci_device(){

  [ $# -eq 1 ] || die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  do_cmd "verify_pci_driver "$dev_name""
  pci_dev_name="0000:`lspci -d "$dev_name" | cut -d' ' -f1`"
  test_print_trc "PCI device $pci_dev_name exist in $PCI_SYSFS_DRV_PATH/$drv_name"
  return 0
}

#Function: pci_device_bind_unbind
#Input: $1:dev_name
#Output: N/A
#Return: 0 success, 1 fail
pci_device_bind_unbind(){

  [ $# -eq 1 ] || die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  drv_name=`get_pci_drv_name "$dev_name"`
  verify_pci_driver "$dev_name" || die "Can't verify pci driver"
  pci_dev_name="0000:`lspci -d "$dev_name" | cut -d' ' -f1`"
  if [ ! -d "$PCI_SYSFS_DRV_PATH/$drv_name/$pci_dev_name" ];then
    test_print_trc "PCI device $pci_dev_name does not bind to driver yet,now bind it"
    do_cmd "echo $pci_dev_name > $PCI_SYSFS_DRV_PATH/$drv_name/bind"
    do_cmd "echo $pci_dev_name > $PCI_SYSFS_DRV_PATH/$drv_name/unbind"
    test_print_trc "successfull bind then unbind"
    return 0
  else
    test_print_trc "PCI device $pci_dev_name has been binded to driver yet,now unbind it"
    do_cmd "echo $pci_dev_name > $PCI_SYSFS_DRV_PATH/$drv_name/unbind"
    do_cmd "echo $pci_dev_name > $PCI_SYSFS_DRV_PATH/$drv_name/bind"
    test_print_trc "successfull unbind then bind"
    return 0
  fi
}

#Function pci_device_remove_rescan
#Input: $1:dev_name
#Output: N/A
#Return: 0 success, 1 fail
pci_device_remove_rescan(){

  [ $# -eq 1 ] || die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  pci_dev_name="0000:`lspci -d "$dev_name" | cut -d' ' -f1`"
  if [ -d "$PCI_SYSFS_DEV_PATH/$pci_dev_name" ];then
    do_cmd "echo 1 > "$PCI_SYSFS_DEV_PATH/$pci_dev_name/remove""
    test_print_trc "Done remove pci device: $pci_dev_name"
    [ -d "$PCI_SYSFS_DEV_PATH/$pci_dev_name" ] && {
      die "Remove PCI device:$pci_dev_name operation has no effort"
    }
    do_cmd "echo 1 > "$PCI_SYSFS_PATH/rescan""
    test_print_trc "Done rescan pci device: $pci_dev_name"
    [ -d "$PCI_SYSFS_DEV_PATH/$pci_dev_name" ] || {
      die "Rescan PCI device:$pci_dev_name operation has no effort"
    }
    return 0
  else
     die "$pci_dev_name does not exist"
  fi
}

#Function verify_pci_config
#Input: $1:dev_name
#Output: N/A
#Return: 0 success, 1 fail
verify_pci_config(){

  [ $# -eq 1 ] || die "Invalid argument for function: $FUNCNAME"
  dev_name="$1"
  PCI_DEV_NAME_LIST="0000:`lspci -d "$dev_name" | cut -d' ' -f1`"
  for pci_dev_name in ${PCI_DEV_NAME_LIST};do
    if [ -d "$PCI_SYSFS_DEV_PATH/$pci_dev_name" ];then
      vendor=`od -tx2 "$PCI_SYSFS_DEV_PATH/$pci_dev_name/config" | tr '\n' ' ' | cut -d' ' -f2`
      device_id=`od -tx2 "$PCI_SYSFS_DEV_PATH/$pci_dev_name/config" | tr '\n' ' ' | cut -d' ' -f3`
      if [ "0x$vendor" == `cat $PCI_SYSFS_DEV_PATH/$pci_dev_name/vendor` ] && \
         [ "0x$device_id" == `cat $PCI_SYSFS_DEV_PATH/$pci_dev_name/device` ];then
         test_print_trc "verified pci config, vendor is $vendor, device id is :$device_id"
         return 0
      else
         die "vendor or device_is is not matched"
      fi
    else
      die "$pci_dev_name" dose not exist
    fi
  done
}
