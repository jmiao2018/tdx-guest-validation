#!/bin/bash
###############################################################################
# Copyright (C) 2018 Intel - http://www.intel.com/
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
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Initial draft.
#
#   Juan Pablo Gomez <juan.p.gomez@intel.com> (Intel)
#     -Script was modified to obtain the all values for all the fields from rtc file
#
###############################################################################
# @desc Check RTC driver info under /proc/driver/rtc .
# @params
# @return
# @history 2015-04-21: First version.

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
    usage: ./${0##*/} [-c FIELD_TO_CHECK]
    -c rtc_time                check rtc_time field.
       rtc_date                check rtc_date field.
       alrm_time               check alrm_time field.
       alrm_date               check alrm_date field.
       alarm_IRQ               check alarm_IRQ field.
       alrm_pending            check alrm_pending field.
       update_IRQ_enable       check update_IRQ_enable field.
       periodic_IRQ_enable     check periodic_IRQ_enable field.
       periodic_IRQ_frequency  check periodic_IRQ_frequency field.
       max_user_IRQ_frequency  check max_user_IRQ_frequency field.
       24h                     check hour format field.
       periodic_IRQ            check periodic_IRQ field.
       update_IRQ              check update_IRQ field.
       HPET_emulated           check HPET_emulated field.
       BCD                     check BCD field.
       DST_enable              check DST_enable field.
       periodic_freq           check periodic_freq field.
       batt_status             check batt_status field.
    -h Help                    print this usage.
EOF
  exit 1
}

# Get the value of a certain field within RTC driver file.
# Input: FIELD the field to get the value for.
#        FILE  driver file absolut path.
# Return: FIELD_VAL the value for the specified field.
get_field_value ()
{
  if [ $# -ne 2 ]; then
    return 1;
  fi
  local FIELD="$1"
  local FILE="$2"
  local SEARCH_STR=""
  local FIELD_VAL=""
  case "$FIELD" in
    rtc_time)               SEARCH_STR="rtc_time";;
    rtc_date)               SEARCH_STR="rtc_date";;
    alrm_time)              SEARCH_STR="alrm_time";;
    alrm_date)              SEARCH_STR="alrm_date";;
    alarm_IRQ)              SEARCH_STR="alarm_IRQ";;
    alrm_pending)           SEARCH_STR="alrm_pending";;
    update_IRQ_enable)      SEARCH_STR="update IRQ enabled";;
    periodic_IRQ_enable)    SEARCH_STR="periodic IRQ enabled";;
    periodic_IRQ_frequency) SEARCH_STR="periodic IRQ frequency";;
    max_user_IRQ_frequency) SEARCH_STR="max user IRQ frequency";;
    24h)                    SEARCH_STR="24hr";;
    periodic_IRQ)           SEARCH_STR="periodic_IRQ";;
    update_IRQ)             SEARCH_STR="update_IRQ";;
    HPET_emulated)          SEARCH_STR="HPET_emulated";;
    BCD)                    SEARCH_STR="BCD";;
    DST_enable)             SEARCH_STR="DST_enable";;
    periodic_freq)          SEARCH_STR="periodic_freq";;
    batt_status)            SEARCH_STR="batt_status";;
    *)                      die "Invalid Option $OPTION ";;
  esac
  FIELD_VAL=`grep ${SEARCH_STR} ${FILE} | cut -d' ' -f2`
  echo "$FIELD_VAL"
}

############################ Script Variables ##################################
# Define default values if possible
OPTIONS_STR=""
PROC_DIR="/proc"
DRIVER_FILENAME="rtc"
OFS=$IFS
IFS='|'

################################ CLI Params ####################################
# Please use getopts
while getopts  :c:h arg
do
  case $arg in
    c)
      case "$OPTARG" in
        rtc_time)               OPTIONS_STR+="${OPTARG}|";;
        rtc_date)               OPTIONS_STR+="${OPTARG}|";;
        alrm_time)              OPTIONS_STR+="${OPTARG}|";;
        alrm_date)              OPTIONS_STR+="${OPTARG}|";;
        alarm_IRQ)              OPTIONS_STR+="${OPTARG}|";;
        alrm_pending)           OPTIONS_STR+="${OPTARG}|";;
        update_IRQ_enable)      OPTIONS_STR+="${OPTARG}|";;
        periodic_IRQ_enable)    OPTIONS_STR+="${OPTARG}|";;
        periodic_IRQ_frequency) OPTIONS_STR+="${OPTARG}|";;
        max_user_IRQ_frequency) OPTIONS_STR+="${OPTARG}|";;
        24h)                    OPTIONS_STR+="${OPTARG}|";;
        periodic_IRQ)           OPTIONS_STR+="${OPTARG}|";;
        update_IRQ)             OPTIONS_STR+="${OPTARG}|";;
        HPET_emulated)          OPTIONS_STR+="${OPTARG}|";;
        BCD)                    OPTIONS_STR+="${OPTARG}|";;
        DST_enable)             OPTIONS_STR+="${OPTARG}|";;
        periodic_freq)          OPTIONS_STR+="${OPTARG}|";;
        batt_status)            OPTIONS_STR+="${OPTARG}|";;
        *)                 die "Invalid Option -$OPTARG ";;
      esac
    ;;
    h)  usage;;
    :)  die "$0: Must supply an argument to -$OPTARG.";;
   \?)  die "Invalid Option -$OPTARG ";;
  esac
done

########################### DYNAMICALLY-DEFINED Params #########################
# Obtain RTC driver file
RTC_DRIVER_FILE=`find $PROC_DIR -type f -name $DRIVER_FILENAME 2>/dev/null | \
                 head -1`
OPTIONS_NUM=`echo ${OPTIONS_STR} | wc -w`

########################### REUSABLE TEST LOGIC ###############################
# Check mandatory vars
if [ -z "${OPTIONS_STR}" ]; then
  die "Error: No check arguments were provided !"
fi
if [ -z "$RTC_DRIVER_FILE" ]; then
  block_test "Error: There's no driver file named $DRIVER_FILENAME in ${PROC_DIR}..."
fi

# Check fields in driver file
test_print_trc "Checking $OPTIONS_NUM fields from $RTC_DRIVER_FILE driver file"
for OPT in $OPTIONS_STR
do
  FIELD_VAL=`get_field_value $OPT $RTC_DRIVER_FILE`
  if [ -z "$FIELD_VAL" ]; then
    test_print_err "[FAIL] Field Present : ${OPT}"
    die "Error: There's no value for $OPT field !"
  fi
  test_print_trc "[OK]Field Present : ${OPT}: $FIELD_VAL"
done
IFS=$OFS
exit 0
