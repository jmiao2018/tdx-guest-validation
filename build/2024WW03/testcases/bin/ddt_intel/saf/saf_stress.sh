#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019 Intel - http://www.intel.com/
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
# Contributors:
#
#     2021/05/11 -Initial draft.
###############################################################################
# @desc do test Scan at fields
#   files: under /sys/devices/system/cpu(or cpus)
#   saf CLI application(scan_field_app)
#   stress tool: stressapptest
#
# @returns None.
# @history
#    2021-10-21: First version -draft!!!!

#source "saf_basic.sh"
source "ifs_basic.sh"

TEST_NAME="STRESS"
#CUR_DIR="$( cd "$( dirname "$0"  )" && pwd  )"
############################# Functions #######################################
echo "#############-------ATTENTION--------############"
saf_show_title "STARTING SAF TEST: $TEST_NAME... "
echo "#####################-------#####################"
# get function type(intel_ifs_x)
ifs_set_mode $*
# check the SAF driver
saf_probe_check
# check interval more than  30 minutes
# tips: default interval time is 30 minutes,
#				for debug, pass a interval time to saf_time_tick
if [ ! "${IFS_INST}" == "1" ]; then
	#array bits need not wait
	saf_time_tick
else
	sleep 1
fi

#before trigger scan, need to check the latest scan was finished before 1 minute
#so force wait 1 minute
#gen log/dmesg prefix
log_file=/tmp/${0##*/}_IFS${IFS_MODE}_${TEST_NAME}_$(date +%y%m%d-%N)

########################################################
#start stressapptest to gen payload 10 minutes
test_print_trc "Run stressapptest!"
${CUR_DIR}/stressapptest -s 600 &

sleep 5
ifs_interrupt_trace_init
#run basic test
basic_test_handler $* 2>&1 | tee ${log_file}.log
# save the time for next checking interval
saf_save_scan_time

# get basic_test_handler return value
key="basic_test_handler RESULT"
cmd_ret=$(grep "${key}" ${log_file}.log | awk '{print $3}')

# save event trace to log
ifs_catch_event_trace_info ${log_file}.trc

echo "$(extract_case_dmesg)" >>${log_file}.dmesg

echo "*************************************************"
ls ${log_file}.* -l

saf_check_scan_dmesg ${log_file}.dmesg || cmd_ret=-1
saf_check_scan_log ${log_file}.log || cmd_ret=-2

echo "**********************---------------------***************************"
saf_show_title "SAF Test Over: $TEST_NAME !!RETURN: $cmd_ret"
echo "**********************---------------------***************************"
echo ""

if [ ! $cmd_ret -eq 0 ]; then
  cmd_ret=1
fi

exit $cmd_ret
