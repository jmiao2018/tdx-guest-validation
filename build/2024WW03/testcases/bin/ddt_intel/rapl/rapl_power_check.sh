#!/bin/bash

###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         rapl_energy_check.sh
#
# Description:  Check Intel RAPL energy status for each power domain
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Aug 08 2017 - Created - Jerry C. Wang
#
#
#

source "rapl_common.sh"

MEASURE_INTERVAL=5

usage() {
  cat <<-EOF >&2
  usage: ./${0##*/} [-e] [-p] [-l] pkg|core|uncore|dram|
    -e  Check RAPL Energy Status
    -p  Check RAPL Power Status with Loading
    -l  Check RAPL power limit setting with workload
    -h  Show this
EOF
  exit 1
}

rapl_teardown() {
  is_kmodule_builtin "$RAPL_MODULE" || {
    modprobe -r "$RAPL_MODULE"
    modprobe "$RAPL_MODULE"
  }
  clear_all_test_load
  x11=$(pgrep -f "Xorg :1" | awk '{print $2}')
  [[ -z "$x11" ]] || kill -9 "$x11"
}

# Main test function
# Input:
#    $1: Domain to be tested
main() {
  local domain=$1
  local cpu=""
  local power_limit_ori=""
  local power_limit_up=""
  local power_limit_down=100
  local power_limit_after=""
  local time_ori=""
  local limit=""
  local pl=$2
  local rc=""
  local sp=""

  domain=$(echo "$domain" | awk '{print tolower($0)}')
  [[ -n $domain ]] || "Please specify RAPL domain to be testsed!"
  [[ $domain =~ (pkg|core|uncore|dram) ]] ||
    die "Invalid RAPL domain. Must be pkg|core|uncore|dram."

  if [[ $CHECK_ENERGY -eq 1 ]]; then
    for ((pkg = 0; pkg < NUM_CPU_PACKAGES; pkg++)); do
      cpu=$(echo "${CPU_TOPOLOGY[$pkg]}" | cut -d" " -f1)
      get_total_energy_consumed_msr "$cpu" "$domain"
      msr_energy=$CUR_ENERGY

      get_total_energy_consumed_sysfs "$pkg" "$domain"
      sysfs_energy=$CUR_ENERGY

      test_print_trc "MSR: $msr_energy, SYSFS: $sysfs_energy"

      diff=$(echo "scale=3;$msr_energy / $sysfs_energy * 100" | bc)
      diff=${diff%.*}
      [[ $diff -le 105 && $diff -ge 95 ]] ||
        die "The delta between MSR and SYSFS is exceeding 5% range: $diff"
    done
  elif [[ $CHECK_POWER_LOAD -eq 1 ]]; then
    # create display :1 for graphic tests
    if [[ $domain == "uncore" ]]; then
      do_cmd "startx -- :1 &> /dev/null &"
      sleep 5
    fi

    if is_server_platform; then
      for ((pkg = 0; pkg < NUM_CPU_PACKAGES; pkg++)); do
        sleep 20
        [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"
        get_power_consumed_server "turbostat" "$pkg" "$domain" "$MEASURE_INTERVAL"
        [[ -n "$CUR_POWER" ]] || die "Fail to get current power(before)."
        power_b4=$CUR_POWER

        create_test_load "$domain"

        sleep 2
        get_power_consumed_server "turbostat" "$pkg" "$domain" "$MEASURE_INTERVAL"
        [[ -n "$CUR_POWER" ]] || die "Fail to get current power(after)."
        power_af=$CUR_POWER
        LOAD_PID=$!

        test_print_trc "Package-$pkg: $domain Power before workload: $power_b4 Watts"
        test_print_trc "Package-$pkg: $domain Power after workload: $power_af Watts"

        diff=$(echo "scale=3;$power_af / $power_b4 * 100" | bc)
        diff=${diff%.*}
        test_print_trc "Package-$pkg: $domain Power is increased by $diff percent!"

        [[ $diff -gt 100 ]] || die "Package-$pkg: $domain no significant power increase after workload!"
      done
    else
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

        test_print_trc "Package-$pkg: $domain Power before workload: $power_b4 Watts"
        test_print_trc "Package-$pkg: $domain Power after workload: $power_af Watts"

        if [[ "$power_b4" = 0.00 ]] && (($(echo "$power_af > $power_b4" | bc -l))); then
          test_print_trc "Package-$pkg: $domain Power is increased while power_b4 was 0.00 watts"
        elif (($(echo "$power_b4 < 1.00" | bc -l))) && (($(echo "$power_af > $power_b4" | bc -l))); then
          test_print_trc "Package-$pkg: $domain Power is increased while power_b4 was less than 1.00 watts"
        elif (($(echo "$power_b4 > 1.00" | bc -l))) && (($(echo "$power_af > $power_b4" | bc -l))); then
          test_print_trc "Package-$pkg: $domain Power is increased while power_b4 was larger than 1.00 watts"
          diff=$(echo "scale=3;$power_af / $power_b4 * 100" | bc)
          diff=${diff%.*}
          test_print_trc "Package-$pkg: $domain Power is increased by $diff percent!"
        else
          die "Package-$pkg: $domain Power does not increase"
        fi

        [[ $diff -gt 100 ]] || die "Package-$pkg: $domain no significant power increase after workload!"
      done
    fi
  elif [[ $CHECK_POWER_LIMIT -eq 1 ]]; then
    # Judge whether power limit is unlocked or not in BIOS
    # Skip this case if BIOS locked pkg or core power limit change

    power_limit_unlock_check "$domain"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      for ((pkg = 0; pkg <= NUM_CPU_PACKAGES; pkg++)); do
        # Save the original power limit and time value
        get_domain_path "$pkg" "$domain"
        client_domain=$(cat "$DOMAIN_PATH"/name)
        [[ "$client_domain" != psys ]] || break
        test_print_trc "Original $domain sysfs path: $DOMAIN_PATH"
        power_limit_ori="$(cat "$DOMAIN_PATH"/constraint_0_power_limit_uw)"
        [[ -n $power_limit_ori ]] || block_test "No intel_rapl sysfs power limit value"
        time_ori="$(cat "$DOMAIN_PATH"/constraint_0_time_window_us)"
        [[ -n $time_ori ]] || block_test "No intel_rapl sysfs time window us"
        test_print_trc "Original $domain power limit: $power_limit_ori uwatts"

        # Enable RAPL control
        do_cmd "echo 1 > $DOMAIN_PATH/enabled"
        enabled_knob=$(cat "$DOMAIN_PATH"/enabled)
        if [[ "$enabled_knob" -eq 1 ]]; then
          test_print_trc "Enabling RAPL control for $DOMAIN_PATH is PASS"
        else
          die "Enabling RAPL control for $DOMAIN_PATH is Fail"
        fi

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

        if is_server_platform; then
          sp=$(("$pkg" + 3))
          do_cmd "$PSTATE_TOOL/turbostat --quiet --show Package,Core,PkgWatt \
        -o tc.log sleep 1"
          test_print_trc "Server turbostat log:"
          cat tc.log
          if [[ $NUM_CPU_PACKAGES -eq 1 ]]; then
            power_limit_after="$(awk '{print $2}' tc.log | sed '/^\s*$/d' |
              sed -n ''"$sp"',1p')"
          else
            power_limit_after="$(awk '{print $3}' tc.log | sed '/^\s*$/d' |
              sed -n ''"$sp"',1p')"
          fi
          test_print_trc "Server power limit after: $power_limit_after"
          [[ -n "$power_limit_after" ]] ||
            die "Fail to get current power from server turbostat"
          power_limit_after="$(echo "scale=2;$power_limit_after * 1000000" | bc)"
        else
          get_power_consumed_server "turbostat" "$pkg" "$domain" "$MEASURE_INTERVAL"
          test_print_trc "$domain power after setting limit: $CUR_POWER watts"
          [[ -n "$CUR_POWER" ]] || die "Fail to get current power from turbostat"
          power_limit_after="$(echo "scale=2;$CUR_POWER * 1000000" | bc)"
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

        # Disable RAPL control
        do_cmd "echo 0 > $DOMAIN_PATH/enabled"
        disabled_knob=$(cat "$DOMAIN_PATH"/enabled)

        # Get Enable power limit value by reading 0x610 bit 15
        enable_power_limit=$(rdmsr 0x610 -f 15:15)
        test_print_trc "Enable RAPL Limit shows: $enable_power_limit"

        # Check if RAPL control disable works as expected
        if [[ $disabled_knob -eq 0 ]]; then
          test_print_trc "RAPL Control is not expected to be set to 0."
        elif [[ $enable_power_limit -eq 0 ]]; then
          die "System allows to disable PL, while writing RAPL control disable fail."
        else
          # Trying to manually write 0x610 bit 15 to 0
          # If it can't be set then you are OK as system is not allowing to disable PL1.
          # But wrmsr can write bit 15 to 0 and enabled is still 1, then this is a bug
          change_bit15=$(wrmsr 0x610 $(($(rdmsr -d 0x610) & ~(1 << 15))))
          test_print_trc "Verify if 0x610 bit 15 can be set to 0: $change_bit15"
          read_bit15=$(rdmsr 0x610 -f 15:15)
          if [[ $read_bit15 -eq 0 ]]; then
            die "0x610 bit 15 can change to 0, while RAPL control disable still 1."
          else
            test_print_trc "0x610 bit 15 cannot change to 0, so RAPL control enable shows 1 is expected."
          fi
        fi

        # Check system should not be throtted with orginal power limit value after RAPL control disable
        # Run workload to get rapl domain power watt after power limit recover
        [[ -z $LOAD_PID ]] || kill -9 "$LOAD_PID"
        create_test_load "$domain"
        sleep 2

        if is_server_platform; then
          sp=$(("$pkg" + 3))
          do_cmd "$PSTATE_TOOL/turbostat --quiet --show Package,Core,PkgWatt \
        -o tc.log sleep 1"
          test_print_trc "Server turbostat log after power limit recover:"
          cat tc.log
          if [[ $NUM_CPU_PACKAGES -eq 1 ]]; then
            power_limit_recover="$(awk '{print $2}' tc.log | sed '/^\s*$/d' |
              sed -n ''"$sp"',1p')"
          else
            power_limit_recover="$(awk '{print $3}' tc.log | sed '/^\s*$/d' |
              sed -n ''"$sp"',1p')"
          fi
          test_print_trc "Server power limit after RAPL control disable: $power_limit_recover"
          [[ -n "$power_limit_recover" ]] ||
            die "Fail to get current power from server turbostat after RAPL control disable"
          power_limit_recover="$(echo "scale=2;$power_limit_recover * 1000000" | bc)"
        else
          get_power_consumed_server "turbostat" "$pkg" "$domain" "$MEASURE_INTERVAL"
          test_print_trc "$domain power after RAPL control disable: $CUR_POWER watts"
          [[ -n "$CUR_POWER" ]] || die "Fail to get current power from turbostat"
          power_limit_recover="$(echo "scale=2;$CUR_POWER * 1000000" | bc)"
        fi
        power_limit_recover="${power_limit_recover%.*}"
        LOAD_PID=$!
        clear_all_test_load

        test_print_trc "Original power limit value: $power_limit_ori uwatts"
        test_print_trc "After power limit value recover: $power_limit_recover uwatts"
        delta=$(("$power_limit_ori" - "$power_limit_recover"))
        if [[ $delta -lt 0 ]]; then
          delta=$((0 - "$delta"))
        fi
        test_print_trc "The delta power after setting power limit recover: $delta uwatts"

        # Re-able RAPL control
        do_cmd "echo 1 > $DOMAIN_PATH/enabled"

        # The accepted pkg watts error range is 100 uwatts to 10% of TDP
        if [[ "$delta" -gt "$power_limit_down" ]] &&
          [[ "$delta" -lt "$power_limit_up" ]]; then
          test_print_trc "Recover RAPL Power limit is PASS"
        else
          die "The power gap after recovering RAPL Power limit: $delta uwatts"
        fi
      done
    else
      skip_test "$domain power limit is locked by BIOS, skip this case."
    fi
  else
    die "Test type is empty! Please specific energy or power tests!"
  fi
}

: "${CHECK_ENERGY:=0}"
: "${CHECK_POWER_LOAD:=0}"
: "${CHECK_POWER_LIMIT:=0}"

while getopts 'epl' flag; do
  case ${flag} in
  e)
    CHECK_ENERGY=1
    ;;
  p)
    CHECK_POWER_LOAD=1
    ;;
  l)
    CHECK_POWER_LIMIT=1
    ;;
  :)
    die "Option -$OPTARG requires an argument."
    ;;
  \?)
    die "Invalid option: -$OPTARG"
    ;;
  esac
done
shift $((OPTIND - 1))

main "$@"
rapl_teardown
