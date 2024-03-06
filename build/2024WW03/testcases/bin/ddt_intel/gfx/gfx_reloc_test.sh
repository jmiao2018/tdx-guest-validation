#!/bin/bash
###############################################################################
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

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage()
{
	cat<<_EOF
	Usage:
		./${0##*/} [-b TEST_CASE] [-s SUB_TEST] [-h]
		-b TEST_CASE Executable test case binary file name
		-s SUB_TEST sub case of the test case
		-h print this help
_EOF
}
#test cases list of reloc func test
GFX_RELOC_CASES="gem_cpu_reloc gem_gtt_cpu_tlb gem_gtt_speed gem_largeobject \
gem_mmap_offset_exhaustion gem_persistent_relocs gem_reloc_overflow gem_reloc_vs_gpu \
gem_bad_reloc gem_mmap gem_mmap_gtt"

TEST_CASE=""
SUB_TEST=""

# Please use getopts
while getopts :b:s:h arg
do
	case $arg in
		b)
		TEST_CASE="$OPTARG"
		;;
		s)
		SUB_TEST="$OPTARG"
		;;
		h)
		usage
		exit 1
		;;
		:)
		die "$0: Must supply an argument to -$OPTARG."
		;;
		\?)
		die "Invalid Option -$OPTARG "
		;;
	esac
done

case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

if [ -z $TEST_CASE ];then
	test_print_trc "Must supply an argument for [-b TEST_CASE]"
	GFX_RELOC_CASES=$(echo $GFX_RELOC_CASES | tr ' ' '\n')
	test_print_trc "The supported tests are:$GFX_RELOC_CASES"
	exit 1
fi

#check if $TEST_CASE is supported in test cases list
bin_name=$(echo $GFX_RELOC_CASES | tr ' ' '\n' | awk '{if(match($0,/^'$TEST_CASE'$/)) print substr($0,RSTART,RLENGTH)}')
if [ -z $bin_name ];then
	test_print_trc "Test case: $TEST_CASE is not supported, please check you argument"
	GFX_RELOC_CASES=$(echo $GFX_RELOC_CASES | tr ' ' '\n')
	test_print_trc "The supported tests are:$GFX_RELOC_CASES"
	exit 1
fi

test_print_start "GFX reloc tests: $TEST_CASE is starting"
if [ -z $SUB_TEST ];then
	gfx_test.sh -t reloc -b $TEST_CASE
else
	gfx_test.sh -t reloc -b $TEST_CASE -s $SUB_TEST
fi