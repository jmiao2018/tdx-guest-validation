#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for thunderbolt3/4 function tests
# TBT4 contains some mandatory function, which is optional for USB4.
# For example: PCIe tunneling is optional for USB4, but it is required in TBT4.
#

source "tbt_common.sh"

TBT_VIEW="/tmp/tbt_view.txt"
TBT4_DEV="/tmp/tbt4_dev"
DEV_NAME="device_name"
DEV_LIST="/tmp/dev_list"
TBT_DEV_FILE="/tmp/tbt_name.txt"
PCI_HEX_FILE="/tmp/pci_hex.txt"
PCI_DEC_FILE="/tmp/pci_dec.txt"
PCI_HEX=""
PCI_DEC=""
DEV_TYPE=""
TBT_DEV_NAME=""
DEV_PCI=""
DEV_SERIAL=""
STUFF_FILE="/tmp/tbt_stuff.txt"
TBT_STUFF_LIST="/tmp/tbt_stuff_list.txt"
TBT_NUM=""
ROOT_PCI=""
PF_BIOS=""

# Find tbt root PCI
# Input: NA
# Return 0 otherwise false or die
find_root_pci() {
  local tbt_devs=""
  local pf_name=""

  pf_name=$(dmidecode --type bios \
                 | grep Version \
                 | cut -d ':' -f 2 \
                 | cut -d '.' -f 1)

  case $pf_name in
    *ICL*)
      PF_BIOS="ICL"
      ROOT_PCI="00:07"
      ;;
    *TGL*)
      PF_BIOS="TGL"
      ROOT_PCI="00:07"
      ;;
    *)
      PF_BIOS=$pf_name
      ROOT_PCI=$(udevadm info --attribute-walk --path=${TBT_PATH}/0-0 \
        | grep "KERNEL" \
        | tail -n 2 \
        | grep -v "pci0000" \
        | cut -d "\"" -f 2)
     ;;
  esac
  test_print_trc "PF_BIOS:$PF_BIOS, tbt root pci:$ROOT_PCI"
  [[ -n "$ROOT_PCI" ]] || die "Could not find tbt root PCI:$ROOT_PCI"
}

# List tbt upstream PCI
# Input: NA
# Return 0 otherwise false or die
tbt_us_pci()
{
  local pcis=""
  local pci=""
  local pci_us=""
  local pci_content=""
  local dr_pci_h=""
  local dr_pci_d=""

  [[ -n "$ROOT_PCI" ]] || find_root_pci
  [[ -n "$ROOT_PCI" ]] || die "Could not find tbt root PCI!"
  dr_pci_h=$(udevadm info -q path --path=${TBT_PATH}/domain0 \
            | awk -F "/" '{print $(NF-1)}' \
            | cut -d ':' -f 2)
  dr_pci_d=$((0x"$dr_pci_h"))
  pcis=$(ls -1 "$PCI_PATH")
  cat /dev/null > "$PCI_HEX_FILE"
  cat /dev/null > "$PCI_DEC_FILE"
  for pci in $pcis; do
    pci_us=""
    PCI_HEX=""
    PCI_DEC=""
    pci_content=$(ls -ltra "$PCI_PATH"/"$pci")
    [[ "$pci_content" == *"$ROOT_PCI"* ]] || continue

    pci_us=$(lspci -v -s "$pci" | grep -i upstream)
    if [[ -z "$pci_us" ]]; then
      continue
    else
      # test_print_trc "Upstream pci:$pci"
      PCI_HEX=$(echo "$pci" | cut -d ':' -f 2)
      PCI_DEC=$((0x"$PCI_HEX"))
      # Due to ICL tbt driver PCI 00:0d.2 and 00:0d.3
      # ICL is no impacted, it's due to ICL dr pci is 00
      [[ "$PCI_DEC" -gt "$dr_pci_d" ]] || {
        #test_print_trc "$PCI_DEC not greater than 3, skip"
        continue
      }
      echo "$PCI_HEX" >> "$PCI_HEX_FILE"
      echo "$PCI_DEC" >> "$PCI_DEC_FILE"
    fi
  done
}

# Fill the tbt dev node and device name into file
# Input:
#   $1: tbt sys name
#   $2: save tbt topo file name
# Return 0 otherwise false or die
topo_name() {
  local tbt_sys=$1
  local devs_file=$2
  local tbt_file=""
  local device_file=""
  local device_topo=""
  local file_topo=""
  local last=""

  [[ -n "$tbt_sys" ]] || {
    test_print_wrg "No tbt device in tbt_sys:$tbt_sys"
    exit 1
  }
  # Get last file
  last=$(echo "$tbt_sys" | awk '{print $NF}')

  # Last file not add <-> in the end
  for tbt_file in ${tbt_sys}; do
    device_file=""
    device_file=$(cat ${TBT_PATH}/${tbt_file}/${DEV_NAME} 2>/dev/null)
    if [ "$tbt_file" == "$last" ]; then
      device_topo=${device_topo}${device_file}
      file_topo=${file_topo}${tbt_file}
    else
      [[ -n "$device_file" ]] || device_file="no_name"
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

# it's for tbt4 topo view function which also could support old tbt1/2/3 device
# Input:
# $1: domain X: sample 0 or 1
# $2: port Y: smaple 1 or 3
# Return 0 for true, otherwise false or die
tbt4_view() {
  local domainx=$1
  local tn=$2
  local tbt_sys_file="/tmp/tbt_sys.txt"
  local tbt_devs=""
  local device_num=""
  local dev_item=""
  local check_point=""

  cat /dev/null > "$tbt_sys_file"
  ls -l ${TBT_PATH}/${domainx}*${tn} 2>/dev/null \
    | grep "-" \
    | awk -F "${REGEX_DOMAIN}${domainx}/" '{print $2}' \
    | awk '{ print length(), $0 | "sort -n" }' \
    | grep -v ":" \
    | grep -v "_" \
    | cut -d ' ' -f 2 \
    | tr '/' ' ' \
    > $tbt_sys_file

  # need tbt devices in specific order
  tbt_devs=$(ls "$TBT_PATH" 2>/dev/null \
    | grep "-" \
    | grep -v ":" \
    | grep "^${domainx}" \
    | grep "${tn}$" \
    | awk '{ print length(), $0 | "sort -n" }' \
    | cut -d ' ' -f 2)
  device_num=$(ls "$TBT_PATH" \
    | grep "^${domainx}" \
    | grep "${tn}$" \
    | wc -l)
  test_print_trc "$domainx-$tn contains $device_num tbt devices."
  echo "$domainx-$tn contains $device_num tbt devices." >> "$TBT_VIEW"
  cat /dev/null > "${TBT4_DEV}_${domainx}_${tn}"
  cp -rf "$tbt_sys_file" "${TBT4_DEV}_${domainx}_${tn}"
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
    [[ -z "$check_point" ]] && continue
    sed -i "/${check_point}$/d" "${TBT4_DEV}_${domainx}_${tn}"
    sed -i "s/${dev_item}$/${check_point}/g" "${TBT4_DEV}_${domainx}_${tn}"
  done
  while IFS= read -r line; do
    topo_name "$line" "$TBT_VIEW"
  done < "${TBT4_DEV}_${domainx}_${tn}"
}

# Collect all the domain and port tbt devices in tbt list file
# Input:
#   $1: domain X like 0 or 1
#   $2: port like 1 or 3
# Return 0 otherwise false or die
tbt_dev_name() {
  local domainx=$1
  local tn=$2
  local dev=""
  local tbt_devs=""
  local tbt_dev=""
  local cp=""

  cat /dev/null > "${DEV_LIST}_${domainx}_${tn}"
  while IFS= read -r line; do
    for dev in $line; do
      cp=""
      cp=$(cat ${DEV_LIST}_${domainx}_${tn} | grep "$dev")
      [[ -z "$cp" ]] || continue
      [[ "$dev" == *"-0" ]] && continue
      echo "$dev" >> "${DEV_LIST}_${domainx}_${tn}"
    done
  done < "${TBT4_DEV}_${domainx}_${tn}"

  # Get tbt dev file in connection order
  tbt_devs=""
  tbt_devs=$(cat ${DEV_LIST}_${domainx}_${tn})

  for tbt_dev in $tbt_devs; do
    echo "$tbt_dev" >> "$TBT_DEV_FILE"
  done
}

# This function will check how many tbt device connected and
# show the tbt devices and stuff under tbt devices
# Inuput: NA
# Return: 0 for true, otherwise false or die
topo_tbt_show() {
  # tbt spec design tbt each domain will seprate to like ?-1 or ?-3 branch
  local t1="1"
  local t3="3"
  local domains=""
  local domain=""
  local topo_result=""

  domains=$(ls "$TBT_PATH"/ \
    | grep "$REGEX_DOMAIN" \
    | grep -v ":" \
    | awk -F "$REGEX_DOMAIN" '{print $2}' \
    | awk -F "->" '{print $1}')

  cat /dev/null > "$TBT_DEV_FILE"
  cat /dev/null > "$TBT_VIEW"

  for domain in ${domains}; do
    tbt4_view "$domain" "$t1"
    tbt4_view "$domain" "$t3"
    tbt_dev_name "$domain" "$t1"
    tbt_dev_name "$domain" "$t3"
  done

  topo_result=$(cat $TBT_VIEW | grep -v "contains 0 ")
  [[ -n "$topo_result" ]] || die "No tbt in $TBT_VIEW:$topo_result!"
}

# Check USB type
# Input:
#   $1: device node
# Return 0 otherwise false or die
check_usb_type() {
  local dev_node=$1
  local speed=""

  speed=$(udevadm info --attribute-walk --name="$dev_node" \
    | grep speed \
    | head -n 1 \
    | cut -d '"' -f 2)

  case $speed in
    480)
      DEV_TYPE="USB2.0"
      ;;
    5000)
      DEV_TYPE="USB3.0"
      ;;
    10000)
      DEV_TYPE="USB3.1"
      ;;
    *)
      test_print_wrg "$dev_node:USB unknow speed->$speed"
      DEV_TYPE="USB_unknow_type"
      ;;
  esac
}

# show specific stuff is under which tbt devices
# Input:
#  $1: device node
# Return 0 otherwise false or die
stuff_in_tbt() {
  local dev_node=$1
  local dev_pci_h=""
  local dev_pci_d=""
  local tbt_pci=""
  local num=""
  local num_add=""

  dev_pci_h=$(udevadm info --attribute-walk --name="$dev_node" \
    | grep "looking" \
    | head -n 1 \
    | awk -F "0000:" '{print $NF}' \
    | cut -d ':' -f 1)
  dev_pci_d=$((0x"$dev_pci_h"))
  for ((num=1;num<=TBT_NUM;num++)); do
    TBT_DEV_NAME=""
    DEV_PCI=""
    num_add=$((num+1))

    [[ "$num_add" -gt "$TBT_NUM" ]] && {
      TBT_DEV_NAME=$(sed -n ${num}p $TBT_DEV_FILE)
      DEV_PCI=$dev_pci_h
      break
    }

    tbt_pci=$(sed -n ${num_add}p $PCI_DEC_FILE)
    if [[ "$dev_pci_d" -lt "$tbt_pci" ]]; then
      TBT_DEV_NAME=$(sed -n ${num}p $TBT_DEV_FILE)
      DEV_PCI=$dev_pci_h
      break
    else
      continue
    fi
  done

  [[ -n "$TBT_DEV_NAME" ]] || {
    test_print_wrg "$dev_node pci_d:$dev_pci_d us:$tbt_pci connected with unkonw tbt"
    return 1
  }
}

# Check device node is under tbt device
# Input:
#   $1: device node
# Return 0 otherwise false or die
dev_under_tbt() {
  local dev_node=$1
  local dev_tp=""
  DEV_SERIAL=""
  DEV_TYPE=""

  pci_dev=$(udevadm info --attribute-walk --name="$dev_node" \
    | grep "KERNEL" \
    | tail -n 2 \
    | head -n 1 \
    | awk -F '==' '{print $NF}' \
    | cut -d '"' -f 2)
  [[ -n "$ROOT_PCI" ]] || find_root_pci
  [[ -n "$ROOT_PCI" ]] || die "Could not find tbt root PCI"
  if [[ "$pci_dev" == *"$ROOT_PCI"* ]]; then
    dev_tp=$(udevadm info --query=all --name="$dev_node" \
      | grep "ID_BUS=" \
      | cut -d '=' -f 2)
    DEV_SERIAL=$(udevadm info --query=all --name="$dev_node" \
      | grep "ID_SERIAL=" \
      | cut -d '-' -f 1 \
      | cut -d '=' -f 2)
    case $dev_tp in
      ata)
        DEV_TYPE="HDD"
        ;;
      usb)
        check_usb_type "$dev_node"
        ;;
      *)
        test_print_wrg "$dev_node is one unknow type:$dev_tp"
        DEV_TYPE="$dev_tp"
        ;;
    esac
    stuff_in_tbt "$dev_node"
    echo " |-> $dev_node $DEV_TYPE pci-${DEV_PCI}:00 $DEV_SERIAL $TBT_DEV_NAME" >> $STUFF_FILE
    return 0
  else
    return 1
  fi
}

# List all stuff under each tbt device
# Input: NA
# Return 0 otherwise false or die
list_tbt_stuff() {
  local tbt_devs=""
  local tbt_dev=""
  local tbt_stuff=""
  local tbt_de_name=""

  cat /dev/null > "$TBT_STUFF_LIST"
  tbt_devs=$(cat $TBT_DEV_FILE)
  for tbt_dev in $tbt_devs; do
    tbt_stuff=""
    tbt_de_name=""
    tbt_de_name=$(cat ${TBT_PATH}/${tbt_dev}/device_name)
    echo "$tbt_dev:$tbt_de_name" >> "$TBT_STUFF_LIST"
    tbt_stuff=$(cat $STUFF_FILE \
              | grep "${tbt_dev}$" \
              | awk -F " $tbt_dev" '{print $1}')
    [[ -z "$tbt_stuff" ]] || \
      echo "$tbt_stuff" >> "$TBT_STUFF_LIST"
  done
  cat $TBT_STUFF_LIST
}

# Check all tbt upstream PCI and tbt device number is correct
# Input: NA
# Return 0 otherwise false or die
check_tbt_us_pci() {
  local tbt_dev_num=""
  local tbt_us_num=""

  tbt_dev_num=$(cat "$TBT_DEV_FILE" | wc -l)
  tbt_us_num=$(cat "$PCI_DEC_FILE" | wc -l)

  [[ "$tbt_dev_num" -eq "$tbt_us_num" ]] || {
    test_print_wrg "$TBT_DEV_FILE num:$tbt_dev_num not equal $PCI_DEC_FILE num:$tbt_us_num"
    test_print_wrg "tbt stuffs maybe not correct due to above reason!!!"
    if [[ "$tbt_dev_num" -gt "$tbt_us_num" ]]; then
      TBT_NUM=$tbt_us_num
    else
      TBT_NUM=$tbt_dev_num
    fi
    test_print_trc "TBT_NUM:$TBT_NUM"
    return 1
  }
  TBT_NUM=$tbt_dev_num
}

# Check each device node and then list all stuff under tbt devices
# Input: NA
# Return 0 otherwise false or die
find_tbt_dev_stuff()
{
  local dev_nodes=""
  local dev_node=""

  cat /dev/null > "$STUFF_FILE"
  tbt_us_pci
  topo_tbt_show
  check_tbt_us_pci
  dev_nodes=$(ls -1 /dev/sd? 2>/dev/null)
  [[ -z "$dev_nodes" ]] && {
    test_print_trc "No /dev/sd? node find:$dev_nodes"
    exit 1
  }
  for dev_node in $dev_nodes; do
    dev_under_tbt "$dev_node"
    [[ "$?" -eq 0 ]] || continue
  done
  list_tbt_stuff
}
