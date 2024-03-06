#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019 Intel - http://www.intel.com/
#
# GNU General Public License for more details.
###############################################################################
# Contributors:
#   Weihong Zhang <weihong.zhang@intel.com> (Intel)
#     -Initial draft.
###############################################################################

source "common.sh" # Import do_cmd(), die() and other functions

############################# Global variables ################################
BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_APP="${BIN_DIR}/lam-64"

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
		usage: ./${0##*/}  [-t TESTCASE ID] [-f LAM_FEATURE]
		Test LAM feature using  malloc, mmap, syscall and uring;
		-t TESTCASE ID
			0: all
			1:malloc
			2:max_bits
			3:mmap
			4:syscall
			5:io_uring
			6:inherit
			7:pasid
			8:cpuid
		-h Help   print this usage
	EOF
	exit 0
}

# check if the cpu support lam feature
check_lam() {
	local lam=$(grep " lam " /proc/cpuinfo | wc -l)
	if [ $lam -eq 0 ]; then
		test_print_err "System is not support LAM feature!"
		exit 1
	fi
}

# check the log to check if the test is pass
lam_check_log() {
	local cnt=$(grep "FAILED" ${log_file} | wc -l)
	if [ $cnt -gt 0 ]; then
		test_print_err "Get failure information!"
		return $cnt
	fi
	return 0
}

#0x1:malloc
#0x2:max_bits
#0x4:mmap
#0x8:syscall
#0x10:io_uring
#0x20:inherit
#0x40:pasid
#0x80:cpuid
lam_handle() {
	local caseid=$1
	local ret=0
	local para=""
	case $caseid in
	0)
		test_name="all"
		;;
	1) #malloc
		test_name="MALLOC"
		para="-t 0x1"
		;;
	2)
		test_name="MAX BITS"
		para="-t 0x2"
		;;
	3)
		test_name="MMAP"
		para="-t 0x4"
		;;
	4)
		test_name="SYSCALL"
		para="-t 0x8"
		;;
	5)
		test_name="IO_URING"
		para="-t 0x10"
		;;
	6)
		test_name="INHERIT"
		para="-t 0x20"
		;;
	7)
		test_name="PASID"
		para="-t 0x40"
		;;
	8)
		test_name="CPUID"
		para="-t 0x80"
		;;
	*)
		test_print_err "Wrong paramater, please check!"
		usage
		;;
	esac

	log_file=/tmp/LAM_${test_name}_$(date +%y%m%d-%N)
	test_print_trc "############## Start ${test_name} tests #############"

	$BIN_APP ${para}

	local err=$?
	if [ $err -gt 0 ]; then
		ret=1
		test_print_err "Get $err failure!"
	fi

	test_print_trc "############## END ${test_name} tests ##############"
	return $ret
}

########################### REUSABLE TEST LOGIC ###############################
#check_lam

while getopts t:h arg; do
	case $arg in
	t)
		CASE_ID="$OPTARG"
		;;
	h)
		usage
		;;
	\?)
		test_print_err "Invalid Option -$OPTARG ignored."
		usage
		exit 1
		;;
	esac
done

echo "###########$CASE_ID###################"

lam_handle "$CASE_ID"
ret=$?

if [ $ret -gt 0 ]; then
	ret=1
fi

exit $ret
