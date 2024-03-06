#!/bin/sh
#
# Copyright (C) 2015 Intel- http://www.intel.com/
# Configuration of ALSA : This file is used to configure al parameters needed to enable audio options on the card
# @history 2015-04-16: (Jose Perez,Rogelio Ceja)
#    - Define ALSA_UTILS_PATH variable
#    - Define set_device_name function
#    - Added parameter DEVICE to amixer commands
# @history 2015-06-08: (Rogelio Ceja)
#    - Add support for USB Audio cards

# Contributors:
#              Initial version:
#               Rogelio Ceja rogelio.ceja@intel.com
#               Jose Perez   jose.perez.carranza@intel.com

source "common.sh"
## Variables
case $MACHINE in
	t100)
		#make sure alsa-utils and sound card are valid on T100
		fw_install.sh || {
			test_print_trc "Failed to install firmware or alsa-utils on ${MACHINE},skipped"
			exit 2
		}
	;;
esac


#Enable Mic for ALSA
enable_mic_alsa() {
	local card=""
	[ $# -ne 1 ] && {
		echo "Please input parameter for amixer -c"
		return 1
	}
	card=$1
	case $MACHINE in
		t100)
			amixer -c $card cset name='Stereo ADC MIXL ADC1 Switch' 1 || return 1 #original is on
 			amixer -c $card cset name='Stereo ADC MIXR ADC1 Switch' 1 || return 1 #original is on
			amixer -c $card cset name='ADC Capture Switch' 1,1 || return 1 #original is both on
			amixer -c $card cset name='IN Capture Volume' 127,127 || return 1 #
			amixer -c $card cset name='ADC Boost Gain' 3,3 || return 1 #original is both on
			amixer -c $card cset name='IN1 Boost' 8 || return 1 #original is 8
			amixer -c $card cset name='Internal Mic Switch' 1 || return 1
			amixer -c $card cset name='Headset Mic Switch' 1 || return 1 #orginal is both on
			return 0
		;;
		nuc5i5ryh|rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-skls06|rvp-bxt)
			amixer -c $card cset name='Capture Switch' 1,1 || return 1
			return 0
		;;
		*)
			test_print_trc "Not supported platform, Failed to set MIC"
			return 1
		;;
	esac
}


# Enable speaker to test ALSA (OUTPUT = 0)
set_output_speaker_alsa() {
	local card=""
	[ $# -ne 1 ] && {
		echo "Please input parameter for amixer -c"
		return 1
	}
	card=$1
	case $MACHINE in
		t100)
			amixer -c $card cset name='DAC MIXL Stereo ADC Switch' 0 || return 1 #must off,original is off
			amixer -c $card cset name='DAC MIXR Stereo ADC Switch' 0 || return 1 #must off,original is off
			amixer -c $card cset name='Stereo DAC MIXL DAC L1 Switch' 1 || return 1 #for speaker,original is on
			amixer -c $card cset name='Stereo DAC MIXR DAC R1 Switch' 1 || return 1 #original is on
			amixer -c $card cset name='Headphone Switch' 0 || return 1 #disable headphone
			amixer -c $card cset name='Speaker Switch' 1 || return 1 #enable speaker
			amixer -c $card cset name='Speaker L Playback Switch' 1 || return 1 #Left
			amixer -c $card cset name='Speaker R Playback Switch' 1 || return 1 #Right
			amixer -c $card cset name='Speaker Channel Switch' 1,1 || return 1 #Enable both Channel
			amixer -c $card cset name='Speaker Playback Volume' 20,20 || return 1 #volume
			return 0
		;;
		nuc5i5ryh|rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-skls06|rvp-bxt)
#			amixer -c $card cset name='PCM Playback Volume' '100%','100%' || return 1
			amixer -c $card cset name='Master Playback Switch' 1,1 || return 1 #enable switch
			amixer -c $card cset name='Master Playback Volume' '20%','20%' || return 1 #set volume
			return 0
		;;
		*)
			test_print_trc "Not supported platform, Failed to set speaker"
			return 1
		;;
	esac
 }

 #Enable headset to test ALSA (OUTPUT = 1)
set_output_headset_alsa(){
	local card=""
	[ $# -ne 1 ] && {
		echo "Please input parameter for amixer -c"
		return 1
	}
	card=$1
	case $MACHINE in
		t100)
			amixer -c $card cset name='DAC MIXL Stereo ADC Switch' 0 || return 1 #must off
			amixer -c $card cset name='DAC MIXR Stereo ADC Switch' 0 || return 1 #must off
			amixer -c $card cset name='DAC MIXL INF1 Switch' 1 || return 1  #for hp
			amixer -c $card cset name='DAC MIXR INF1 Switch' 1 || return 1
			amixer -c $card cset name='Speaker Switch' 0 || return 1
			amixer -c $card cset name='Headphone Switch' 1 || return 1
			amixer -c $card cset name='HP L Playback Switch' 1 || return 1
			amixer -c $card cset name='HP R Playback Switch' 1 || return 1
			amixer -c $card cset name='HP Channel Switch' 1,1 || return 1
			amixer -c $card cset name='HP Playback Volume' 20,20 || return 1
			return 0
		;;
		nuc5i5ryh)
			test_print_trc "$MACHINE has no headset, skip"
			return 0
		;;
		rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-skls06|rvp-bxt)
			amixer -c $card cset name='Headphone Playback Switch' || return 1
			amixer -c $card cset name='Headphone Playback Volume' 20,20 || return 1
		;;
		*)
			test_print_trc "Not supported platform, Failed to set Headset"
			return 1
		;;
	esac
 }

enable_all_playback(){
 	local card=""
	[ $# -ne 1 ] && {
		echo "Please input parameter for amixer -c"
		return 1
	}
	card=$1
	case $MACHINE in
		t100)
			amixer -c $card cset name='DAC MIXL Stereo ADC Switch' 0 || return 1 #must off
			amixer -c $card cset name='DAC MIXR Stereo ADC Switch' 0 || return 1 #must off
			amixer -c $card cset name='Stereo DAC MIXL DAC L1 Switch' 1 || return 1 #for speaker
			amixer -c $card cset name='Stereo DAC MIXR DAC R1 Switch' 1 || return 1
			amixer -c $card cset name='DAC MIXL INF1 Switch' 1 || return 1  #for hp
			amixer -c $card cset name='DAC MIXR INF1 Switch' 1 || return 1
			amixer -c $card cset name='Speaker Switch' 1 || return 1
			amixer -c $card cset name='Headphone Switch' 1 || return 1
			amixer -c $card cset name='HP L Playback Switch' 1 || return 1
			amixer -c $card cset name='HP R Playback Switch' 1 || return 1
			amixer -c $card cset name='HP Channel Switch' 1,1 || return 1
			amixer -c $card cset name='HP Playback Volume' 20,20 || return 1
			amixer -c $card cset name='Speaker L Playback Switch' 1 || return 1
			amixer -c $card cset name='Speaker R Playback Switch' 1 || return 1
			amixer -c $card cset name='Speaker Channel Switch' 1,1 || return 1
			amixer -c $card cset name='Speaker Playback Volume' 20,20 || return 1
			return 0
		;;
		nuc5i5ryh|rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-skls06|rvp-bxt)
			set_output_speaker_alsa "$card" || return 1
			set_output_headset_alsa "$card" || return 1
			enable_mic_alsa "$card" || return 1
		;;
		*)
			test_print_trc "Not supported platform, Failed to set Headset"
			return 1
		;;
	esac
}
#Get alsa switch
#Return: "$PLAYBACK_SWITCH_NAME_1,$PLAYBACK_SWITCH_NAME_2,$CAPTURE_SWITCH_NAME_1,$CAPTURE_SWITCH_NAME_2"
get_alsa_switch(){
	case $MACHINE in
		t100)
			echo "Speaker Switch,Headphone Switch,Internal Mic Switch,Headset Mic Switch"
		;;
		nuc5i5ryh)
			echo "Master Playback Switch,Beep Playback Switch,Mic Playback Switch,Capture Switch"
		;;
		rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-bxt)
			echo "Master Playback Switch,Headphone Playback Switch,Mic Playback Switch,Capture Switch"
		;;
		rvp-skls06)
			echo "Master Playback Switch,Headphone Playback Switch,Rear Mic Playback Switch,Capture Switch"
		;;
		*)
			echo ""
		;;
	esac
}

#Get alsa volume
#Return: "$SPK_PLAYBACK_VOLUME,$HP_PLAYBACK_VOLUME..."
get_alsa_playback_volume(){
	case $MACHINE in
		t100)
			echo "Speaker Playback Volume,HP Playback Volume"
		;;
		nuc5i5ryh)
			echo "Master Playback Volume,Mic Playback Volume,Beep Playback Volume,PCM Playback Volume,Mic Boost Volume"
		;;
		rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-bxt)
			echo "Master Playback Volume,Headphone Playback Volume,Mic Playback Volume,Speaker Playback Volume"
		;;
		rvp-skls06)
			echo "Master Playback Volume,Headphone Playback Volume,Rear Mic Playback Volume,Center Playback Volume"
		;;
		*)
			echo ""
		;;
	esac
}

get_alsa_capture_volume(){
	case $MACHINE in
		t100)
			echo "ADC Capture Volume"
		;;
		*)
			echo ""
		;;
	esac
}

get_alsa_dev_type(){
	case $MACHINE in
		t100)
			echo "audio"
		;;
		*)
			echo "Analog"
		;;
	esac
}
