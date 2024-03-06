#!/bin/bash
#
# Copyright (C) 2015 Intel - http://www.intel.com/
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

source "common.sh"

BIN_PATH="$PWD/ddt_intel/gfx/bin"

GFX_API_CASES_M="gem_madvise"

GFX_BASIC_CASES_M="gem_basic gem_close_race gem_flink gem_flink_race"

GFX_CTX_CASES_M="gem_ctx_exec gem_ctx_bad_exec"

GFX_RW_CASES_M="gem_pread gem_pwrite gem_pwrite_pread gem_readwrite"

GFX_RELOC_CASES_M="gem_bad_reloc gem_mmap gem_mmap_gtt gem_persistent_relocs gem_reloc_vs_gpu"

GFX_EXEC_CASES_M="gem_exec_bad_domains gem_exec_faulting_reloc gem_exec_nop \
gem_cs_tlb"

CFX_CON_CASES_M="gem_caching"

GFX_BUFMGR_CASES_M=""

GFX_TILE_CASES_M="gem_set_tiling_vs_blt gem_tiled_blits gem_tiled_partial_pwrite_pread"

GFX_RING_CASES_M="gem_dummy_reloc_loop gem_ringfill gem_write_read_ring_switch"

GFX_PERF_CASES_M=""

GFX_KMS_CASES_M="kms_addfb kms_pipe_crc_basic kms_setmode"

GFX_MISC_CASES_M="prime_self_import"

GFX_DISPLAY_CASES_M=""

test_type_list="basic api ctx bufmgr rw reloc exec con tile ring kms misc perf display"

TEST_TYPE=""
TEST_CASE=""
SUB_TEST=""

function usage()
{
	cat<<_EOF
	Usage:${0##*/} [-t TEST_TYPE] [-b TEST_CASE] [-s SUBTEST]
	-t TEST_TYPE: The supported test types are:
	${test_type_list}
	-b TEST_CASE: Binary file name to be excuted
	-s SUBTEST: Every test has different subtests.
	-h Help: Print this usage
_EOF
}

#Function: is_multi_case -- seperate cases with subcases
#Input:$1:test type. $2:binary name
#Output:1:if it has subcases
#		0:has no subcases
#		2:Params error
function is_multi_case()
{
	[ $# -ne 2 ] && return 2
	test_type=$1
	bin_name=$2
	test_print_trc "Confirm if $bin_name of $test_type is mult cases"
	test_type=$(echo $test_type_list | tr ' ' '\n' | awk '{if(match($0,/^'$test_type'$/)) print substr($0,RSTART,RLENGTH)}')
	if [ -z $test_type ];then
		test_print_trc "Invalid test type, please check you argument"
		return 2
	fi
	test_type=$(echo $test_type | tr '[:lower:]' '[:upper:]')
	test_type="GFX_"${test_type}"_CASES_M"
	if [ ! -f $BIN_PATH/$bin_name ];then
		test_print_trc "$2 dose not exist, please check you argument"
		return 2
	fi
	bin_name=$(echo ${!test_type} | tr ' ' '\n' | awk '{if(match($0,/^'$bin_name'$/)) print substr($0,RSTART,RLENGTH)}')
	if [ -z $bin_name ];then
		test_print_trc "$2 is not multi case"
		return 0
	else
		test_print_trc "$2 is multi case"
		return 1
	fi
}

#Function: parse_ret -- parse the return value to match with ltp-ddt
#Input: return value
#Output:0/1/2
function parse_ret()
{
	[ $# -ne 1 ] && return 1
	ret=$1
	case $ret in
		0)
		test_print_end "GFX $TEST_TYPE test $TEST_CASE is SUCCEEDED!"
		return 0
		;;
		77)
		test_print_end "GFX $TEST_TYPE test $TEST_CASE is SKIPPED!"
		return 2
		;;
		*)
		test_print_end "GFX $TEST_TYPE test $TEST_CASE is FAILED!"
		return 1
		;;
	esac
}

#Function: run_test -- run test
#Input: [-t TEST_TYPE] [-b TEST_CASE][-s SUB_TEST]
#Output:0:succeed
#       1:failed
#       2:skipped

#function run_test()
while getopts :t:b:s:h arg
do
	case $arg in
		t)
		TEST_TYPE="$OPTARG"
		;;
		s)
		SUB_TEST="$OPTARG"
		;;
		b)
		TEST_CASE="$OPTARG"
		;;
		h)
		usage
		exit 1
		;;
		:)
		test_print_trc "$0: Must supply an argument to -$OPTARG." >&2
		exit 1
		;;
		\?)
		test_print_trc "Invalid Option -$OPTARG ignored." >&2
		usage
		exit 1
		;;
	esac
done
#must have a test type and a binary file name
if [ -z $TEST_CASE ] || [ -z $TEST_TYPE ];then
	test_print_trc "Must supply argument [-t TEST_TYPE] and [-b TEST_CASE]"
	exit 1
fi
#test type must be in test_type_list
TEST_TYPE=$(echo $test_type_list | tr ' ' '\n' | awk '{if(match($0,/^'$TEST_TYPE'$/)) print substr($0,RSTART,RLENGTH)}')
if [ -z $TEST_TYPE ];then
	test_print_trc "Invalid test type, please check you argument"
	exit 1
fi
#Confirm if TEST_CASE are legal
if [ ! -f $BIN_PATH/$TEST_CASE ];then
	test_print_trc "Invalid test case, please check you argument"
	exit 1
fi
#if subtest is not empty,check if it's legal
if [ -n $SUB_TEST  ];then
	#check TEST_CASE is multi case
	is_multi_case $TEST_TYPE $TEST_CASE
	if [ $? -eq 2 ];then
		test_print_trc "Check is_multi_case failed"
		exit 1
	elif [ $? -eq 0 ];then #if it is not multi case, ignor SUB_TEST
		test_print_trc "$TEST_CASE is not multi case, -s $SUB_TEST will be ignored"
		test_print_trc "Start running test:---$TEST_CASE---,please wait."
		$TEST_CASE
		ret=$?
	else
		sub_list=$($TEST_CASE --list-subtests)
		tmp=$(echo $sub_list | tr ' ' '\n' | awk '{if(match($0,/^'$SUB_TEST'$/)) print substr($0,RSTART,RLENGTH)}')
		if [ -z $tmp ];then
			test_print_trc "$TEST_CASE does not support $SUB_TEST,it will be ignored"
			test_print_trc "Start running test:---$TEST_CASE---,please wait."
			#if the SUB_TEST is not supported, then run all tests
			$TEST_CASE
			ret=$?
		else
			test_print_trc "Start running test:--- $TEST_CASE ---,subtest:--- $SUB_TEST ---,please wait."
			$TEST_CASE --run-subtest $SUB_TEST
			ret=$?
		fi
	fi
fi
test_print_trc "--- $TEST_CASE --- has been finished"
#parse the return value, to match with ltp-ddt
parse_ret $ret
exit $?

