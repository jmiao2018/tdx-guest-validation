#!/bin/sh

source "powermgr_common.sh"

#Store values that have to be restored after test
#Those for sata
DIRTY_WB_CS=""
DIRTY_EX_CS=""
LAPTOP_MODE=""
PORT_CTL_STATUS=()
DISK_CTL_STATUS=()
DIST_AUTO_DELAY=()

#Those for simulate a structure like this
#"0000:00:00.0"  "Host bridge"                   "8086:191f"    "0"
#"0000:00:02.0"  "VGA compatible controller"     "8086:1911"    "0"
#"0000:00:08.0"  "System peripheral"             "8086:a135"    "0"
#"0000:00:13.0"  "Non-VGA unclassified device"   "8086:a12f"    "0"
#"0000:00:14.0"  "USB controller"                "8086:a131"    "0"
#"000:00:14.2"   "Signal processing controller"  "8086:a160"    "0"
#This 1st field is pci slot, the 2nd field is device name, the 3rd field is device
#id, the 4th field is test result.
#4th field can be 0,1,2,3
#0: Device does not enter D3 when runtime PM control has been set as "auto". It's FAIL
#1: Device enter D3 and wake up from D3. It's PASS
#2: Device enter D3 but can't stay D3 state for $TEST_TIME. It's used for stress test. It's FAIL
#3: Device enter D3 but can't wake up from D3. It's FAIL
DEV_SLOTS_ARRAY=""
DEV_NAME_ARRAY=""
DEV_ID_ARRAY=""
RUNTIME_STATUS_ARRAY=()

function get_all_pci_devs()
{
	#Use '|' as the delimeter
	DEV_SLOTS_ARRAY=`lspci -D -nn | cut -d' ' -f1 | tr '\n' '|'`
	DEV_NAME_ARRAY=`lspci -D -nn | cut -d' ' -f2- | sed 's/\[.*//g' | tr '\n' '|'`
	DEV_ID_ARRAY=`lspci -D -nn | grep -oE '\[[0-9a-f]+:[0-9a-f]+\]' | sed 's/\[\|\]//g' | tr '\n' '|'`
}


sata_ctl=`lspci -D | grep "SATA controller" | cut -d' ' -f1`
function prepare_for_sata()
{
	# Max every 10 minutes flush dirty pages
	local flush=600
	local timeout=15
	local cnt=0
	# See Documentation/laptops/laptop-mode.txt for more information
	# following tunables.
	DIRTY_WB_CS=`cat $VM_PROCFS_PATH/dirty_writeback_centisecs`
	DIRTY_EX_CS=`cat $VM_PROCFS_PATH/dirty_expire_centisecs`
	do_cmd "echo $((flush * 100)) > $VM_PROCFS_PATH/dirty_writeback_centisecs"
	do_cmd "echo $((flush * 100)) > $VM_PROCFS_PATH/dirty_expire_centisecs"
	# Enable laptop mode
	LAPTOP_MODE=`cat $VM_PROCFS_PATH/laptop_mode`
	test_print_trc "Enable laptop mode"
	do_cmd "echo 5 > $VM_PROCFS_PATH/laptop_mode"

	# Enable runtime PM for all ports
	test_print_trc "Get all sata ports"
	ports=`ls /sys/bus/pci/devices/$sata_ctl | grep "ata[0-9]\+"`
	for port in $ports
	do
		PORT_CTL_STATUS[$cnt]=`cat /sys/bus/pci/devices/$sata_ctl/$port/power/control`
		do_cmd "echo auto > /sys/bus/pci/devices/$sata_ctl/$port/power/control"
		cnt=$((cnt + 1))
	done

	# And last for the disk
	sata_disks=`ls /dev/disk/by-id -al | grep -vE "DVD|usb|part" | grep ata | awk -F'../' '{print $NF}'`
	cnt=0
	for sata_disk in $sata_disks
	do
		DISK_CTL_STATUS[$cnt]=`cat /sys/block/$sata_disk/device/power/control`
		DISK_AUTO_DELAY[$cnt]=`cat /sys/block/$sata_disk/device/power/autosuspend_delay_ms`
		do_cmd "echo auto > /sys/block/$sata_disk/device/power/control"
		do_cmd "echo $((timeout * 1000)) > /sys/block/$sata_disk/device/power/autosuspend_delay_ms"
		cnt=$((cnt + 1))
	done
}

function restore_for_sata()
{
	local cnt=0
	do_cmd "echo $DIRTY_WB_CS > $VM_PROCFS_PATH/dirty_writeback_centisecs"
	do_cmd "echo $DIRTY_EX_CS > $VM_PROCFS_PATH/dirty_expire_centisecs"
	do_cmd "echo $LAPTOP_MODE > $VM_PROCFS_PATH/laptop_mode"

	# Restore runtime PM control setting for all ports
	test_print_trc "Get all sata ports"
	ports=`ls /sys/bus/pci/devices/$sata_ctl | grep "ata[0-9]\+"`
	for port in $ports
	do
		do_cmd "echo ${PORT_CTL_STATUS[$cnt]} > /sys/bus/pci/devices/$sata_ctl/$port/power/control"
		cnt=$((cnt + 1))
	done
	# And for the disk
	sata_disks=`ls /dev/disk/by-id -al | grep -vE "DVD|usb|part" | grep ata | awk -F'../' '{print $NF}'`
	cnt=0
	for sata_disk in $sata_disks
	do
		do_cmd "echo ${DISK_CTL_STATUS[$cnt]} > /sys/block/$sata_disk/device/power/control"
		do_cmd "echo ${DISK_AUTO_DELAY[$cnt]} > /sys/block/$sata_disk/device/power/autosuspend_delay_ms"
		cnt=$((cnt + 1))
	done
}

#Unbind usb hub to ensure usb device won't impact USB controller enter D3
usb_binded_hubs=`ls /sys/bus/usb/drivers/usb | grep -oE "usb[0-9]+" | tr '\n' '|'`
function prepare_for_usb()
{
	local usb_hub=""
	#If we are using USB ethernet, don't unbind this hub
	iface=`mii-tool 2>/dev/null | grep "link ok" | cut -d":" -f1`
	if [ "x$iface" != "x" ];then
		usb_hub=`ls -al /sys/class/net/$iface | grep -oE "usb[0-9]+" | tr '\n' '|'`
	fi
	for usb_binded_hub in $usb_binded_hubs
	do
		if [ "x$usb_bub" == "x$usb_hub" ];then
			continue
		fi
		do_cmd "echo $usb_binded_hub > /sys/bus/usb/drivers/usb/unbind"
	done
}

function restore_for_usb()
{
	for usb_binded_hub in $usb_binded_hubs
	do
		if [ -e /sys/bus/usb/drivers/usb/$usb_binded_hub ];then
			continue
		fi
		do_cmd "echo $usb_binded_hub > /sys/bus/usb/drivers/usb/bind"
	done
}

function prepare_for_all()
{
	if [ "x$sata_ctl" != "x" ];then
		do_cmd prepare_for_sata
	fi
	if [ "x$usb_binded_hubs" != "x" ];then
		do_cmd prepare_for_usb
	fi
}

function restore_for_all()
{
	local cnt=0
	if [ "x$sata_ctl" != "x" ];then
		do_cmd restore_for_sata
	fi
	if [ "x$usb_binded_hubs" != "x" ];then
		do_cmd restore_for_usb
	fi
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		do_cmd "echo ${CTL_STATUS_ARRAY[$cnt]} > /sys/bus/pci/devices/$dev_slot/power/control"
		cnt=$((cnt + 1))
	done
}

#This is for saving runtime PM control setting of all pci slots.
CTL_STATUS_ARRAY=()

function enter_to_d3()
{
	local cnt=0
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		echo -e "dev_slot:$dev_slot\ndev_name:${DEV_NAME_ARRAY[$cnt]}\ndev_id:${DEV_ID_ARRAY[$cnt]}"
		orig_status=`cat /sys/bus/pci/devices/$dev_slot/power/control`
		test_print_trc "Original runtime PM control setting of ${DEV_NAME_ARRAY[$cnt]} is $orig_status"
		CTL_STATUS_ARRAY[$cnt]=$orig_status
		test_print_trc "Set runtime PM control of ${DEV_NAME_ARRAY[$cnt]} as \"auto\""
		do_cmd "echo auto > /sys/bus/pci/devices/$dev_slot/power/control"
		cnt=$((cnt + 1))
	done
}

function wakeup_from_d3()
{
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		test_print_trc "Set runtime PM control of ${DEV_NAME_ARRAY[$cnt]} as \"on\""
		do_cmd "echo on > /sys/bus/pci/devices/$dev_slot/power/control"
	done
}

function check_if_enter_d3()
{
	local cnt=0
	local tmp=""
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		current_runtime_status=`cat /sys/bus/pci/devices/$dev_slot/power/runtime_status`
		test_print_trc "/sys/bus/pci/devices/$dev_slot/power/runtime_status:$current_runtime_status"
		tmp=${RUNTIME_STATUS_ARRAY[$cnt]}
		[ "$current_runtime_status" == "active" ] && RUNTIME_STATUS_ARRAY[$cnt]=0 || RUNTIME_STATUS_ARRAY[$cnt]=1
		#Only runtime status changed, print the log
		if [ "${RUNTIME_STATUS_ARRAY[$cnt]}" -eq "0" ] && [ "x$tmp" != "x${RUNTIME_STATUS_ARRAY[$cnt]}" ];then
			test_print_trc "PCI device $dev_slot-${DEV_NAME_ARRAY[$cnt]}-${DEV_ID_ARRAY[$cnt]} didn't enter D3"
		fi
		cnt=$((cnt + 1))
	done
}

function check_if_stay_d3()
{
	local cnt=0
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		current_runtime_status=`cat /sys/bus/pci/devices/$dev_slot/power/runtime_status`
		test_print_trc "/sys/bus/pci/devices/$dev_slot/power/runtime_status:$current_runtime_status"
		if [ "${RUNTIME_STATUS_ARRAY[$cnt]}" -eq "1" ] && [ "$current_runtime_status" == "active" ];then
			test_print_trc "PCI device $dev_slot-${DEV_NAME_ARRAY[$cnt]}-${DEV_ID_ARRAY[$cnt]} wake up from D3 during stress test"
			RUNTIME_STATUS_ARRAY[$cnt]=2
		fi
		cnt=$((cnt + 1))
	done
}

function check_if_wakeup_d3()
{
	local cnt=0
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		current_runtime_status=`cat /sys/bus/pci/devices/$dev_slot/power/runtime_status`
		test_print_trc "/sys/bus/pci/devices/$dev_slot/power/runtime_status:$current_runtime_status"
		if [ "${RUNTIME_STATUS_ARRAY[$cnt]}" -eq "1" ] && [ "$current_runtime_status" == "suspended" ];then
			test_print_trc "PCI device $dev_slot-${DEV_NAME_ARRAY[$cnt]}-${DEV_ID_ARRAY[$cnt]} didn't wake up from D3"
			RUNTIME_STATUS_ARRAY[$cnt]=3
		fi
		cnt=$((cnt + 1))
	done
}

fail_flag=0
function show_results()
{
	local cnt=0
	echo "=============================================================="
	printf "%10s\t%30s\t%10s\t%30s\n" dev_slot dev_name results descibe
	for dev_slot in ${DEV_SLOTS_ARRAY[@]}
	do
		case ${RUNTIME_STATUS_ARRAY[$cnt]} in
			0)
				printf "%10s\t%30s\t%10s\t%30s\n" $dev_slot ${DEV_NAME_ARRAY[$cnt]} FAIL "FAILED TO ENTER D3"
				fail_flag=1
			;;
			1)
				printf "%10s\t%30s\t%10s\t%30s\n" $dev_slot ${DEV_NAME_ARRAY[$cnt]} PASS "ENTER D3 then wake up from it"
			;;
			2)
				printf "%10s\t%30s\t%10s\t%30s\n" $dev_slot ${DEV_NAME_ARRAY[$cnt]} FAIL "FAILED TO STAY D3"
				fail_flag=1
			;;
			3)
				printf "%10s\t%30s\t%10s\t%30s\n" $dev_slot ${DEV_NAME_ARRAY[$cnt]} FAIL "FAILED TO WAKE UP FROM D3"
				fail_flag=1
			;;
		esac
		cnt=$((cnt + 1))
	done
	echo "============================================================"
}

: ${TEST_MODE:="func"}
: ${TEST_COUNT:="5"}
: ${TEST_TIME:="3600"}
while getopts m:t:T:h arg
do
	case $arg in
		m)
			TEST_MODE=$OPTARG
		;;
		t)
			TEST_COUNT=$OPTARG
		;;
		T)
			TEST_TIME=$OPTARG
		;;
		h)
			die "${0##*/} [-m TEST_MODE] [-t TEST_COUNT] [-T TEST_TIME] -h
				-m: TEST_MODE - func/stress
				-t: TEST_COUNT - Unit is second. Get states every one second
					for TEST_COUNT times to eliminate the influence as some
					devices may not be able to enter/wake up from D3 at once.
				-T: TEST_TIME - Unit is second. Test if device can stay D3 for
					TEST_TIME seconds
				-h: print this help
			"
		;;
		\?)
			die "Invalid argument"
		;;
	esac
done

oldIFS=$IFS
IFS="|"

#test logic
test_print_trc "Get all pci devices"
do_cmd get_all_pci_devs
do_cmd prepare_for_all

count=0
DEV_SLOTS_ARRAY=($DEV_SLOTS_ARRAY)
DEV_NAME_ARRAY=($DEV_NAME_ARRAY)
DEV_ID_ARRAY=($DEV_ID_ARRAY)
case $TEST_MODE in
	func)
		do_cmd enter_to_d3
		while [ $count -lt $TEST_COUNT ]
		do
			do_cmd check_if_enter_d3
			sleep 1
			count=$((count + 1))
		done
		do_cmd wakeup_from_d3
		do_cmd check_if_wakeup_d3
	;;
	stress)
		do_cmd enter_to_d3
		while [ $count -lt $TEST_COUNT ]
		do
			do_cmd check_if_enter_d3
			sleep 1
			count=$((count + 1))
		done
		count=0
		while [ $count -lt $TEST_TIME ]
		do
			do_cmd check_if_stay_d3
			sleep 1
			count=$((count + 1))
		done
		do_cmd wakeup_from_d3
		do_cmd check_if_wakup_d3
	;;
esac
do_cmd restore_for_all
do_cmd show_results
IFS=$oldIFS

exit $fail_flag

