#!/bin/bash
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
# @desc alsa bat test script
# @returns 0 if the execution was finished successfully, else 1
# @history 2016-08-18: First version

source "common.sh"  # Import do_cmd(), die() and other functions

# alsa-utils path
# alsa confige path
readonly ALSA_UTILS_PATH="${LTPROOT}/testcases/bin/ddt_intel/alsa_ddt"
readonly ALSA_CONFIGURATION_PATH="${LTPROOT}/testcases/data/alsabat"

# default devices
DEV_PLAYBACK="default"
DEV_CAPTURE="default"

# file name of wav
FILE_SIN_MONO="default_mono.wav"
FILE_SIN_DUAL="default_dual.wav"

# frequency range of signal
MAXFREQ=16547
MINFREQ=17

# load driver stat for the sound card from configuration file
# load driver file for the sound card from configuration file, the default value is "/usr/local/etc"
check_env_var 'ALSA_CONFIGURATION_FILE' \
  || die "Check env variable ALSA_CONFIGURATION_FILE failed!"
: ${ALSA_DRIVER_FILE:="/usr/local/etc"}
cp $ALSA_UTILS_PATH/alsa.conf $ALSA_DRIVER_FILE
$ALSA_UTILS_PATH/alsactl restore -f $ALSA_CONFIGURATION_PATH/$ALSA_CONFIGURATION_FILE

test_print_trc "current setting:"
test_print_trc "  $0 $DEV_PLAYBACK $DEV_CAPTURE"

while getopts :c:h:C:P arg
do
	 case $arg in
			c)
				CASE_ID="$OPTARG"
			;;
			C)
				DEV_CAPTURE="$OPTARG"
			;;
			P)
				DEV_PLAYBACK="$OPTARG"
			;;
			h)
				die "${0##*/} -c <CASE_ID> -h
					-c CASE_ID: which case to launch
					-h: show help "
			;;
			\?)
				die "You must supply an argument, ${0##*/} -h"
			;;
			*)
				die "Invalid argument, ${0##*/} -h"
			;;
		esac
done

#1,check generate mono wav file with default params
#2,check generate dual wav file with default params
#3,check playback wav file on single line mode
#4,check capture  wav file on single line mode
#5,check playback mono wav file and detect
#6,check playback dual wav file and detect
#7,check capture and playback wave file with channel num: 1
#8,check capture and playback wave file with chaanel num: 2
#9,check capture and playback wave file with sample rate: 44100
#10,check capture and playback wave file with smaple rate: 48000
#11,check cpature and playback wave file with duration: in samples
#12,check capture and playback wave file with duration: in seconds
#13,check capture and playback wave file with data format: U8
#14,check capture and playback wave file with data format: S16_LE
#15,check capture and playback wave file with data format: S24_3LE
#16,check capture and playback wave file with data format: S32_LE
#17,check capture and playback wave file with data format: cd
#18,check capture and playback wave file with data format: dat
#19,check capture and playback wave file on single line mode
#20,check analyze local wave file
case $CASE_ID in
	1)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -c1 --saveplay $FILE_SIN_MONO"
	;;
	2)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -c2 --saveplay $FILE_SIN_DUAL"
		sleep 5
	;;
	3)
		do_cmd "alsabat -P $DEV_PLAYBACK"
	;;
	4)
		do_cmd "alsabat -C $DEV_CAPTURE --standalone"
	;;
	5)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE --file $FILE_SIN_MONO"
	;;
	6)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE --file $FILE_SIN_DUAL"
	;;
	7)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -c1"
	;;
	8)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -c2 -F $MINFREQ:$MAXFREQ"
	;;
	9)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -r44100"
	;;
	10)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -r48000"
	;;
	11)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -n10000"
	;;
	12)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -n2.5s"
	;;
	13)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -f U8"
	;;
	14)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -f S16_LE"
	;;
	15)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -f S24_3LE"
	;;
	16)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -f S32_LE"
	;;
	17)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -f cd"
	;;
	18)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -f dat"
	;;
	19)
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE -F $MAXFREQ --standalone"
	;;
	20)
		latestfile=`ls -t1 /tmp/bat.wav.* | head -n 1`
		if [ -e $latestfile ]; then
		do_cmd "alsabat -P $DEV_PLAYBACK -C $DEV_CAPTURE --local -F $MAXFREQ --file $latestfile"
		else
		die "$latestfile not exist"
		fi
	;;
	*)
		die "Invalid case ID, the currently supported case IDs range from 1-20"
	;;
esac
