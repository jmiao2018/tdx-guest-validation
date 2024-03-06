#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation

source "common.sh"

# Global variables
export EXIT_FAILURE=1
BINDIR=/usr/bin
DSA_PATH="$(pwd)/ddt_intel/dsa"

# Global variables
: "${DMATEST_SYSFS_PATH:=/sys/module/dmatest/parameters}"
: "${DEVICE_TYPE=dsa}"

: "${DRV_SYSFS_PATH:=''}"
: "${DEVICE_SYSFS_PATH:=''}"
: "${DSA_PCI_ID:=0b25}"
: "${IAX_PCI_ID:=0cfe}"

: "${DEVICE_NUM:=8}"
: "${GROUPS_PER_DEV:=4}"
: "${WQS_PER_DEV:=8}"
: "${ENGINES_PER_DEV:=4}"
: "${DEVICE_USED:=1}"
: "${WQ_USED_PER_DEV:=1}"
: "${CHANNELS:=1}"
: "${ITERATIONS:=100}"
: "${WQ_MODE:=shared}"
: "${THREADS:=1}"

idxd_setup() {
  test_print_trc "idxd setup"
  init_global_variables
  load_idxd_module
  check_accfg
  read_max_devices
  unloading_test_module
  load_test_module
  read_num_per_device
}

init_global_variables() {
  dsa_lists=(0 2 4 6 8 10 12 14)
  iax_lists=(1 3 5 7 9 11 13 15)
  DRV_SYSFS_PATH="/sys/bus/dsa/drivers/idxd"
  DEVICE_SYSFS_PATH="/sys/bus/dsa/devices"
}

check_accfg() {
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
}

read_max_devices() {
  if [[ "$DEVICE_TYPE" == "dsa" ]]; then
    DEVICE_NUM=$(lspci | grep -c "$DSA_PCI_ID")
  else
    DEVICE_NUM=$(lspci | grep -c "$IAX_PCI_ID")
  fi
  if [[ $DEVICE_NUM -eq 0 ]]; then
    block_test "Device number is 0!"
  fi
  test_print_trc "Device number is $DEVICE_NUM"
}

read_num_per_device() {
  read_groups_pre_device
  read_engines_pre_device
  read_wqs_pre_device
}

read_groups_pre_device() {
  local dev0_sysfs_path="${DEVICE_SYSFS_PATH}/dsa0"

  if [[ ! -f "${dev0_sysfs_path}/max_groups" ]]; then
    block_test "${dev0_sysfs_path}/max_groups doesn't exist!"
  fi
  GROUPS_PER_DEV=$(cat "${dev0_sysfs_path}/max_groups")
  test_print_trc "Groups per device: $GROUPS_PER_DEV"
}

read_engines_pre_device() {
  local dev0_sysfs_path="${DEVICE_SYSFS_PATH}/dsa0"

  if [[ ! -f "${dev0_sysfs_path}/max_engines" ]]; then
    block_test "${dev0_sysfs_path}/max_engines doesn't exist!"
  fi
  ENGINES_PER_DEV=$(cat "${dev0_sysfs_path}/max_engines")
  test_print_trc "Engines per device: $ENGINES_PER_DEV"
}

read_wqs_pre_device() {
  local dev0_sysfs_path="${DEVICE_SYSFS_PATH}/dsa0"

  if [[ ! -f "${dev0_sysfs_path}/max_work_queues" ]]; then
    block_test "${dev0_sysfs_path}/max_work_queues doesn't exist!"
  fi
  WQS_PER_DEV=$(cat "${dev0_sysfs_path}/max_work_queues")
  test_print_trc "WQ per device: $WQS_PER_DEV"
}

# Disable all active devices dsa/iax and enabled wqs.
# Use accel-config tool to disable the device and wq.
disable_devices() {
  test_print_trc "Disabling devices..."

  local device_type

  # assume same max device number for dsa and iax
  max_dev_index=$((DEVICE_NUM-1))
  for device_type in 'dsa' 'iax'; do
    if [[ "$DEVICE_TYPE" == "iax" ]]; then
      device_lists=("${iax_lists[@]}")
    else
      device_lists=("${dsa_lists[@]}")
    fi

    for i in $(seq 0 $max_dev_index); do
      local dev_sysfs_path="${DEVICE_SYSFS_PATH}"
      local state_path="${dev_sysfs_path}/$device_type${device_lists[$i]}/state"
      if [[ ! -f "$state_path" ]]; then
        continue
      fi
      local state
      state=$(cat "$state_path")
      if [[ $state == "enabled" ]]; then
        do_cmd "accel-config disable-device ${device_type}${device_lists[$i]}"
      fi
    done
  done
}

disable_device() {
  test_print_trc "Disabling $1 device with index $2..."

  local device_type=$1
  local index=$2
  local drv_sysfs_path="/sys/bus/$device_type/drivers/$device_type"
  local unbind_sysfs_path="${drv_sysfs_path}/unbind"
  echo "${device_type}${index}" > "$unbind_sysfs_path"
}
idxd_teardown() {
  test_print_trc "idxd teardown"
  unloading_test_module
  disable_devices
}

# If idxd module is not loaded, load it
load_idxd_module() {
  lsmod | grep -w -q "idxd" || {
  	modprobe idxd
  	sleep 1
  }
}

load_test_module() {
  test_print_trc "Loading test module..."

  do_cmd "modprobe dmatest"
  sleep 1
}

unloading_test_module() {
  test_print_trc "Unloading test module..."

  lsmod | grep -q "dmatest" && {
  	rmmod dmatest
  	sleep 1
  }
}

load_config() {
  test_print_trc "loading config..."
  local config_name
  case $CHANNELS in
    1)
      if [[ $WQ_MODE == "shared" ]]; then
        config_name="1d1g1q_kernel_shared.conf"
      else
        # $WQ_MODE == "dedicated"
        config_name="1d1g1q_kernel_dedicated.conf"
      fi
      DEVICE_USED=1
      WQ_USED_PER_DEV=1
    ;;
    2)
      config_name="2d2g2q_kernel.conf"
      DEVICE_USED=2
      WQ_USED_PER_DEV=1
    ;;
    4)
      config_name="4d4g4q_kernel.conf"
      DEVICE_USED=4
      WQ_USED_PER_DEV=1
    ;;
    8)
      config_name="8d8g8q_kernel.conf"
      DEVICE_USED=8
      WQ_USED_PER_DEV=1
    ;;
    32)
      config_name="4d16g32q_kernel.conf"
      DEVICE_USED=4
      WQ_USED_PER_DEV=8
    ;;
    64)
      config_name="8d32g64q_kernel.conf"
      DEVICE_USED=8
      WQ_USED_PER_DEV=8
    ;;
    *)
    block_test "Invalid channel number $CHANNELS, allowed: 1/2/4/8/32/64"
  esac
  config_dir="$(dirname "$0")/${DEVICE_TYPE}_configs"
  config_path="${config_dir}/${config_name}"
  test_print_trc "config file: $config_path"
  accel-config load-config -c "$config_path"
}

enable_devices() {
  test_print_trc "Enabling devices..."

  if [[ "$DEVICE_TYPE" == "iax" ]]; then
    device_lists=("${iax_lists[@]}")
  else
    device_lists=("${dsa_lists[@]}")
  fi

  for i in $(seq 0 $((DEVICE_USED-1)) ); do
    test_print_trc "Enabling $DEVICE_TYPE${device_lists[$i]}..."
    accel-config enable-device "$DEVICE_TYPE${device_lists[$i]}" \
      || die "Failed to enable device $DEVICE_TYPE${device_lists[$i]}"
    for j in $(seq 0 $((WQ_USED_PER_DEV-1)) ); do
      test_print_trc "Enabling $DEVICE_TYPE${device_lists[$i]}/wq${device_lists[$i]}.${j}..."
      accel-config enable-wq "$DEVICE_TYPE${device_lists[$i]}/wq${device_lists[$i]}.${j}" \
        || die "Failed to enable $DEVICE_TYPE${device_lists[$i]}/wq${device_lists[$i]}.${j}"
    done
  done
}

check_channels() {
  local channel_num
  channel_num=$(ls -altr /sys/class/dma/ | wc -l)

  test_print_trc "Channels:"
  ls -altr /sys/class/dma/

  if [[ $channel_num -lt $CHANNELS ]]; then
    die "Channel number is less than ${CHANNELS}"
  fi
}

config_dmatest() {
  test_print_trc "Configurating dmatest..."
  do_cmd "echo 2000 > /sys/module/dmatest/parameters/timeout"
  do_cmd "echo $ITERATIONS > /sys/module/dmatest/parameters/iterations"
  do_cmd "echo $THREADS > /sys/module/dmatest/parameters/threads_per_chan"
  do_cmd "echo \"\" > /sys/module/dmatest/parameters/channel"
}

do_test() {
  load_config
  enable_devices
  check_channels
  config_dmatest

  test_print_trc "Running dmatest..."
  echo 1 > /sys/module/dmatest/parameters/run
  cat /sys/module/dmatest/parameters/wait

  test_print_trc "Test complete:"
  local total_threads
  local passed_threads
  local dmesg_num
  total_threads=$((CHANNELS*THREADS))
  dmesg_num=$((total_threads+2*CHANNELS))
  # log dmesg
  dmesg | grep ' dmatest: ' | tail -n "$dmesg_num" | grep ' summary '
  passed_threads=$(dmesg \
               | grep ' dmatest: ' \
               | tail -n "$dmesg_num" \
               | grep -c ', 0 failures ')
  test_print_trc "Total threads: $total_threads"
  test_print_trc "Passed threads: $passed_threads"
  if [[ "$passed_threads" -lt "$total_threads" ]]; then
    die "Test failed"
  fi
  test_print_trc "Test passed"
}

usage() {
  cat <<-EOF
  usage: ./${0##*/} [-c channels ] [-d device_type] [-i iterations ] [ -m mode]
                    [ -t threads ] [-h Help]
  -c channels :     Number of channels
  -d device_type :  "dsa"(default) / "iax"
  -i iterations :   Number of iterations
  -m mode :         "shared"/"dedicated", used when channels is equal to 1
  -t threads:       Threads per channel
  -h :              Print this
EOF
}

#################### DO THE WORK ####################
while getopts :c:d:i:m:t:h arg; do
  case $arg in
    c)
      CHANNELS=$OPTARG
    ;;
    d)
      DEVICE_TYPE=$OPTARG
    ;;
    i)
      ITERATIONS=$OPTARG
    ;;
    m)
      WQ_MODE=$OPTARG
      if [[ $WQ_MODE != "shared" ]] && [[ $WQ_MODE != "dedicated" ]]; then
        block_test "Invalide wq mode: $WQ_MODE"
      fi
    ;;
    t)
      THREADS=$OPTARG
    ;;
    h)
      usage && exit 0
    ;;
    \?)
      usage && die "Invalid Option -$OPTARG"
    ;;
    :)
      usage && die "Option -$OPTARG requires an argument."
    ;;
  esac
done

export teardown_handler="idxd_teardown"

idxd_setup
do_test
exec_teardown
