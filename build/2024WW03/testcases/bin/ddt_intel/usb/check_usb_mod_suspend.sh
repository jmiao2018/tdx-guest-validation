#!/bin/bash
###############################################################################
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

# @Author   Luis Rivas(luis.miguel.rivas.zepeda@intel.com)
# @desc     Check if HCI notification are present on dmesg after resume
# @params   -p  optional; power states to test randomly, example "mem freeze"
#               default is "mem"
# @params   -t  optional; maximum suspend or freeze time; the suspend time
#               will be a random number between 0 and max time; default 10 sec
# @params   -i  optionall; define how many times to test OTC notifications;
#               default is 1
# @returns  0 if the execution was finished succesfully, else 1
# @history  2015-05-19: First version
#           2015-06-09: Port script to check Host Controller Interface info

source "functions.sh"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
    usage: ./${0##*/} [-p PSTATES] [-t MAX_STIME] [-i ITERATIONS]
    -p PSTATES          optional; power states to test randomly, example
                        "mem freeze"; default 'mem'
    -t MAX_STIME        optional; maximum suspend or standby time, the suspend
                        time will be a random number between 0 and max time;
                        default is 10 sec
    -i ITERATIONS       optionall; defines how many times to test OTC
                        notification; default is 1
    -h help             print this usage
EOF
exit 1
}

check_HCI_notification() {
    local power_state=$1
    local last_dmesg_time=0
    local expect="ULPI is working well"
    shift 1

    test_print_trc "checking HCI notification after resume: $expect"

    # Get last dmesg time before entering suspend state
    last_dmesg_time=$(dmesg | tail -1 | grep -Eo '\[.*[0-9]+\.[0-9]+.*\]' | tr -d []' ')
    suspend -p $power_state -t $MAX_STIME -i 1
    if [ $? -ne 0 ]; then
        test_print_trc "Error while suspending"
        return 1
    fi

    sleep 10 # wait a little more for HCI notifications

    # Check if OTG notification was received
    if $(dmesg | sed "1,/$last_dmesg_time/d" | grep -Eqo "$expect"); then
        test_print_trc "HCI notification received"
        return 0
    else
        test_print_trc "Error, HCI notification not received"
        return 1
    fi
}

############################### CLI Params ###################################
while getopts  :p:t:i:h arg
do case $arg in
    p)  PSTATES="$OPTARG";;
    t)  TIME="$OPTARG";;
    i)  ITERATIONS="$OPTARG";;
    h)  usage;;
    :)  test_print_trc "$0: Must supply an argument to -$OPTARG." >&2
    exit 1
    ;;
    \?) test_print_trc "Invalid Option -$OPTARG ignored." >&2
    usage
    exit 1
    ;;
esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden
: ${ITERATIONS:=1}
: ${PSTATES:="mem"}
: ${MAX_STIME:=10}

########################### DYNAMICALLY-DEFINED Params #########################
# Try to use /sys and /proc information to determine values dynamically.
# Alternatively you should check if there is an existing script to get the
# value you want
PSTATE_ARR=($PSTATES)

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

for i in $(seq 1 $ITERATIONS); do
    check_HCI_notification ${PSTATE_ARR[$(( $RANDOM % ${#PSTATE_ARR[@]} ))]} || \
    die "Error on USB HCI notifications"
done
