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
		./${0##*/} [-h]
		-h print this help
_EOF
}
#test cases list of display func test
GFX_DISPLAY_CASES="testdisplay"
WAKE_UNLOCK_PATH="/sys/power/wake_unlock"
BIN_PATH="/data/ltp/testcases/bin/ddt_intel/gfx/bin"
# Please use getopts
while getopts h arg
do
	case $arg in
		h)
		usage
		exit 1
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

test_print_start "GFX display tests: $GFX_DISPLAY_CASES is starting"
screen_stat=$(cat $WAKE_UNLOCK_PATH | tr ' ' '\n' | grep "PowerManagerService.Display")
if [ -n $screen_stat ];then
	test_print_trc "Open Device's Screen Now..."
	input keyevent 26
	if [ $? -ne 0 ];then
		test_print_trc "Open device's screen failed"
		exit 1
	fi
fi
test_print_trc "Open device's screen succeeded"
sleep 3
${BIN_PATH}/${GFX_DISPLAY_CASES} -a
if [ $? -ne 0 ];then
	test_print_end "GFX display tests: $GFX_DISPLAY_CASES is FAILED"
	exit 1
fi
test_print_end "GFX display tests: $GFX_DISPLAY_CASES is SUCCEEDED"
exit 0
