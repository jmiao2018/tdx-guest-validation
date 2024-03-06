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
# @desc     Automate intel_s0ix test cases
# @returns  0 if the execution was finished successfully, else 1
# @history  2016-08-11: First Version (Ning Han)
#           2021-10-10: Updated by Wendy Wang

source "powermgr_common.sh"

GET_PMC_OCCURANCE="cat $SLP_S0_RESIDENCY_USEC_NODE"

check_precondition_for_pc10_test() {
    # Ensure msr has been loaded in kernel
    msr_module_koption=$(get_kconfig $MSR_KOPTION)
    if [[ "$msr_module_koption" == "m" ]]; then
        modprobe msr
        if [ $? -ne 0 ]; then
            block_test "fail to modprobe msr"
        else
            test_print_trc "modprobe msr successfully"
        fi
    elif [[ "$msr_module_koption" == "y" ]]; then
        test_print_trc "msr is built in kernel"
    else
        block_test "fail to get msr kernel config option"
    fi
}

s0ix_freeze_pmc_test() {
    local test_flag=$1
    local num_to_iter=$2
    local iteration=0
    local arry_pmc_val=()
    local occurrence_before=""
    local occurrence_after=""
    # Sleep 10 seconds to wait SUT enter S0ix and check S0ix Occurrence
    local check_interval="10"
    # Wake up after 30 seconds
    local freeze_time="30"

    while [ $iteration != $num_to_iter ]; do
        test_print_trc "Test Cycle: $iteration"
        # Check pmc_core sysfs
        [ -d "$PMC_CORE_SYSFS_PATH" ] || die "intel_pmc_core has not been loaded"

        which rtcwake &>/dev/null || block_test "rtcwake is not in current environment"

        occurrence_before=$(eval $GET_PMC_OCCURANCE)
        test_print_trc "occurrence_before: $occurrence_before"
        rtcwake -m freeze -s $freeze_time
        sleep $check_interval
        occurrence_after=$(eval $GET_PMC_OCCURANCE)
        test_print_trc "S0ix occurrence: $occurrence_after"
        if [[ $occurrence_after -gt $occurrence_before ]]; then
            arry_pmc_val[$iteration]="$occurrence_after"
        else
            break
        fi
        iteration=$(($iteration + 1))
    done

    if [[ $iteration -ne $num_to_iter ]]; then
        test_print_trc "The system fails to enter s2idle s0ix state, will run s0ix selftest tool:"
        do_cmd s0ix-selftest-tool.sh -s
        sleep 5
        die "Fails to enter s2idle s0ix, please check the s0ix selftest tool output"
    # if can get pmc value everytime, ENTRY_EXIT test pass
    elif [ "$test_flag" == "entry_exit" ]; then
        # if can get pc10 value everytime, ENTRY_EXIT test pass
        test_print_trc "S0ix ENTRY_EXIT TEST via PMC_Core: success"
    elif [ "$test_flag" == "recidency" ]; then
        # for residency test, the wave range need less than 10%
        s0ix_value_judge "${arry_pmc_val[*]}" 1
        [[ 0 != $? ]] && die "S0ix RESIDENCY TEST vis PMC_Core: fail"
        test_print_trc "PMC RESIDENCY TEST: success"
    fi
}

s0ix_freeze_turbostat_test() {
    local test_flag=$1
    local num_to_iter=$2
    local iteration=0
    local arry_s0ix_val=()
    local s0ix_residency_before=""
    local s0ix_residency_after=""
    # Sleep 10 seconds to wait SUT enter S0ix and check S0ix Occurrence
    local check_interval=10
    # Wake up after 30 seconds
    local duration=30

    while [ $iteration != $num_to_iter ]; do
        test_print_trc "Test Cycle: $iteration"

        which rtcwake &>/dev/null || block_test "rtcwake is not in current environment"

        #check PC10 residency
        columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10,SYS%LPI"
        turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 10 2>&1)
        test_print_trc "turbostat log before S2idle: $turbostat_output"
        s0ix_residency_before=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $9}')
        [ -z $s0ix_residency_before ] && block_test "Did not get SYS%LPI from turbostat tool, \
        please check turbostat tool version"
        test_print_trc "S2idle S0ix residency before s2idle:$s0ix_residency_before"

        echo 0 >/sys/class/rtc/rtc0/wakealarm || block_test "echo 0 to wakealarm failed"
        echo +$duration >/sys/class/rtc/rtc0/wakealarm || block_test "echo +$duration to wakealarm failed"
        turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns echo freeze 2>&1 >/sys/power/state)
        test_print_trc "turbostat log after S2idle: $turbostat_output"
        s0ix_residency_after=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $9}')
        [ -z $s0ix_residency_after ] && block_test "Fails to get S2idle s0ix residency via turbostat tool."
        test_print_trc "S2idle S0ix residency after s2idle:$s0ix_residency_after"

        if [[ "$(echo "scale=2; $s0ix_residency_after > $s0ix_residency_before" | bc)" -eq 1 ]]; then
            arry_s0ix_val[$iteration]="$s0ix_residency_after"
        else
            break
        fi
        iteration=$(($iteration + 1))
    done

    if [[ $iteration -ne $num_to_iter ]]; then
        test_print_trc "The system fails to enter s2idle s0ix state, will run s0ix selftest tool:"
        do_cmd s0ix-selftest-tool.sh -s
        sleep 5
        die "Fails to enter s2idle s0ix, please check s0ix selftest tool output"
    # if can get s0ix value everytime, ENTRY_EXIT test pass
    elif [ "$test_flag" == "entry_exit" ]; then
        # if can get s0ix value everytime, ENTRY_EXIT test pass
        test_print_trc "S0ix ENTRY_EXIT TEST: success"
    elif [ "$test_flag" == "recidency" ]; then
        # for residency test, the wave range need less than 10%
        s0ix_value_judge "${arry_pmc_val[*]}" 1
        [[ 0 != $? ]] && die "S0ix RESIDENCY TEST: fail"
        test_print_trc "S2idle S0ix RESIDENCY TEST: success"
    fi
}

s0ix_runtime_pc10_entry_via_turbostat_screen_off() {
    local pc10_val=""
    # Sleep 40 seconds to wait SUT enter PC10 and check PC10 residency
    local time_to_enter_pc10="40"

    powertop --auto-tune &>/dev/null || block_test "powertop failed"

    #Turn off the screen
    which xset &>/dev/null || block_test "xset is not in current environment"
    xset dpms force off || die "Fails to turn off the monitor"

    sleep $time_to_enter_pc10

    #check PC10 residency after idle for 40 seconds
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 30 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc10_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $8}')
    [ -z $pc10_val ] && block_test "Did not get PC10 from turbostat tool,\
    please check turbostat tool version."
    test_print_trc "pc10_val:$pc10_val"

    if [[ "$(echo "scale=2; $pc10_val > 01.00" | bc)" -eq 1 ]]; then
        test_print_trc "The system enters runtime pc10 state."
        # Turn on monitor
        xset dpms force on
    else
        # Turn on monitor
        xset dpms force on
        die "The system fails to enter runtime pc10 state."
    fi
}

s0ix_runtime_pc10_residency_via_turbostat_screen_off() {
    local pc10_residency_margin_error=$1
    local pc10_residency=""
    # Sleep 40 seconds to wait SUT enter PC10 and check PC10 residency
    local time_to_enter_pc10="40"

    powertop --auto-tune &>/dev/null || block_test "powertop fails to run"

    #Turn off the screen
    which xset &>/dev/null || block_test "xset is not in current environment"
    xset dpms force off || die "Fails to turn off the monitor"

    sleep $time_to_enter_pc10

    #check PC10 residency
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 30 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc10_residency=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $8}')
    [ -z $pc10_residency ] && block_test "Did not get PC10 from turbostat tool, \
    please check turbostat tool version."
    test_print_trc "pc10 residency during screen off:$pc10_residency"

    if [[ "$(echo "scale=2; $pc10_residency > $pc10_residency_margin_error" | bc)" -eq 1 ]]; then
        test_print_trc "The system runtime PC10 residency during screen off is larger than 50%!"
    else
        die "The system runtime PC10 residency during screen off is less than 50%"
    fi

    #Turn on the screen
    xset dpms force on
}

#Function to check runtime PC2 for server platform
#Server usually disable pkg cstate in BIOS by default
#Need to enable pkg cst control before testing
runtime_pc2_entry_via_turbostat_screen_on() {
    local pc2_val=""
    # Sleep 10 seconds to wait SUT enter PC2
    local time_to_enter_pc2="10"

    powertop --auto-tune &>/dev/null || block_test "powertop failed"
    #Read MSR_PKG_CST_CONFIG_CONTROL: 0xe2
    pkg_cst_ctl=$(rdmsr -a $PKG_CST_CTL 2>/dev/null/)

    #Read MSR_PKG_C2_RESIDENCY: 0x60d
    msr_pkg2_before=$(rdmsr -a $MSR_PKG2 2>/dev/null)
    test_print_trc "MSR_PKG_C2_RESIDENCY before: $msr_pkg2_before"

    sleep $time_to_enter_pc2

    #check PC2 residency after idle for 10 seconds
    columns="Core,CPU,CPU%c1,CPU%c6,Pkg%pc2,Pkg%pc6"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 10 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc2_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $5}')
    msr_pkg2_after=$(rdmsr -a $MSR_PKG2 2>/dev/null)
    test_print_trc "MSR_PKG_C2_RESIDENCY after: $msr_pkg2_after"

    [ -z $pc2_val ] && block_test "Did not get PC2 from turbostat tool, \
    please check turbostat tool version or if BIOS disabled Pkg cstate."
    test_print_trc "All the CPUs PC2 residency:$pc2_val"
    test_print_trc "MSR_PKG_CST_CONFIG_CONTROL: $pkg_cst_ctl"

    if [[ "$(echo "scale=2; $pc2_val > 0.01" | bc)" -eq 1 ]]; then
        test_print_trc "The system enters runtime pc2 state."
    else
        die "The system fails to enter runtime pc2 state."
    fi
}

#Function to check runtime PC6 for server platform
#Server usually disable pkg cstate in BIOS by default
#Need to enable pkg cst control before testing
runtime_pc6_entry_via_turbostat_screen_on() {
    local pc6_val=""
    # Sleep 10 seconds to wait SUT enter PC6
    local time_to_enter_pc6="10"

    powertop --auto-tune &>/dev/null || block_test "powertop failed"
    #Read MSR_PKG_CST_CONFIG_CONTROL: 0xe2
    pkg_cst_ctl=$(rdmsr -a $PKG_CST_CTL 2>/dev/null/)

    #Read MSR_PKG_C6_RESIDENCY: 0x3f9
    msr_pkg6_before=$(rdmsr -a $MSR_PKG6 2>/dev/null)
    test_print_trc "MSR_PKG_C6_RESIDENCY before: $msr_pkg6_before"

    sleep $time_to_enter_pc6

    #check PC6 residency after idle for 10 seconds
    columns="Core,CPU,CPU%c1,CPU%c6,Pkg%pc2,Pkg%pc6"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 10 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc6_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $6}')
    msr_pkg6_after=$(rdmsr -a $MSR_PKG6 2>/dev/null)
    test_print_trc "MSR_PKG_C6_RESIDENCY after: $msr_pkg6_after"

    [ -z $pc6_val ] && block_test "Did not get PC6 from turbostat tool, \
    please check turbostat tool version or if BIOS disabled Pkg cstate."
    test_print_trc "All the CPUs PC6 residency:$pc6_val"
    test_print_trc "MSR_PKG_CST_CONFIG_CONTROL: $pkg_cst_ctl"

    if [[ "$(echo "scale=2; $pc6_val > 0.01" | bc)" -eq 1 ]]; then
        test_print_trc "The system enters runtime pc6 state."
    else
        die "The system fails to enter runtime pc6 state."
    fi
}

#Function to check runtimec PC6 residency and stability
runtime_pc6_residency() {
    local pc6_res=""

    powertop --auto-tune &>/dev/null || block_test "powertop failed"
    #Read MSR_PKG_CST_CONFIG_CONTROL: 0xe2
    pkg_cst_ctl=$(rdmsr -a $PKG_CST_CTL 2>/dev/null/)

    for ((i = 1; i <= 10; i++)); do
        #check PC6 residency after idle for 10 seconds
        columns="Core,CPU,CPU%c1,CPU%c6,Pkg%pc2,Pkg%pc6"
        turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 10 2>&1)
        test_print_trc "turbostat log: $turbostat_output"
        pc6_res=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $6}')
        [ -z $pc6_res ] && block_test "Did not get PC6 from turbostat tool, \
please check turbostat tool version or if BIOS disabled Pkg cstate."
        test_print_trc "All the CPUs PC6 residency:$pc6_res"

        if [[ "$(echo "scale=2; $pc6_res > 90.01" | bc)" -eq 1 ]]; then
            test_print_trc "Cycle $i: The system enters runtime pc6 state with \
good residency (>90%)"
        elif [[ "$(echo "scale=2; $pc6_res > 70.01" | bc)" -eq 1 ]]; then
            test_print_trc "Cycle $i: The system enters runtime pc6 state but \
less than 90% residency"
        elif [[ "$(echo "scale=2; $pc6_res > 5.01" | bc)" -eq 1 ]]; then
            die "Cycle $i: The system enters runtime pc6 state with low residency"
        else
            die "Cycle $i: The system fails to enter runtime pc6 state or \
the residency is extremely low"
        fi
    done
}

s0ix_runtime_pc8_entry_via_turbostat_screen_on() {
    local pc8_val=""
    # Sleep 40 seconds to wait SUT enter PC8 and check PC8 residency
    local time_to_enter_pc8="40"

    powertop --auto-tune &>/dev/null || block_test "powertop failed"

    sleep $time_to_enter_pc8

    #check PC8 residency after idle for 40 seconds
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 30 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc8_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $6}')
    [ -z $pc8_val ] && block_test "Did not get PC8 from turbostat tool, \
    please check turbostat tool version."
    test_print_trc "pc8_val:$pc8_val"

    if [[ "$(echo "scale=2; $pc8_val > 01.00" | bc)" -eq 1 ]]; then
        test_print_trc "The system enters runtime pc8 state."
    else
        die "The system fails to enter runtime pc8 state."
    fi
}

s0ix_runtime_pc10_entry_via_turbostat_screen_on() {
    local pc10_val=""
    # Sleep 40 seconds to wait SUT enter PC10 and check PC10 residency
    local time_to_enter_pc10="40"

    powertop --auto-tune &>/dev/null || block_test "powertop fails to run"

    sleep $time_to_enter_pc10

    #check PC10 residency after idle for 40 seconds
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 30 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc10_val=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $8}')
    [ -z $pc10_val ] && block_test "Did not get PC10 from turbostat tool,\
    please check turbostat tool version."
    test_print_trc "pc10_val:$pc10_val"

    if [[ "$(echo "scale=2; $pc10_val > 01.00" | bc)" -eq 1 ]]; then
        test_print_trc "The system enters runtime pc10 state."
    else
        test_print_trc "Will run s0ix selftest tool:"
        do_cmd s0ix-selftest-tool.sh -r on
        sleep 5
        die "The system fails to enter runtime pc10 state, please check s0ix selftest tool outputs."
    fi
}

s0ix_runtime_pc10_residency_via_turbostat_screen_on() {
    local pc10_residency_margin_error=$1
    local pc10_residency=""
    # Sleep 40 seconds to wait SUT enter PC10 and check PC10 residency
    local time_to_enter_pc10="40"

    powertop --auto-tune &>/dev/null || block_test "powertop failed"

    sleep $time_to_enter_pc10

    #check PC10 residency
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 30 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc10_residency=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $8}')
    [ -z $pc10_residency ] && block_test "Did not get PC10 from turbostat tool,\ 
    please check turbostat tool version."
    test_print_trc "pc10 residency during screen on:$pc10_residency"

    if [[ "$(echo "scale=2; $pc10_residency > $pc10_residency_margin_error" | bc)" -eq 1 ]]; then
        test_print_trc "The system runtime PC10 residency during screen on is larger than 50%!"
    else
        die "The system runtime PC10 residency during screen on is less than 50%"
    fi
}

#read out value in PC8 from PMC_CORE
s0ix_runtime_pc8_entry_via_pmc_core_screen_on() {
    PMC_CORE_PATH="/sys/kernel/debug/pmc_core/package_cstate_show"

    #check PC8 residency during idle
    [[ -f $PMC_CORE_PATH ]] || die "Intel_pmc_core driver is not ready for this platform"
    pc8_val_init=$(grep "Package C8" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc8_val_init:$pc8_val_init
    sleep 10
    pc8_val_before=$(grep "Package C8" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc8_val_before:$pc8_val_before

    #Judge whether runtime PC8 is achieved during idle
    if [[ $pc8_val_before -gt $pc8_val_init ]]; then
        test_print_trc "Runtime PC8 residency is achieved during idle"
    else
        die "Fails to get runtime pc8 residency."
    fi
}

#read out value in PC10 from PMC_CORE
s0ix_runtime_pc10_entry_via_pmc_core_screen_on() {
    PMC_CORE_PATH="/sys/kernel/debug/pmc_core/package_cstate_show"

    #check PC10 residency during idle
    [[ -f $PMC_CORE_PATH ]] || die "Intel_pmc_core driver is not ready for this platform"
    pc10_val_init=$(grep "Package C10" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc10_val_init:$pc10_val_init
    sleep 10
    pc10_val_before=$(grep "Package C10" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc10_val_before:$pc10_val_before

    #Judge whether runtime PC10 is achieved during idle
    if [[ $pc10_val_before -gt $pc10_val_init ]]; then
        test_print_trc "Runtime PC10 residency is achieved during idle"
    else
        die "Fails to get runtime pc10 residency."
    fi
}

#read out value in PC8 from PMC_CORE
s0ix_s2idle_pc8_entry_via_pmc_core() {
    local duration=30
    PMC_CORE_PATH="/sys/kernel/debug/pmc_core/package_cstate_show"

    #check PC8 residency during idle
    [[ -f $PMC_CORE_PATH ]] || die "Intel_pmc_core driver is not ready for this platform"
    pc8_val_before=$(grep "Package C8" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc8_val_before:$pc8_val_before

    #Check PC8 residency after resume s2idle
    echo 0 >/sys/class/rtc/rtc0/wakealarm || block_test "echo 0 to wakealarm failed"
    echo +$duration >/sys/class/rtc/rtc0/wakealarm || block_test "echo +$duration to wakealarm failed"
    echo freeze >/sys/power/state
    sleep 30
    pc8_val_after=$(grep "Package C8" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc8_val_after:$pc8_val_after

    #Judge whether runtime PC8 residency is increased after resume from S2idle
    if [[ $pc8_val_after -gt $pc8_val_before ]]; then
        test_print_trc "Runtime PC8 residency is achieved after resuming from S2idle"
    else
        die "Fail to get runtime PC8 residency after resuming from S2idle "
    fi
}

#read out value in PC10 from PMC_CORE
s0ix_s2idle_pc10_entry_via_pmc_core() {
    local duration=100
    PMC_CORE_PATH="/sys/kernel/debug/pmc_core/package_cstate_show"

    #check PC10 residency during idle
    [[ -f $PMC_CORE_PATH ]] || die "Intel_pmc_core driver is not ready for this platform"
    pc10_val_before=$(grep "Package C10" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc10_val_before:$pc10_val_before

    #Check PC10 residency after resume s2idle
    echo 0 >/sys/class/rtc/rtc0/wakealarm || block_test "echo 0 to wakealarm failed"
    echo +$duration >/sys/class/rtc/rtc0/wakealarm || block_test "echo +$duration to wakealarm failed"
    echo freeze >/sys/power/state
    sleep 30
    pc10_val_after=$(grep "Package C10" $PMC_CORE_PATH | awk -F": " '{print $2}')
    test_print_trc pc10_val_after:$pc10_val_after

    #Judge whether runtime PC10 residency is increased after resuming from S2idle
    if [[ $pc10_val_after -gt $pc10_val_before ]]; then
        test_print_trc "Runtime PC10 residency is achieved after resuming from S2idle"
    else
        die "Fail to get runtime PC10 residency after resuming from S2idle "
    fi
}

# read out value in PC8 from turbostat
s0ix_freeze_pc8_test_via_turbostat() {
    local pc8_val_before=""
    local pc8_val_after=""
    local turbostat_output=""
    local duration=30

    #check PC8 residency before S2idle
    powertop --auto-tune &>/dev/null || block_test "powertop failed"
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 30 2>&1)
    test_print_trc "turbostat log before S2idle: $turbostat_output"
    pc8_val_before=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $6}')
    [ -z $pc8_val_before ] && block_test "Did not get PC8 from turbostat tool, \
    please check turbostat tool version."
    test_print_trc "pc8_val_before:$pc8_val_before"

    #Check PC8 residency after resuming from s2idle
    echo 0 >/sys/class/rtc/rtc0/wakealarm || block_test "echo 0 to wakealarm failed"
    echo +$duration >/sys/class/rtc/rtc0/wakealarm || block_test "echo +$duration to wakealarm failed"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns echo freeze 2>&1 >/sys/power/state)
    test_print_trc "turbostat log after S2idle: $turbostat_output"
    pc8_val_after=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $6}')
    test_print_trc "pc8_val_after:$pc8_val_after"

    #Judge whether PC8 residency is increased after resuming from S2idle
    rt_value_after=$(echo "$pc8_val_after > 0" | bc)
    if [ $rt_value_after -eq 1 ]; then
        test_print_trc "PC8 residency is achieved after resume from S2idle"
    else
        die "Fail to get S2idle PC8 residency."
    fi
}

# read out value in PC10 from turbostat
s0ix_freeze_pc10_test_via_turbostat() {
    local pc10_val_before=""
    local pc10_val_after=""
    local turbostat_output=""
    local duration=30

    powertop --auto-tune &>/dev/null || block_test "powertop failed"
    #check PC10 residency before s2idle
    columns="Core,Pkg%pc2,Pkg%pc3,Pkg%pc6,Pkg%pc7,Pkg%pc8,Pkg%pc9,Pk%pc10"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns sleep 10 2>&1)
    test_print_trc "turbostat log: $turbostat_output"
    pc10_val_before=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $8}')
    [ -z $pc10_val_before ] && block_test "Did not get PC10 from turbostat tool, \
    please check turbostat tool version."
    test_print_trc "pc10_val_before:$pc10_val_before"

    #Check PC10 residency after resuming from s2idle
    echo 0 >/sys/class/rtc/rtc0/wakealarm || block_test "echo 0 to wakealarm failed"
    echo +$duration >/sys/class/rtc/rtc0/wakealarm || block_test "echo +$duration to wakealarm failed"
    turbostat_output=$("$PSTATE_TOOL/turbostat" -i 10 --quiet --show $columns echo freeze 2>&1 >/sys/power/state)
    test_print_trc "turbostat log: $turbostat_output"
    pc10_val_after=$(echo "$turbostat_output" | grep -E "^-" | awk '{print $8}')
    test_print_trc "pc10_val_after:$pc10_val_after"

    #Judge whether S2idle PC10 residency is increased after resuming from S2idle
    rt_value_after=$(echo "$pc10_val_after > 0" | bc)
    if [ $rt_value_after -eq 1 ]; then
        test_print_trc "S2idle PC10 residency is achieved."
    else
        die "Fail to get S2idle PC10 residency."
    fi
}

s0ix_value_judge() {
    # for residency test, the wave range need less than 10%
    local array=($1)
    local flag=$2
    local max=$(echo $array | awk '{print $1}')
    local min=$(echo $array | awk '{print $1}')
    local delta=0

    for i in "${array[@]}"; do
        [ $(echo "$max < $i" | bc) -eq 1 ] && max=$i
        [ $(echo "$min > $i" | bc) -eq 1 ] && min=$i
    done

    [ -z "$max" ] && die "max not exist !"
    [ $max -eq 0 ] && die "the value of max cannot be 0 !"

    if [ -z $flag ]; then
        delta=$(awk -v x="$max" -v y="$min" 'BEGIN{printf "%.2f\n",x-y}')
    else
        delta=$(awk -v x="$max" -v y="$min" 'BEGIN{printf "%.2f\n",(x-y)*100/x}')
    fi

    [ $(echo "$delta > 10" | bc) -eq 1 ] && {
        die "Delta great is ${delta}%, great than %10, test failed."
    }

    return 0
}

#This funtion is used to check PS_ON signal to be triggerred or not
#This case only supported Client -S SKU which has ATS PSU power source
#The aims of PS_ON is to turn off all the main rails of AC to DC power (PSU)
#by setting PS_ON# HIGH (turn off non-SB PSU rails)
ps_on_entry_check() {
    local ps_on_before_s2idle=""
    local ps_on_after_s2idle=""
    local iteration=0
    local num_to_iter=$1
    local duration=30

    [[ -f "$PMC_CORE_SYSFS_PATH"/pson_residency_usec ]] ||
        block_test "PS_ON is not enabled for the test platform!"

    while [[ $iteration != "$num_to_iter" ]]; do
        test_print_trc "Test Cycle: $iteration"
        ps_on_before_s2idle=$(cat "$PMC_CORE_SYSFS_PATH"/pson_residency_usec)
        test_print_trc "PS_ON residency value before S2idle: $ps_on_before_s2idle"

        test_print_trc "Will run s2idle cycle for iteration$iteration,duration is 30 seconds:"
        echo 0 >/sys/class/rtc/rtc0/wakealarm ||
            block_test "echo 0 to wakealarm failed"
        echo +$duration >/sys/class/rtc/rtc0/wakealarm ||
            block_test "echo +$duration to wakealarm failed"
        echo freeze >/sys/power/state
        sleep 30

        ps_on_after_s2idle=$(cat "$PMC_CORE_SYSFS_PATH"/pson_residency_usec)
        test_print_trc "PS_ON residency value after S2idle: $ps_on_after_s2idle"

        if [[ $ps_on_after_s2idle -gt $ps_on_before_s2idle ]]; then
            test_print_trc "PS_ON signal is triggerred successfully."
        else
            die "PS_ON signal is failed to be triggerred."
        fi
        iteration=$(("$iteration" + 1))
    done
}

ps_on_residency_check() {
    local ps_on_before_s2idle=""
    local ps_on_after_s2idle=""
    local iteration=0
    local duration=300
    local tsc_msr=0x10
    local tsc_freq=""
    local cycles=$1

    [[ -f "$PMC_CORE_SYSFS_PATH"/pson_residency_usec ]] ||
        block_test "PS_ON is not enabled for the test platform!"

    turbostat_debug=$("$PSTATE_TOOL/turbostat" -i 1 sleep 1 2>&1)
    test_print_trc "Turbostat debug output is:$turbostat_debug"
    tsc_freq=$(echo "$turbostat_debug" | grep TSC: | awk '{print $2}')
    test_print_trc "TSC Freq: $tsc_freq MHz"
    [[ -n "$tsc_freq" ]] || block_test "Did not get turbostat log!"

    while [[ $iteration != "$cycles" ]]; do
        test_print_trc "------ps_on residency test cycle $iteration------"
        ps_on_before_s2idle=$(cat "$PMC_CORE_SYSFS_PATH"/pson_residency_usec)
        test_print_trc "PS_ON residency value before S2idle: $ps_on_before_s2idle"
        tsc_bf=$(rdmsr $tsc_msr)
        tsc_bf_dec=$(echo "$((16#$tsc_bf))" | bc)
        test_print_trc "TSC value before S2idle:$tsc_bf_dec"

        test_print_trc "Will run one cycle s2idle,duration is 300 seconds:"
        echo 0 >/sys/class/rtc/rtc0/wakealarm ||
            block_test "echo 0 to wakealarm failed"
        echo +$duration >/sys/class/rtc/rtc0/wakealarm ||
            block_test "echo +$duration to wakealarm failed"
        echo freeze >/sys/power/state

        ps_on_after_s2idle=$(cat "$PMC_CORE_SYSFS_PATH"/pson_residency_usec)
        test_print_trc "PS_ON residency value after S2idle: $ps_on_after_s2idle"
        tsc_af=$(rdmsr $tsc_msr)
        tsc_af_dec=$(echo "$((16#$tsc_af))" | bc)
        test_print_trc "TSC value after S2idle:$tsc_af_dec"

        tsc_delta_dec=$(echo "$tsc_af_dec - $tsc_bf_dec" | bc)
        test_print_trc "TSC delta decimal by reading from MSR: $tsc_delta_dec"
        #Switch tsc_time unit to usec/hz: (tsc_delta * 1000000 ) / tsc_freq * 1000000 Hz
        tsc_time_usec=$(echo "$tsc_delta_dec * 1000000 / $tsc_freq / 1000000" | bc)
        test_print_trc "TSC delta decimal by switching to usec/Hz unit: $tsc_time_usec"

        ps_on_resi_delta_dec=$(echo "$ps_on_after_s2idle - $ps_on_before_s2idle" | bc)
        test_print_trc "PS_ON Residency delta decimal: $ps_on_resi_delta_dec"

        ps_on_resi=$(echo "scale=2; $ps_on_resi_delta_dec / $tsc_time_usec" | bc)
        ps_on_resi_percentage=$(echo "$ps_on_resi * 100" | bc)
        test_print_trc "PS_ON Residency: $ps_on_resi_percentage%"
        if [[ $(echo "$ps_on_resi_percentage > 50.00" | bc) -eq 1 ]]; then
            test_print_trc "PS_ON residency is larger than 50%"
        else
            die "PS_ON residency is less than 50%"
        fi
        iteration=$(("$iteration" + 1))
    done
}

deepest_substate_residency() {
    local deepest_sub_bf=""
    local deepest_sub_af=""
    local duration=300
    local tsc_msr=0x10
    local tsc_freq=""

    turbostat_debug=$("$PSTATE_TOOL/turbostat" -i 1 sleep 1 2>&1)
    test_print_trc "Turbostat debug output is:$turbostat_debug"
    tsc_freq=$(echo "$turbostat_debug" | grep TSC: | awk '{print $2}')
    test_print_trc "TSC Freq: $tsc_freq MHz"
    [[ -n "$tsc_freq" ]] || block_test "Did not get turbostat log!"

    deepest_sub_bf=$(cat "$PMC_CORE_SYSFS_PATH"/substate_residencies | awk 'END {print}' | awk '{print $2}')
    test_print_trc "The deepest S0ix substate residency value before S2idle: $deepest_sub_bf"
    tsc_bf=$(rdmsr $tsc_msr)
    tsc_bf_dec=$(echo "$((16#$tsc_bf))" | bc)
    test_print_trc "TSC value before S2idle:$tsc_bf_dec"

    test_print_trc "Will run one cycle s2idle,duration is 300 seconds:"
    echo 0 >/sys/class/rtc/rtc0/wakealarm ||
        block_test "echo 0 to wakealarm failed"
    echo +$duration >/sys/class/rtc/rtc0/wakealarm ||
        block_test "echo +$duration to wakealarm failed"
    echo freeze >/sys/power/state

    deepest_sub_af=$(cat "$PMC_CORE_SYSFS_PATH"/substate_residencies | awk 'END {print}' | awk '{print $2}')
    test_print_trc "The deepest S0ix substate residency value before S2idle: $deepest_sub_af"
    tsc_af=$(rdmsr $tsc_msr)
    tsc_af_dec=$(echo "$((16#$tsc_af))" | bc)
    test_print_trc "TSC value after S2idle:$tsc_af_dec"

    tsc_delta_dec=$(echo "$tsc_af_dec - $tsc_bf_dec" | bc)
    test_print_trc "TSC delta decimal by reading from MSR: $tsc_delta_dec"
    #Switch tsc_time unit to usec/hz: (tsc_delta * 1000000 ) / tsc_freq * 1000000 Hz
    tsc_time_usec=$(echo "$tsc_delta_dec * 1000000 / $tsc_freq / 1000000" | bc)
    test_print_trc "TSC delta decimal by switching to usec/Hz unit: $tsc_time_usec"

    deepest_sub_res_delta_dec=$(echo "$deepest_sub_af - $deepest_sub_bf" | bc)
    test_print_trc "The deepest S0ix substate residency delta decimal: $deepest_sub_res_delta_dec"

    deepest_sub_resi=$(echo "scale=2; $deepest_sub_res_delta_dec / $tsc_time_usec" | bc)
    deepest_sub_resi_percentage=$(echo "$deepest_sub_resi * 100" | bc)
    test_print_trc "The deepest S0ix substate residency: $deepest_sub_resi_percentage%"
    if [[ $(echo "$deepest_sub_resi_percentage > 50.00" | bc) -eq 1 ]]; then
        test_print_trc "The deepest S0ix substate residency is larger than 50%"
    else
        die "The deepest S0ix substate residency is less than 50%"
    fi
}

cdie-c6-idle() {
    local iteration=0
    local cycles=$1

    [[ -f "$PMC_CORE_SYSFS_PATH"/die_c6_us_show ]] ||
        block_test "Computer Die is not support or pmc_core sysfs is not ready!"

    [[ -f die-c6-debugfs.log ]] && do_cmd "rm -f die-c6-debugfs.log"

    while [[ $iteration != "$cycles" ]]; do
        sleep 1
        do_cmd "cat $PMC_CORE_SYSFS_PATH/die_c6_us_show >> die-c6-debugfs.log"
        iteration=$(("$iteration" + 1))
    done

    test_print_trc "Cdie-C6-residency in past $iteration seconds idle:"
    do_cmd "cat die-c6-debugfs.log"

    repeat_item=$(uniq -d die-c6-debugfs.log)
    if [[ -n "$repeat_item" ]]; then
        die "Cdie-C6 residency does not change consistently during idle."
    else
        test_print_trc "Cdie-C6 residency changes as expected during idle."
    fi
}

cdie-c6-cdie-cpus-offline() {
    local iteration=0
    local cycles=$1

    [[ -f "$PMC_CORE_SYSFS_PATH"/die_c6_us_show ]] ||
        block_test "Computer Die does not support or pmc_core sysfs is not ready!"

    [[ -f die-c6-debugfs-offline.log ]] && do_cmd "rm -f die-c6-debugfs-offline.log"

    # Offline Cdie-CPUs
    # The low power cpu on SoC die does not have the cache index3 directory
    # So use this cache index3 information to judge if SUT supports SoC die or not
    cache_index=$(grep . /sys/devices/system/cpu/cpu*/cache/index3/shared_cpu_list | sed -n '1p' |
        awk -F "-" '{print $NF}' 2>&1)
    [[ -n "$cache_index" ]] || block_test "CPU cache index sysfs is not available."
    test_print_trc "CPU number from cache index3: $cache_index"

    cpu_list=$("$TOOL"/cpuid | grep -c "core type" 2>&1)
    test_print_trc "CPU number from cpuid: $cpu_list"

    if [[ "$cache_index" != "$cpu_list" ]]; then
        for ((i = 0; i <= cache_index; i++)); do
            do_cmd "echo 0 > $CPU_SYSFS_PATH/cpu$i/online"
        done

        while [[ $iteration != "$cycles" ]]; do
            sleep 1
            do_cmd "cat $PMC_CORE_SYSFS_PATH/die_c6_us_show >> die-c6-debugfs-offline.log"
            iteration=$(("$iteration" + 1))
        done

        test_print_trc "Cdie-C6-residency in past $iteration seconds after CPUs offline:"
        do_cmd "cat die-c6-debugfs-offline.log"

        # Re-online Cdie CPUs
        for ((i = 0; i <= cache_index; i++)); do
            do_cmd "echo 1 > $CPU_SYSFS_PATH/cpu$i/online"
        done

        repeat_item=$(uniq -d die-c6-debugfs-offline.log)
        if [[ -n "$repeat_item" ]]; then
            die "Cdie-C6 residency does not change consistently after Cdie CPUs offline."
        else
            test_print_trc "Cdie-C6 residency change as expected after Cdie CPUs offline."
        fi

    else
        block_test "Test platform does not support SoC Die CPU."
    fi
}

while getopts c:h arg; do
    case $arg in
    c)
        CASE_ID=$OPTARG
        test_print_trc "case is: $CASE_ID"
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

# Set the default case id as 1
: "${CASE_ID:="1"}"

case $CASE_ID in
1)
    test_print_trc "Start runtime pc10 state entry check via turbostat tool for screen off scenario:"
    s0ix_runtime_pc10_entry_via_turbostat_screen_off
    ;;
2)
    test_print_trc "Start runtime pc10 state residency check via turbostat tool for screen off scenario:"
    s0ix_runtime_pc10_residency_via_turbostat_screen_off 50.00
    ;;
3)
    test_print_trc "Start runtime pc8 state entry check via turbostat tool for screen on scenario:"
    s0ix_runtime_pc8_entry_via_turbostat_screen_on
    ;;
4)
    test_print_trc "Start runtime pc10 state entry check via turbostat tool for screen on scenario:"
    s0ix_runtime_pc10_entry_via_turbostat_screen_on
    ;;
5)
    test_print_trc "Start runtime pc10 state residency check via turbostat tool for screen on scenario:"
    s0ix_runtime_pc10_residency_via_turbostat_screen_on 50.00
    ;;
6)
    test_print_trc "Start runtime pc8 state entry check via pmc_core for screen on scenario:"
    test_kconfigs m CONFIG_INTEL_PMC_CORE ||
        block_test "No intel_pmc_core driver in kernel"
    s0ix_runtime_pc8_entry_via_pmc_core_screen_on
    ;;
7)
    test_print_trc "Start runtime pc10 state entry check via pmc_core for screen on scenario:"
    test_kconfigs m CONFIG_INTEL_PMC_CORE ||
        block_test "No intel_pmc_core driver in kernel"
    s0ix_runtime_pc10_entry_via_pmc_core_screen_on
    ;;
8)
    test_print_trc "Start s2idle pc8 state entry check via turbostat tool:"
    test_kconfigs m CONFIG_INTEL_PMC_CORE ||
        block_test "No intel_pmc_core driver in kernel"
    s0ix_freeze_pc8_test_via_turbostat
    ;;
9)
    test_print_trc "Start s2idle pc10 state entry check via turbostat tool:"
    s0ix_freeze_pc10_test_via_turbostat
    ;;
10)
    test_print_trc "Start s2idle pc8 state entry check via pmc_core:"
    test_kconfigs m CONFIG_INTEL_PMC_CORE ||
        block_test "No intel_pmc_core driver in kernel"
    s0ix_s2idle_pc8_entry_via_pmc_core
    ;;
11)
    test_print_trc "Start s2idle pc10 state entry check via pmc_core:"
    test_kconfigs m CONFIG_INTEL_PMC_CORE ||
        block_test "No intel_pmc_core driver in kernel"
    s0ix_s2idle_pc10_entry_via_pmc_core
    ;;
12)
    test_print_trc "Start s2idle S0ix state entry check once via turbostat:"
    s0ix_freeze_turbostat_test entry_exit 1
    ;;
13)
    test_print_trc "Start s2idle S0ix state entry check once via pmc_core:"
    s0ix_freeze_pmc_test entry_exit 1
    ;;
14)
    test_print_trc "Start s2idle S0ix state entry check 10 cycles via turbostat:"
    s0ix_freeze_turbostat_test entry_exit 10
    ;;
15)
    test_print_trc "Start s2idle S0ix state entry check 10 cycles via pmc_core:"
    s0ix_freeze_pmc_test entry_exit 10
    ;;
16)
    test_print_trc "Start runtime pc2 state for server platform via turbostat:"
    runtime_pc2_entry_via_turbostat_screen_on
    ;;
17)
    test_print_trc "Start runtime pc6 state for server platform via turbostat:"
    runtime_pc6_entry_via_turbostat_screen_on
    ;;
18)
    test_print_trc "Start runtime pc6 residency check for server platform:"
    runtime_pc6_residency
    ;;
19)
    test_print_trc "Start PS_ON signal check for Client desktop platform:"
    ps_on_entry_check 2
    ;;
20)
    test_print_trc "Start PS_ON signal 10 cycles check for Client desktop platform:"
    ps_on_entry_check 10
    ;;
21)
    test_print_trc "Start PS_ON residency check for Client desktop platform:"
    ps_on_residency_check 10
    ;;
22)
    test_print_trc "Start the deepest S0ix substate residency check for Client desktop platform:"
    deepest_substate_residency
    ;;
23)
    test_print_trc "Start PS_ON residency testing 100 cycles for Client desktop platform:"
    ps_on_residency_check 100
    ;;
24)
    test_print_trc "Start CDie-C6 residency during idle"
    cdie-c6-idle 60
    ;;
25)
    test_print_trc "Start CDie-C6 residency during idle after CDie CPUs offline"
    cdie-c6-cdie-cpus-offline 60
    ;;
*)
    block_test "Wrong Case Id is assigned: $CASE_ID"
    ;;
esac
