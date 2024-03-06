#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for DLSM(Dynamic Lock Step Mode) common functions
#
[[ "$CPU_COMMON_SOURCED" -eq 1 ]] || source "cpu_common.sh"

readonly LOCKSTEP="lockstep"
readonly CPU="cpu"
readonly ACTIVE="active"
readonly SHADOW="shadow"
readonly ROLE="role"
readonly BUDDY="peer_cpu"
readonly CPU_FOLDER="/sys/devices/system/cpu"
readonly ENABLE="enable"
readonly SHOW="show"

export ACTIVE_CPUS=""
export SHADOW_CPUS=""
export KMSG="/dev/kmsg"

FAIL_NUM=0
BUDDY_CPU=""

export teardown_handler="dlsm_teardown"
# Reserve for taerdown, present no change for cpu test
dlsm_teardown() {
  online_all_cpu
}

get_buddy_cpu() {
  local cpu=$1

  case $cpu in
    "0")
      BUDDY_CPU="1"
      ;;
    # TODO: will add more mapppings for buddy cpu
    *)
      die "Invalid cpu type:$cpu when get buddy cpu."
      ;;
  esac
}

get_active_cpu_list() {
  ACTIVE_CPUS=$(grep -H . "$CPU_FOLDER"/cpu*/"$LOCKSTEP"/"$ROLE" \
          | grep "$ACTIVE" \
          | awk -F "${CPU_FOLDER}/cpu" '{print $2}' \
          | cut -d '/' -f 1)
}

get_shadow_cpu_list() {
  SHADOW_CPUS=$(grep -H . "$CPU_FOLDER"/cpu*/"$LOCKSTEP"/"$ROLE" \
          | grep "$SHADOW" \
          | awk -F "${CPU_FOLDER}/cpu" '{print $2}' \
          | cut -d '/' -f 1)
}

check_dlsm_sysfs() {
  local lockstep_folder=

  lockstep_folder=$(ls ${CPU_FOLDER}/cpu*/${LOCKSTEP} | grep ":$")
  if [[ -z "$lockstep_folder" ]]; then
    die "No ${CPU_FOLDER}/cpu*/${LOCKSTEP} sysfs found:$lockstep_folder"
  else
    test_print_trc "Found lockstep sysfs: $lockstep_folder"
  fi
}

set_cpu_test() {
  local cpu=$1
  local set_val=$2
  local ret_exp=$3
  local val_exp=$4
  local ret=""
  local value=""

  [[ -z "$cpu" || -z "$set_val" ]] && {
    block_test "No cpu:$cpu or set_val:$set_val info, exit."
  }

  if [[ $cpu == "0" ]]; then
    test_print_trc "[INFO] Skip offline/online cpu 0 due to kernel v6.4-rc2 commit e59e74dc48a3"
    return 0
  fi
  test_print_trc "[INFO] echo $set_val > ${CPU_FOLDER}/cpu${cpu}/online"
  echo "$set_val" > "$CPU_FOLDER"/cpu"$cpu"/online 2>/dev/null
  ret=$?
  if [[ "$ret" != "$ret_exp" ]]; then
    test_print_trc "[FAIL] Set cpu$cpu enable to:$set_val, ret:$ret, exp:$ret_exp"
    ((FAIL_NUM++))
  fi

  if [[ -n "$val_exp" ]]; then
    value=$(cat "$CPU_FOLDER"/cpu"$cpu"/online)
    if [[ "$value" == "$val_exp" ]]; then
      test_print_trc "[PASS] ${CPU_FOLDER}/cpu${cpu}/online:$value, exp:$val_exp"
    else
      test_print_trc "[FAIL] ${CPU_FOLDER}/cpu${cpu}/online:$value, exp:$val_exp"
      ((FAIL_NUM++))
    fi
  fi
}

set_cpu() {
  local cpu_list=$1
  local set_val=$2
  local ret_exp=$3
  local val_exp=$4
  local cpu=""

  for cpu in $cpu_list; do
    set_cpu_test "$cpu" "$set_val" "$ret_exp" "$val_exp"
  done
}

show_lockstep_sysfs() {
  local cpu=$1
  local cpu_peer=""

  cpu_peer=$(cat /sys/devices/system/cpu/cpu"$cpu"/lockstep/peer_cpu 2>/dev/null)
  grep -H . /sys/devices/system/cpu/cpu"$cpu"/lockstep/* 2>/dev/null
  grep -H . /sys/devices/system/cpu/cpu"$cpu_peer"/lockstep/* 2>/dev/null
}

set_lockstep() {
  local cpu=$1
  local set_val=$2
  local ret_exp=$3
  local enable_exp=$4
  local enable_val=""
  local ret=""

  echo "$set_val" > "$CPU_FOLDER"/cpu"$cpu"/${LOCKSTEP}/${ENABLE} 2>/dev/null
  ret=$?
  enable_val=$(cat "$CPU_FOLDER"/cpu"$cpu"/"$LOCKSTEP"/"$ENABLE")
  if [[ "$ret" == "$ret_exp" ]]; then
    test_print_trc "[PASS] echo $set_val > ${CPU_FOLDER}/cpu${cpu}/${LOCKSTEP}/${ENABLE}:$enable_val; ret:$ret, exp:$ret_exp"
  else
    test_print_trc "[FAIL] echo $set_val > ${CPU_FOLDER}/cpu${cpu}/${LOCKSTEP}/${ENABLE}:$enable_val; ret:$ret, exp:$ret_exp"
    ((FAIL_NUM++))
  fi

  if [[ -n "$enable_exp" ]]; then
    if [[ "$enable_val" != "$enable_exp" ]]; then
      test_print_trc "[FAIL] ${CPU_FOLDER}/cpu${cpu}/${LOCKSTEP}/${ENABLE}:$enable_val, exp:$enable_exp"
      ((FAIL_NUM++))
    fi
  fi
}

lockstep_cpu() {
  local cpu_list=$1
  local set_value=$2
  local ret_exp=$3
  local enable_exp=$4
  local enable_show=$5
  local cpu=""

  for cpu in $cpu_list; do
    [[ "$enable_show" == "$SHOW" ]] && {
      echo "[INFO] Before cpu $cpu lockstep test:"
      show_lockstep_sysfs "$cpu"
    }
    set_lockstep "$cpu" "$set_value" "$ret_exp" "$enable_exp"
    [[ "$enable_show" == "$SHOW" ]] && {
      echo "[INFO] After cpu $cpu lockstep test:"
      show_lockstep_sysfs "$cpu"
    }
  done
}

test_dlsm_sync_cpu() {
  local cpu=$1

  # It's very basic dlsm test on simics
  get_buddy_cpu "$cpu"

  sysfs_check "${CPU_FOLDER}/${CPU}${BUDDY_CPU}/${LOCKSTEP}/${ROLE}" "$SHADOW"
  sysfs_check "${CPU_FOLDER}/${CPU}${BUDDY_CPU}/${LOCKSTEP}/${BUDDY}" "$cpu"

  do_cmd "echo 1 > ${CPU_FOLDER}/${CPU}${cpu}/${LOCKSTEP}/${ENABLE}"

  sysfs_check "${CPU_FOLDER}/${CPU}${cpu}/${LOCKSTEP}/${ROLE}" "$ACTIVE"
  sysfs_check "${CPU_FOLDER}/${CPU}${cpu}/${LOCKSTEP}/${BUDDY}" "$BUDDY_CPU"
}
