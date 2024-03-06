#! /bin/sh
#
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
#
# @desc Checks the multi stream Capture and Playback
# @params t) Test type     : Capture,playback
#         D) Audio Device  : Audio Device.
# @history 2011-04-07: First version
# @history 2011-05-13: Removed st_logs.sh

source "common.sh"  # Import do_cmd(), die() and other functions
source "alsa_configurations.sh"
############################# Functions #######################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-t TEST_TYPE] [-D DEVICE]
	-t TEST_TYPE		Test Type. Possible Values are Capture,playback,loopback.
	-D DEVICE           Device Name like plughw:0,0.
	EOF
	exit 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :t:D:l:h arg
do case $arg in
        t)      TYPE="$OPTARG";;
        D)      DEVICE="$OPTARG";;
        h)      usage;;
        :)      die "$0: Must supply an argument to -$OPTARG.";;
        \?)     die "Invalid Option -$OPTARG ";;
esac
done

dev_type=$(get_alsa_dev_type)
# Define default values if possible
: ${TYPE:='playback'}
: ${DEVICE:=$(get_audio_devnodes.sh -d $dev_type -t play | grep 'hw:[0-9]' || echo 'plughw:0,0')}
CARD=$(echo ${DEVICE} | cut -c 8 )

enable_mic_alsa "$CARD" || exit 1
enable_all_playback "$CARD" || exit 1

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use USER-DEFINED Params section above.

# Print the test params.
test_print_trc " ****************** TEST PARAMETERS ******************"
test_print_trc " TYPE		: $TYPE"
test_print_trc " DEVICE		: $DEVICE"

test_print_trc " *************** END OF TEST PARAMETERS ***************"

case "$TYPE" in

	capture)
		RESULT=0
		test_print_trc "CMD=arecord -f dat test.snd -d 60 & "
		arecord -D $DEVICE -f dat test.snd -d 60&
		pidlist="$!"
		test_print_trc "CMD=arecord -f dat testnew.snd -d 10 "
		arecord -D $DEVICE -f dat testnew.snd -d 10
		pidlist="$pidlist $!"
		for job in $pidlist
		do
			wait $job || let "RESULT+=1"
		done
		if [ $RESULT -eq 0 ] ; then
			test_print_err "Capture Multistream Test failed."
			rm *.snd
			exit 1
		fi
		test_print_trc "Capture Multistream Test succeeded."
		rm *.snd
		;;
	playback)
		RESULT=0
		test_print_trc "CMD=arecord -f dat test.snd -d 60 "
		arecord -D $DEVICE -f dat test.snd -d 60
		test_print_trc "CMD:aplay -f dat test.snd -d 10 -v"
		aplay -D $DEVICE -f dat test.snd -d 60&
		pidlist="$!"
		test_print_trc "CMD:aplay -f dat /usr/share/sounds/alsa/Front_Right.wav -d 10"
		aplay -D $DEVICE -f dat /usr/share/sounds/alsa/Front_Right.wav -d 10
		pidlist="$pidlist $!"
		for job in $pidlist
		do
			wait $job || let "RESULT+=1"
		done
		if [ $RESULT -eq 0 ] ; then
			test_print_err "Playback Multistream Test failed."
			rm test.snd
			exit 1
		fi
		test_print_trc "Playback Multistream Test succeeded."
		rm test.snd
		;;
esac
