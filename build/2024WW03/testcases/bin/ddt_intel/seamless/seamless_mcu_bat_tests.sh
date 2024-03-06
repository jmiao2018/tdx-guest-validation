#!/bin/bash
#
# Copyright 2023 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate seamless mircocode update (MCU).
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ruifeng Gao <ruifeng.gao@intel.com>
#
# History:
#             Dec. 21, 2023 - (Ruifeng Gao)Creation

source common.sh
source dmesg_functions.sh

mcu_check_msr1(){
    cpuid_value=$(cpuid -1 -l 0x7 -s 0x0 -r)
    eex_value=${cpuid_value% eex*}
    edx_value=${eex_value#*edx=}
    is_mcu_enabled=$((edx_value>>29 &1))
    if [[ "$is_mcu_enabled" == "1" ]]; then
        test_print_trc "CPUID.(EAX=07H, ECX=0):EDX[29] == 1"
    else
        die "IA32_MCU_ENUMERATION and IA32_MCU_STATUS are not set correctly."
    fi

    msr_0x7c_value=$(rdmsr 0x10a -f 16:16)
    if [[ "$msr_0x7c_value" == "1" ]]; then
        test_print_trc "IA32_ARCH_CAPABILITIES[16] == 1"
    else
        die "IA32_ARCH_CAPABILITIES is not set correctly."
    fi
}

mcu_check_msr2(){
    mcu_avail_value=$(rdmsr 0x7b -f 0:0)
    mcu_config_reqd_value=$(rdmsr 0x7b -f 1:1)
    mcu_config_cmpl_value=$(rdmsr 0x7b -f 2:2)
    mcu_scope_value=$(rdmsr 0x7b -f 15:8)
    if [[ "$mcu_avail_value" == "1" ]]; then
        test_print_trc "Uniform MCU is available."
    else
        die "Uniform MCU is not available."
    fi

    if [[ "$mcu_config_reqd_value" == "1" && "$mcu_config_cmpl_value" == "0" ]]; then
        die "Necessary configruation has not been correctly completed."
    else
        test_print_trc "Runtime updates loads all MCU components."
    fi

    if [[ "$mcu_scope_value" == "2" ]]; then
        test_print_trc "Core scpoed."
    elif [[ "$mcu_scope_value" == "80" ]]; then
        test_print_trc "Package scpoed."
    elif [[ "$mcu_scope_value" == "c0" ]]; then
        test_print_trc "Platform scpoed."
    else
        die "Invalid scope definition."
    fi
}

mcu_check_uniform(){
    if check_dmesg_keyword "Microcode Uniform Update Capability detected" ; then
       test_print_trc "Microcode Uniform Update Capability detected"
    else
       die "Keyword \"Microcode Uniform Update Capability detected\" not found in dmesg!"
    fi
}

mcu_check_staging(){
    if check_dmesg_keyword "Microcode Staging Capability detected" ; then
       test_print_trc "Microcode Staging Capability detected"
    else
       die "Keyword \"Microcode Staging Capability detected\" not found in dmesg!"
    fi
}

mcu_check_rollback(){
    if check_dmesg_keyword "Microcode Rollback Capability detected" ; then
       test_print_trc "Microcode Rollback Capability detected"
    else
       die "Keyword \"Microcode Rollback Capability detected\" not found in dmesg!"
    fi
}

#########

if [[ ${1} == "" ]]; then
    die "Please enter at least one test case name."
else
    case "${1}" in
        "mcu_check_msr1")
        mcu_check_msr1
        ;;
	"mcu_check_msr2")
        mcu_check_msr2
        ;;
        "mcu_check_uniform")
        mcu_check_uniform
        ;;
        "mcu_check_staging")
        mcu_check_staging
        ;;
        "mcu_check_rollback")
        mcu_check_rollback
        ;;

        *)
        die "The test case name does not exist."
        ;;
    esac
fi

