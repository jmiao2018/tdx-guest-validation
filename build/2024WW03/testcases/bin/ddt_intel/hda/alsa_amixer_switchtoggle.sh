#! /bin/sh
#
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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
#
# @desc Toggles the switch by playing the audio in backgroung using amixer interface.
# @params  l) TEST_LOOP    test loop for switch toggling. default is 1.
# @history 2011-04-07: First version
# @history 2011-05-13: Removed st_log.sh
# @history 2015-07-28: 1.Remove "case $MACHINE in..." that is unnesessary to intel
#						 platforms
source "common.sh"  # Import do_cmd(), die() and other functions
source "alsa_configurations.sh"
############################# Functions #######################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-l TEST_LOOP]  [-D <device> ]
  -D audio device to use during the test, i.e plughw:1,0, defaults to plughw:0,0
	EOF
	exit 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :l:D:h arg
do case $arg in
        l)      TEST_LOOP="$OPTARG";;
        D)      DEVICE="$OPTARG";;
        h)      usage;;
        :)      die "$0: Must supply an argument to -$OPTARG.";;
        \?)     die "Invalid Option -$OPTARG ";;
esac
done

# Define default values if possible
dev_type=$(get_alsa_dev_type)
: ${TEST_LOOP:=3}
: ${DEVICE:=$(get_audio_devnodes.sh -d $dev_type -t play | grep 'hw:[0-9]' || echo 'plughw:0,0')}
CARD=$(echo "${DEVICE}" | cut -c 8)

SWITCHES=$(get_alsa_switch)

########################### REUSABLE TEST LOGIC ###############################

amixer -c ${CARD} controls
amixer -c ${CARD} contents
arecord -D ${DEVICE} -f dat -d 300 | aplay -D ${DEVICE} -f dat -d 300&

oldIFS=$IFS
IFS=','
i=0
while [[ $i -lt $TEST_LOOP ]]
do
	for switch in $SWITCHES
	do
		if [ "$switch" != "" ] ; then
			amixer -c ${CARD} cset name=\'$switch\' 0 || {
				test_print_trc "Failed to toggle switch $switch off"
				IFS=$oldIFS
				exit 1
			}
			sleep 2
			amixer -c ${CARD} cset name=\'$switch\' 1 || {
				test_print_trc "Failed to toggle switch $switch off"
				IFS=$oldIFS
				exit 1
			}
			sleep 2
		fi
	done
	let "i += 1"
done
IFS=$oldIFS
test_print_trc "Succeeded to test amixer switch toggle"
exit 0

