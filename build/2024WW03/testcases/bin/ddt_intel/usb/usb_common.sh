#!/bin/bash
#
# Copyright 2016 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ning Han <ningx.han@intel.com>
#
# History:
#             Nov. 25, 2016 - (Ning Han)Creation
#             Feb. 16, 2017 - (Ning Han)modification
#               - refine the logic of finding a usb storage device
#             Jun.  9, 2017 - (Ammy Yi) add gadget configfs setup/teardown
#             Mar.  9, 2018 - (Zhang Chao) add typec switch function


# @desc provide common functions for usb test cases

source "common.sh"
source "dmesg_functions.sh"

readonly USB_SYS_DEVICE_PATH="/sys/bus/usb/devices"
readonly BLOCK_DEVICE_DIR="/dev/disk/by-id"
readonly POWER_STATE_NODE="/sys/power/state"
readonly POWER_DISK_NODE="/sys/power/disk"
readonly POWER_PM_TEST_NODE="/sys/power/pm_test"
readonly USB_XHCI="pci0000:00/0000:00:14.0"

# This function check whether given size is greater than threshold
# Input:
#       $1: threshold size
#       $2: block size of the file, with unit
#       $3: block count
# Return:
#       0: given size > threshold
#       1: given size <= threshold
size_too_big() {
  local threshold=$1
  local block_size=$2
  local block_count=$3
  local size=""
  local threshold_size=""

  size=$(caculate_size_in_bytes "$block_size" "$block_count")
  threshold_size=$(caculate_size_in_bytes "$threshold" 1)
  test_print_trc "size:$size, threshold_size:$threshold_size"

  [[ "$size" -gt "$threshold_size" ]]
}

# Check whether usb device actual capacity is greater than test file size
# input
#       $1: usb device node i.e. /dev/sdb
#       $2: block size of the file, with unit
#       $3: block count of the file
# Return:
#       0: usb device actual size > test file size
#       1: usb device actual size <= test file size
check_test_size() {
  local device_node=$1
  local block_size=$2
  local block_count=$3
  local needed_size=""

  actual_size=$(fdisk -l "$device_node" 2> /dev/null | grep "$device_node" \
                | grep bytes | awk '{print $5}')

  needed_size=$(caculate_size_in_bytes "$block_size" "$block_count")

  [[ "$actual_size" -gt "$needed_size" ]]
}

# Check necessary utilities
check_test_env() {
  which du &> /dev/null || die "du is not in current environment!"
  which dd &> /dev/null || die "dd is not in current environment!"
  which diff &> /dev/null || die "diff is not in current environment!"
  which fdisk &> /dev/null || die "fdisk is not in current environment!"
}

# generate temporary file to be used in w/r test
# Input:
#       $1: block size of the file, with unit
#       $2: block count of the file
#       $3: where the file will be created
# Output:
#       absolute path of the created file on success
#       empty string on failure
generate_test_file() {
  local block_size=$1
  local block_count=$2
  local dir=$3
  local number=$4
  local if="/dev/zero"
  local of=""

  if [ -n "$number" ]; then
    of="${dir}/test.$number"
  else
    of="${dir}/test.$(date +%Y%m%d%H%M%S)"
  fi
  dd if="$if" of="$of" bs="$block_size" count="$block_count" &> /dev/null
  if [[ $? -eq 0 ]] && [[ -e "$of" ]]; then
    echo "$of"
  else
    echo
  fi
}

# umount /mnt/test if mounted
umount_dir(){
  local dir=$1

  [ -z "$dir" ] || do_cmd "umount $dir"
}

format_ext4(){
  local usb_device_node=$1
  [ -z $usb_device_node ] || do_cmd "mkfs.ext4 ${usb_device_node}"
  wait
}

# mount /mnt/test if not mounted
mount_dir(){
  local usb_device_node=$1
  local dir=$2

  [ ! -d "$dir" ] && mkdir -p "$dir"
  mount | grep -q -e "${usb_device_node}" -e "$dir"
  if [[ $? != 0  ]]; then
    format_ext4 "$usb_device_node"
    do_cmd "mount ${usb_device_node} $dir"
  fi
}

# This function try to find the path which may contain usb3_hardware_lpm_u1/2
# based on the the input parameters
# Input:
#       $1: usb protocol type i.e. 2.0/3.0
#       $2: usb device type i.e. flash/uas
# Output:
#       absolute path on success
#       empty string on failure
get_power_attrs_dir() {
  local protocol_type=$1
  local device_type=$2
  local usb_device_dirs=""
  local sub_dir_count=""
  local sub_dir=""
  local sys_speed=""

  # Convert protocol_type to speed
  case $protocol_type in
    2.0) speed="480" ;;
    3.0) speed="5000" ;;
    3.1) speed="10000" ;;
    3.2) speed="20000" ;;
    *) return 1 ;;
  esac

  # Convert device_type to driver type
  case $device_type in
    flash) driver="usb-storage" ;;
    uas) driver="uas" ;;
    *) return 1 ;;
  esac

  # Get the sysfs directories of usb devices which were connected on the root
  # hub
  usb_device_dirs=$(regex_scan_dir "$USB_SYS_DEVICE_PATH" "^[0-9]-[0-9]$")
  [[ -n "$usb_device_dirs" ]] || echo
  # Walk the usb device directories
  for dir in $usb_device_dirs; do
    # Get speed the the usb device, by which we can know what protocol is the
    # usb device are using
    sys_speed=$(cat "$USB_SYS_DEVICE_PATH/$dir/speed")
    # Look into the usb device directory, if there are more than one
    # sub-directory, we skip to next
    # usb device directory, becasue this is not a usb storage device.
    sub_dir_count=$(ls "$USB_SYS_DEVICE_PATH/$dir" |\
                        grep -Ec "^[0-9]-[0-9]:[0-9].[0-9]$")
    [[ "$sub_dir_count" -eq 1 ]] || continue
    # Get sub-directory in usb device directory, look into it and get the
    # driver type by which we can the device type, flash or uas
    sub_dir=$(regex_scan_dir "$USB_SYS_DEVICE_PATH/$dir" \
                             "^[0-9]-[0-9]:[0-9].[0-9]$")
    sys_driver=$(grep DRIVER "$USB_SYS_DEVICE_PATH/$dir/$sub_dir/uevent" |\
                      awk -F= '{print $2}')
    # If speed(protocol type) and driver(device type) both match, it means we
    # find the right path
    if [[ "$sys_speed" == "$speed" ]] && [[ "$sys_driver" == "$driver" ]]; then
      echo "$USB_SYS_DEVICE_PATH/$dir/power"
      return
    fi
  done
}

# check whether device node match the protocol
protocol_type_is() {
  local dev_node=$1
  local protocol=$2
  local speed=""
  local speed_count=0
  local controller_count=0
  case $protocol in
    3.2) speed="20000";;
    3.1) speed="10000";;
    3.0) speed="5000" ;;
    2.0) speed="480" ;;
    *) exit 2 ;;
  esac

  controller_count=$(udevadm info --attribute-walk --name=/dev/"$dev_node" \
                     | grep -C 5 speed \
                     | grep -C 5 $speed \
                     | awk -v RS="@#$j" '{print gsub(/Controller/,"&")}')

  speed_count=$(udevadm info --attribute-walk --name=/dev/"$dev_node" \
                | grep -C 5 speed \
                | grep -C 5 $speed \
                | awk -v RS="@#$j" '{print gsub(/speed/,"&")}')

  if [[ $speed_count -gt $controller_count ]]; then
    return 0
  else
    return 1
  fi
}

# check whether device node match the type
device_type_is() {
  local dev_node=$1
  local type="$2"
  local driver=""

  case $type in
    flash) driver="usb-storage" ;;
    uas) driver="uas" ;;
    *) exit 2 ;;
  esac

  udevadm info --attribute-walk --name=/dev/"$dev_node" \
                                         | grep DRIVERS \
                                         | grep -q $driver

  return $?
}

#check whether hub number match connected hub number
hub_num_is() {
  local dev_node=$1
  local hub_num=$2
  local num=0
  local usb_base=11
  local tbt_base=17
  local USB_TR="pci0000:00/0000:00:1c.0"
  local USB_UCMX="pci0000:00/0000:00:1c.4"
  num=$(udevadm info --attribute-walk --name=/dev/"$dev_node" \
                                         | grep "$dev_node" \
                                         | awk -v RS="@#$j" '{print gsub(/\//,"&")}')

  udevadm info --attribute-walk --name=/dev/"$dev_node" | grep "$dev_node" | grep -q "$USB_XHCI"
  if [[ $? -eq 0 ]]; then
    usb_base=11
    tbt_base=15
  fi
  lspci | grep a32c -q
  if [[ $? -eq 0 ]]; then
    TR_ID=$(lspci | grep a32c | awk '{print $1}')
    USB_TR="pci0000:00/0000:"${TR_ID}
  fi
  lspci | grep a33c -q
  if [[ $? -eq 0 ]]; then
    TR_ID=$(lspci | grep a33c | awk '{print $1}')
    USB_TR="pci0000:00/0000:"${TR_ID}
  fi
  udevadm info --attribute-walk --name=/dev/"$dev_node" | grep "$dev_node" | grep -q "$USB_TR"
  if [[ $? -eq 0 ]]; then
    usb_base=14
    tbt_base=17
  fi

  udevadm info --attribute-walk --name=/dev/"$dev_node" | grep "$dev_node" | grep -q "$USB_UCMX"
  if [[ $? -eq 0 ]]; then
    usb_base=14
    tbt_base=17
  fi

  # usb hub num could not reach $tbt_base
  # tbt usb num is greater than $tbt_base, so return 0, other wise could not detect
  if [[ $num -gt $tbt_base ]]; then
    return 0;
  fi

  #if no hub, the command will return usb_base
  num=$((num-usb_base))
  if [[ $num -eq $hub_num ]]; then
    return 0
  else
    return 1
  fi
}

# find usb storage device by parameters provided
find_usb_storage_device() {
  local protocol_type=$1
  local device_type=$2
  local block_size=$3
  local block_count=$4
  local hub_num=$5
  local device_nodes=""
  local dev_node=""

  device_nodes=$(regex_scan_dir "/dev" "^sd[a-z]$")
  [ -n "$device_nodes" ] || exit 2

  for node in $device_nodes
  do
    protocol_type_is "$node" "$protocol_type" || continue
    device_type_is "$node" "$device_type" || continue
    hub_num_is "$node" "$hub_num" || continue
    dev_node="$node"
    break
  done

  [[ -n "$dev_node" ]] || exit 2

  if [[ -z "$block_size" || -z "$block_count" ]]; then
    echo "/dev/$dev_node"
  else
    # Check wether the usb storage device has enough capacity to
    # perform the test
    check_test_size "/dev/$dev_node" "$block_size" "$block_count"
    [[ $? -eq 0 ]] || exit 2
    echo "/dev/$dev_node"
  fi
}

# This function perform write test on usb device
# Input:
#       $1: device to be performed test on
#       $2: data source
# Return: follow command 'dd'
write_test_with_file() {
  local of=$1
  local if=$2
  local count=$3
  local if_size=""

  if_size=$(du -b "$if" | awk '{print $1}')
  test_print_trc "size of $if is $if_size"
  [ -z "$count" ] && count=1
  do_cmd "dd if=$if of=$of bs=$if_size count=$count &> /dev/null"
}

# This function perform write test on usb device w/ msc tool
# Input:
#       $1: device to be performed test on
#       $2: times for msc loop
# Return: check msc result, fail = 1
rw_test_with_msc() {
  local dev_blk=$1
  local count=$2
  local val_re=0
  sh msc.sh -o $dev_blk -c $count > temp.txt
  grep temp.txt -e "FAIL" && val_re=1
  rm temp.txt
  return $val_re
}

# This function perform read test on usb device
# Input:
#       $1: device to be performed test on
#       $2: original file, to be compared with the read out data
read_test_with_file() {
  local if=$1
  local test_file=$2
  local count=$3
  local of="${test_file}.copy"
  local file_size=""

  file_size=$(du -b "$test_file" | awk '{print $1}')
  test_print_trc "size of $test_file is $file_size"
  [ -z "$count" ] && count=1
  do_cmd "dd if=$if of=$of bs=$file_size count=$count &> /dev/null"
  mdsum_testfile=$(md5sum "$test_file" | awk '{print$1}')
  mdsum_testfile_copy=$(md5sum "$of" | awk '{print$1}')
  [[ "$mdsum_testfile" == "$mdsum_testfile_copy" ]] || die "read test with file fail"
  rm "$test_file" "$of"
}

# This function perform write test on usb device
# Input:
#       $1: device to be performed test on
#       $2: block size to be write to the device
#       $3: block count to be write to the device
# Return: follow command 'dd'
write_test_without_file() {
  local of=$1
  local block_size=$2
  local block_count=$3
  local if="/dev/zero"

  do_cmd "dd if=$if of=$of bs=$block_size count=$block_count"
}

# This function perform read test on usb device
# Input:
#       $1: device to be performed test on
#       $2: block size to be write to the device
#       $3: block count to be write to the device
read_test_without_file() {
  local if=$1
  local block_size=$2
  local block_count=$3
  local of="/dev/null"

  do_cmd "dd if=$if of=$of bs=$block_size count=$block_count"
}

cal_local_device_swap_space() {
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
  elif [[ "$final" == "M" ]]; then
    die "local space / too small"
  fi
  swap=$(free -g |awk '{print $4}' |tail -n2 |awk '{sum+=$1}END{print sum}')G
  final_swap=${swap: -1}
  free_swap=${swap%?}

  if [[ "$final" == "$final_swap" ]]; then
    value=$(echo "$free_swap < $free_space" | bc )
    [ "$value" == 1 ] && free_space=$free_swap
  else
    echo "$free_swap""$final_swap"
  fi
  echo "$free_space""$final"
}

: ${GNAME:=""}
: ${VID:=""}
: ${PRODUCTID:=""}
: ${GPATH:=""}

##configfs set up for gadget device
configfs_setup() {
  type=$1
  img_file=$2
  dwc3_id=$(ls /sys/class/udc/ | grep dwc3)
  do_cmd "modprobe libcomposite"
  do_cmd "mkdir -p /config"
  do_cmd "mount none /config -t configfs"
  do_cmd "mkdir /config/usb_gadget/$GPATH"
  do_cmd "echo $VID > /config/usb_gadget/$GPATH/idVendor"
  do_cmd "echo $PRODUCTID > /config/usb_gadget/$GPATH/idProduct"
  do_cmd "mkdir /config/usb_gadget/$GPATH/strings/0x409"
  do_cmd "echo 12345 > /config/usb_gadget/$GPATH/strings/0x409/serialnumber"
  do_cmd "echo "Test" > /config/usb_gadget/$GPATH/strings/0x409/manufacturer"
  do_cmd "echo "Test" > /config/usb_gadget/$GPATH/strings/0x409/product"
  do_cmd "mkdir -p /config/usb_gadget/$GPATH/configs/c.1/strings/0x409"
  do_cmd "echo "Config1" > /config/usb_gadget/$GPATH/configs/c.1/strings/0x409/configuration"
  do_cmd "mkdir /config/usb_gadget/$GPATH/functions/$GNAME.usb0"
  if [[ $type = "storage" ]]; then
    do_cmd "echo $img_file > /config/usb_gadget/$GPATH/functions/$GNAME.usb0/lun.0/file "
  fi
  do_cmd "ln -s /config/usb_gadget/$GPATH/functions/$GNAME.usb0 /config/usb_gadget/$GPATH/configs/c.1"
  do_cmd "echo $dwc3_id > /config/usb_gadget/$GPATH/UDC"
}

#clean configfs setting
configfs_teardown() {
  echo "" > /config/usb_gadget/$GPATH/UDC || \
    test_print_wrg "One step in teardown fails"
  rm /config/usb_gadget/$GPATH/configs/c.1/$GNAME.usb0 || \
    test_print_wrg "One step in teardown fails"
  rmdir /config/usb_gadget/$GPATH/configs/c.1/strings/0x409 || \
    test_print_wrg "One step in teardown fails"
  rmdir /config/usb_gadget/$GPATH/configs/c.1 || \
    test_print_wrg "One step in teardown fails"
  rmdir /config/usb_gadget/$GPATH/functions/$GNAME.usb0 || \
    test_print_wrg "One step in teardown fails"
  rmdir /config/usb_gadget/$GPATH/strings/0x409 || \
    test_print_wrg "One step in teardown fails"
  rmdir /config/usb_gadget/$GPATH || \
    test_print_wrg "One step in teardown fails"
  umount /config || \
    test_print_wrg "One step in teardown fails"
  rmdir /config || \
    test_print_wrg "One step in teardown fails"
}

#check if usb serial can communicate
serial_check() {
  local i=0
  local val_re=0
  local serial_c="/dev/ttyGS0"
  local serial_h="/dev/ttyUSB0"
  local serial_h_2="/dev/ttyACM0"

  do_cmd "modprobe usbserial"
  do_cmd "echo $VID $PRODUCTID >/sys/bus/usb-serial/drivers/generic/new_id"
  echo -e "test\ntest\n" > ./temp.txt
  (
  cat $serial_c > test.txt
  )&
  temp_pid=$!
  while [ $i -lt 20 ]; do
    i=$((i + 1))
    cat temp.txt > $serial_h
    cat temp.txt > $serial_h_2
  done
  sleep 1
  kill $temp_pid
  grep -q "test" test.txt || {
    val_re=1
    test_print_trc "USB serial input/output check fail"
  }
  do_cmd "rm temp.txt"
  do_cmd "rm test.txt"
  return $val_re
}

#check usb speed with vid&pid
usb_speed_check() {
  local speed=$1
  local sys_vid=""
  local sys_pid=""

  vid=$(echo ${VID#*x})
  pid=$(echo ${PRODUCTID#*x})
  usb_device_dirs=$(ls $USB_SYS_DEVICE_PATH | grep -E "^[0-9]-[0-9]$" | xargs)
  [ -n "$usb_device_dirs" ] || return 1
  for dir in $usb_device_dirs
  do
    sys_vid=$(cat $USB_SYS_DEVICE_PATH/$dir/idVendor)
    if [[ $sys_vid != $vid ]]; then
      continue
    fi
    sys_pid=$(cat $USB_SYS_DEVICE_PATH/$dir/idProduct)
    if [[ $sys_pid != $pid ]]; then
      continue
    fi
    sys_speed=$(cat $USB_SYS_DEVICE_PATH/$dir/speed)
    if [[ $sys_speed == $speed  ]]; then
      test_print_trc "Find USB Device with speed = $speed!"
      return 0
    else
      continue
    fi
  done
}

#simple r/w test w mass storage
mass_storage_check() {
  BLOCK_SIZE=$1
  BLOCK_COUNT=$2
  local count=5
  local usb_device_node=$(ls -al /dev/disk/by-id | grep usb-Linux_File-Stor_Gadget | awk '{print $11}')
  usb_device_node=$(echo ${usb_device_node#*../})
  usb_device_node=$(echo ${usb_device_node#*../})
  usb_device_node="/dev/"${usb_device_node}
  test_print_trc "usb_device_node = $usb_device_node"
  write_test_without_file "$usb_device_node" "$BLOCK_SIZE" "$BLOCK_COUNT"
  read_test_without_file "$usb_device_node" "$BLOCK_SIZE" "$BLOCK_COUNT"
  rw_test_with_msc $usb_device_node $count
}

#check if midi device works
usb_midi_check() {
  ###check if midi device can be recognized
  local usb_midi_play_id=$(aplaymidi -l | grep f_midi | awk '{print $1}')
  if [[ -z $usb_midi_play_id ]]; then
    return 1
  fi
  local usb_midi_record_id=$(arecordmidi -l | grep f_midi | awk '{print $1}')
  if [[ -z $usb_midi_record_id ]]; then
    return 1
  fi
  return 0
}


#check if rndis device works
usb_rndis_check() {
  local USB_IP="192.168.0.11"
  local count=10
  ###check if rndis device can be recognized
  local usb_rndis_id=$(ifconfig -a | grep usb | awk '{print $1}')
  test_print_trc "usb_rndis_id = $usb_rndis_id"
  if [[ -z $usb_rndis_id ]]; then
    return 1
  fi
  do_cmd "ifconfig $usb_rndis_id $USB_IP"
  do_cmd "ping $USB_IP -c $count > temp.log"
  ping_loss=$(cat temp.log | grep loss | awk '{print $6}')
  test_print_trc "ping package loss rate = $ping_loss"
  if [[ $ping_loss != "0%" ]]; then
    return 0
  fi
  do_cmd "rm temp.log"
  return 0
}


#check if usb serial can communicate
usb_printer_check() {
  local i=0
  local val_re=0
  local printer_id="/dev/usb/lp0"
  local printer_h="/dev/g_printer0"

  echo -e "test\ntest\n" > ./temp.txt
  (
    cat $printer_h > test.txt
  )&
  temp_pid=$!
  (
    while [ $i -lt 20 ]
    do
      i=$((i + 1))
      cat temp.txt > $printer_id
    done
  )&
  temp_pid_2=$!
  sleep 1
  kill $temp_pid
  kill $temp_pid_2
  grep -q "test" test.txt || {
    val_re=1
    test_print_trc "USB printer input/output check fail"
  }
  do_cmd "rm temp.txt"
  do_cmd "rm test.txt"
  return $val_re
}

#check if rndis device works
usb_audio_check() {
  ###check if audio device can be recognized
  local usb_audio_id=$(cat /proc/asound/cards | grep "USB" | awk '{print $1}')
  if [[ -z $usb_audio_id ]]; then
    return 1
  fi
  return 0
}


#modules set up
MODULE_NAME=""
module_setup() {
  local param=$1
  if [[ -z $param ]]; then
    load_unload_module.sh -c -d $MODULE_NAME|| \
      do_cmd "load_unload_module.sh -l -d $MODULE_NAME"
  else
    load_unload_module.sh -c -d $MODULE_NAME|| \
      do_cmd "load_unload_module.sh -l -d $MODULE_NAME -p $param"
  fi
}

#modules clean up
module_teardown() {
  rmmod $MODULE_NAME
}

PORTNUMBER=""
HILBOARD="http://localhost:9999/api/v1/stack"

# This function perform connection of usb device with hil board
# Input:
#       n/a
# Output: 0 as pass, 1 as fail
usb_connect_w_hilboard() {
  local result=0
  #start hil board service
  hil_server start&
  sleep 3
  #connect hil board
  result=$(curl -X POST $HILBOARD)
  result=$(echo $result | grep "201")
  [[ -z $result ]] && return 1
  sleep 3
  return 0
}


# This function perform disconnection of usb device with hil board
# Input:
#       n/a
# Output: 0 as pass, 1 as fail
usb_disconnect_w_hilboard() {
  local result=0
  #disconnect hil board
  result=$(curl -X DELETE $HILBOARD)
  result=$(echo $result | grep "201")
  [[ -z $result ]] && return 1
  sleep 1
  #stop hil board service
  hil_server stop
  return 0
}

# This function perform enable of usb device with hil board
# Input:
#       $1: port number of hil board
# Output: 0 as pass, 1 as fail
usb_enable_w_hilboard() {
  PORTNUMBER=$1
  curl -X PUT $HILBOARD/hil1/usb$PORTNUMBER -H "Content-Type: application/json" -d "{\"state\": 1}"
  sleep 15
  do_cmd "lsusb -t"
  return 0
}

# This function perform disable of usb device with hil board
# Input:
#       $1: port number of hil board
# Output: 0 as pass, 1 as fail
usb_disable_w_hilboard() {
  PORTNUMBER=$1
  curl -X PUT $HILBOARD/hil1/usb$PORTNUMBER -H "Content-Type: application/json" -d "{\"state\": 0}"
  sleep 1
  do_cmd "lsusb -t"
  return 0
}

# This function perform hotplug of usb device with hil board
# Input:
#       $1: port number of hil board
# Output: 0 as pass, 1 as fail
usb_hotplug() {
  PORTNUMBER=$1
  usb_disable_w_hilboard $PORTNUMBER
  usb_enable_w_hilboard $PORTNUMBER
  return 0
}


# This function perform hotplug setup of usb device with hil board
# Input:
#       $1: port number of hil board
# Output: 0 as pass, 1 as fail
usb_hotplug_setup() {
  PORTNUMBER=$1
  usb_connect_w_hilboard
  [[ $? -eq 0 ]] || return 1
  usb_enable_w_hilboard $PORTNUMBER
  return 0
}

# This function perform hotplug enable of usb device with typec switch
usb_enable_w_switch() {
  local PORTNUMBER=$1
  python2 $PWD/ftdi/FtdiWrapper/cswitch.py "$PORTNUMBER"
  sleep 8
  do_cmd "lsusb -t"
  return 0
}

# This function perform hotplug disable of usb device with typec switch
usb_disable_w_switch() {
  local PORTNUMBER=$1
  if [ "$PORTNUMBER" -lt 3 ]; then
    PORTNUMBER=$((PORTNUMBER+1))
  else
    PORTNUMBER=$((PORTNUMBER-1))
  fi
  python2 $PWD/ftdi/FtdiWrapper/cswitch.py "$PORTNUMBER"
  sleep 8
  do_cmd "lsusb -t"
  return 0
}

# This function perform hotplug of usb device with typec switch
usb_hotplug_switch() {
  local PORTNUMBER=$1
  usb_disable_w_switch "$PORTNUMBER"
  usb_enable_w_switch "$PORTNUMBER"
  return 0
}

# This function perform hotplug setup of usb device with typec switch
usb_hotplug_setup_switch() {
  local PORTNUMBER=$1
  rmmod ftdi_sio
  rmmod usbserial
  usb_enable_w_switch "$PORTNUMBER"
  return 0
}

# This function perform hotplug teardown of usb device with hil board
# Input:
#       n/a
# Output: 0 as pass, 1 as fail
usb_hotplug_teardown() {
  usb_disconnect_w_hilboard
  return 0
}

suspend_to_resume() {
  local state=$1
  local rtc_time=20

  echo platform > "$POWER_DISK_NODE"
  echo none > "$POWER_PM_TEST_NODE"

  case $state in
    freeze)
      echo freeze > "$POWER_STATE_NODE" &
      rtcwake -m no -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      wait $!
      [[ $? -eq 0 ]] || die "fail to echo $state > $POWER_STATE_NODE!"
      ;;
    mem|disk)
      echo deep > /sys/power/mem_sleep
      rtcwake -m "$state" -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      ;;
    *)
      die "state: $state not supported!"
      ;;
  esac
}

usb_setup() {
  usb_log_setup
}

#enable usb related logs
usb_log_setup() {
  echo 81920 > /sys/kernel/debug/tracing/buffer_size_kb
  if [ -d /sys/kernel/debug/tracing/events/xhci-hcd ]; then
    echo 1 > /sys/kernel/debug/tracing/events/xhci-hcd/enable
  fi

  if [ -d /sys/kernel/debug/tracing/events/dwc3 ]; then
    echo 1 > /sys/kernel/debug/tracing/events/dwc3/enable
    echo 0 > /sys/kernel/debug/tracing/events/dwc3/dwc3_writel/enable
    echo 0 > /sys/kernel/debug/tracing/events/dwc3/dwc3_readl/enable
  fi

  if [ -d /sys/kernel/debug/tracing/events/ucsi ]; then
    echo 1 >  /sys/kernel/debug/tracing/events/ucsi/enable
  fi

  echo > /sys/kernel/debug/tracing/trace
}

#usb log check
usb_trace_check() {
  count=5
  echo "count = $count"
  while read line
  do
    cat /sys/kernel/debug/tracing/trace | grep "${line}"
    if [[ $? -eq 0 ]]; then
      dump_log
      echo "find trace error log"
      return 1
    fi
  done < $PWD/ddt_intel/usb/trace_error.dat


  while read line
  do
    extract_case_dmesg | grep "${line}"
    if [[ $? -eq 0 ]]; then
      dump_log
      echo "find dmesg error log"
      return 1
    fi
  done < $PWD/ddt_intel/usb/dmesg_error.dat

  extract_case_dmesg | grep -e 'xhci' -e 'dwc3' -e 'ucsi' | grep ERR
  if [[ $? -eq 0 ]]; then
    dump_log
    echo "find dmesg error log"
    return 1
  fi

  extract_case_dmesg | grep -e 'xhci' -e 'dwc3' -e 'ucsi' | grep WARN
  if [[ $? -eq 0 ]]; then
    dump_log
    echo "find dmesg waring log, please check detailed logs"
  fi

  while read line
  do
    num=$(cat /sys/kernel/debug/tracing/trace | grep -o "${line}" | grep -c "${line}")
    if [[ $num -ge $count ]]; then
      dump_log
      echo "num=$num"
    break
  fi
  done < $PWD/ddt_intel/usb/trace_error_low.dat

  return 0
}

#tear down for usb related logs
usb_log_teardown() {
  if [ -d /sys/kernel/debug/tracing/events/xhci-hcd ]; then
    echo 0 > /sys/kernel/debug/tracing/events/xhci-hcd/enable
  fi

  if [ -d /sys/kernel/debug/tracing/events/dwc3 ]; then
    echo 0 > /sys/kernel/debug/tracing/events/dwc3/enable
  fi

  if [ -d /sys/kernel/debug/tracing/events/ucsi ]; then
    echo 0 >  /sys/kernel/debug/tracing/events/ucsi/enable
  fi

  echo > /sys/kernel/debug/tracing/trace
  return 0
}

#will dump logs
dump_log() {
  #dump dmesg
  extract_case_dmesg > $LOG_PATH/${TAG}_dmesg.log
  echo "dmesg is $LOG_PATH/${TAG}_dmesg.log"
  #dump trace log
  cat /sys/kernel/debug/tracing/trace > $LOG_PATH/${TAG}_trace.log
  echo "dmesg is $LOG_PATH/${TAG}_trace.log"
  return 0
}

path_all_polling_check() {
  local path_check=$1
  dirs=$(ls $path_check | xargs)
  for dir in $usb_device_dirs; do
    if [[ $path_check = $USB_SYS_DEVICE_PATH ]]; then
      do_cmd "find $path_check/$dir/ -type f ! -name \"autosuspend_delay_ms\" ! -name \"remove\" -exec cat {} +  > /dev/null"
    else
      do_cmd "find $path_check/$dir/ -type f -exec cat {} + > /dev/null"
    fi
  done
  return 0
 }
