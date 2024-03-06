#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Description: test script for TPMI_RAPL feature
# Which is supported on Server GNR and beyond
# TPMI:Topology Aware Register and PM Capsule Interface
# RAPL: Runtime Average Power Limiting
#
# Authors:      wendy.wang@intel.com
# History:      June 20 2022 - Created - Wendy Wang

source "rapl_common.sh"
source "dmesg_functions.sh"
source "powermgr_common.sh"

RAPL_SYSFS_PATH="/sys/class/powercap"
TPMI_RAPL_DOMAIN_LIST=$(grep . $RAPL_SYSFS_PATH/intel-rapl-tpmi/*/* 2>&1 |
  grep -v "Is a directory" |
  grep -v "No data available")
RAPL_DMESG_FAILURE=$(dmesg | grep -iE rapl | grep -iE "fail|Call Trace|error")

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

load_unload_module() {
  # $1 is the driver module name
  local module_name=$1
  is_kmodule_builtin "$module_name" && skip_test
  dmesg -C

  load_unload_module.sh -c -d "$module_name" &&
    do_cmd "load_unload_module.sh -u -d $module_name"

  do_cmd "load_unload_module.sh -l -d $module_name"
  do_cmd "load_unload_module.sh -u -d $module_name"
  do_cmd "load_unload_module.sh -l -d $module_name"
}

tpmi_rapl_check_interface() {
  test_print_trc "Check SYSFS - \"$RAPL_SYSFS_PATH\"intel-rapl-tpmi..."
  [[ -d "$RAPL_SYSFS_PATH"/intel-rapl-tpmi ]] ||
    die "intel-rapl-tpmi SYSFS does not exist!\n \
dmesg log: $RAPL_DMESG_FAILURE"

  lines=$(grep . "$RAPL_SYSFS_PATH"/intel-rapl-tpmi*/* 2>&1 |
    grep -v "Is a directory" | grep -v "No data available")
  for line in $lines; do
    test_print_trc "$line"
  done
}

tpmi_domain_probe() {
  local PKG_NAME=""
  local PKG_NUM=""

  PKG_NAME=$(grep -E "package-([0-9]{1})" $RAPL_SYSFS_PATH/intel-rapl-tpmi:*/name)
  if [[ $? -eq 0 ]]; then
    test_print_trc "TPMI RAPL Package name: $PKG_NAME"
    PKG_NUM=$(awk -F- '{print $4}' <<<"$PKG_NAME" | sort -n | tail -n1)
    test_print_trc "TPMI RAPL Package number: $PKG_NUM"
    MAX_RAPL_NUM_TPMI=$((PKG_NUM + 1))
    test_print_trc "Total TPMI RAPL Package number: $MAX_RAPL_NUM_TPMI"
  else
    die "TPMI RAPL Package domain probe fail:$RAPL_DMESG_FAILURE"
  fi

}

tpmi_rapl_check_pkg_domain() {
  local domain_path="$RAPL_SYSFS_PATH/intel-rapl-tpmi:"
  tpmi_domain_probe

  test_print_trc "Check SYSFS - \"$domain_path\"X..."

  [[ -n $MAX_RAPL_NUM_TPMI ]] || block_test "No tpmi_rapl package number."

  for ((i = 0; i < MAX_RAPL_NUM_TPMI; i++)); do
    if [[ -d "$domain_path""$i" ]]; then
      test_print_trc "TPMI RAPL Pkg domain sysfs: $domain_path$i"
    else
      die "intel-rapl-tpmi package domain folder does not exist!"
    fi
    grep -q "package-${i}" "${domain_path}${i}/name"
    if [[ $? -eq 0 ]]; then
      test_print_trc "package-${i} is supported in ${domain_path}${i}/name:"
      do_cmd "cat ${domain_path}${i}/name"
    else
      block_test "This server does not support package-${i}!"
    fi
  done
}

tpmi_rapl_check_psys_domain() {
  local domain_path="$RAPL_SYSFS_PATH/intel-rapl-tpmi:"
  tpmi_domain_probe

  test_print_trc "Check Platform domain sysfs - ${domain_path}X..."
  [[ -d "${domain_path}1" ]] ||
    block_test "intel-rapl-tpmi platform domain sysfs does not exist:\
$TPMI_RAPL_DOMAIN_LIST \
dmesg log: $RAPL_DMESG_FAILURE"

  grep -q "psys" "${domain_path}1/name" ||
    na_test "intel-rapl-tpmi platform domain (aka Psys) does not exit!"
  test_print_trc "${domain_path}1/name psys sysfs exists."
  do_cmd "cat ${domain_path}1/name"
}

tpmi_rapl_check_dram_domain() {
  local domain_path="$RAPL_SYSFS_PATH/intel-rapl-tpmi:"
  local domain_num=0
  tpmi_domain_probe

  test_print_trc "Check SYSFS - \"$domain_path\"X:\"$domain_num\"..."

  [[ -n $MAX_RAPL_NUM_TPMI ]] || block_test "No tpmi_rapl package number."

  for ((i = 0; i < MAX_RAPL_NUM_TPMI; i++)); do
    [[ -d "$domain_path""$i":"$domain_num" ]] ||
      block_test "intel-rapl-tpmi DRAM domain folder does not exist!"
    if ! grep -q "dram" "${domain_path}${i}:${domain_num}/name"; then
      block_test "intel-rapl-tpmi DRAM domain name does not match!"
    else
      test_print_trc "\"$domain_path\"X:\"$domain_num\" existed!"
      do_cmd "cat ${domain_path}${i}:${domain_num}/name"
    fi
  done
}

# Get the corresponding domain SYSFS path
# Input:
#     $1: Select CPU Package
#     $2: Select Power Domain
# Output:
#     DOMAIN_PATH: SYSFS PATH for the select domain
get_tpmi_rapl_domain_path() {
  local pkg=$1
  local domain=$2

  DOMAIN_PATH="$RAPL_SYSFS_PATH/intel-rapl-tpmi:$pkg"
  test_print_trc "Domain path: $DOMAIN_PATH"

  [[ -d $DOMAIN_PATH ]] || die "TPMI RAPL PKG Path does not exist.\n \
dmesg log: $RAPL_DMESG_FAILURE"

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  test_print_trc "Domain name: $domain"

  case $domain in
  pkg)
    [[ "$pkg" == 1 ]] && pkg=$(("$pkg" + 1))
    DOMAIN_PATH="$RAPL_SYSFS_PATH/intel-rapl-tpmi:$pkg"
    ;;
  psys)
    DOMAIN_PATH="$RAPL_SYSFS_PATH/intel-rapl-tpmi:1"
    ;;
  dram)
    DOMAIN_PATH="$DOMAIN_PATH:0"
    ;;
  *)
    die "Invalid Power Domain!"
    ;;
  esac
}

# Enable power limit from sysfs
# Inputs:
#      $1: Select CPU package
#      $2: Select Domain
#      $3: Select Power Limit
#      $4: Select Time Windows
set_power_limit() {
  local pkg=$1
  local domain=$2
  local limit=$3
  local time_win=$4

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  test_print_trc "The TPMI RAPL pkg name is: $pkg"
  test_print_trc "The TPMI RAPL domain name is: $domain"
  get_tpmi_rapl_domain_path "$pkg" "$domain"

  do_cmd "echo \"$time_win\" > \"$DOMAIN_PATH/constraint_0_time_window_us\""
  do_cmd "echo \"$limit\" > \"$DOMAIN_PATH/constraint_0_power_limit_uw\""
}

# Create workloads on the specified domain
# Input:
#   $1: Select Domain
# Output:
#   LOAD_PID: PID of the test workload
create_test_load() {
  local domain=$1

  [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  case $domain in
  pkg)
    which "$CPU_LOAD" &>/dev/null || die "fspin does not exist"
    do_cmd "$CPU_LOAD $CPU_LOAD_ARG > /dev/null &"
    ;;
  dram)
    which "$DRAM_LOAD" &>/dev/null || die "stress does not exist"
    mem_avail=$(grep MemAvailable /proc/meminfo | awk -F " " '{print $2}')
    mem_test=$(echo "$mem_avail"/10000000 | bc)
    do_cmd "$DRAM_LOAD --vm $mem_test --vm-bytes 1024M -t 30 > /dev/null &"
    ;;
  *)
    die "Invalid domain!"
    ;;
  esac

  LOAD_PID=$!
}

# Read total energy consumption from SYSFS
# Input:
#     $1: Select Package
#     $2: Select Domain
# Output:
#   CUR_ENERY: Current energy obtained from SYSFS
get_total_energy_consumed_sysfs() {
  local pkg=$1
  local domain=$2

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  get_tpmi_rapl_domain_path "$pkg" "$domain"

  local energy_path="$DOMAIN_PATH/energy_uj"
  [[ -f $energy_path ]] || die "Unable to find the energy data in SYSFS"
  CUR_ENERGY=$(cat "$energy_path")
  test_print_trc "Package-$pkg - Total $domain Energy: $CUR_ENERGY uj"
}

# Calculate power consumption over a set period
# Input:
#     $1: Energy measurement method (SYSFS)
#     $2: Select CPU package
#     $3: Select power domain
#     $4: (Optional) Measurement duration (Default: 15s)
get_power_consumed() {
  local method=$1
  local pkg=$2
  local domain=$3
  local duration=$4

  : "${duration:=15}"

  [[ $# -ge 3 ]] || die "Invalid parameters!"

  method=$(echo "$method" | awk '{print tolower($0)}')
  domain=$(echo "$domain" | awk '{print tolower($0)}')

  [[ $pkg -le $NUM_CPU_PACKAGES ]] || die "Package number is out of range!"
  [[ $domain =~ (pkg|psys|dram) ]] || die "Invalid power domain!"

  case $method in
  sysfs)
    get_total_energy_consumed_sysfs "$pkg" "$domain"
    energy_b4=$CUR_ENERGY

    sleep "$duration"

    get_total_energy_consumed_sysfs "$pkg" "$domain"
    energy_af=$CUR_ENERGY
    ;;
  turbostat)
    which turbostat &>/dev/null || die "turbostat tool does not exist"
    socket_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
    if [[ "$socket_num" == 1 ]]; then
      columns="CPU,PkgWatt,RAMWatt"
      do_cmd "$PSTATE_TOOL/turbostat --quiet --show $columns -o ts.log sleep $duration"
      test_print_trc "Turbostat log during idle:"
      cat ts.log

      res=$(grep -e "^-" ts.log | awk '{print $2,$3}' | head -1)
      test_print_trc "Supported Domain zone columns from turbostat log: $res"
    else
      columns="Package,CPU,PkgWatt,RAMWatt"
      do_cmd "$PSTATE_TOOL/turbostat --quiet --show $columns -o ts.log sleep $duration"
      test_print_trc "Turbostat log during idle:"
      cat ts.log

      res=$(grep -e "^-" ts.log | awk '{print $3,$4}' | head -1)
      test_print_trc "Supported Domain zone columns from turbostat log: $res"
    fi
    [[ -n $res ]] || die "No result is obtained from turbostat!"

    case $domain in
    pkg)
      CUR_POWER=$(echo "$res" | awk '{print $1}')
      ;;
    dram)
      CUR_POWER=$(echo "$res" | awk '{print $2}')
      ;;
    *)
      die "Invalid Power Domain!"
      ;;
    esac
    return 0
    ;;
  *)
    die "Invalid Measurement Method!"
    ;;
  esac
  CUR_POWER=$(echo "scale=6;($energy_af - $energy_b4) / $duration / 10^6" | bc)
  test_print_trc "Package-$pkg $domain Power = $CUR_POWER Watts"
}

# Function to test TPMI RAPL domain with workload
# Input:
#    $1: Domain to be tested
tpmi_rapl_check_workload() {
  local domain=$1
  local MEASURE_INTERVAL=5

  [[ -n $NUM_CPU_PACKAGES ]] || block_test "No tpmi_rapl package number."

  for ((pkg = 0; pkg < NUM_CPU_PACKAGES; pkg++)); do
    sleep 20
    [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"
    get_power_consumed "turbostat" "$pkg" "$domain" "$MEASURE_INTERVAL"
    [[ -n "$CUR_POWER" ]] || die "Fail to get current power(before)."
    power_b4=$CUR_POWER

    create_test_load "$domain"

    sleep 2
    get_power_consumed "turbostat" "$pkg" "$domain" "$MEASURE_INTERVAL"
    [[ -n "$CUR_POWER" ]] || die "Fail to get current power(after)."
    power_af=$CUR_POWER
    LOAD_PID=$!
    clear_all_test_load

    test_print_trc "Package-$pkg: $domain Power before workload: $power_b4 Watts"
    test_print_trc "Package-$pkg: $domain Power after workload: $power_af Watts"

    diff=$(echo "scale=3;$power_af / $power_b4 * 100" | bc)
    diff=${diff%.*}
    test_print_trc "Package-$pkg: $domain Power is increased by $diff percent!"

    [[ $diff -gt 100 ]] || die "Package-$pkg: $domain no significant power increase after workload!"
  done
}

# Function to test TPMI RAPL domain for power limit
# Input:
#    $1: Domain to be tested
#    $2: Power limit percentage
tpmi_rapl_check_power_limit() {
  local domain=$1
  local power_limit_ori=""
  local power_limit_up=""
  local power_limit_down=100
  local power_limit_after=""
  local time_ori=""
  local limit=""
  local pl=$2
  local sp=""

  [[ -n $NUM_CPU_PACKAGES ]] || block_test "No tpmi_rapl package number."

  for ((pkg = 0; pkg < NUM_CPU_PACKAGES; pkg++)); do
    # Save the original power limit and time value
    get_tpmi_rapl_domain_path "$pkg" "$domain"
    test_print_trc "Original $domain sysfs path: $DOMAIN_PATH"
    power_limit_ori="$(cat "$DOMAIN_PATH"/constraint_0_power_limit_uw)"
    [[ -n $power_limit_ori ]] || block_test "No tpmi_rapl sysfs power limit value"
    time_ori="$(cat "$DOMAIN_PATH"/constraint_0_time_window_us)"
    [[ -n $time_ori ]] || block_test "No tpmi_rapl sysfs time window us"
    test_print_trc "Original $domain power limit: $power_limit_ori uwatts"

    # Set the power limit and time value
    echo "Received power limit test value: $pl percentage"
    limit=$(("$pl" * "$power_limit_ori" / 100))
    test_print_trc "Real Power limit test value: $limit uwatts"
    power_limit_up=$((10 * "$power_limit_ori" / 100))
    time_win=1000000
    set_power_limit "$pkg" "$domain" "$limit" "$time_win"

    # Run workload to get rapl domain power watt after setting power limit
    [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"
    create_test_load "$domain"
    sleep 2

    # If SUT only supports one socket,then turbostat does not support to
    # print Package column
    socket_num=$(lscpu | grep "Socket(s)" | awk -F " " '{print $2}' 2>&1)
    if [[ "$socket_num" == 1 ]]; then
      sp=$(("$pkg" + 3))
      do_cmd "$PSTATE_TOOL/turbostat --quiet --show Core,PkgWatt \
        -o tc.log sleep 1"
      test_print_trc "Server turbostat log:"
      cat tc.log
      power_limit_after="$(awk '{print $2}' tc.log | sed '/^\s*$/d' |
        sed -n ''"$sp"',1p')"
      test_print_trc "Server power limit after: $power_limit_after"
      [[ -n "$power_limit_after" ]] ||
        die "Fail to get current power from server turbostat"
      power_limit_after="$(echo "scale=2;$power_limit_after * 1000000" | bc)"
    else
      sp=$(("$pkg" + 3))
      do_cmd "$PSTATE_TOOL/turbostat --quiet --show Package,Core,PkgWatt \
        -o tc.log sleep 1"
      test_print_trc "Server turbostat log:"
      cat tc.log
      power_limit_after="$(awk '{print $3}' tc.log | sed '/^\s*$/d' |
        sed -n ''"$sp"',1p')"
      test_print_trc "Server power limit after: $power_limit_after"
      [[ -n "$power_limit_after" ]] ||
        die "Fail to get current power from server turbostat"
      power_limit_after="$(echo "scale=2;$power_limit_after * 1000000" | bc)"
    fi

    power_limit_after="${power_limit_after%.*}"
    LOAD_PID=$!
    clear_all_test_load

    # Restore the power limit value to origin
    set_power_limit "$pkg" "$domain" "$power_limit_ori" "$time_ori"

    test_print_trc "Original power limit value: $power_limit_ori uwatts"
    test_print_trc "Configured power limit value: $limit uwatts"
    test_print_trc "After setting power limit value: $power_limit_after uwatts"
    delta=$(("$limit" - "$power_limit_after"))
    if [[ $delta -lt 0 ]]; then
      delta=$((0 - "$delta"))
    fi
    test_print_trc "The delta power after setting limit: $delta uwatts"

    # The accepted pkg watts error range is 100 uwatts to 10% of TDP
    if [[ "$delta" -gt "$power_limit_down" ]] &&
      [[ "$delta" -lt "$power_limit_up" ]]; then
      test_print_trc "Setting RAPL $domain rapl power limit to $pl is PASS"
    else
      die "The power gap after setting limit to $pl percentage: $delta uwatts"
    fi
  done
}

dmesg_check() {
  local dmesg_log

  dmesg_log=$(extract_case_dmesg)

  if echo "$dmesg_log" | grep -iE "fail|Call Trace|error"; then
    die "Kernel dmesg shows failure: $dmesg_log"
  else
    test_print_trc "Kernel dmesg when case running shows Okay."
  fi
}

tpmi_rapl_test() {
  case $TEST_SCENARIO in
  load_unload_tpmi_rapl)
    load_unload_module intel_rapl_tpmi
    ;;
  tpmi_rapl_sysfs)
    tpmi_rapl_check_interface
    ;;
  tpmi_rapl_pkg_domain)
    tpmi_rapl_check_pkg_domain
    ;;
  tpmi_rapl_psys_domain)
    tpmi_rapl_check_psys_domain
    ;;
  tpmi_rapl_dram_domain)
    tpmi_rapl_check_dram_domain
    ;;
  tpmi_rapl_pkg_workload)
    tpmi_rapl_check_workload pkg
    ;;
  tpmi_rapl_dram_workload)
    tpmi_rapl_check_workload dram
    ;;
  tpmi_rapl_pkg_power_limit_75)
    tpmi_rapl_check_power_limit pkg 75
    ;;
  tpmi_rapl_pkg_power_limit_50)
    tpmi_rapl_check_power_limit pkg 50
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

tpmi_rapl_test
