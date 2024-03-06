#!/bin/bash

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

# @Author   Zelin Deng <zelinx.deng@intel.com>
#
# Oct, 2015 Zelin Deng  <zelinx.deng@intel.com>
#           -Initial Draft
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#           -Modifed add source to pci_functions script

############################ DESCRIPTION ######################################

# @desc     Script runs sanity functions that check PCI driver and devices functionalities
# @returns
# @history  2015-10-19: Initial Version
# @history  2017-08-05: PCI_functions source added

############################# FUNCTIONS #######################################
source "common.sh"
source "pci_functions.sh"

usage(){
  cat <<_EOF
    Usage: ./${0##*/} [-t <DEV_TYPE>] [-c <CASE_ID>] [-l <TEST_LOOP>]

    -t DEV_TYPE: PCI device type, such as "Audio device","USB controller" .e.g
    -c CASE_ID: Test case id, the case need to be run
    -l TEST_LOOP: Test Loop
    -h : print this usage
_EOF
}

while getopts t:c:l:h arg; do
  case $arg in
    t) DEV_TYPE="$OPTARG"  ;;
    c) CASE_ID="$OPTARG"   ;;
    l) TEST_LOOP="$OPTARG" ;;
    h) usage
       exit 0
       ;;
    \?)
       test_print_trc "Invalid option"
       usage
       exit 1
       ;;
  esac
done

: ${CASE_ID:="1"}
: ${TEST_LOOP:="1"}

if [ -z "$DEV_TYPE" ];then
  PCI_DEV_LIST=$(get_pci_device.sh $DEV_TYPE)
else
  PCI_DEV_LIST=$(get_pci_device.sh)
fi
#if we get empty device list, we should return block due to lack of precondition
if [ $? -eq 0 ];then
  test_print_trc "get pci device list successfull, device are:$PCI_DEV_LIST"
else
  test_print_trc "no valid pci device"
  exit 2
fi

#before test, make sure x server has been closed.The tests will remove vga card
#requires root. However, you have to lanuch runtests.sh by "sudo", if you don't
#many cases will fail due to need permission owned by root
systemctl status lightdm
if [ $? -eq "0" ];then
  systemctl stop lightdm || die "systemctl stop lightdm failed"
fi

x="0"
PCI_DEV_LIST=($PCI_DEV_LIST)
cnt="${#PCI_DEV_LIST[@]}"
test_print_trc "============Starting PCI basic tests=============="
while [ $x -lt "$TEST_LOOP" ]
do
  for dev in ${PCI_DEV_LIST[*]}
    do
      test_print_trc "====Now testting pci device $dev ===="
      case $CASE_ID in
        1)
          #check PCI speed and width
          lspci -d "$dev" | grep "PCI bridge:" || {
            cnt=$(($cnt-1))
            test_print_trc "No pci bridge"
            [ "$cnt" -eq "0" ]
            continue
            }
          cnt=$(($cnt+1))
          sta_speed=$(get_pci_speed "$dev" "LnkSta") || die "failed to get $dev staspeed"
          sta_width=$(get_pci_width "$dev" "LnkSta") || die "failed to get $dev stawidth"
          cap_speed=$(get_pci_speed "$dev" "LnkCap") || die "failed to get $dev capspeed"
          cap_width=$(get_pci_width "$dev" "LnkCap") || die "failed to get $dev capwidth"
          test_print_trc "PCI bridge:$dev,sta_speed=$sta_speed GB/s,sta_width=$sta_width,cap_speed=$cap_speed GB/s,cap_width=$cap_width"
          ;;
        2)
          verify_pci_driver "$dev" || die "Failed to verify pci driver"
          ;;
        3)
          verify_pci_device "$dev" || die "Failed to verify pci device"
          ;;
        4)
          verify_pci_config "$dev" || die "Failed to verify pci config"
          ;;
        5)
          lspci -v -d "$dev" | grep "Kernel driver in use:" || {
            cnt=$(($cnt-1))
            test_print_trc "kernel driver in use info is missing"
            [ "$cnt" -eq "0" ]
            continue
            }
          pci_device_bind_unbind "$dev" || die "Failed to bind/unbind"
          ;;
        6)
          pci_device_remove_rescan "$dev" || die "Failed to remove/rescan"
          ;;
        7)
          #skip if it is not pci bridge
          cnt=$(($cnt-1))
          lspci -d "$dev" | grep "PCI bridge:" || {
            test_print_trc "No pci bridge"
            [ "$cnt" -eq "0" ] && die "No pci gen4 device is over 16G"
            continue
            }
          dev_rep_cnt=$(lspci -d "$dev" | grep -c "PCI bridge:")
		  dev_addr=$(lspci -d "$dev" | grep "PCI bridge:" | cut -d' ' -f1)
		  if [[ "$dev_rep_cnt" -gt "1" ]]; then
			  for i in $dev_addr
				  do
					  do_cmd "sta_speed=$(lspci -s "$i" -vv | grep "LnkSta" | grep -ioE "Speed [0-9\.]+GT/s" | cut -d' ' -f2 | cut -d'G' -f1)"
					  do_cmd "sta_width=$(lspci -s "$i" -vv | grep "LnkSta" | grep -ioE "Width x[0-9]+" | cut -d' ' -f2)"
					  do_cmd "cap_speed=$(lspci -s "$i" -vv | grep "LnkCap" | grep -ioE "Speed [0-9\.]+GT/s" | cut -d' ' -f2 | cut -d'G' -f1)"
					  do_cmd "cap_width=$(lspci -s "$i" -vv | grep "LnkCap" | grep -ioE "Width x[0-9]+" | cut -d' ' -f2)"
					  test_print_trc "PCI bridge:$dev,sta_speed=$sta_speed GB/s,sta_width=$sta_width,cap_speed=$cap_speed GB/s,cap_width=$cap_width"
					  #Pass if speed is over 16G
					  if [[ $(echo "$sta_speed >= 16" | bc) -eq 1 ]] ;then
						  break;
					  fi
				  done
		  else
			  do_cmd "sta_speed=$(get_pci_speed "$dev" "LnkSta")"
			  do_cmd "sta_width=$(get_pci_width "$dev" "LnkSta")"
			  do_cmd "cap_speed=$(get_pci_speed "$dev" "LnkCap")"
			  do_cmd "cap_width=$(get_pci_width "$dev" "LnkCap")"
			  test_print_trc "PCI bridge:$dev,sta_speed=$sta_speed GB/s,sta_width=$sta_width,cap_speed=$cap_speed GB/s,cap_width=$cap_width"
		  fi
		  #Pass if speed is over 16G
		  if [[ $(echo "$sta_speed >= 16" | bc) -eq 1 ]] ;then
			  test_print_trc "Speed is over 16G, pass"
			  break;
		  elif [[ "$cnt" -eq 0 ]] ;then
			  die "No pci gen4 device is over 16G"
          fi
          ;;
        8)
          cnt=$(($cnt-1))
          lspci -d "$dev" | grep "PCI bridge:" || {
            test_print_trc "No pci bridge"
            [ "$cnt" -eq "0" ] && die "No pci gen5 device is over 32G"
            # continue for 'for' to check next pci device
            continue
            }
          do_cmd "sta_speed=$(get_pci_speed "$dev" "LnkSta")"

          # Pass if speed is over 16G
          if [[ $(echo "$sta_speed >= 32" | bc) -eq 1 ]]; then
            test_print_trc "Speed is over 32G, pass"
            # break out of 'for'
            break;
          elif [[ "$cnt" -eq 0 ]]; then
            die "No pci gen4 device is over 16G"
          fi
          ;;
        9)
          cnt=$(($cnt-1))
          lspci -d "$dev" | grep "PCI bridge:" || {
            test_print_trc "No pci bridge"
            [ "$cnt" -eq "0" ] && die "No pci gen6 device is over 64G"
            # continue for 'for' to check next pci device
            continue
            }
          do_cmd "cap_speed=$(get_pci_speed "$dev" "LnkCap")"

          # Pass if speed is over 64G
          if [[ $(echo "$cap_speed >= 64" | bc) -eq 1 ]]; then
            test_print_trc "Speed is over 64G, pass"
            # break out of 'for'
            break;
          elif [[ "$cnt" -eq 0 ]]; then
            die "No pci gen6 device is over 64G"
          fi
          ;;
        10)
          cnt=$(($cnt-1))
          lspci -d "$dev" | grep "PCI bridge:" || {
            test_print_trc "No pci bridge"
            [ "$cnt" -eq "0" ] && die "No pci gen6 device is over 64G"
            # continue for 'for' to check next pci device
            continue
            }
          do_cmd "sta_speed=$(get_pci_speed "$dev" "LnkSta")"

          # Pass if speed is over 64G
          if [[ $(echo "$sta_speed >= 64" | bc) -eq 1 ]]; then
            test_print_trc "Speed is over 64G, pass"
            # break out of 'for'
            break;
          elif [[ "$cnt" -eq 0 ]]; then
            die "No pci gen6 device is over 64G"
          fi
          ;;
        11)
          cnt=$(($cnt-1))
          lspci -d "$dev" | grep "PCI bridge:" || {
            test_print_trc "No pci bridge"
            [ "$cnt" -eq "0" ] && die "No pci gen6 device is over 64G"
            # continue for 'for' to check next pci device
            continue
            }
          do_cmd "ctl2_speed=$(get_pci_speed "$dev" "LnkCtl2")"

          # Pass if speed is over 64G
          if [[ $(echo "$ctl2_speed >= 64" | bc) -eq 1 ]]; then
            test_print_trc "Speed is over 64G, pass"
            # break out of 'for'
            break;
          elif [[ "$cnt" -eq 0 ]]; then
            die "No pci gen6 device is over 64G"
          fi
          ;;
      esac
  done
  x=$(($x+1))
done
