#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2014                                                  ##
##                                                                            ##
## Author:                                                                    ##
##  Wenzhong Sun <wenzhong.sun@intel.com>                                     ##
##                                                                            ##
## History:                                                                   ##
##  Aug 22, 2014 - (Wenzhong Sun) Created                                     ##
##  Sep 08, 2015 - (Rogelio Ceja) Add ALS sensor name for Sofia               ##
##  Nov 04, 2015 - (Jose Perez Carranza) Add WiFI module name for Sofia LTE   ##
##  Oct 27, 2016 - (Kun Yan) Add WiFI module name for bxt-p-rvp               ##
##                                                                            ##
################################################################################
#
# File:
#	get_module_config_name.sh
#
# Description:
#	Get module name according to the driver name and PLATFORM file
#
#-----------------------------------------------------------------------
if [ $# -lt 2 ];then
	echo "Error: Invalid Argument. Syntax: $0 <drivername> <machine>"
	exit -1
fi

get_mod_cfg_name()
{
	local drv_name=$1
	local machine=$2
	local mod_name=""

	case "${machine}" in
		ecs2_10a|ECS2_10A)
			Accelerometer="bmc150-accel"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			uart="8250_dw"
			;;
		malata8|MALATA8)
			Accelerometer="inv-mpu6050"
			Compass="ak8975"
			ALS="cm3232"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			uart="8250_dw"
			;;
		malata8_low|MALATA8_LOW)
			Accelerometer="kxcjk-1013"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			uart="8250_dw"
			;;
		ecs2_8a|ECS2_8A)
			Accelerometer="bmc150-accel"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			uart="8250_dw"
			;;
		ecs2_7b|ECS2_7B)
			Accelerometer="bmc150-accel"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			uart="8250_dw"
			;;
		anchor8|Anchor8)
			Compass="bmc150_magn"
			Accelerometer="bmc150-accel"
			Gyroscope="bmg160"
			ALS="jsa1127"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			;;
		ecs|ECS)
			Compass="bmc150_magn"
			Accelerometer="bmc150-accel"
			Gyroscope="bmg160"
			ALS="cm32181"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			uart="8250_dw"
			;;
		t100|T100)
			Compass="ak8975"
			Accelerometer="kxcjk-1013"
			Gyroscope=""
			ALS="cm32181"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			i2c="i2c_designware_platform"
			;;
		mrd7|MRD7)
			Compass="kxcjk-1013"
			Accelerometer="kxcjk-1013"
			Gyroscope="bmg160"
			ALS="jsa1212"
			WiFi="8723bs"
			BT="6lowpan_iphc bluetooth hci_uart"
			;;
		ecs2_edu|ECS2_EDU)
			uart="8250_dw"
			;;
		oars7a)
			uart=""
			;;
		simics-vp|SIMICS-VP)
			uart="8250_dw"
			;;
		rvp|nuc5i5ryh)
			i2c="i2c_designware_platform"
			;;
		rvp-bxt)
			WiFi="pcie8xxx"
			;;
		mrd6s|MRD6S)
			WiFi="iwlwifi"
			ALS="apds9930r"
			Compass="mmc35240"
			Accelerometer="kxcjk-1013"
			Gyroscope="st_gyro_i2c"
			;;
		mrd6sl_a|MRD6SL_A)
			ALS="apds9930"
			Compass="mmc35240"
			Accelerometer="kxcjk-1013"
			Gyroscope="st_gyro_i2c"
			WiFi="iwlwifi"
			;;
		mrd6sl_b|MRD6SL_B)
			ALS="apds9930"
			Compass="mmc35240"
			Accelerometer="kxcjk-1013"
			Gyroscope="st_gyro_i2c"
			WiFi="iwlwifi"
			;;
	esac

	eval mod_name=\$${drv_name}
	echo "$mod_name"
}

get_mod_cfg_name $1 $2
