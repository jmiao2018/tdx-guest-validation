#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
#
# Description:  dsa2.0 op config test script

source "common.sh"

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
    cp -a $DSA_PATH/libaccel-config.so.1.0.0 /usr/lib64/
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

op_config_teardown(){
    disable_all
}

op_config_test() {

  reset_idxd

  checking_test_precondition

  disable_all

  case $TEST_SCENARIO in
    feature_check)
	[ ! -f "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config" ] && die "fail: opcode config is not supported "
      ;;
    default_value)
	disable_all
	reset_idxd
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	# 00000000,00000000,00000000,00000000,00000000,00000000,0000007b,00bf07ff
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,0000007b,00bf07ff" ]; then
		echo "fail: opsconfig=$opsconfig,should be 0000007b,00bf07ff"
		exit 1
	fi
      ;;
    write_0)
	echo 0 > "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config"
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000" ]; then
		echo "fail: opsconfig=$opsconfig,should be 00000000,00000000"
		exit 1
	fi
      ;;
    config_default)
	"$ACCFG" config-wq --group-id=0 --mode=dedicated --type=user --name="app1" --driver-name=user --priority=10 --op-config=0000007b,00bf07ff "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,0000007b,00bf07ff" ]; then
		echo "fail: opsconfig=$opsconfig,should be 0000007b,00bf07ff"
		exit 1
	fi
      ;;
    write_memory_all)
	echo 238 > "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config"
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000238" ]; then
		echo "fail: opsconfig=$opsconfig,should be 00000000,00000238"
		exit 1
	fi
      ;;
    config_memory)
	"$ACCFG" config-wq --group-id=0 --mode=dedicated --type=user --name="app1" --driver-name=user --priority=10 --op-config=9 "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000009" ]; then
		echo "fail: opsconfig=$opsconfig,should be 00000000,00000009"
		exit 1
	fi
      ;;
    wq_0_test)
	"$ACCFG" config-wq --group-id=0 --mode=dedicated --type=user --name="app1" --driver-name=user --priority=10 "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" --group-id=0
	#cat /sys/bus/dsa/devices/wq0.0/op_config
	#value is:0-10,16-21,23,32-33,35-39,51-55
	echo 0 > "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config"
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000" ]; then
		echo "fail: opsconfig=$opsconfig,should be 00000000,00000000"
		exit 1
	fi
	"$ACCFG" enable-device "dsa${DSA_ID}"
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	if "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x3 -v;then
		echo "fail: case 5 dsa_test should fail but pass"
		exit 1
	fi
	"$ACCFG" disable-device "dsa${DSA_ID}"
      ;;
    wq_memory_copy_test)
	"$ACCFG" config-wq --group-id=0 --mode=dedicated --type=user --name="app1" --driver-name=user --priority=10 "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" --group-id=0
	#cat /sys/bus/dsa/devices/wq0.0/op_config
	#value is:0-10,16-21,23,32-33,35-39,51-55
	echo 8 > "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config"
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000008" ]; then
		echo "fail: opsconfig=$opsconfig,should be 00000000,00000008"
		exit 1
	fi
	"$ACCFG" enable-device "dsa${DSA_ID}"
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	if ! "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x3 -v;then
		echo "fail: case 6 dsa_test should pass but fail"
		exit 1
	fi
	if "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x5 -v;then
		echo "fail: case 6 dsa_test 0x5 should fail but pass"
		exit 1
	fi
	"$ACCFG" disable-device "dsa${DSA_ID}"
      ;;
    wq_memory_fill_test)
	"$ACCFG" config-wq --group-id=0 --mode=dedicated --type=user --name="app1" --driver-name=user --priority=10 --op-config=30 "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" --group-id=0
	#cat /sys/bus/dsa/devices/wq0.0/op_config
	#value is:0-10,16-21,23,32-33,35-39,51-55
	opsconfig=$(cat "/sys/bus/dsa/devices/wq${DSA_ID}.${WQ_ID}/op_config")
	if [ "$opsconfig" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000030" ]; then
		echo "fail: opsconfig=$opsconfig,should be 00000000,00000030"
		exit 1
	fi
	"$ACCFG" enable-device "dsa${DSA_ID}"
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	if ! "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x4 -v;then
		echo "fail: case 7 dsa_test should pass but fail"
		exit 1
	fi
	if ! "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x5 -v;then
		echo "fail: case 7 dsa_test should pass but fail"
		exit 1
	fi
	if "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x9 -v;then
		echo "fail: case 7 dsa_test 0x5 should fail but pass"
		exit 1
	fi
	"$ACCFG" disable-device "dsa${DSA_ID}"
      ;;
    *)
      die "Invalid tests!"
      ;;
    esac

  return 0
}

################################ DO THE WORK ##################################
TEST_SCENARIO="version"
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

op_config_test
teardown_handler="op_config_teardown"
exec_teardown
