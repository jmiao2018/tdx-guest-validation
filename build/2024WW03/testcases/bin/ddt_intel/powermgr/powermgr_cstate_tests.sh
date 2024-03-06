#!/bin/bash
###############################################################################
#
# Copyright (C) 2015 Intel - http://www.intel.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################
# @Author   Ning Han (ningx.han@intel.com)
# @desc     Test Intel C-State switch
# @returns  0 if the execution was finished successfully, else 1
# @history  2016-08-12: First Version (Ning Han)

source "powermgr_common.sh"
source "common.sh"
source "dmesg_functions.sh"

TOOL="$LTPROOT/testcases/bin/ddt_intel/powermgr"
current_cpuidle_driver=$(cat "$CPU_IDLE_SYSFS_PATH"/current_driver)

test_cstate_switch_idle() {
    local usage_before=()
    local usage_after=()
    local CPUS
    CPUS=$(ls "$CPU_BUS_SYSFS_PATH" | xargs)
    local cpu_num
    cpu_num=$(lscpu | grep "^CPU(s)" | awk '{print $2}')

    if [[ -n "$CPUS" ]]; then
        for cpu in $CPUS; do
            STATES=$(ls "${CPU_BUS_SYSFS_PATH}"/"${cpu}"/cpuidle | grep state | xargs)
            if [[ -n "$STATES" ]]; then
                for state in $STATES; do
                    # disable stateX of cpuX
                    echo 1 >"${CPU_SYSFS_PATH}/${cpu}/cpuidle/${state}/disable"
                done
            else
                die "fail to get state node for $cpu"
            fi
        done
    else
        die "fail to get cpu sysfs directory"
    fi

    for state in $STATES; do
        test_print_trc ------ loop for "$state" ------

        # Count usage of the stateX of cpuX before enable stateX
        i=0
        while [[ "$i" != "$cpu_num" ]]; do
            usage_before[$i]=$(cat "${CPU_SYSFS_PATH}"/cpu"${i}"/cpuidle/"${state}"/usage)
            [[ -n ${usage_before[$i]} ]] || die "fail to count usage_before of $state of cpu${i}"
            i=$((i + 1))
        done

        # Enable stateX of cpuX
        for cpu in $CPUS; do
            echo 0 >"${CPU_SYSFS_PATH}/${cpu}/cpuidle/${state}/disable"
        done

        # Sleep and wait for entry of the state
        sleep "$check_interval"

        # Count usage of the stateX for cpuX after enable stateX
        i=0
        while [[ "$i" != "$cpu_num" ]]; do
            usage_after[$i]=$(cat "${CPU_SYSFS_PATH}"/cpu"${i}"/cpuidle/"${state}"/usage)
            [[ -n ${usage_after[$i]} ]] || die "fail to count usage_after of $state of cpu${i}"
            i=$((i + 1))
        done

        # Compare the usage to see if the cpuX enter stateX
        i=0
        while [[ "$i" != "$cpu_num" ]]; do
            if [[ ${usage_after[${i}]} -gt ${usage_before[${i}]} ]]; then
                test_print_trc "cpu${i} enter $state successfully"
            else
                test_print_trc "cpu${i} fail to enter $state"
                return 1
            fi
            i=$((i + 1))
        done
    done
    return 0
}

check_acpi_idle() {
    [[ $current_cpuidle_driver == "acpi_idle" ]] || {
        block_test "Please append intel_idle.max_cstate=0 to switch " \
            "cpuidle driver from Intel_Idle to ACPI Idle."
    }
    return 0
}

check_intel_idle() {
    [[ $current_cpuidle_driver == "intel_idle" ]] || {
        block_test "If the platform does not support Intel_Idle driver yet, " \
            "please ignore this test case"
    }
    return 0
}

check_valid_idle() {
    [[ -d "$CPU_IDLE_SYSFS_PATH" ]] || die "CPU Idle sysfs path doesn't exist."
    [[ $current_cpuidle_driver == "acpi_idle" ]] && return 0
    [[ $current_cpuidle_driver == "intel_idle" ]] && return 0
    die "$CPU_IDLE_SYSFS_PATH/current_driver:$current_cpuidle_driver is " \
        "false, please check test box."
}

test_cstate_switch_acpi_idle() {
    # time to wait for cpuX to enter stateX
    local check_interval=$1

    check_valid_idle
    check_acpi_idle
    test_cstate_switch_idle
}

test_cstate_switch_intel_idle() {
    # time to wait for cpuX to enter stateX
    local check_interval=$1

    check_valid_idle
    check_intel_idle
    test_cstate_switch_idle
}

test_all_client_cpu_deepest_cstate() {
    # time to wait for cpuX to enter stateX
    local check_interval=$1
    local unexpected_cstate=0.00

    columns="sysfs,CPU%c1,CPU%c6,CPU%c7"
    turbostat_output=$("$TOOL"/turbostat -i 10 --quiet \
        --show $columns sleep 10 2>&1)
    test_print_trc "$turbostat_output"
    all_deepest_cstate=$(echo "$turbostat_output" |
        awk '{for(i=0;++i<=NF;)a[i]=a[i]?a[i] FS $i:$i} END{for(i=0;i++<=NF;)print a[i]}' |
        grep "CPU%c7")
    test_print_trc "The deepest CPU Core cstate: $all_deepest_cstate"
    if [[ $all_deepest_cstate =~ $unexpected_cstate ]]; then
        test_print_trc "Getting CPU C7 state by reading MSR 0x3fe:"
        rdmsr -a 0x3fe
        die "CPU Core did not enter the deepest C7 state!"
    else
        test_print_trc "All the CPU enter the deepest C7 state!"
    fi
}

test_all_server_cpu_deepest_cstate() {
    # time to wait for cpuX to enter stateX
    local check_interval=$1
    local unexpected_cstate=0.00

    columns="sysfs,CPU%c1,CPU%c6"
    turbostat_output=$("$TOOL"/turbostat -i 10 --quiet \
        --show $columns sleep 10 2>&1)
    test_print_trc "$turbostat_output"
    all_deepest_cstate=$(echo "$turbostat_output" |
        awk '{for(i=0;++i<=NF;)a[i]=a[i]?a[i] FS $i:$i} END{for(i=0;i++<=NF;)print a[i]}' |
        grep "CPU%c6")
    test_print_trc "The deepest core cstate is: $all_deepest_cstate"
    if [[ $all_deepest_cstate =~ $unexpected_cstate ]]; then
        test_print_trc "Getting CPU C6 state by reading MSR 0x3fd:"
        rdmsr -a 0x3fd
        die "CPU Core did not enter the deepest cstate!"
    else
        test_print_trc "All the CPU core enter the deepest cstate!"
    fi
}

judge_cc7_residency_during_s2idle() {
    columns="Core,CPU%c1,CPU%c6,CPU%c7"
    turbostat_output=$(
        "$TOOL"/turbostat --show $columns \
            rtcwake -m freeze -s 15 2>&1
    )
    turbostat_output=$(grep "CPU%c7" -A1 <<<"$turbostat_output")
    test_print_trc "$turbostat_output"
    CC7_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $4}')
    test_print_trc "Core CPU C7 residency :$CC7_val"
    [[ -n "$CC7_val" ]] || die "CPU Core C7 residency is not available."

    # Judge whether CC7 residency is available during idle
    turbostat_CC7_value=$(echo "scale=2; $CC7_val > 0.00" | bc)
    [[ $turbostat_CC7_value -eq 1 ]] ||
        die "Did not get CPU Core C7 residency during S2idle " \
            "when $current_cpuidle_driver is running"
    test_print_trc "CPU Core C7 residency is available during S2idle " \
        "when $current_cpuidle_driver is running."
}

test_cpu_core_c7_residency_acpi_s2idle() {
    check_valid_idle
    check_acpi_idle
    judge_cc7_residency_during_s2idle
}

test_cpu_core_c7_residency_intel_s2idle() {
    check_valid_idle
    check_intel_idle
    judge_cc7_residency_during_s2idle
}

judge_cc7_residency_during_idle() {
    columns="Core,CPU%c1,CPU%c6,CPU%c7"
    turbostat_output=$("$TOOL"/turbostat -i 10 --quiet \
        --show $columns sleep 10 2>&1)
    test_print_trc "$turbostat_output"
    CC7_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $4}')
    test_print_trc "Core CPU C7 residency :$CC7_val"
    [[ -n "$CC7_val" ]] || die "CPU Core C7 residency is not available."

    # Judge whether CC7 residency is available during idle
    turbostat_CC7_value=$(echo "scale=2; $CC7_val > 0.00" | bc)
    [[ $turbostat_CC7_value -eq 1 ]] ||
        die "Did not get CPU Core C7 residency during idle " \
            "when $current_cpuidle_driver is running."
    test_print_trc "CPU Core C7 residency is available during idle " \
        "when $current_cpuidle_driver is running"
}

test_cpu_core_c7_residency_acpi_idle() {
    check_valid_idle
    check_acpi_idle
    judge_cc7_residency_during_idle
}

test_cpu_core_c7_residency_intel_idle() {
    check_valid_idle
    check_intel_idle
    judge_cc7_residency_during_idle
}

judge_cc6_residency_during_idle() {
    columns="Core,CPU%c1,CPU%c6"
    turbostat_output=$("$TOOL"/turbostat -i 10 --quiet \
        --show $columns sleep 10 2>&1)
    test_print_trc "$turbostat_output"
    CC6_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $3}')
    test_print_trc "Core CPU C6 residency :$CC6_val"
    [[ -n $CC6_val ]] || die "CPU Core C6 residency is not available."

    # Judge whether CC6 residency is available during idle
    turbostat_CC6_value=$(echo "scale=2; $CC6_val > 0.00" | bc)
    [[ $turbostat_CC6_value -eq 1 ]] ||
        die "Did not get CPU Core C6 residency during idle " \
            "when $current_cpuidle_driver is running"
    test_print_trc "CPU Core C6 residency is available " \
        "during idle when $current_cpuidle_driver is running"
}

test_cpu_core_c6_residency_acpi_idle() {
    check_valid_idle
    check_acpi_idle
    judge_cc6_residency_during_idle
}

test_cpu_core_c6_residency_intel_idle() {
    check_valid_idle
    check_intel_idle
    judge_cc6_residency_during_idle
}

test_cstate_table_name() {
    local cstate_name
    local name

    cstate_name=$(cat "$CPU_SYSFS_PATH"/cpu0/cpuidle/state*/name)
    name=$(echo "$cstate_name" | grep ACPI)
    if [[ -n $name ]]; then
        test_print_trc "$cstate_name"
        die "Intel_idle driver refers to ACPI cstate table."
    else
        test_print_trc "$cstate_name"
        test_print_trc "Intel_idle driver refers to BIOS _CST table."
    fi
}

cc_state_disable_enable() {
    local cc=$1
    local setting=$2

    for ((i = 0; i < cpu_num; i++)); do
        #Find Core Cx state
        cc_num=$(grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/name |
            sed -n "/$cc$/p" | awk -F "/" '{print $8}' | cut -c 6)
        test_print_trc "Core $cc state name is: $cc_num"
        [[ -n "$cc_num" ]] || block_test "Did not get Core $cc state."
        #Change Core Cx state
        do_cmd "echo $setting > /sys/devices/system/cpu/cpu$i/cpuidle/state$cc_num/disable"
        let deeper=$cc_num+1
        #Change deeper Core Cx state
        for ((j = deeper; j < state_num; j++)); do
            do_cmd "echo $setting > /sys/devices/system/cpu/cpu$i/cpuidle/state$j/disable"
        done
    done
}

disable_cc_check_pc() {
    local cc=$1
    local pc_y=$2
    local pc_n=$3
    local cpu_num
    local columns

    cpu_num=$(lscpu | grep "^CPU(s)" | awk '{print $2}')
    state_num=$(ls "${CPU_BUS_SYSFS_PATH}"/cpu0/cpuidle | grep -c state)
    columns="Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"

    cc_state_disable_enable "$cc" 1

    #Check Package Cstates, CC10 disable--> expect PC8 only
    #CC8 and deeper disable--> PC6 only
    tc_out=$("$TOOL"/turbostat -q --show $columns -i 1 sleep 20 2>&1)
    [[ -n "$tc_out" ]] || die "Did not get turbostat log"
    test_print_trc "turbostat tool output: $tc_out"
    pc_y_res=$(echo "$tc_out" |
        awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
        grep "$pc_y" | awk -F " " '{print $3}')
    pc_n_res=$(echo "$tc_out" |
        awk '{for(k=0;++k<=NF;)a[k]=a[k]?a[k] FS $k:$k} END{for(k=0;k++<NF;)print a[k]}' |
        grep "$pc_n" | awk -F " " '{print $3}')
    [[ -n "$pc_y_res" ]] || die "Did not get $pc_y state."
    [[ -n "$pc_n_res" ]] || die "Did not get $pc_n state."
    if [[ $(echo "scale=2; $pc_y_res > 0.00" | bc) -eq 1 ]] && [[ $pc_n_res == "0.00" ]]; then
        cc_state_disable_enable "$cc" 0
        test_print_trc "Expected to get $pc_y only when disable $cc and deeper state.\
$pc_y residency: $pc_y_res; $pc_n residency: $pc_n_res"
    else
        cc_state_disable_enable "$cc" 0
        die "Did not get $pc_y residency after disable $cc and deeper states. \
$pc_y residency: $pc_y_res; $pc_n residency: $pc_n_res"
    fi
}

# perf tool listed cstate is based on kernel MSRs, turbostat tool listed
# cstate is based on user space MSRs, these two outputs should be aligned
# also client and server platforms support different core and pkg cstates.
perf_cstate_list_client() {
    tc_out=$("$TOOL"/turbostat -q --show idle sleep 1 2>&1)
    [[ -n "$tc_out" ]] || block_test "Did not get turbostat log"
    test_print_trc "turbostat tool output: $tc_out"
    tc_out_cstate_list=$(echo "$tc_out" | grep -E "^POLL")

    perf_cstates=$(perf list | grep cstate)
    [[ -n "$perf_cstates" ]] || block_test "Did not get cstate events by perf list"
    test_print_trc "perf list shows cstate events: $perf_cstates"
    perf_core_cstate_num=$(perf list | grep -c cstate_core)
    for ((i = 1; i <= perf_core_cstate_num; i++)); do
        perf_core_cstate=$(perf list | grep cstate_core | sed -n "$i, 1p")
        if [[ $perf_core_cstate =~ c1 ]] && [[ $tc_out_cstate_list =~ CPU%c1 ]]; then
            test_print_trc "$perf_core_cstate is supported and aligned with turbostat"
        elif [[ $perf_core_cstate =~ c6 ]] && [[ $tc_out_cstate_list =~ CPU%c6 ]]; then
            test_print_trc "$perf_core_cstate is supported and aligned with turbostat"
        elif [[ $perf_core_cstate =~ c7 ]] && [[ $tc_out_cstate_list =~ CPU%c7 ]]; then
            test_print_trc "$perf_core_cstate is supported and aligned with turbostat"
        else
            die "perf list shows unexpected core_cstate event."
        fi
    done

    perf_pkg_cstate_num=$(perf list | grep -c cstate_pkg)
    for ((i = 1; i <= perf_pkg_cstate_num; i++)); do
        perf_pkg_cstate=$(perf list | grep cstate_pkg | sed -n "$i, 1p")
        if [[ $perf_pkg_cstate =~ c2 ]] && [[ $tc_out_cstate_list =~ Pkg%pc2 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c3 ]] && [[ $tc_out_cstate_list =~ Pkg%pc3 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c6 ]] && [[ $tc_out_cstate_list =~ Pkg%pc6 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c7 ]] && [[ $tc_out_cstate_list =~ Pkg%pc7 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c8 ]] && [[ $tc_out_cstate_list =~ Pkg%pc8 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c9 ]] && [[ $tc_out_cstate_list =~ Pkg%pc9 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c10 ]] && [[ $tc_out_cstate_list =~ Pk%pc10 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        else
            die "perf list shows unexpected pkg_cstate event."
        fi
    done
}

# Server platforms support different core cstate and package cstate
perf_cstate_list_server() {
    tc_out=$("$TOOL"/turbostat -q --show idle sleep 1 2>&1)
    [[ -n "$tc_out" ]] || block_test "Did not get turbostat log"
    test_print_trc "turbostat tool output: $tc_out"
    tc_out_cstate_list=$(echo "$tc_out" | grep -E "^POLL")

    perf_cstates=$(perf list | grep cstate)
    [[ -n "$perf_cstates" ]] || block_test "Did not get cstate events by perf list"
    test_print_trc "perf list shows cstate events: $perf_cstates"
    perf_core_cstate_num=$(perf list | grep -c cstate_core)
    for ((i = 1; i <= perf_core_cstate_num; i++)); do
        perf_core_cstate=$(perf list | grep cstate_core | sed -n "$i, 1p")
        if [[ $perf_core_cstate =~ c1 ]] && [[ $tc_out_cstate_list =~ CPU%c1 ]]; then
            test_print_trc "$perf_core_cstate is supported and aligned with turbostat"
        elif [[ $perf_core_cstate =~ c6 ]] && [[ $tc_out_cstate_list =~ CPU%c6 ]]; then
            test_print_trc "$perf_core_cstate is supported and aligned with turbostat"
        else
            die "perf list shows unexpected core_cstate event."
        fi
    done

    perf_pkg_cstate_num=$(perf list | grep -c cstate_pkg)
    for ((i = 1; i <= perf_pkg_cstate_num; i++)); do
        perf_pkg_cstate=$(perf list | grep cstate_pkg | sed -n "$i, 1p")
        if [[ $perf_pkg_cstate =~ c2 ]] && [[ $tc_out_cstate_list =~ Pkg%pc2 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        elif [[ $perf_pkg_cstate =~ c6 ]] && [[ $tc_out_cstate_list =~ Pkg%pc6 ]]; then
            test_print_trc "$perf_pkg_cstate is supported and aligned with turbostat"
        else
            die "perf list shows unexpected pkg_cstate event."
        fi
    done
}

# Verify if cstate_core or cstate_pkg pmu event updates during idle
perf_cstat_update_server() {
    local cstate_name=$1

    perf_cstates=$(perf list | grep "$cstate_name" 2>&1)
    perf_cstates_num=$(perf list | grep -c "$cstate_name" 2>&1)
    [[ -n $perf_cstates ]] || block_test "Did not get $cstate_name event by perf list"

    #Sleep 20 seconds to capture the cstate counter update
    for ((i = 1; i <= perf_cstates_num; i++)); do
        perf_cstate=$(echo "$perf_cstates" | awk '{print $1}' | sed -n "$i, 1p" 2>&1)
        test_print_trc "perf event name: $perf_cstate"
        option="$option -e $perf_cstate"
        test_print_trc "option name: $option"
    done
    do_cmd "perf stat -o $LOG_PATH/out.txt --per-socket $option sleep 20"
    test_print_trc "$cstate_name perf events log:"
    do_cmd "cat $LOG_PATH/out.txt"
    perf_cstates_sockets=$(grep cstate "$LOG_PATH"/out.txt | awk '{print $NF}' | wc -l 2>&1)

    if ! counter=$(grep cstate "$LOG_PATH"/out.txt | awk '{print $3}'); then
        block_test "Did not get $cstate_name perf event: $counter"
    else
        for ((i = 1; i <= perf_cstates_sockets; i++)); do
            perf_cstat_counter=$(grep cstate "$LOG_PATH"/out.txt | awk '{print $3}' | sed -n "$i, 1p" 2>&1)
            perf_cstat_name=$(grep cstate "$LOG_PATH"/out.txt | awk '{print $4}' | sed -n "$i, 1p" 2>&1)
            if [[ $perf_cstat_counter -eq 0 ]]; then
                die "$perf_cstat_name event counter shows 0"
            else
                test_print_trc "$perf_cstat_name event counter is updated"
            fi
        done
    fi
}

cpu_off_on_stress() {
    local cycle=$1
    local dmesg_log

    cpu_num=$(lscpu | grep "On-line CPU" | awk '{print $NF}' | awk -F "-" '{print $2}')
    [ -n "$cpu_num" ] || block_test "On-line CPU is not available."
    test_print_trc "The max CPU number is: $cpu_num "

    for ((i = 1; i <= cycle; i++)); do
        test_print_trc "CPUs offline online stress cycle$i"
        for ((j = 1; j <= cpu_num; j++)); do
            do_cmd "echo 0 > /sys/devices/system/cpu/cpu$j/online"
        done
        sleep 1
        for ((j = 1; j <= cpu_num; j++)); do
            do_cmd "echo 1 > /sys/devices/system/cpu/cpu$j/online"
        done
    done

    dmesg_log=$(extract_case_dmesg)
    if echo "$dmesg_log" | grep -iE "fail|Call Trace|error|BUG|err"; then
        die "Kernel dmesg shows failure after CPU offline/online stress: $dmesg_log"
    else
        test_print_trc "Kernel dmesg shows Okay after CPU offline/online stress."
    fi
}

override_residency_latency() {
    local idle_debugfs="/sys/kernel/debug/intel_idle"
    test_print_trc "Will override state3 with new target residency:100 us,new exit latency value\
to 30 us:"
    [[ -e "$idle_debugfs"/control ]] || block_test "Intel idle debugfs file does not exist"
    do_cmd "echo 3:100:30 > $idle_debugfs/control"

    test_print_trc "Switch to the default intel idle driver"
    do_cmd "echo > $idle_debugfs/control"

    test_print_trc "Change two changes together"
    do_cmd "echo 1:0:10 3:100:30 > $idle_debugfs/control"

    test_print_trc "Switch to the default intel idle driver"
    do_cmd "echo > $idle_debugfs/control"
}

# Function to check if each platform shows all the supported Core cstates
# This case need to maintain continues as each platforment maybe different
core_cstate_list() {
    local preset_cstates_list
    local cstate_name
    # Will use array to define each different platform supported core cstates
    # For MTL, the CPU Model is 172,170, supported core cstates are: POLL,C1,C1E,C6,C7,C8,C9,C10
    # For LNL, the CPU Model is 189, supported core cstates are: POLL,C1,C1E,C6,C7,C8,C9,C10
    # For ARL, the CPU Model is 197,198 supported core cstates are: POLL,C1,C1E,C6,C7,C8,C9,C10
    # For EMR, the CPU Model is 207, supported core cstates are:POLL C1, C1E, C6
    # For GNR, the CPU Model is 173,174 supported core cstates are:POLL C1, C1E, C6, C6P
    # For SRF, the CPU Model is 175, supported core cstates are:POLL C1, C1E, C6S, C6SP
    # For CWF, the CPU Model is 221,222, supported core cstates are:POLL C1, C1E, C6S, C6SP
    cpu_model=$(sed -n '/model/p' /proc/cpuinfo | head -1 | awk '{print $3}' 2>&1)
    [[ -n "$cpu_model" ]] || block_test "Failed to get SUT model."
    if [[ $cpu_model -eq 173 ]] || [[ $cpu_model -eq 174 ]]; then
        preset_cstates_list=(POLL C1 C1E C6 C6P)
    elif [[ $cpu_model -eq 207 ]]; then
        preset_cstates_list=(POLL C1 C1E C6)
    elif [[ $cpu_model -eq 175 ]] || [[ $cpu_model -eq 221 ]] || [[ $cpu_model -eq 222 ]]; then
        preset_cstates_list=(POLL C1 C1E C6S C6SP)
    else
        preset_cstates_list=(POLL C1 C1E C6 C7 C8 C9 C10)
    fi

    sysfs_cstates_name=$(grep . /sys/devices/system/cpu/cpu0/cpuidle/state*/name | awk -F ":" '{print $NF}')
    [[ -n "$sysfs_cstates_name" ]] && test_print_trc "CPUIDLE sysfs shows core cstate name are: $sysfs_cstates_name"
    for cstate_name in "${preset_cstates_list[@]}"; do
        if [[ $sysfs_cstates_name =~ $cstate_name ]]; then
            test_print_trc "Core cstate $cstate_name is available."
        else
            die "Core cstate $cstate_name is NOT available."
        fi
    done
}

while getopts c:t:h arg; do
    case $arg in
    c)
        CASE_ID=$OPTARG
        ;;
    t)
        TIME_TO_WAIT=$OPTARG
        ;;
    h)
        die "${0##*/} -c <CASE_ID> -h
                -c CASE_ID: which case to launch
                -h: show help
                "
        ;;
    \?)
        die "You must supply an argument, ${0##*/} -h"
        ;;
    *)
        die "Invalid argument, ${0##*/} -h"
        ;;
    esac
done

#set the default case id as 1
: "${CASE_ID:="1"}"

case $CASE_ID in
1)
    test_cpu_core_c7_residency_acpi_idle "$TIME_TO_WAIT" || die
    ;;
2)
    test_cpu_core_c7_residency_acpi_s2idle "$TIME_TO_WAIT" || die
    ;;
3)
    test_cstate_switch_acpi_idle "$TIME_TO_WAIT" || die
    ;;
4)
    test_cpu_core_c7_residency_intel_idle "$TIME_TO_WAIT" || die
    ;;
5)
    test_cpu_core_c7_residency_intel_s2idle "$TIME_TO_WAIT" || die
    ;;
6)
    test_cstate_switch_intel_idle "$TIME_TO_WAIT" || die
    ;;
7)
    test_cpu_core_c6_residency_acpi_idle "$TIME_TO_WAIT" || die
    ;;
8)
    test_cpu_core_c6_residency_intel_idle "$TIME_TO_WAIT" || die
    ;;
9)
    test_all_client_cpu_deepest_cstate "$TIME_TO_WAIT" || die
    ;;
10)
    test_all_server_cpu_deepest_cstate "$TIME_TO_WAIT" || die
    ;;
11)
    test_cstate_table_name
    ;;
12)
    disable_cc_check_pc C8 Pkg%pc6 Pkg%pc8
    ;;
13)
    disable_cc_check_pc C10 Pkg%pc8 Pk%pc10
    ;;
15)
    perf_cstate_list_client
    ;;
16)
    cpu_off_on_stress 5
    ;;
17)
    override_residency_latency
    ;;
18)
    core_cstate_list
    ;;
19)
    disable_cc_check_pc C7 Pkg%pc6 Pkg%pc7
    ;;
20)
    disable_cc_check_pc C8 Pkg%pc7 Pkg%pc8
    ;;
21)
    disable_cc_check_pc C9 Pkg%pc8 Pkg%pc9
    ;;
22)
    disable_cc_check_pc C10 Pkg%pc9 Pk%pc10
    ;;
23)
    perf_cstate_list_server
    ;;
24)
    perf_cstat_update_server cstate_core
    ;;
25)
    perf_cstat_update_server cstate_pkg
    ;;
*)
    block_test "Wrong Case Id is assigned: $CASE_ID"
    ;;
esac
