#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
#
# Description:  dsa2.0 inter-pasid test script

source "common.sh"

############################# FUNCTIONS #######################################

# Global variables
export EXIT_FAILURE=1
TESTDIR=/usr/libexec/accel-config/test
BINDIR=/usr/bin
DSA_PATH="$(pwd)/ddt_intel/dsa"
IDXD_DEVICE_PATH=/sys/bus/dsa/devices
LOG_PATH="/tmp/itp"

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

  # ITPTEST
  if [ -f "$TESTDIR/inter_pasid_test" ] && [ -x "$TESTDIR/inter_pasid_test" ]; then
    export ITPTEST="$TESTDIR"/inter_pasid_test
    test_print_trc "dsa_test1:$ITPTEST"
  elif [ -f "$DSA_PATH/inter_pasid_test" ] && [ -x "$DSA_PATH/inter_pasid_test" ]; then
    export ITPTEST=$DSA_PATH/inter_pasid_test
    test_print_trc "dsa_test2:$ITPTEST"
  else
    test_print_trc "Couldn't find an dsa_test binary"
    exit "$EXIT_FAILURE"
  fi

  [ ! -d "$IDXD_DEVICE_PATH/dsa0" ] && echo "No dsa0" && exit "$EXIT_SKIP"

  [ -d "$LOG_PATH" ] || mkdir "$LOG_PATH"

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

itp_teardown(){
    disable_all
}

itp_test() {
  local failed_result=""
  local error_result=""

  reset_idxd

  checking_test_precondition

  disable_all

  "$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.0" -g 0
  "$ACCFG" config-engine "dsa${DSA_ID}/engine${DSA_ID}.1" -g 0
  "$ACCFG" config-wq -g 0 -m dedicated -s 16 -y user -n wq0 -d user -p 10 "dsa${DSA_ID}/wq${DSA_ID}.0"
  "$ACCFG" config-wq -g 0 -m dedicated -s 16 -y user -n wq1 -d user -p 10 "dsa${DSA_ID}/wq${DSA_ID}.1"
  "$ACCFG" enable-device "dsa${DSA_ID}"
  "$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.0"
  "$ACCFG" enable-wq "dsa${DSA_ID}/wq${DSA_ID}.1"
  test_print_trc "enable dsa${DSA_ID} and wq${DSA_ID}.${WQ_ID}"

  case $TEST_SCENARIO in
    single_user_window)
	"$ITPTEST" -v > ${LOG_PATH}/itp_test.log
      ;;
    pass_owner_file)
	"$ITPTEST" -pv > ${LOG_PATH}/itp_test.log
      ;;
    multi_user_window)
	"$ITPTEST" -mv > ${LOG_PATH}/itp_test.log
      ;;
    pass_owner_multi_user)
	"$ITPTEST" -pmv > ${LOG_PATH}/itp_test.log
      ;;
    *)
      die "Invalid tests!"
      ;;
    esac

  "$ACCFG" disable-wq "dsa${DSA_ID}/wq${DSA_ID}.0"
  "$ACCFG" disable-wq "dsa${DSA_ID}/wq${DSA_ID}.1"
  "$ACCFG" disable-device "dsa${DSA_ID}"

  failed_result=$(grep -c "failed" "$LOG_PATH/itp_test.log")
  error_result=$(grep -c "Submitter error" "$LOG_PATH/itp_test.log")

  if [[ $failed_result -eq 0 ]] && [[ $error_result -eq 0 ]]; then
    test_print_trc "itp pass $(cat $LOG_PATH/itp_test.log)"
  else
    die "itp test failed $(cat $LOG_PATH/itp_test.log)"
  fi

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

itp_test
teardown_handler="itp_teardown"
exec_teardown
