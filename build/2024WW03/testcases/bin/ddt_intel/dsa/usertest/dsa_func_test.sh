#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
#
# Description:  dsa3.0 function test script

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

dsa_func_teardown(){
    disable_all
}

dsa_func_test() {

  reset_idxd

  checking_test_precondition

  disable_all

  case $TEST_SCENARIO in
    dsa3_version_check)
	version=$(cat "$IDXD_DEVICE_PATH/dsa${DSA_ID}/version")
	if [ "$version" != "0x300" ]; then
		echo "fail: version=$version,should be 0x300"
		exit "$EXIT_FAILURE"
	fi
      ;;
    pasid_enabled_check)
	[ ! -f "$IDXD_DEVICE_PATH/dsa${DSA_ID}/pasid_enabled" ] && test_print_trc "No SVM support" && exit "$EXIT_FAILURE"
	pasid_en=$(cat "$IDXD_DEVICE_PATH/dsa${DSA_ID}/pasid_enabled")
	if [ "$pasid_en" -ne 1 ]; then
    	test_print_trc "expect pasid_enabled 1, but it is $pasid_en"
		exit "$EXIT_FAILURE"
	fi
      ;;
    read_bandwith_limit_enabled_check)
	[ ! -f "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit" ] && test_print_trc "No read_bandwith_limit support" && exit "$EXIT_FAILURE"
      ;;
    write_bandwith_limit_enabled_check)
	[ ! -f "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit" ] && test_print_trc "No write_bandwith_limit support" && exit "$EXIT_FAILURE"
      ;;
    read_bandwith_limit_default_value)
	read_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit")
	if [ "$read_bandwith_limit" -ne 0 ]; then
		echo "read_bandwith_limit=$read_bandwith_limit,should be 0"
		exit "$EXIT_FAILURE"
	fi
      ;;
    write_bandwith_limit_default_value)
	write_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit")
	if [ "$write_bandwith_limit" -ne 0 ]; then
		echo "write_bandwith_limit=$write_bandwith_limit,should be 0"
		exit "$EXIT_FAILURE"
	fi
      ;;
    read_bandwith_limit_set_value_1)
	echo 1 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit"
	read_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit")
	if [ "$read_bandwith_limit" -ne 1 ]; then
		echo "read_bandwith_limit=$read_bandwith_limit,should be 1"
		exit "$EXIT_FAILURE"
	fi
      ;;
    read_bandwith_limit_set_value_2)
	echo 2 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit"
	read_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit")
	if [ "$read_bandwith_limit" -ne 2 ]; then
		echo "read_bandwith_limit=$read_bandwith_limit,should be 2"
		exit "$EXIT_FAILURE"
	fi
      ;;
    read_bandwith_limit_set_value_3)
	echo 3 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit"
	read_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit")
	if [ "$read_bandwith_limit" -ne 3 ]; then
		echo "read_bandwith_limit=$read_bandwith_limit,should be 3"
		exit "$EXIT_FAILURE"
	fi
      ;;
    write_bandwith_limit_set_value_1)
	echo 1 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit"
	write_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit")
	if [ "$write_bandwith_limit" -ne 1 ]; then
		echo "write_bandwith_limit=$write_bandwith_limit,should be 1"
		exit "$EXIT_FAILURE"
	fi
      ;;
    write_bandwith_limit_set_value_2)
	echo 1 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit"
	write_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit")
	if [ "$write_bandwith_limit" -ne 1 ]; then
		echo "write_bandwith_limit=$write_bandwith_limit,should be 1"
		exit "$EXIT_FAILURE"
	fi
      ;;
    write_bandwith_limit_set_value_3)
	echo 1 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit"
	write_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit")
	if [ "$write_bandwith_limit" -ne 1 ]; then
		echo "write_bandwith_limit=$write_bandwith_limit,should be 1"
		exit "$EXIT_FAILURE"
	fi
      ;;
    rbl_1_wbl_2_engine0_dsa_test)
	"$ACCFG" config-wq --group-id="${GP_ID}" --mode=dedicated --type=user --name="app1" --driver-name=user --priority=10 "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	"$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" --group-id="${GP_ID}"
	echo 1 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit"
	echo 2 > "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit"
	"$ACCFG" enable-device "dsa${DSA_ID}"
	"$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.${WQ_ID}"
	read_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/read_bandwith_limit")
	if [ "$read_bandwith_limit" -ne 1 ]; then
		echo "read_bandwith_limit=$read_bandwith_limit,should be 1"
		exit "$EXIT_FAILURE"
	fi
	write_bandwith_limit=$(cat "$IDXD_DEVICE_PATH/group${DSA_ID}.${GP_ID}/write_bandwith_limit")
	if [ "$write_bandwith_limit" -ne 2 ]; then
		echo "write_bandwith_limit=$write_bandwith_limit,should be 2"
		exit "$EXIT_FAILURE"
	fi
	if "$DSATEST" -w 0 -l 4096 -f 0x1 -o 0x5 -v;then
		echo "fail: case 6 dsa_test 0x5 should fail but pass"
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
GP_ID=0

while getopts :t:d:g:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    d)
      DSA_ID=$OPTARG
      ;;
    g)
      GP_ID=$OPTARG
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

dsa_func_test
teardown_handler="dsa_func_teardown"
exec_teardown
