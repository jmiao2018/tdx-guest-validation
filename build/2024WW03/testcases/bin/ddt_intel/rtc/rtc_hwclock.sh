#!/bin/bash
###############################################################################
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
###############################################################################
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Initial draft.
#     -Fixed date string format for RTC time set.
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Updated 'set_date()' function to set date & time with 'hwclock' when
#       it is requested.
###############################################################################

# @desc Communicate with hardware clock (RTC) using hwclock command.
# @params [-s DATE] [-g FIELD] [-c CRITERIA] [-l LOOP] [-y CLOCK][-huo].
# @returns .
# @history 2015-04-23: First version.
# @history 2015-05-04: Fixed date string format for RTC time set.
# @history 2016-12-07: support date string format of ISO 8601.
# @history 2017-02-09: Updated 'set_date()' to change date with 'hwclock'

source "common.sh"  # Import do_cmd(), die() and other functions

export LC_ALL=C

############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
    usage: ./${0##*/} [-s DATE] [-g FIELD] [-c CRITERIA] [-l LOOP]
                      [-y CLOCK][-huo]
    -c CRITERIA compare system clock time with RTC time.
                CRITERIA may be '='  both to be equal or '!' to be different.
    -g FIELD    get the specified RTC value for FIELD which may be one of the
                following:
                  date : to get only the date field.
                  time : to get only the time field.
                  all  : to get both date and time fields.
    -l LOOP     iterations for the test. LOOP must be an integer, by default is
                 1.
    -o          use local time.
    -r DATE     set RTC date and time. DATE string must be in format
                "YYYYMMDD.hhmmss".
                  DD    : two digit day number. e.g. 01, 15, 30, etc.
                  MM    : two digit month number. e.g. 03, 10, 06, etc.
                  YYYY  : four digit year number. e.g. 1990, 2005, 2010, etc.
                  hh    : two digit hour number. e.g. 00, 12, 20, etc.
                  mm    : two digit minute number. e.g. 55, 33, 10, etc.
                  ss    : two digit second number. e.g. 43, 21, 00, etc.
    -s DATE     set System clock date and time. DATE string must be in format
                "YYYYMMDD.hhmmss".
                  DD    : two digit day number. e.g. 01, 15, 30, etc.
                  MM    : two digit month number. e.g. 03, 10, 06, etc.
                  YYYY  : four digit year number. e.g. 1990, 2005, 2010, etc.
                  hh    : two digit hour number. e.g. 00, 12, 20, etc.
                  mm    : two digit minute number. e.g. 55, 33, 10, etc.
                  ss    : two digit second number. e.g. 43, 21, 00, etc.
    -y CLOCK    sync RTC and system clock. CLOCK can take one of the following
                values:
                 rtc : To write RTC value to system clock.
                 sys : To write system clock value to RTC.
    -u          use Universal Coordinated time (UTC).
    -h Help     print this usage
EOF
  exit 1
}

# This function converts a date_time to Android format (YYYYMMDD.hhmmss).
# Input: CONVERT_STR which is a STR containing date / time or both.
#        CLK_FIELD   which is one of: date, time, all.
# Return: ANDROID_STR which is in the form YYYYMMDD.hhmmss.
convert_to_android_format()
{
  if [ "$#" -ne 2 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Get args
  local CONVERT_STR="$1"
  local CLK_FIELD="$2"
  local ANDROID_STR=""
  local MONTH_NUM=""
  local DATE=""
  local TIME=""
  local MONTH=""

  DATE=$(echo "$CONVERT_STR" | awk '{printf ("%04d %s %02d\n", $3, $2, $1)}')
  TIME=$(echo "$CONVERT_STR" | awk '{print $4}')
  MONTH=$(echo "$CONVERT_STR" | awk '{print $2}')

  # Convert month str to num
  case "$MONTH" in
    Jan)  MONTH_NUM="01";;
    Feb)  MONTH_NUM="02";;
    Mar)  MONTH_NUM="03";;
    Apr)  MONTH_NUM="04";;
    May)  MONTH_NUM="05";;
    Jun)  MONTH_NUM="06";;
    Jul)  MONTH_NUM="07";;
    Aug)  MONTH_NUM="08";;
    Sep)  MONTH_NUM="09";;
    Oct)  MONTH_NUM="10";;
    Nov)  MONTH_NUM="11";;
    Dec)  MONTH_NUM="12";;
      *)  die "Unknown month $MONTH"; return 1;;
  esac
  # Prepare return str
  case "$CLK_FIELD" in
    time) ANDROID_STR="${TIME}";;
    date) ANDROID_STR="${DATE}";;
     all) ANDROID_STR="${DATE}.${TIME}";;
       *) die "CLK_FIELD = $CLK_FIELD is not a valid option"; return 1;;
  esac
  # Replace unwanted characters (':' , ' ' ...)
  ANDROID_STR=${ANDROID_STR//$MONTH/$MONTH_NUM}
  ANDROID_STR=${ANDROID_STR// /}
  ANDROID_STR=${ANDROID_STR//:/}
  echo "$ANDROID_STR"
}

# This function converts a date_time which in ISO 8601 (YYYY-MM-DD) to the format which
# matches defined DATE_RGX="[0-9]{2} [a-zA-Z]{3} [0-9]{4}"
#                 TIME_RGX="[0-9]{2}:[0-9]{2}:[0-9]{2}"
#                 DATE_TIME_RGX="${DATE_RGX} ${TIME_RGX}"
# Input: original_format  which is a ISO 8601 format date-time.
#        date_or_time  which is one of: date, time, all.
# Return: date-time which matches DATE_RGX/TIME_RGX/DATE_TIME_RGX..
handle_iso8601_format()
{
  local original_format=$1
  local date_or_time=$2
  local original_month=""
  local new_day=""
  local new_month=""
  local new_year=""
  local new_time=""

  new_day=$(echo "$original_format" | awk -F- '{print $3}' | awk '{print $1}')
  new_year=$(echo "$original_format" | awk -F- '{print $1}')
  new_time=$(echo "$original_format" | awk -F" " '{print $2}' | awk -F'.' '{print $1}')

  original_month=$(echo "$original_format" | awk -F- '{print $2}')
  case $original_month in
    01) new_month="Jan" ;;
    02) new_month="Feb" ;;
    03) new_month="Mar" ;;
    04) new_month="Apr" ;;
    05) new_month="May" ;;
    06) new_month="Jun" ;;
    07) new_month="Jul" ;;
    08) new_month="Aug" ;;
    09) new_month="Sep" ;;
    10) new_month="Oct" ;;
    11) new_month="Nov" ;;
    12) new_month="Dec" ;;
  esac

  if [ -z "$new_day" ] || [ -z "$new_month" ] || [ -z "$new_year" ] || [ -z "$new_time" ]; then
    echo
    return 1
  else
    case $date_or_time in
      date) echo "$new_day $new_month $new_year" ;;
      time) echo "$new_time" ;;
      all) echo "$new_day $new_month $new_year $new_time" ;;
    esac
  fi
}


# This function obtains the date string from RTC / System clock.
# Input: CLOCK which may be one of sys / rtc.
#        [TIME_TYPE] -u for UTC.
# Return: DATE string from specified clock.
get_date()
{
  if [ "$#" -lt 1 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Get args
  local CLK="$1"
  local TIME_TYPE="$2"
  local DATE=""
  # Get date string
  case "$CLK" in
    sys)
      DATE=$(date $TIME_TYPE | \
          awk -v f_day="$SYS_DAY_FIELD" -v f_month="$SYS_MONTH_FIELD" -v f_year="$SYS_YEAR_FIELD" \
          '{printf("%02d %s %04d\n", $f_day, $f_month, $f_year)}');;
    rtc)
      DATE=$(hwclock $TIME_TYPE)
      # Check if need format conversion for ISO_8601 format
      # matched with the pattern defined in ISO_8601_RGX
      echo "$DATE" | grep -qE "$ISO_8601_RGX"
      if [ $? -eq 0 ]; then
        DATE=$(handle_iso8601_format "$DATE" "date")
      else
        DATE=$(hwclock $TIME_TYPE | \
            awk -v f_day="$RTC_DAY_FIELD" -v f_month="$RTC_MONTH_FIELD" -v f_year="$RTC_YEAR_FIELD" \
            '{printf("%02d %s %04d\n", $f_day, $f_month, $f_year)}')
      fi
      ;;
    *)
      die "Error: $CLK is not a valid clock"
      ;;
  esac
  # Return date string
  echo "$DATE"
}

# Obtain the time string from RTC / System clock.
# Input: CLK which may be one of rtc / sys.
#        [TIME_TYPE] -u for UTC.
# Return: TIME string from specified clock.
get_time()
{
  if [ "$#" -lt 1 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Get args
  local CLK="$1"
  local TIME_TYPE="$2"
  local TIME=""
  # Get time string
  case "$CLK" in
    sys)
      DATE=$(date $TIME_TYPE | awk -v f_time="$SYS_TIME_FIELD" '{print $f_time}')
      ;;
    rtc)
      TIME="hwclock $TIME_TYPE"
      # Check if need format conversion for ISO_8601 format
      # matched with the pattern defined in ISO_8601_RGX
      echo "$TIME" | grep -qE "$ISO_8601_RGX"
      if [ $? -eq 0 ]; then
        TIME=$(handle_iso8601_format "$TIME" "time")
      else
        TIME=$(hwclock $TIME_TYPE | awk -v f_time="$RTC_TIME_FIELD" '{print $f_time}')
      fi
      ;;
    *)
      die "Error: $CLK is not a valid clock"
      ;;
  esac
  # Return time string
  echo "$TIME"
}

# Obtain date-time string from RTC / System clock.
# Input: CLK which may be one of rtc / sys.
#        [TIME_TYPE] -u for UTC.
# Return: DATE string from specified clock.
get_date_time()
{
  if [ "$#" -lt 1 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Get args
  local CLK="$1"
  local TIME_TYPE="$2"
  local ALL=""
  # Obtain the date string
  case "$CLK" in
    sys)
      ALL=$(date $TIME_TYPE | \
          awk -v f_day="$SYS_DAY_FIELD" -v f_month="$SYS_MONTH_FIELD" -v f_year="$SYS_YEAR_FIELD" -v f_time="$SYS_TIME_FIELD" \
          '{printf("%02d %s %04d %s\n", $f_day, $f_month, $f_year, $f_time)}')
      ;;
    rtc)
      ALL=$(hwclock $TIME_TYPE)
      # Check if need format conversion for ISO_8601 format
      # matched with the pattern defined in ISO_8601_RGX
      echo "$ALL" | grep -qE "$ISO_8601_RGX"
      if [ $? -eq 0 ]; then
        ALL=$(handle_iso8601_format "$ALL" "all")
      else
        ALL=$(hwclock $TIME_TYPE | \
            awk -v f_day="$RTC_DAY_FIELD" -v f_month="$RTC_MONTH_FIELD" -v f_year="$RTC_YEAR_FIELD" -v f_time="$RTC_TIME_FIELD" \
            '{printf("%02d %s %04d %s\n", $f_day, $f_month, $f_year, $f_time)}')
      fi
      ;;
    *)
      die "Error: $CLK is not a valid clock"
      ;;
  esac
  # Return date string
  echo "$ALL"
}

# Set the date for a RTC / System clock.
# Input:     CLK         which may be one of rtc / sys.
#            DATE        the date strint to set of form dd mmm yyyy HH:MM.
#        [TIME_TYPE]     which may be one of --utc or --localtime.
# Return: the exit status of the cmd to set the date.
set_date()
{
  if [ "$#" -lt 2 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Getting args
  # Here transfer DATE_FIELD format into YYYY-MM-DD, which can be supported by both
  # Android and ubuntu OS
  local CLK="$1"
  local DATE="$2"
  local TIME_TYPE="$3"
  local DATE_FIELD=""
  local TIME_FIELD=""

  DATE_FIELD=$(echo "$DATE" | cut -d'.' -f1 | sed "s/^.\{4\}/&-/;s/^.\{7\}/&-/")
  TIME_FIELD=$(echo "$DATE" | cut -d'.' -f2 | sed "s/^.\{2\}/&:/;s/^.\{5\}/&:/")

  # Set date
  case "$CLK" in
    sys)
      if [ "$TIME_TYPE" = "--localtime" ]; then
        unset TIME_TYPE
      fi
      date -s "$DATE_FIELD" $TIME_TYPE 2>/dev/null
      date -s "$TIME_FIELD" $TIME_TYPE 2>/dev/null
      ;;
    rtc)
      if [ "$OS" = "ANDROID" ]; then
	      date -s "$DATE_FIELD" $TIME_TYPE 2>/dev/null
	      date -s "$TIME_FIELD" $TIME_TYPE 2>/dev/null
	      hwclock -w 2>/dev/null
      else
        hwclock --set --date "$DATE_FIELD $TIME_FIELD" 2>/dev/null
      fi
      ;;
    *)
      die "Error: $CLK is not a valid clock"
      ;;
  esac
  # Check for error in set date cmd
  local RET="$?"
  if [ "$RET" -ne 0 ]; then
    test_print_err "date command returned with $RET status !"
  fi
  return "$RET"
}

# Compare RTC and system clock fields.
# Input: CLK_FIELD may be one of date, time, all.
#        CRITERIA may be one of '=' for fields to be equal or '!' for fields to
#                 be different.

# Return: 0 is comparison CRITERIA was met, otherwise return 1.
cmp_clocks()
{
  if [ "$#" -lt 2 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Getting args
  local CLK_FIELD="$1"
  local CRITERIA="$2"
  local TIME_TYPE="$3"
  local SYS_TIME=""
  local RTC_TIME=""
  # Get clocks values
  case "$CLK_FIELD" in
    date)
      SYS_TIME=$(get_date "sys" "$TIME_TYPE")
      RTC_TIME=$(get_date "rtc" "$TIME_TYPE")
      ;;
    time)
      SYS_TIME=$(get_time "sys" "$TIME_TYPE")
      RTC_TIME=$(get_time "rtc" "$TIME_TYPE")
      ;;
    all)
      SYS_TIME=$(get_date_time "sys" "$TIME_TYPE")
      RTC_TIME=$(get_date_time "rtc" "$TIME_TYPE")
      ;;
    *)
      die "Error: $CLK_FIELD is not a valid clock field"
      ;;
  esac
  test_print_trc "SYS_TIME = $SYS_TIME  RTC_TIME = $RTC_TIME"
  #we'd better remove second field in order to avoid delay between two cmds
  SYS_TIME=$(echo "$SYS_TIME" | cut -d':' -f1-2)
  RTC_TIME=$(echo "$SYS_TIME" | cut -d':' -f1-2)
  # Compare clocks
  case "$CRITERIA" in
    =)  [ "$SYS_TIME" = "$RTC_TIME" ] && return 0;;
    !)  [ "$SYS_TIME" != "$RTC_TIME" ] && return 0;;
    *)  die "Error: $CRITERIA is not a valid comparison criteria";;
  esac
  # Criteria was not met, fail !
  return 1
}

# This function sync RTC with System clock.
# Input: CLOCK which may be one of:
#         rtc : set system clock with RTC value.
#         sys : set the RTC with system clock value.
# Return: 0 for a successful sync.
sync_clocks()
{
  if [ "$#" -ne 1 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Get args
  local CLK="$1"
  local RET=""
  # Sync clocks
  case "$CLK" in
    sys)  hwclock -w 2>/dev/null;;
    rtc)  hwclock -s 2>/dev/null;;
      *)  die "Error: $CLK is not a valid clock";;
  esac
  # Check if sync was succesful
  RET="$?"
  if [ "$RET" -ne 0 ]; then
    die "clocks sync failed... hwclock cmd returned with $RET status !"
  fi
  return "$RET"
}

# This function compares if two strings are equal.
# Input: FIELD_1 clock string.
#        FIELD_2 clock string.
# Return: 0 for equal strings or 1 for different strings.
cmp_clk_fields()
{
  if [ "$#" -ne 2 ]; then
    die "Error: $0 arguments missing..."
  fi
  # Get args
  local FIELD_1="$1"
  local FIELD_2="$2"
  # Compare fields
  [ "$FIELD_1" = "$FIELD_2" ] && test_print_trc "Fields are Equal !" && return 0
  # Fields are different
  test_print_wrg "${FIELD_1} != ${FIELD_2}"
  return 1
}

############################ Script Variables ##################################
# Define default values if possible
#BUSYBOX_DIR="$LTPROOT/bin/"
ANDROID_DATE_RGX="[0-9]{8}"
ANDROID_TIME_RGX="[0-9]{6}"
ANDROID_DATE_TIME_RGX="${ANDROID_DATE_RGX}.${ANDROID_TIME_RGX}"
DATE_RGX="[0-9]{2} [a-zA-Z]{3} [0-9]{4}"
TIME_RGX="[0-9]{2}:[0-9]{2}:[0-9]{2}"
DATE_TIME_RGX="${DATE_RGX} ${TIME_RGX}"
# ISO 8601 format example: 2016-12-19 09:56:45.004826+8:00
ISO_8601_RGX="[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{6}"
eval LC_TIME=en_US.UTF-8

if grep -q "androidboot" "/proc/cmdline"; then
  eval OS="ANDROID"
else
  eval OS="UPSTREAM"
fi

case $OS in
  ANDROID)
    RTC_YEAR_FIELD=5
    RTC_MONTH_FIELD=2
    RTC_DAY_FIELD=3
    RTC_WEEK_FIELD=1
    RTC_TIME_FIELD=4
    SYS_YEAR_FIELD=6
    SYS_MONTH_FIELD=2
    SYS_DAY_FIELD=3
    SYS_WEEK_FIELD=1
    SYS_TIME_FIELD=4
	  ;;
  UPSTREAM)
    if [[ "$(hwclock -v | awk '{print $4}')" =~ 2.25 ]];then
      RTC_YEAR_FIELD=5
      RTC_MONTH_FIELD=2
      RTC_DAY_FIELD=3
      RTC_WEEK_FIELD=1
      RTC_TIME_FIELD=4
    else
      RTC_YEAR_FIELD=4
      RTC_MONTH_FIELD=3
      RTC_DAY_FIELD=2
      RTC_WEEK_FIELD=1
      RTC_TIME_FIELD=5
    fi
    SYS_YEAR_FIELD=6
    SYS_MONTH_FIELD=2
    SYS_DAY_FIELD=3
    SYS_WEEK_FIELD=1
    SYS_TIME_FIELD=4
    ;;
  *)
    die "OS $OS is not supportted"
    ;;
esac
################################ CLI Params ####################################
# Please use getopts
while getopts  :c:d:g:l:r:s:t:y:hou arg
do
  case $arg in
    c)    CRITERIA="$OPTARG";;
    g)    GET_FIELD="$OPTARG";;
    l)    LOOP_CNT="$OPTARG";;
    o)    TIME_TYPE="--localtime";;
    r)    UPDATE_CLK="rtc"; DATE_STR="${OPTARG}";;
    s)    UPDATE_CLK="sys"; DATE_STR="${OPTARG}";;
    u)    TIME_TYPE="-u";;
    y)    SYNC_CLK="$OPTARG";;
    h)    usage;;
    :)    die "$0: Must supply an argument to -$OPTARG.";;
   \?)    die "Invalid Option -$OPTARG ";;
  esac
done

############################ USER-DEFINED Params ###############################
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
  # Use machine parameters file instead
esac

########################### DYNAMICALLY-DEFINED Params #########################

########################### REUSABLE TEST LOGIC ###############################
: ${LOOP_CNT:='1'}
: ${CRITERIA:='='}
: ${TIME_TYPE:='--localtime'}
test_print_trc "+++++++++++++++++ Start RTC test via hwclock +++++++++++++++++"
test_print_trc "GET_FIELD : $GET_FIELD"
test_print_trc "UPDATE_CLK : $UPDATE_CLK"
test_print_trc "DATE_STR : $DATE_STR"
test_print_trc "SYNC_CLK : $SYNC_CLK"

# Store original clock values before test
if [ -n "$UPDATE_CLK" -o -n "$SYNC_CLK" ]; then
  test_print_trc "Saving current clocks values"
  #in order to avoid timezone difference, do not add $TIME_TYPE argument
  RTC_ORIGINAL=$(get_date_time "rtc")
  SYS_ORIGINAL=$(get_date_time "sys")
  test_print_trc "Original Values:"
  test_print_trc "RTC : $RTC_ORIGINAL"
  test_print_trc "SYS : $SYS_ORIGINAL"
fi

# Attend requests...
i=0
while [ "$i" -lt "$LOOP_CNT" ]
do
  test_print_trc "================== LOOP $i =================="
  # Get field from clock
  if [ -n "$GET_FIELD" ]; then
    CLK_FIELD=""
    FIELD_CHECK_RGX=""
    case "$GET_FIELD" in
      time)
        CLK_FIELD=$(get_time "rtc")
        FIELD_CHECK_RGX="^${TIME_RGX}$"
        ;;
      date)
        CLK_FIELD=$(get_date "rtc")
        FIELD_CHECK_RGX="^${DATE_RGX}$"
        ;;
      all)
        CLK_FIELD=$(get_date_time "rtc")
        FIELD_CHECK_RGX="^${DATE_TIME_RGX}$";;
      *)
        die "-g $GET_FIELD not a valid argument for flag"
        ;;
    esac

    test_print_trc "CLK_FIELD: $CLK_FIELD"

    # Check if clock field is correct
    [[ "${CLK_FIELD}" =~ ${FIELD_CHECK_RGX} ]] || \
      die "RTC $GET_FIELD = ${CLK_FIELD} does not match ${FIELD_CHECK_RGX}"
    test_print_trc "[OK] RTC $GET_FIELD = ${CLK_FIELD}"
  fi

  # Update the clock value
  if [ -n "$UPDATE_CLK" ]; then
    [[ "$DATE_STR" =~ ${ANDROID_DATE_TIME_RGX} ]] || \
        die "DATE_STR = $DATE_STR is invalid it must be in the form YYYYMMDD.hhmmss"
    test_print_trc "Trying to set $UPDATE_CLK : $DATE_STR"
    # Update clock val and check any failure in set command
    set_date "$UPDATE_CLK" "$DATE_STR" "$TIME_TYPE"
    RET=$?
    [ "$RET" -ne 0 ] && \
        die "Set date of $UPDATE_CLK with ${DATE_STR} failed !"
    # Verify clock was actually updated
    cmp_clocks "all" "="
    RET=$?
    [ "$RET" -ne 0 ] && \
        die "Set date of $UPDATE_CLK with $DATE_STR failed !"
    test_print_trc "[OK] Set date of $UPDATE_CLK with $DATE_STR"
  fi

  # Sync RTC and System Clock
  if [ -n "$SYNC_CLK" ]; then
    # Check if sync cmd had error
    sync_clocks "$SYNC_CLK"
    RET=$?
    [ "$RET" -ne 0 ] && \
      die "Error: RTC & System clock sync failed !"
    # Verify if clocks are synced
    cmp_clocks "all" "$CRITERIA"
    RET=$?
    [ "$RET" -ne 0 ] && \
      die "Error: RTC & System clock sync failed !"
    test_print_trc "[OK] Sync RTC & System clock "
  fi
  i=$(( i + 1 ))
done

# Restore original clock values
if [ -n "$UPDATE_CLK" -o -n "$SYNC_CLK" ]; then
  test_print_trc "Restore original clocks values"
  RTC_ORIGINAL=$(convert_to_android_format "$RTC_ORIGINAL" "all")
  SYS_ORIGINAL=$(convert_to_android_format "$SYS_ORIGINAL" "all")
  #in order to avoid the difference of timezone, do not add $TIME_TYPE options
  do_cmd set_date "rtc" "$RTC_ORIGINAL"
  do_cmd set_date "sys" "$SYS_ORIGINAL"
fi
exit 0
