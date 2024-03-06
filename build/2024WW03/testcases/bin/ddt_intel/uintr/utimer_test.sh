#! /bin/bash
#
# Copyright (C) 2015-2019 Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# @desc Script to run uintr test

source "common.sh"
############################# Functions #######################################
test_cases=(
    "UINTR_XS_FUNC_UTIMER_TEST(syscall_utimer)"
    "UINTR_XS_FUNC_SELF_IPI_TEST(senduipi_self_ipi)"
    "UINTR_XS_FUNC_SHARE_IPI_FD_TEST(syscall_ipi_fd)"
    "UINTR_XS_FUNC_SENDUIPI_TEST(senduipi_instr)"
    "UINTR_XS_FUNC_REGISTER_RECEIVER_TEST(syscall_handler)"
    "UINTR_XS_FUNC_REGISTER_SENDER_TEST(syscall_sender)"
    "UINTR_XS_FUNC_IPC_BASE_TEST(ipc_base)"
    "UINTR_XS_FUNC_BLOCKING_TEST(syscall_blocking)"
    "UINTR_XS_FUNC_ALT_STACK_TEST(syscall_alt_stack)"
    "UINTR_XS_FUNC_SYSCALL_INVALID_FLAG_TEST(syscall_flags)"
    "UINTR_XS_FUNC_INVALID_VECTOR_TEST(syscall_vector)"
    "UINTR_XS_STRESS_CONTEXT_SWITCH_TEST(uintr_context_switch_ipc)"
)

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"

# Display usage information
usage() {
    echo "Usage: $0 <test_id | -a | -h>"
    echo "Options:"
    echo "  <test_id> - Execute a specific test case by ID"
    echo "  -a        - Execute all test cases"
    echo "  -h        - Display this usage information"
    echo "Test ID and Test Cases:"
    for ((id=0; id<${#test_cases[@]}; id++)); do
        name=$(echo "${test_cases[$id]}" | awk -F '[()]' '{print $1}')
        echo "  ID: $id - Test Name: $name"
    done
    exit 1
}

# Check if a parameter is provided
if [ $# -ne 1 ]; then
    usage
fi

# Extract the first parameter
arg=$1

# If the parameter is "-h," display usage information
if [ "$arg" == "-h" ]; then
    usage
fi


uintr_context_switch_ipc() {
    test_print_trc "Running Test ID: 11"
    test_print_trc "Test Name: UINTR_XS_FUNC_CONTEXT_SWITCH_TEST"
    param_list=(
        "'-p 2 -c 2 -i 100'"
        "'-p 8 -c 2 -i 100'"
        "'-p 8 -c 4 -i 1000'"
        "'-p 256 -c 128 -i 1000'"
	)
    for param in "${param_list[@]}"; do
        test_print_trc "Executing: context_switch_ipc $param"
    	${BIN_DIR}/context_switch_ipc $param
        if [ $? -eq 0 ]; then
            test_print_trc "Test Pass with param = $param"
	else
	    die "Test Failed with param = $param"
        fi
    done  
}


# If the parameter is "-a," execute all test cases
if [ "$arg" == "-a" ]; then
    for ((id=0; id<${#test_cases[@]} - 1; id++)); do
        bin_name=$(echo "${test_cases[$id]}" | awk -F '[()]' '{print $2}')
        test_name=$(echo "${test_cases[$id]}" | awk -F '[()]' '{print $1}')

        test_print_trc "Running Test ID: $id"
        test_print_trc "Test Case: $test_name"
        test_print_trc "Executing Binary: $bin_name"

	${BIN_DIR}/$bin_name
        if [ $? -eq 0 ]; then
            test_print_trc "Test Pass"
        else
            die "Test Failed"
        fi
    done
    # case 13
    uintr_context_switch_ipc
    exit 0
fi

# If a valid test ID is provided, execute a specific test case
if [ "$arg" == "11" ]; then
    uintr_context_switch_ipc
elif [ "$arg" -ge 11 ]; then
    test_print_err "Error: Invalid Test ID or option"
else
    id=$arg
    bin_name=$(echo "${test_cases[$id]}" | awk -F '[()]' '{print $2}')
    test_name=$(echo "${test_cases[$id]}" | awk -F '[()]' '{print $1}')

    test_print_trc "Running Test ID: $id"
    test_print_trc "Test Name: $test_name"
    test_print_trc "Executing Binary: $bin_name"

    ${BIN_DIR}/$bin_name
    if [ $? -eq 0 ]; then
        test_print_trc "Test Pass"
    else
        die "Test Failed"
    fi
fi


