#!/bin/bash
###############################################################################
#
# Copyright (C) 2015 Intel - http://www.intel.com
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
# @Author   Ning Han (ningx.han@intel.com)
# @desc     suspend timing test: freeze,s3
# @returns  0 if the execution was finished successfully, else 1
# @history  2016-11-08: First Version (Ning Han)

source "powermgr_common.sh"

REQUIRED_KCONFIGS="CONFIG_PM_DEBUG,CONFIG_PM_SLEEP_DEBUG,CONFIG_FTRACE,CONFIG_FUNCTION_TRACER,CONFIG_FUNCTION_GRAPH_TRACER,CONFIG_KPROBES,CONFIG_KPROBES_ON_FTRACE"
SUPPORTED_STATES="freeze,mem"
SUSPEND_TIMING_PATTERN="Kernel Suspend Time:"
RESUME_TIMING_PATTERN="Kernel Resume Time:"
# Automatic wakeup after 15s
RTC_TIME="15"
# This variable is reference time which to be compared with the
# suspend time get via suspendresume.py, the comparison result
# determine whether test will pass.
# Set default reference time to 2000 ms. It's value can be modified
# by initializing it in corresponding params file.
: ${SUSPEND_REF_TIME:="2000"}
: ${RESUME_REF_TIME:="2000"}

fcomp()
{
    local ret=""
    ret=$(awk -v f1="$1" -v f2="$2" 'BEGIN{ if (f1 > f2) exit 0; exit 1}')
    return $ret
}

check_env()
{
    # Check kernel configurations
    IFS_OLD="$IFS"
    IFS=","
    for kconfig in $REQUIRED_KCONFIGS
    do
        k_opt=$(get_kconfig "$kconfig")
        [[ "$k_opt" != "y" ]] && block_test "option of $kconfig is: $k_opt, should be y!"
    done
    IFS="$IFS_OLD"
    IFS_OLD=""

    # Check runtime environment: rtcwake, python2
    which rtcwake &> /dev/null || block_test "rtcwake not installed in current environment!"
    which python2 &> /dev/null || block_test "python2 not installed in current environment"

    # Check whether analyze_suspend.py is available
    which analyze_suspend.py &> /dev/null
    [ $? -eq 0 ] || die "analyze_suspend.py is not available!"
}

make_preparations_for_test()
{
    # Create temp directory for timing test
    TEMP_DIR=$(mktemp -d)
    [ -e "$TEMP_DIR" ] || do_cmd "fail to create temporary for timing test!"
    test_print_trc "temporary directory: $TEMP_DIR created"

    # Check whether the state is supported
    echo "$SUPPORTED_STATES" | grep -q "$STATE" || block_test "$STATE is not suppoerted! Only support: $SUPPORTED_STATES"
}

run_test()
{
    # Begin test
    #suspend-stress.sh comes from wget http://power-sh.sh.intel.com/power/scripts/suspend-stress.sh
    sh suspend-stress.sh -m "$STATE" -w "$RTC_TIME" -i 10 -o "$TEMP_DIR" -h -e

    logs_dir="${LOG_PATH}/${STATE}_timing_log"
    if [[ "$logs_dir" != "/" ]]; then
      rm -rf "$logs_dir"
      cp -r "$TEMP_DIR" "$logs_dir"
    else
      die "Invalid logs directory"
    fi

    subruns=$(ls "$logs_dir" | grep -v "summary")

    for subrun in $subruns; do
      subrun_dir="$logs_dir/$subrun"
      html_file="$subrun_dir/$(ls $subrun_dir | grep .html)"
      SUSPEND_TIME=$(grep -a "$SUSPEND_TIMING_PATTERN" "$html_file" \
                     | awk -F'ms' '{print $1}' \
                     | awk -F'<b>' '{print $2}')
      [ -n "$SUSPEND_TIME" ] || block_test "fail to get suspend time!"
      test_print_trc "suspend time: $SUSPEND_TIME"
      RESUME_TIME=$(grep -a "$RESUME_TIMING_PATTERN" "$html_file" \
                    | awk -F'Kernel Resume Time:' '{print $2}' \
                    | awk -F'ms' '{print $1}' \
                    | awk -F'<b>' '{print $2}')
      [ -n "$RESUME_TIME" ] || block_test "fail to get resume time!"
      test_print_trc "resume time: $RESUME_TIME"

      for st in $SUSPEND_TIME; do
          if [[ "$st" == "0.000" ]]; then
              die "Suspend time can't be 0, test failed."
          fi
          fcomp "$st" "$SUSPEND_REF_TIME"
          if [[ "$?" -eq 0 ]]; then
              test_print_trc "Test fail, Suspend time: $st, great than Ref time: $SUSPEND_REF_TIME, html file is $html_file"
              do_cmd "rm -rf $TEMP_DIR"
              die "Test failed."
          else
              test_print_trc "Test pass, Suspend time: $st, less than Ref time: $SUSPEND_REF_TIME, html file is $html_file"
              do_cmd "rm -rf $TEMP_DIR"
          fi
      done

      for rt in $RESUME_TIME; do
          if [[ "$rt" == "0.000" ]]; then
              die "Resume time can't be 0, test failed."
          fi
          fcomp "$rt" "$RESUME_REF_TIME"
          if [[ "$?" -eq 0 ]]; then
              test_print_trc "Test fail, Resume time: $rt, great than Ref time: $RESUME_REF_TIME, html file is $html_file"
              do_cmd "rm -rf $TEMP_DIR"
              die "Test failed."
          else
              test_print_trc "Test pass, Resume time: $rt, less than Ref time: $RESUME_REF_TIME, html file is $html_file"
              do_cmd "rm -rf $TEMP_DIR"
          fi
      done
    done
}

#-s: which state to be suspend: freeze, mem
#-h: help message
while getopts :s:h arg
do
	case $arg in
		s)
			STATE="$OPTARG"
		;;
		h)
			die "Usage: ${0##*/} -s <STATE> -m <MODE> -p <PAUSE> -t <TIME> -h
				-s STATE: state to be suspend: freeze,mem
				-h: show this Usage
			"
		;;
		\?)
			die "You must supply argument: ${0##*/} -h"
		;;
		*)
			die "Invalid options: ${0##*/} -h"
		;;
	esac
done

# Check testing environment: kconfig, rtcwake, python
check_env
# Create temporary directory and check options of test
make_preparations_for_test
# Run tests
run_test
