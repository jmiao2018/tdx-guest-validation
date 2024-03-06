#!/bin/sh
source "common.sh"

FW_PATH="${PWD}/ddt_intel/fw"
HDA_PATH="${PWD}/ddt_intel/hda"
SYS_FW_PATH="/lib/firmware/intel"
SND_STATE_PATH="/var/lib/alsa"
MODULES_LIST="snd_soc_sst_byt_rt5640_mach snd_soc_sst_baytrail_pcm snd_seq_midi"

test_print_trc "fireware path=${FW_PATH} HDA path=${HDA_PATH}"

dpkg -l | grep "alsa-utils" || {
	test_print_trc "Not installed alsa-utils, Start install..."
	apt-get update && apt-get install alsa-utils
	test_print_trc "Finished installing alsa-utils"
	dpkg -l | grep "alsa-utils" || {
		test_print_trc "Failed to install alsa-utils,exit"
		exit 1
	}
}

#if can detect sound card, no need to reinstall firmware
aplay -l && exit 0

cp ${FW_PATH}/* ${SYS_FW_PATH} -rf

if [ -f "${SND_STATE_PATH}/asound.state" ] || [ -f  "${SND_STATE_PATH}/asound.state.lock" ];then
	rm asound*
fi
cp ${HDA_PATH}/asound.state ${SND_STATE_PATH}

alsactl -f ${SND_STATE_PATH}/asound.state restore

#check if modules has been load
for mod in $MODULES_LIST
do
	lsmod | cut -d' ' -f1 | grep -w "${mod}"
	if [ $? -eq 1 ];then
		modprobe ${mod}
	else
		modprobe -r ${mod}
		modprobe ${mod}
	fi
done
aplay -l || {
	test_print_trc "Can\'t enable sound card on this device,exit"
	exit 1
}
