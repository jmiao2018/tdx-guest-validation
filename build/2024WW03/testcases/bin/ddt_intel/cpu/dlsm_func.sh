#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for DLSM(Dynamic Lock Step Mode) function tests
#

source "dlsm_common.sh"
[[ "$CPU_COMMON_SOURCED" -eq 1 ]] || source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-b BIN_NAME][-s dlsm_msr_cap][-h]
  -b  Test cpu bin name
  -s  Test msr like "dlsm_msr_cap"
  -p  PARM like 0x2b3
  -h  show This
__EOF
}

dlsm_test() {
  [[ -z "$ACTIVE_CPUS" ]] && get_active_cpu_list
  [[ -z "$SHADOW_CPUS" ]] && get_shadow_cpu_list
  online_all_cpu

  case $SCENARIO in
    dlsm_msr_cap)
      # 0x2b3: IA32_DLSM_CAPABILITY, defined MSR_IA32_DLSM_CAPABILITY in kernel.
      local dlsm_cap="$PARM"
      local high_bit="1"
      local low_bit="1"
      local exp_value="1"

      basic_check_msr "$dlsm_cap"
      check_msr "$dlsm_cap" "$high_bit" "$low_bit" "$exp_value"
      ;;
    dlsm_msr_cpu_role)
      # Write with different SCENARIO to add more check point in future
      basic_check_msr "$PARM"
      ;;
    dlsm_msr_break_status)
      basic_check_msr "$PARM"
      ;;
    dlsm_msr_lockstep_state)
      basic_check_msr "$PARM"
      ;;
    dlsm_sysfs)
      check_dlsm_sysfs
      ;;
    dlsm_sync)
      test_dlsm_sync_cpu "$PARM"
      ;;
    check_shadow_lockstep)
      echo "[INFO] 1. Shadow cpu doesn't have enable lockstep item:" | tee "$KMSG"
      # Should not have /sys/devices/system/cpu/cpu1/lockstep/enable item
      for cpu_id in $SHADOW_CPUS; do
        if [[ -e "${CPU_FOLDER}/cpu${cpu_id}/lockstep/enable" ]]; then
          test_print_trc "[FAIL] There should not be file ${CPU_FOLDER}/cpu${cpu_id}/lockstep/enable"
          ((FAIL_NUM++))
        else
          test_print_trc "[PASS] There should not be file ${CPU_FOLDER}/cpu${cpu_id}/lockstep/enable"
        fi
      done
      ;;
    enable_active_lockstep)
      echo "[INFO] 2. All cpus are lockstep disabled and online, enable lockstep for active cpu should pass:"  | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1" "$SHOW"
      ;;
    offline_shadow_lockstep)
      echo "[INFO] 3. Active cpus are lockstep and online, shadow cpus are lockstep and offline, offline shadow cpu again should still offline:" | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      set_cpu "$SHADOW_CPUS" "0" "0" "0"
      ;;
    disable_active_lockstep)
      echo "[INFO] 4. Active cpus are lockstep and online, shadow cpus are lockstep and offline, disable lockstep for active cpu should pass:" | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      lockstep_cpu "$ACTIVE_CPUS" "0" "0" "0" "$SHOW"
      ;;
    online_shadow_lockstep)
      echo "[INFO] 5. Active cpus are lockstep and online, shadow cpus are lockstep and offline, online shadow cpu should pass:" | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      set_cpu "$SHADOW_CPUS" "1" "0" "1"
      ;;
    offline_active_lockstep)
      echo "[INFO] 6. Active cpus are lockstep and online, shadow cpus are lockstep and offline, offline active cpu should fail:" | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      set_cpu "$ACTIVE_CPUS" "0" "1" "1"
      ;;
    online_acitve_lockstep)
      echo "[INFO] 7. Active cpus are lockstep and online, online active cpu should pass:" | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      set_cpu "$ACTIVE_CPUS" "1" "0" "1"
      ;;
    disable_active_lockstep_again)
      echo "[INFO] 8. All cpus are lockstep disabled and online, disable active cpu lockstep again should pass:" | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "0" "0" "0"
      lockstep_cpu "$ACTIVE_CPUS" "0" "0" "0"
      ;;
    offline_active_lockstep_disabled)
      echo "[INFO] 9. All cpus are lockstep disabled and online, offline active cpu should pass:" | tee "$KMSG"
      online_all_cpu
      lockstep_cpu "$ACTIVE_CPUS" "0" "0" "0"
      set_cpu "$ACTIVE_CPUS" "0" "0" "0"
      ;;
    offline_shadow_lockstep_disabled)
      echo "[INFO] 10. All cpus are lockstep disabled and online, offline shadow cpu should pass:" | tee "$KMSG"
      online_all_cpu
      lockstep_cpu "$ACTIVE_CPUS" "0" "0" "0"
      set_cpu "$SHADOW_CPUS" "0" "0" "0"
      ;;
    enable_active_lockstep_lockstep_shadow)
      echo "[INFO] 11. Enable lockstep for active cpu, offline shadow cpu, enable shadow cpu again should successful." | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      set_cpu "$SHADOW_CPUS" "0" "0" "0"
      lockstep_cpu "$ACTIVE_CPUS" "1" "0" "1"
      ;;
    enable_active_lockstep_offline_shadow)
      echo "[INFO] 12. Online all cpu, disable lockstep for all cpu, offline all shadow cpu, enable lockstep for acitve cpus should fail." | tee "$KMSG"
      lockstep_cpu "$ACTIVE_CPUS" "0" "0" "0"
      set_cpu "$SHADOW_CPUS" "0" "0" "0"
      lockstep_cpu "$ACTIVE_CPUS" "1" "1" "0"
      ;;
    *)
      usage && exit 1
      ;;
  esac

  if [[ "$FAIL_NUM" -eq 0 ]]; then
    test_print_trc "[INFO] All dlsm cases passed, FAIL_NUM:$FAIL_NUM."
  else
    die "[WARN] dlsm failed case num:$FAIL_NUM."
  fi

  dmesg_check "Call Trace" "$NULL"
  dmesg_check "segfault" "$NULL"
}

while getopts :b:s:p:h arg; do
  case $arg in
    b)
      BIN_NAME=$OPTARG
      ;;
    s)
      SCENARIO=$OPTARG
      ;;
    p)
      PARM=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      die "Invalid Option -$OPTARG"
      ;;
  esac
done

dlsm_test
exec_teardown
