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
#      files: under /sys/devices/system/cpu(or cpus)
#
# @returns None.
# @history
#    2021-05-11: First version -draft!!!!
#    2021-05-14: add inject test!
#    2022-06-16: the test is unavailable yet in new driver intel_ifs!

source "ifs_func.sh" # Import do_cmd(), die() and other functions

############################# Functions #######################################
echo "##########################################"
saf_show_title "STARTING SAF TEST: Inject... "
echo "##########################################"

# check the SAF driver
saf_probe_check
# check interval more than  30 minutes
# tips: default interval time is 30 minutes,
# for debug, pass a interval time to saf_time_tick
saf_time_tick
#gen log/dmesg prefix
log_file=/tmp/${0##*/}_IFS${IFS_MODE}_${TEST_NAME}_$(date +%y%m%d-%N)

#run basic test with INJECT and without offline/ wait
basic_test_handler $* -w 0 -o -1 -I 2>&1 | tee ${log_file}.log

# get basic_test_handler return value
key="basic_test_handler RESULT"
cmd_ret=$(grep "${key}" ${log_file}.log | awk '{print $3}')

#get dmesge information
echo $(extract_case_dmesg) >>${log_file}.dmesg

#log_para=(${para_string// /\#})
#echo $log_para

########################################################
## show log files
echo "*************************************************"
ls ${log_file}.* -l
echo "*************************************************"
saf_show_title "SAF Test Over:Inject !!!!! "
echo "*************************************************"

##############Check error!###################
err="Failure code ="
ret=$(grep "${err}" ${log_file}.log) && {
  test_print_err "Error: $ret!!!"
  test_print_err "Inject: failure is expected!!!"
  cmd_ret=0
}

exit $cmd_ret
