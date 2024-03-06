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
BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_APP="${BIN_DIR}/umsr_utimer"

test_tips=()
test_para=()
log_file=""

test_name=""
############################# Functions #######################################
test_print_trc() {
        log_info=$1
        echo "|$(date +"$TIME_FMT")|TRACE|$log_info|"
}
test_print_err() {
        log_info=$1
        echo "|$(date +"$TIME_FMT")|ERROR|$log_info|"
}

usage() {
        cat <<-EOF >&2
                usage: ./${0##*/} 
		Test User_MSR (UMSR) feature using  umsr_utimer;
                -h Help   print this usage
	EOF
        exit 0
}
# check if the CPU support the umsr feature
check_umsr() {
        local umsr=$(grep " user_msr " /proc/cpuinfo | wc -l)
        if [ $umsr -eq 0 ]; then
                test_print_err "System does not support the user_msr feature!"
                exit 1
        fi
}

# check the log to see if the test passed
umsr_check_log() {
        local cnt=$(grep "FAILED" ${log_file} | wc -l)
        if [ $cnt -gt 0 ]; then
                test_print_err "Get failure information!"
                return $cnt
        fi
        return 0
}

check_umsr
log_file=/tmp/UMSR_${test_name}_$(date +%y%m%d-%N)
test_print_trc "############## Start ${test_name} tests #############"

$BIN_APP | tee $log_file

err=$?
if [ $err -gt 0 ]; then
        ret=1
        test_print_err "Get $err failure!"
fi

umsr_check_log

test_print_trc "############## END ${test_name} tests ##############"
exit $ret

