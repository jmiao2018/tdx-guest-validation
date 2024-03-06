#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2021 Intel Corporation
#
# Description:  accel-config tool test script

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
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
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
  if [ -f "$DSA_PATH/dsa_test" ] && [ -x "$DSA_PATH/dsa_test" ]; then
    export DSATEST=$DSA_PATH/dsa_test
    test_print_trc "dsa_test1:$DSATEST"
  elif [ -f "$TESTDIR/dsa_test" ] && [ -x "$TESTDIR/dsa_test" ]; then
    export DSATEST="$TESTDIR"/dsa_test
    test_print_trc "dsa_test2:$DSATEST"
  else
    test_print_trc "Couldn't find an dsa_test binary"
    exit "$EXIT_FAILURE"
  fi

  [ ! -d "$IDXD_DEVICE_PATH/dsa0" ] && echo "No dsa0" && exit "$EXIT_SKIP"

  return 0
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

load_config()
{
  # CONFIGS
  if [ -f "$DSA_PATH/usertest/$CONFIG_NAME.conf" ]; then
    export CONFIG1=$DSA_PATH/usertest/${CONFIG_NAME}.conf
  else
    test_print_trc "Can't find config file $DSA_PATH/usertest/$CONFIG_NAME.conf"
    exit "$EXIT_FAILURE"
  fi
  configurable=$(cat /sys/bus/dsa/devices/dsa0/configurable)
  if [ "$configurable" ]; then
    do_cmd "$ACCFG" load-config -c "$CONFIG1"
  fi
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

accel_config_teardown(){
    disable_all
}

accel_config_test() {

  checking_test_precondition

  disable_all

  reset_idxd

  case $TEST_SCENARIO in
    version)
	  do_cmd "$ACCFG -v"
	  do_cmd "$ACCFG --version"
	  do_cmd "$ACCFG version"
      ;;
    help)
	  do_cmd "$ACCFG -h"
	  do_cmd "$ACCFG --help"
	  do_cmd "$ACCFG help"
      ;;
    list-cmds)
	  do_cmd "$ACCFG --list-cmds"
      ;;
    list)
	  do_cmd "$ACCFG list"
      ;;
    load-config_h)
	  do_cmd "$ACCFG load-config -h"
      ;;
    save-config_h)
	  do_cmd "$ACCFG save-config -h"
      ;;
    disable-device_h)
	  do_cmd "$ACCFG disable-device -h"
      ;;
    enable-device_h)
	  do_cmd "$ACCFG enable-device -h"
      ;;
    disable-wq_h)
	  do_cmd "$ACCFG disable-wq -h"
      ;;
    enable-wq_h)
	  do_cmd "$ACCFG enable-wq -h"
      ;;
    config-device_h)
	  do_cmd "$ACCFG config-device -h"
      ;;
    config-group_h)
	  do_cmd "$ACCFG config-group -h"
      ;;
    config-wq_h)
	  do_cmd "$ACCFG config-wq -h"
      ;;
    config-engine_h)
	  do_cmd "$ACCFG config-engine -h"
      ;;
    config-engine_groupid)
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 --group-id=0"
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 --group-id 0"
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 --group-id=\"1\""
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 --group-id \"1\""
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 -g 2"
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 -g \"3\""
	  group_id=$(cat $IDXD_DEVICE_PATH/dsa0/engine0.0/group_id)
	  if [ "$group_id" -ne 3 ]; then
		die "Failed: engine group id should be 3"
	  fi
      ;;
    config-wq_mode)
	  do_cmd "$ACCFG config-wq --mode=dedicated dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq --mode=shared dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -m dedicated dsa0/wq0.0"
	  mode=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/mode)
          if [ "$mode" != "dedicated" ]; then
		die "Failed:  mode=$mode,should be dedicated"
	  fi
	  do_cmd "$ACCFG config-wq -m shared dsa0/wq0.0"
      ;;
    config-wq_size)
	  do_cmd "$ACCFG config-wq --wq-size 32 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -s 128 dsa0/wq0.0"
	  size=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/size)
	  if [ "$size" -ne 128 ]; then
		die "Failed: size=$size,should be 128"
	  fi
	  do_cmd "$ACCFG config-wq -s 64 dsa0/wq0.0"
      ;;
    config-wq_groupid)
	  do_cmd "$ACCFG config-wq --group-id 3 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -g 3 dsa0/wq0.0"
	  group_id=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/group_id)
	  if [ "$group_id" -ne 3 ]; then
		die "Failed: group_id=$group_id,should be 3"
	  fi
	  do_cmd "$ACCFG config-wq -g 1 dsa0/wq0.0"
      ;;
    config-wq_priority)
	  do_cmd "$ACCFG config-wq --priority=15 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -p 12 dsa0/wq0.0"
	  priority=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/priority)
	  if [ "$priority" -ne 12 ]; then
		die "Failed priority=$priority,should be 12"
	  fi
	  do_cmd "$ACCFG config-wq -p 3 dsa0/wq0.0"
      ;;
    config-wq_blockonfault)
	  do_cmd "$ACCFG config-wq --block-on-fault 0 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -b 1 dsa0/wq0.0"
	  block_on_fault=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/block_on_fault)
	  if [ "$block_on_fault" -ne 1 ]; then
		die "Failed: block_on_fault=$block_on_fault,should be 1"
	  fi
	  do_cmd "$ACCFG config-wq -b 0 dsa0/wq0.0"
      ;;
    config-wq_maxbatchsize)
	  do_cmd "$ACCFG config-wq --max-batch-size=1024 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -c 128 dsa0/wq0.0"
	  max_batch_size=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/max_batch_size)
	  if [ "$max_batch_size" -ne 128 ]; then
		die "Failed max_batch_size=$max_batch_size,should be 128"
	  fi
	  do_cmd "$ACCFG config-wq -c 64 dsa0/wq0.0"
      ;;
    config-wq_maxxfersize)
	  do_cmd "$ACCFG config-wq --max-transfer-size=2147483648 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -x 134217728 dsa0/wq0.0"
	  max_transfer_size=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/max_transfer_size)
	  if [ "$max_transfer_size" -ne 134217728 ]; then
		die "Failed: max_transfer_size=$max_transfer_size,should be 134217728"
	  fi
	  do_cmd "$ACCFG config-wq -x 2097152 dsa0/wq0.0"
      ;;
    config-wq_type)
	  do_cmd "$ACCFG config-wq --type=user dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -y user dsa0/wq0.0"
      ;;
    config-wq_name)
	  do_cmd "$ACCFG config-wq --name=app1 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -n app1 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -n guest1 dsa0/wq0.0"
	  name=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/name)
	  if [ "${name}" != "guest1" ]; then
		die "$FAIL_MESSAGE name=$name,should be guest1"
	  fi
	  do_cmd "$ACCFG config-wq -n dmaengine1 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -n crypto1 dsa0/wq0.0"
      ;;
    config-wq_drivername)
	  do_cmd "$ACCFG config-wq --driver-name=crypto dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -d user dsa0/wq0.0"
	  driver_name=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/driver_name)
	  if [ "${driver_name}" != "user" ]; then
		die "Failed driver_name=$driver_name,should be user"
	  fi
	  do_cmd "$ACCFG config-wq -d dmaengine dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -d crypto dsa0/wq0.0"
      ;;
    config-wq_threshold)
	  do_cmd "$ACCFG config-wq -m shared dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq --wq-size 64 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq --threshold=64 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -t 31 dsa0/wq0.0"
	  threshold=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/threshold)
	  if [ "$threshold" -ne 31 ]; then
		die "Failed: threshold=$threshold,should be 31"
	  fi
	  do_cmd "$ACCFG config-wq -t 1 dsa0/wq0.0"
      ;;
    enable_disable_dedicated)
	  do_cmd "$ACCFG config-wq -g 0 -m dedicated -y user -n app1  -d user -p 15 dsa0/wq0.0"
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 -g 0"
	  do_cmd "$ACCFG enable-device dsa0"
  	  do_cmd "$ACCFG enable-wq dsa0/wq0.0"
	  state=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/state)
	  if [ "${state}" != "enabled" ]; then
		die "$FAIL_MESSAGE state=$state,should be disabled"
	  fi
	  do_cmd "$ACCFG disable-wq dsa0/wq0.0"
	  do_cmd "$ACCFG disable-device dsa0"
      ;;
    enable_disable_shared)
	  do_cmd "$ACCFG config-wq -g 0 -m shared -s 64 -y user -n app1 -d user -p 13 -t 19 dsa0/wq0.0"
	  do_cmd "$ACCFG config-engine dsa0/engine0.0 -g 0"
	  do_cmd "$ACCFG enable-device dsa0"
  	  do_cmd "$ACCFG enable-wq dsa0/wq0.0"
	  state=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/state)
	  if [ "${state}" != "enabled" ]; then
		die "$FAIL_MESSAGE state=$state,should be disabled"
	  fi
	  do_cmd "$ACCFG disable-wq dsa0/wq0.0"
	  do_cmd "$ACCFG disable-device dsa0"
      ;;
    config-wq_op_config)
	  do_cmd "$ACCFG config-wq --op-config 9 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -o 30 dsa0/wq0.0"
	  op_config=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/op_config)
	  if [ "$op_config" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000030" ]; then
		die "Failed: op_config=$op_config,should be 00000000,00000030"
	  fi
	  do_cmd "$ACCFG config-wq --op-config=0000007b,00bf07ff dsa0/wq0.0"
      ;;
    config-wq_prs_disable)
	  do_cmd "$ACCFG config-wq --prs-disable 0 dsa0/wq0.0"
	  do_cmd "$ACCFG config-wq -r 1 dsa0/wq0.0"
	  prs_disable=$(cat $IDXD_DEVICE_PATH/dsa0/wq0.0/prs_disable)
	  if [ "$prs_disable" -ne 1 ]; then
		die "Failed: prs_disable=$prs_disable,should be 1"
	  fi
	  do_cmd "$ACCFG config-wq -r 0 dsa0/wq0.0"
      ;;
    config-event_log_size)
	  do_cmd "$ACCFG config-device --event-log-size 8197 dsa0"
	  do_cmd "$ACCFG config-device -e 65535 dsa0"
	  event_log_size=$(cat $IDXD_DEVICE_PATH/dsa0/event_log_size)
	  if [ "$event_log_size" -ne 65535 ]; then
		die "Failed: event_log_size=$event_log_size,should be 65535"
	  fi
	  do_cmd "$ACCFG config-device -e 64 dsa0"
      ;;
    config-group_batch_progress_limit)
	  do_cmd "$ACCFG config-group --batch-progress-limit 0 dsa0/group0.0"
	  do_cmd "$ACCFG config-group -p 3 dsa0/group0.0"
	  batch_progress_limit=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/batch_progress_limit)
	  if [ "$batch_progress_limit" -ne 3 ]; then
		die "Failed: batch_progress_limit=$batch_progress_limit,should be 3"
	  fi
	  do_cmd "$ACCFG config-group -p 0 dsa0/group0.0"
      ;;
    config-group_desc_progress_limit)
	  do_cmd "$ACCFG config-group --desc-progress-limit 0 dsa0/group0.0"
	  do_cmd "$ACCFG config-group -d 3 dsa0/group0.0"
	  desc_progress_limit=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/desc_progress_limit)
	  if [ "$desc_progress_limit" -ne 3 ]; then
		die "Failed: desc_progress_limit=$desc_progress_limit,should be 3"
	  fi
	  do_cmd "$ACCFG config-group -d 0 dsa0/group0.0"
      ;;
    config-group_read_bandwith_limit)
	  do_cmd "$ACCFG config-group --read-bandwith-limit 0 dsa0/group0.0"
	  do_cmd "$ACCFG config-group --read-bandwith-limit 3 dsa0/group0.0"
	  read_bandwith_limit=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/read_bandwith_limit)
	  if [ "$read_bandwith_limit" -ne 3 ]; then
		die "Failed: read_bandwith_limit=$read_bandwith_limit,should be 3"
	  fi
	  do_cmd "$ACCFG config-group --read-bandwith-limit dsa0/group0.0"
      ;;
    config-group_write_bandwith_limit)
	  do_cmd "$ACCFG config-group --write-bandwith-limit 0 dsa0/group0.0"
	  do_cmd "$ACCFG config-group --write-bandwith-limit 3 dsa0/group0.0"
	  write_bandwith_limit=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/write_bandwith_limit)
	  if [ "$write_bandwith_limit" -ne 3 ]; then
		die "Failed: write_bandwith_limit=$write_bandwith_limit,should be 3"
	  fi
	  do_cmd "$ACCFG config-group --write-bandwith-limit dsa0/group0.0"
      ;;
    config-group_read_buffers_allowed)
	  do_cmd "$ACCFG config-group --read-buffers-allowed 16 dsa0/group0.0"
	  do_cmd "$ACCFG config-group -t 28 dsa0/group0.0"
	  read_buffers_allowed=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/read_buffers_allowed)
	  if [ "$read_buffers_allowed" -ne 28 ]; then
		die "Failed: read_buffers_allowed=$read_buffers_allowed,should be 28"
	  fi
	  do_cmd "$ACCFG config-group -t 0 dsa0/group0.0"
      ;;
    config-group_read_buffers_reserved)
	  do_cmd "$ACCFG config-group --read-buffers-reserved 7 dsa0/group0.0"
	  do_cmd "$ACCFG config-group -r 37 dsa0/group0.0"
	  read_buffers_reserved=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/read_buffers_reserved)
	  if [ "$read_buffers_reserved" -ne 37 ]; then
		die "Failed: read_buffers_reserved=$read_buffers_reserved,should be 37"
	  fi
	  do_cmd "$ACCFG config-group -r 0 dsa0/group0.0"
      ;;
    config-group_use_read_buffer_limit)
	  do_cmd "$ACCFG config-device -l 11 dsa0"
	  do_cmd "$ACCFG config-group --use-read-buffer-limit 0 dsa0/group0.0"
	  do_cmd "$ACCFG config-group -l 1 dsa0/group0.0"
	  use_read_buffer_limit=$(cat $IDXD_DEVICE_PATH/dsa0/group0.0/use_read_buffer_limit)
	  if [ "$use_read_buffer_limit" -ne 1 ]; then
		die "Failed: use_read_buffer_limit=$use_read_buffer_limit,should be 1"
	  fi
	  do_cmd "$ACCFG config-group -l 0 dsa0/group0.0"
	  do_cmd "$ACCFG config-device -l 0 dsa0"
      ;;
    *)
      die "Invalid tests!"
      ;;
    esac

  return 0
}

################################ DO THE WORK ##################################
TEST_SCENARIO="version"

while getopts :t:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
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

accel_config_test
teardown_handler="accel_config_teardown"
exec_teardown
