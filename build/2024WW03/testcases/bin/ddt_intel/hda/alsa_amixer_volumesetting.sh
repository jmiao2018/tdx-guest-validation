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
# @desc Varies the volume by playing the audio in backgroung using amixer interface.
# @params  none.
# @history 2011-04-07: First version
# @history 2011-05-13: Removed st_log.sh
source "common.sh"  # Import do_cmd(), die() and other functions
source "alsa_configurations.sh"
############################# Functions #######################################
usage()
{
	cat <<-EOF >&2
	usage: ./${0##*/} [-D <device> ]
  -D audio device to use during the test, i.e plughw:1,0, defaults to plughw:0,0
	EOF
	exit 0
}

################################ CLI Params ####################################
# Please use getopts
while getopts  :h:D arg
do case $arg in
        h)      usage;;
        D)      DEVICE="$OPTARG";;
        :)      die "$0: Must supply an argument to -$OPTARG.";;
        \?)     die "Invalid Option -$OPTARG ";;
esac
done

dev_type=$(get_alsa_dev_type)
: ${DEVICE:=$(get_audio_devnodes.sh -d $dev_type -t play | grep 'hw:[0-9]' || echo 'plughw:0,0')}
CARD=$(echo "${DEVICE}" | cut -c 8)


########################### REUSABLE TEST LOGIC ###############################

amixer -c ${CARD} controls
amixer -c ${CARD} contents

enable_all_playback "${CARD}" || exit 1
enable_mic_alsa "${CARD}" || exit 1
sleep 5
echo -------------------device=$DEVICE
arecord -D ${DEVICE} -f dat -d 1000 | aplay -D ${DEVICE} -f dat -d 1000&

PLAYBACK_VOLUME=$(get_alsa_playback_volume)
CAPTURE_VOLUME=$(get_alsa_capture_volume)

MINVAL=0
MAXVAL=100
STEP=10

oldIFS=$IFS
IFS=','
i=$MINVAL
j=$MINVAL
while [[ $i -lt $MAXVAL ]]
do
	j=$MINVAL
	while [[ $j -lt $MAXVAL ]]
	do
		for playback in $PLAYBACK_VOLUME
		do
			if [ -n $playback ];then
				amixer -c ${CARD} cset name=\'$playback\' "$i%,$j%" || {
					IFS=$oldIFS
					test_print_trc "Failed to set volume"
					exit 1
				}
				test_print_trc "Succeeded to set volume"
			fi
		done
		sleep 2
		let "j += $STEP"
	done
	let "i += $STEP"
	sleep 2

done

i=$MINVAL
j=$MINVAL
while [[ $i -lt $MAXVAL ]]
do
	j=$MINVAL
	while [[ $j -lt $MAXVAL ]]
	do
		for capture in $CAPTURE_VOLUME
		do
			if [ -n $capture ];then
				amixer -c ${CARD} cset name=\'$capture\' "$i%,$j%" || {
					IFS=$oldIFS
 					test_print_trc "Failed to set volume"
 					exit 1
				}
				test_print_trc "Succeeded to set volume"
			fi
		done
		sleep 5
		let "j += $STEP"
	done
	let "i += $STEP"
	sleep 5
done
IFS=$oldIFS
exit 0
