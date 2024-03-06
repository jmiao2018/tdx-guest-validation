#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
#
# Description:  dsa3.0 function test script

source "common.sh"
source "dmesg_functions.sh"

############################# FUNCTIONS #######################################

# Global variables
export EXIT_FAILURE=1
TESTDIR=/usr/libexec/accel-config/test
BINDIR=/usr/bin
DSA_PATH="$(pwd)/ddt_intel/dsa"
IDXD_DEVICE_PATH=/sys/bus/dsa/devices

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID -d DSA_ID -w WQ_ID] [-H]
  -t  TEST CASE ID
  -d  TEST DSA ID
  -w  TEST WQ ID
  -H  show this
__EOF
}

# Check if accel-config and dsa_test installed and worked.
function checking_test_precondition()
{
  # ACCFG
  if [ -f "$BINDIR/accel-config" ] && [ -x "$BINDIR/accel-config" ]; then
    export ACCFG="$BINDIR"/accel-config
    test_print_trc "accfg1:$ACCFG"
  elif [ -f "$DSA_PATH/accel-config" ] && [ -x "$DSA_PATH/accel-config" ]; then
    cp -a "$DSA_PATH/libaccel-config.so.1.0.0" /usr/lib64/
    ln -s /usr/lib64/libaccel-config.so.1.0.0 /usr/lib64/libaccel-config.so.1
    export ACCFG=$DSA_PATH/accel-config
    test_print_trc "accfg2:$ACCFG"
  else
    test_print_trc "Couldn't find an accel-config binary"
    exit "$EXIT_FAILURE"
  fi

  # DSATEST
  if [ -f "$TESTDIR/dsa_test" ] && [ -x "$TESTDIR/dsa_test" ]; then
    export DSATEST="$TESTDIR"/dsa_test
    test_print_trc "dsa_test1:$DSATEST"
  elif [ -f "$DSA_PATH/dsa_test" ] && [ -x "$DSA_PATH/dsa_test" ]; then
    export DSATEST=$DSA_PATH/dsa_test
    test_print_trc "dsa_test2:$DSATEST"
  else
    test_print_trc "Couldn't find an dsa_test binary"
    exit "$EXIT_FAILURE"
  fi

  [ ! -d "$IDXD_DEVICE_PATH/dsa0" ] && echo "No dsa0" && exit "$EXIT_SKIP"

  return 0
}

# If idxd module is not loaded, load it
load_idxd_module() {
  lsmod | grep -w -q "idxd" || {
  	modprobe idxd
  	sleep 1
  }
}

# load/unload drivers to make sure load config file successfully
reset_idxd()
{
  lsmod | grep -q "iaa_crypto" && {
	rmmod iaa_crypto
  }
  lsmod | grep -q "iax_crypto" && {
	rmmod iax_crypto
  }
  lsmod | grep -q "idxd_mdev" && {
	rmmod idxd_mdev
  }
  lsmod | grep -q "idxd_vdev" && {
	rmmod idxd_vdev
  }
  lsmod | grep -q "idxd_uacce" && {
	rmmod idxd_uacce
  }
  lsmod | grep -q "idxd" && {
	rmmod idxd
  }
  sleep 1
  modprobe idxd
  sleep 1
}

# Disable all active devices dsa/iax and enabled wqs.
# Use accel-config tool to disable the device and wq.
disable_all() {
  test_print_trc "Start to disable the device and wq"
  for device_type in 'dsa' 'iax'; do
    # Kernel before 5.13 has dsa and iax bus. Because of ABI change, iax
    # bus is removed. All devices are in /sys/bus/das/devices.
    if [ -d /sys/bus/iax ] && [ $device_type == 'iax' ]; then
      DSA_DEVICE_PATH="/sys/bus/iax/devices"
    else
      DSA_DEVICE_PATH="/sys/bus/dsa/devices"
    fi
    # Get available devices
    for device_path in ${DSA_DEVICE_PATH}/${device_type}* ; do
      [[ $(echo "$device_path" | grep -c '!') -eq 0 ]] && {
	# Get wqs and disable it if the status is enabled
        for wqp in ${device_path}/wq* ; do
          [[ $( cat "${wqp}"/state ) == "enabled" ]] && {
            wq=${wqp##${DSA_DEVICE_PATH}/}
            test_print_trc "info:disable wq $wq"
            "$ACCFG" disable-wq "${wq}"
            echo "-1" > "${wqp}"/group_id
          }
          done
		# Disable device
        [[ $( cat "${device_path}"/state ) == "enabled" ]] && {
          test_print_trc "info:disable ${device_path##${DSA_DEVICE_PATH}/}"
          "$ACCFG" disable-device "${device_path##${DSA_DEVICE_PATH}/}"
        }
		# Remove group id of engine
        for engine in ${device_path}/engine* ; do
          echo -1 > "$engine"/group_id
        done
      }
    done
  done
  test_print_trc "disable_all is end"
}

dsa_stress_teardown(){
    disable_all
}

dsa_stress_test() {

  reset_idxd

  checking_test_precondition

  disable_all

  if [ -d $IDXD_DEVICE_PATH/wq0.15 ]; then
    wq_numbers=15
  elif [ -d $IDXD_DEVICE_PATH/wq0.7 ]; then
	wq_numbers=7
  else
    test_print_trc "DSA device is abnormal, please check devices."
    exit "$EXIT_FAILURE"
  fi

  case $TEST_SCENARIO in
    wq_shared_mode)
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" -g 0
	"$ACCFG" enable-device "dsa${DSA_ID}"
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	#run dsa test in parallel
	loop_times=0
	while [ $loop_times -le $wq_numbers ];
	do
	"$DSATEST" -v -d "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}" -t 150000 -f 0x1 -o 0x1 -b 0x3 -c 16 -l 2097152 &
	loop_times=$((loop_times+1))
 	done
	# wait test is done
	echo -en "\nWaiting for tests to finish 1"
	while [[ $(ps -aux | grep -c dsa_test) -gt 1 ]] ; do sleep 1 ; echo -n "." ; done
	"$ACCFG" disable-device "dsa${DSA_ID}"
      ;;
    dsa0_dedicated_all_wqs)
	# Config dsa device and work queue
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" -g 0
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.1" -g 1
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.2" -g 2
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.3" -g 3
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.0" -g 0 -m dedicated -y user -n app0 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.1" -g 1 -m dedicated -y user -n app1 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.2" -g 1 -m dedicated -y user -n app2 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.3" -g 2 -m dedicated -y user -n app3 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.4" -g 2 -m dedicated -y user -n app4 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.5" -g 3 -m dedicated -y user -n app5 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.6" -g 3 -m dedicated -y user -n app6 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.7" -g 3 -m dedicated -y user -n app7 -d user -s 16 -p 10
	if [[ $wq_numbers -eq 15 ]];then
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.8" -g 0 -m dedicated -y user -n app8 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.9" -g 1 -m dedicated -y user -n app9 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.10" -g 1 -m dedicated -y user -n app10 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.11" -g 2 -m dedicated -y user -n app11 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.12" -g 2 -m dedicated -y user -n app12 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.13" -g 3 -m dedicated -y user -n app13 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.14" -g 3 -m dedicated -y user -n app14 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.15" -g 3 -m dedicated -y user -n app15 -d user -s 16 -p 10
	fi
	# Enable dsa device
	"$ACCFG" enable-device "dsa${DSA_ID}"
	# Enable dsa work queues
	for i in {0..7..1}
	do
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.$i"
	done
	if [[ $wq_numbers -eq 15 ]];then
		for i in {8..15..1}
		do
		"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.$i"
		done
	fi
	#run dsa test in parallel
	loop_wq=0
	while [ $loop_wq -le $wq_numbers ];
	do
	"$DSATEST" -v -d "dsa${DSA_ID}/wq${DSA_ID}.${loop_wq}" -t 150000 -f 0x1 -o 0x1 -b 0x9 -c 16 -l 2097152 &
	loop_wq=$((loop_wq+1))
 	done
	# wait test is done
	echo -en "\nWaiting for tests to finish 1"
	while [[ $(ps -aux | grep -c dsa_test) -gt 1 ]] ; do sleep 1 ; echo -n "." ; done
	"$ACCFG" disable-device "dsa${DSA_ID}"
      ;;
    dsa0_shared_all_wqs)
	# Config dsa device and work queue
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" -g 0
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.1" -g 0
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.2" -g 1
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.3" -g 2
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.0" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.1" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.2" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.3" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.4" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.5" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.6" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.7" -g 2 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	if [[ $wq_numbers -eq 15 ]];then
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.8" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.9" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.10" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.11" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.12" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.13" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.14" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${DSA_ID}/wq${DSA_ID}.15" -g 2 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	fi
	# Enable dsa device
	"$ACCFG" enable-device "dsa${DSA_ID}"
	# Enable dsa work queues
	for i in {0..7..1}
	do
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.$i"
	done
	if [[ $wq_numbers -eq 15 ]];then
		for i in {8..15..1}
		do
		"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.$i"
		done
	fi
	#run dsa test in parallel
	loop_wq=0
	while [ $loop_wq -le $wq_numbers ];
	do
	"$DSATEST" -v -d "dsa${DSA_ID}/wq${DSA_ID}.${loop_wq}" -t 150000 -f 0x1 -o 0x1 -b 0x5 -c 16 -l 2097152 &
	loop_wq=$((loop_wq+1))
 	done
	# wait test is done
	echo -en "\nWaiting for tests to finish 1"
	while [[ $(ps -aux | grep -c dsa_test) -gt 1 ]] ; do sleep 1 ; echo -n "." ; done
	"$ACCFG" disable-device "dsa${DSA_ID}"
      ;;
    dsa_all_wqs)
    dsa_array=( $(ls -d ${IDXD_DEVICE_PATH}/dsa*) )
    dsa_numbers=$(( ${#dsa_array[@]} - 1 ))
    dsa_numbers=$((dsa_numbers+dsa_numbers))
	loop_dsa=0
	while [ $loop_dsa -le $dsa_numbers ];
	do
	# Config dsa device and work queue
	"$ACCFG" config-engine "dsa${loop_dsa}/engine${loop_dsa}.0" -g 0
	"$ACCFG" config-engine "dsa${loop_dsa}/engine${loop_dsa}.1" -g 0
	"$ACCFG" config-engine "dsa${loop_dsa}/engine${loop_dsa}.2" -g 1
	"$ACCFG" config-engine "dsa${loop_dsa}/engine${loop_dsa}.3" -g 2
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.0" -g 0 -m dedicated -y user -n app1 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.1" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.2" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.3" -g 0 -m dedicated -y user -n app1 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.4" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.5" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.6" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.7" -g 2 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	if [[ $wq_numbers -eq 15 ]];then
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.8" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.9" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.10" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.11" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.12" -g 0 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.13" -g 1 -m dedicated -y user -n app1 -d user -s 16 -p 10
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.14" -g 1 -m shared -y user -n app1 -d user -s 16 -b 1 -p 10 -t 15
	"$ACCFG" config-wq "dsa${loop_dsa}/wq${loop_dsa}.15" -g 2 -m dedicated -y user -n app1 -d user -s 16 -p 10
	fi
	  # Enable dsa device
	  "$ACCFG" enable-device "dsa${loop_dsa}"
	  # Enable dsa work queues
	  for j in {0..7..1}
	  do
	  "$ACCFG" enable-wq "dsa${loop_dsa}/wq${loop_dsa}.$j"
	  done
	  if [[ $wq_numbers -eq 15 ]];then
	  	for j in {8..15..1}
	  	do
	  	"$ACCFG" enable-wq "dsa${loop_dsa}/wq${loop_dsa}.$j"
	  	done
	  fi
	  loop_dsa=$((loop_dsa+2))
	done
	#run dsa test in parallel
	loop_dsa=0
	while [ $loop_dsa -le $dsa_numbers ];
	do
	  loop_wq=0
	  while [ $loop_wq -le $wq_numbers ];
	  do
	  "$DSATEST" -v -d "dsa${loop_dsa}/wq${loop_dsa}.${loop_wq}" -t 150000 -f 0x1 -o 0x1 -b 0x3 -c 16 -l 2097152 &
	  loop_wq=$((loop_wq+1))
 	  done
	  loop_dsa=$((loop_dsa+2))
	done
	# wait test is done
	echo -en "\nWaiting for tests to finish 1"
	while [[ $(ps -aux | grep -c dsa_test) -gt 1 ]] ; do sleep 1 ; echo -n "." ; done
	# disable dsa devices
	loop_dsa=0
	while [ $loop_dsa -le $dsa_numbers ];
	do
	  "$ACCFG" disable-device "dsa${loop_dsa}"
	  loop_dsa=$((loop_dsa+2))
	done
      ;;
    *)
      die "Invalid tests!"
      ;;
    esac

	# Check dmesgs for errors or call trace
	if extract_case_dmesg | grep "watchdog: BUG: soft lockup"; then
		die "FAIL: There is watchdog: BUG: soft lockup"
	elif extract_case_dmesg | grep "Call Trace"; then
		die "FAIL: There is Call Trace"
	else
		test_print_trc "test pass"
	fi

  return 0
}

################################ DO THE WORK ##################################
TEST_SCENARIO="wq_shared_mode"
DSA_ID=0
WQ_ID=0

while getopts :t:d:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    d)
      DSA_ID=$OPTARG
      ;;
    w)
      WQ_ID=$OPTARG
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

dsa_stress_test
teardown_handler="dsa_stress_teardown"
exec_teardown
