#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for acpi_cppc for Hybrid SKU

# Authors:      wendy.wang@intel.com
# History:      20th Oct 2021 - Created - Wendy Wang

source "common.sh"
source "powermgr_common.sh"
source "dmesg_functions.sh"
TOOL="$LTPROOT/testcases/bin"

pcore_id_first=$("$TOOL"/cpuid | grep "core type" | grep -n "Intel Core" | head -n 1 | awk -F ":" '{print $1}')
pcore_id_first=$(("$pcore_id_first" - 1))
test_print_trc "The 1st pcore cpu id: $pcore_id_first"
pcore_id_last=$("$TOOL"/cpuid | grep "core type" | grep -n "Intel Core" | tail -n 1 | awk -F ":" '{print $1}')
pcore_id_last=$(("$pcore_id_last" - 1))
test_print_trc "The last pcore cpu id: $pcore_id_last"

ecore_id_first=$("$TOOL"/cpuid | grep "core type" | grep -n "Intel Atom" | head -n 1 | awk -F ":" '{print $1}')
ecore_id_first=$(("$ecore_id_first" - 1))
test_print_trc "The 1st ecore cpu id: $ecore_id_first"
ecore_id_last=$("$TOOL"/cpuid | grep "core type" | grep -n "Intel Atom" | tail -n 1 | awk -F ":" '{print $1}')
ecore_id_last=$(("$ecore_id_last" - 1))
test_print_trc "The last ecore cpu id: $ecore_id_last"

acpi_cppc_check() {
  local i=""
  for ((i = $1; i <= $2; i++)); do
    highest_perf=$(cat "$CPU_SYSFS_PATH"/cpu"$i"/acpi_cppc/highest_perf)
    lowest_nonlinear_perf=$(cat "$CPU_SYSFS_PATH"/cpu"$i"/acpi_cppc/lowest_nonlinear_perf)
    lowest_perf=$(cat "$CPU_SYSFS_PATH"/cpu"$i"/acpi_cppc/lowest_perf)
    nominal_freq=$(cat "$CPU_SYSFS_PATH"/cpu"$i"/acpi_cppc/nominal_freq)
    nominal_perf=$(cat "$CPU_SYSFS_PATH"/cpu"$i"/acpi_cppc/nominal_perf)
    test_print_trc "CPU$i acpi_cppc:"
    do_cmd "grep . $CPU_SYSFS_PATH/cpu$i/acpi_cppc/*"

    if [[ -n "$highest_perf" ]] && [[ "$highest_perf" -gt 0 ]]; then
      test_print_trc "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/highest_perf is expected"
    else
      die "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/highest_perf is not expected"
    fi

    if [[ -n "$lowest_nonlinear_perf" ]] &&
      [[ "$lowest_nonlinear_perf" -lt "$highest_perf" ]]; then
      test_print_trc "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/lowest_nonlinear_perf is expected"
    else
      die "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/lowest_nonlinear_perf is not expected"
    fi

    if [[ -n "$lowest_perf" ]] && [[ "$lowest_perf" -lt "$highest_perf" ]] &&
      [[ "$lowest_perf" -lt "$nominal_perf" ]]; then
      test_print_trc "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/lowest_perf is expected"
    else
      die "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/lowest_perf is not expected"
    fi

    if [[ -n "$nominal_freq" ]] && [[ "$nominal_freq" -gt 0 ]]; then
      test_print_trc "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/nominal_freq is expected"
    else
      die "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/nominal_freq is not expected"
    fi

    if [[ -n "$nominal_perf" ]] &&
      [[ "$nominal_perf" -le "$highest_perf" ]]; then
      test_print_trc "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/nominal_perf is expected"
    else
      die "$CPU_SYSFS_PATH/cpu$i/acpi_cppc/nominal_perf is not expected"
    fi

  done
}

#ecore.nominal_perf should not be equal to pcore.nominal_perf
nominal_perf_compare() {
  pcore_nominal_perf=$(cat "$CPU_SYSFS_PATH"/cpu"$pcore_id_first"/acpi_cppc/nominal_perf)
  test_print_trc "The 1st Pcore nominal perf is: $pcore_nominal_perf"
  ecore_nominal_perf=$(cat "$CPU_SYSFS_PATH"/cpu"$ecore_id_first"/acpi_cppc/nominal_perf)
  test_print_trc "The 1st Ecore nominal perf is: $ecore_nominal_perf"

  if [[ -n "$pcore_nominal_perf" ]] && [[ -n "$ecore_nominal_perf" ]] &&
    [[ "$pcore_nominal_perf" -ne "$ecore_nominal_perf" ]]; then
    test_print_trc "Ecore nominal perf is not equal to Pcore nominal perf."
  else
    die "Ecore nominal perf is not equal to Pcore nominal perf is not expected"
  fi
}

#ecore_nominal_freq should be equal to pcore.nominal_freq
nominal_freq_compare() {
  pcore_nominal_freq=$(cat "$CPU_SYSFS_PATH"/cpu"$pcore_id_first"/acpi_cppc/nominal_freq)
  test_print_trc "The 1st Pcore nominal freq is: $pcore_nominal_freq"
  ecore_nominal_freq=$(cat "$CPU_SYSFS_PATH"/cpu"$ecore_id_first"/acpi_cppc/nominal_freq)
  test_print_trc "The 1st Ecore nominal perf is: $ecore_nominal_freq"

  if [[ -n "$pcore_nominal_freq" ]] && [[ -n "$ecore_nominal_freq" ]] &&
    [[ "$pcore_nominal_freq" -eq "$ecore_nominal_freq" ]]; then
    test_print_trc "Ecore nominal freq is not equal to Pcore nominal freq."
  else
    die "Ecore nominal freq is not equal to Pcore nominal freq is not expected"
  fi
}

#funtion to check the highest freq for HWP Cap MSR 0x771 and CPPC SYSFS
high_hwp_cap_cppc_compare() {
  local core_id=$1

  cap_msr=$(rdmsr -p "$core_id" 0x771 -f 7:0)
  highest_hwp_cap=$((16#$cap_msr))
  test_print_trc "The CPU$core_id's highest freq from HWP CAP MSR shows: $highest_hwp_cap"

  highest_perf_cppc=$(cat /sys/devices/system/cpu/cpu"$core_id"/acpi_cppc/highest_perf)
  test_print_trc "The CPU$core_id's highest perf from CPPC sysfs shows: $highest_perf_cppc"

  if [[ "$highest_hwp_cap" -eq "$highest_perf_cppc" ]]; then
    test_print_trc "CPU$core_id's highest freq between HWP CAP MSR and CPPC is match."
  else
    die "CPU$core_id's highest freq between HWP CAP MSR and CPPC is mismatch."
  fi
}

#funtion to check the min freq for cpufreq sysfs and MSR Platform Info
min_cpufreq_platform_info_compare() {
  local core_id=$1

  min_freq_KHz=$(cat /sys/devices/system/cpu/cpu"$core_id"/cpufreq/cpuinfo_min_freq)
  test_print_trc "The CPU$core_id's min freq from cpufreq sysfs shows: $min_freq_KHz KHz"

  cpu_stat_debug=$("$PSTATE_TOOL/turbostat" sleep 2 2>&1)
  test_print_trc "Turbostat debug output is:"
  test_print_trc "$cpu_stat_debug"
  max_efficiency_freq_ratio=$(echo "$cpu_stat_debug" |
    grep "max efficiency frequency" | awk '{print $1}')
  max_efficiency_freq_KHz=$(("$max_efficiency_freq_ratio" * 100000))
  test_print_trc "The CPU$core_id's max efficiency from MSR Platform Info shows: \
$max_efficiency_freq_KHz KHz"

  if [[ "$min_freq_KHz" -eq "$max_efficiency_freq_KHz" ]]; then
    test_print_trc "CPU$core_id's min freq between cpufreq sysfs and MSR Platform Info is match."
  else
    die "CPU$core_id's min freq between cpufreq sysfs and MSR Platform Info is mismatch."
  fi
}

: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

dmesg_check() {
  should_fail "extract_case_dmesg | grep fail"
  should_fail "extract_case_dmesg | grep 'Call Trace'"
  should_fail "extract_case_dmesg | grep error"
}

acpi_cppc_test() {
  case $TEST_SCENARIO in
  pcore)
    acpi_cppc_check $pcore_id_first $pcore_id_last
    ;;
  ecore)
    acpi_cppc_check $ecore_id_first $ecore_id_last
    ;;
  perf_compare)
    nominal_perf_compare
    ;;
  freq_compare)
    nominal_freq_compare
    ;;
  pcore_high_freq_comp_hwp_cap_cppc)
    high_hwp_cap_cppc_compare $pcore_id_first
    ;;
  ecore_high_freq_comp_hwp_cap_cppc)
    high_hwp_cap_cppc_compare $ecore_id_first
    ;;
  pcore_min_freq_comp_cpufreq_msr_platform_info)
    min_cpufreq_platform_info_compare $pcore_id_first
    ;;
  ecore_min_freq_comp_cpufreq_msr_platform_info)
    min_cpufreq_platform_info_compare $ecore_id_first
    ;;
  esac
  dmesg_check
  return 0
}

while getopts :t:H arg; do
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

acpi_cppc_test
