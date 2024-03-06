#! /bin/sh
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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

# @desc Run the alsa performance binary to get CPU ulilization numbers for
#       record and playback

source "common.sh"  # Import do_cmd(), die() and other functions
source "alsa_configurations.sh"
############################# Functions #######################################
usage()
{
	echo "run_alsa_perf.sh [For options (see iperf help)"
	echo " all other args are passed as-is to alsa_perf_tests"
	echo " alsa_perf_tests help:"
        echo `alsa_perf_tests -h`
	exit 1
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :H:h arg
do case $arg in
        h)      usage;;
        :)      ;;
        \?)     ;;
esac
done
# Define default values if possible
DEVICE=''
if [[ "$*" != *-device* ]]
then
  dev_type=$(get_alsa_dev_type)
  DEVICE=$(get_audio_devnodes.sh -d $dev_type -t play | grep 'hw:[0-9]' || echo 'plughw:0,0')
  DEVICE="-device=${DEVICE}"
fi

# Define default values for variables being overriden

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

test_print_trc "Starting lsa_perf_tests TEST"

do_cmd "alsa_perf_tests ${DEVICE} $*"

