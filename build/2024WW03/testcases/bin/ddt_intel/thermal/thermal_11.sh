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

# Copyright (C) 2015, Intel - http://www.intel.com
# @Author   Luis Rivas <luis.miguel.rivas.zepeda@intel>
# @desc     The driver permits reading the DTS (Digital Temperature Sensor)
#           embedded inside Intel CPUs. This driver  can read  both  the
#           per-core and per-package temperature using  the appropiate sensors
#           https://www.kernel.org/doc/Documentation/hwmon/coretemp
# @params   c)  Check per core temperature
# @params   p)  Check per package temperature
# @params   t)  Timeout in seconds, default is 10
# @params   i)  Check temperatures each i seconds, default is 10 seconds
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-02-24: First version (Luis Rivas)

source common.sh
source functions.sh
source thermal_functions.sh

############################# Functions #######################################
usage() {
  cat << _EOF
    usage: ./${0##*/}  [-c]  [-p] [-t TIME]
    -c  Check per core temperature
    -p  Check per package temperature
    -t  Stress time in seconds, default is 120 seconds
    -i  Check temperatures each i seconds, default is 10 seconds
    -h  Help print this usage
    *** If -c or -p are not provided, the script will checks core temperature
_EOF
}

check_temp_change() {
  #Busybox does not support "grep --include=file_name", so replace it with "find" command.
  #And here "find" command is used to find matched files and store them in $indices_file.
  local indices_file=""
  local indices=""
  local count=0
  local temp_list=
  local final_temp=0
  local cool_temp=0

  local pass=0
  local time_out=0

  indices_file=$(find "$CORETEMP_PATH" -name "$RGX_LABEL")
  indices=$(grep -slE "$RGX_TARGET" "$indices_file" \
                 | xargs -rn 1 basename \
                 | grep -Eo "$RGX_NUM")
  for index in $indices; do
    temp_list[$count]=$(cat "$CORETEMP_PATH"'/temp'"$index"'_input')
    test_print_trc "Initial temp${index}_temp: ${temp_list[$count]}"
    count=$((count + 1))
  done

  check "core/package exists in $CORETEMP_PATH" "test" "$count -gt 0" \
    || return 1
  $HEAT_CPU_MODERATE --timeout "$TIME" &
  local pid=$!

  while [ $time_out -lt "$TIME" ]; do
    pass=1
    count=0

    for index in $indices; do
      final_temp=$(cat "$CORETEMP_PATH"'/temp'"$index"'_input')
      cool_temp=$((final_temp - ${temp_list[$count]}))
      test_print_trc "$time_out: temp${index}_temp = $final_temp"

      if test $cool_temp -le 0; then
        pass=0
      fi
      count=$((count + 1))
    done

    if [ $pass -eq 1 ]; then
      kill $pid || kill -9 $pid
      test_print_trc "All Temperatures increased after $time_out seconds"
      return 0
    fi

    sleep "$INTERVAL"
    time_out=$((time_out + INTERVAL))
  done

  kill $pid || kill -9 $pid
  test_print_trc "All Temperatures didnt increase after $time_out seconds"

  return 1
}

############################ Script Variables ##################################
# Define default valus if possible
HEAT_CPU_MODERATE="stress  --cpu 4"
RGX_NUM="[0-9]+"
RGX_LABEL="temp[0-9]_label"

################################ CLI Params ####################################
# Please use getopts
while getopts  cpt:i:h arg
do
  case $arg in
    c) CHECK_CORE=1 ;;
    p) CHECK_PACKAGE=1 ;;
    t) TIME=$OPTARG ;;
    i) INTERVAL=$OPTARG ;;
    h) usage && exit ;;
    \?) die "Invalid Option -$OPTARG " ;;
    :) die "$0: Must supply an argument to -$OPTARG." ;;
esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
: ${CHECK_CORE:=0}
: ${CHECK_PACKAGE:=0}
: ${TIME:=120}
: ${INTERVAL:=10}

if [ $CHECK_CORE -eq 1 ] && [ $CHECK_PACKAGE -eq 1 ]; then
  RGX_TARGET="^Core.[0-9]+$|^Physical.id.[0-9]+$"
elif [ $CHECK_PACKAGE -eq 1 ]; then
  RGX_TARGET="^Physical.id.[0-9]+$"
else
  RGX_TARGET="^Core.[0-9]+$"
fi

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
test_print_trc "STARTING READ PER CORE/PACKAGE Test..."
test_print_trc "Search core/package regex: $RGX_TARGET"
test_print_trc "Max wait time: $TIME seconds"
test_print_trc "Check temps each $INTERVAL seconds"

sleep 60  # Let the system rest for 1 minute
check_temp_change || exit 1
