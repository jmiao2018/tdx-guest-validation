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
# @desc do test Scan at fields
#   files: under /sys/devices/system/cpu(or cpus)
#   saf CLI application(scan_field_app)
#   stress tool: stressapptest
#
# @returns None.
# @history
#    2021-05-11: First version -draft!!!!
#    2021-05-14: add usage and reload test!
#    2022-03-14: add intel_ifs interrupt test code
###############################################################################

source "ifs_basic.sh" # Import do_cmd(), die() and other functions

TEST_NAME="Interrupt"
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
# for debug, pass a interval time to saf_time_tick
if [ ! "${IFS_INST}" == "1" ]; then
	saf_time_tick
else
	sleep 1
fi

#gen log/dmesg prefix
log_file=/tmp/${0##*/}_IFS${IFS_MODE}_${TEST_NAME}_$(date +%y%m%d-%N)

########################################################
#start alarm 10minutes with 10 msec internal
${CUR_DIR}/alarm -m 10 -i 1 &
${CUR_DIR}/alarm -m 10 -i 1 &

ifs_interrupt_trace_init

#run basic test
echo "basic_test_handler $* 2>&1 | tee ${log_file}.log"
basic_test_handler $* 2>&1 | tee ${log_file}.log
# save the time for next checking interval
saf_save_scan_time

# get basic_test_handler return value
key="basic_test_handler RESULT"
cmd_ret=$(grep "${key}" ${log_file}.log | awk '{print $3}')

#get dmesge information
echo "$(extract_case_dmesg)" >>"${log_file}".dmesg

# save event trace to log
ifs_catch_event_trace_info ${log_file}.trc

########################################################
## show log files
echo "*************************************************"
ls ${log_file}.* -l
echo "*************************************************"
saf_show_title "SAF Test Over: $TEST_NAME !!!!! "
echo "*************************************************"

if [ "$cmd_ret" == "" ]; then
  test_print_err "[$TEST_NAME] Failed to run test! exit!!!"
  exit 1
fi
# check the kernel crash message
ret=$(grep -c -e "Call Trace" "${log_file}".dmesg)
if [ $ret -gt 0 ]; then
  test_print_trc "Get kernel error message!!! exit!!!"
  cmd_ret=1
fi

# just check if the keywords shown in log or dmesg, keywords are expected
if [ $cmd_ret -eq 0 ]; then
  ##############Check error!###################
  err="nterrupt occurred prior"
  ret=$(grep "${err}" ${log_file}.log)
  cmd_ret=1
  if [ "$ret" != "" ]; then
    test_print_trc "Get keywords from log: $ret!!!"
    cmd_ret=0
  fi
  ret=$(grep "${err}" ${log_file}.dmesg)
  if [ "$ret" != "" ]; then
    test_print_trc "Get keywords from dmesg: $ret!!!"
    cmd_ret=0
  fi

  # check the value of scan status for interrupt
  ret=$(grep -c -e "status: 90000" -e "status: 20000" "${log_file}.trc")
  if [ ${ret} -gt 0 ]; then
    test_print_trc "Get ${ret} interrupt information from event trace!"
    cmd_ret=0
  fi

  if [ ${cmd_ret} -gt 0 ]; then
    test_print_err "Failed to find interrupt information!"
  fi
fi

echo "**********************---------------------***************************"
saf_show_title "SAF Test Over: $TEST_NAME !!RETURN: $cmd_ret"
echo "**********************---------------------***************************"
echo ""

exit $cmd_ret
