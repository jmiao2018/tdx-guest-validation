#!/bin/bash
#
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2014 Intel - http://www.intel.com/
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
# @desc Script to run gpio test

source "common.sh"
#source "super-pm-tests.sh"

#############################Sysfs Global variables###########################
GPIO_SYSFS_DIR="/sys/class/gpio"
GPIO_SYSFS_EXPORT="/sys/class/gpio/export"
GPIO_SYSFS_UNEXPORT="/sys/class/gpio/unexport"
GPIO_SYSFS_ACPI_ENUM_DIR="/sys/bus/acpi/devices"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
  usage: ./${0##*/}  [-l TEST_LOOP] [-t SYSFS_TESTCASE] [-i TEST_INTERRUPT] [-n GPIO_NUMS] [-s GPIO_NUM_SKIPPED ] [-a GPIOCHIP_ALL]
  -l TEST_LOOP  test loop
  -t SYSFS_TESTCASE testcase like 'out', 'in'
  -i TEST_INTERRUPT if test interrupt, default is 0.
  -n GPIO_NUMS GPIO pins number list to test separated by commas like '10,13,23,135,200'
  -s GPIO_NUM_SKIPPED GPIO pins number to be skipped for the test
  -a Perform test for all GPIO's controlled by gpiochipX
  -h Help   print this usage
EOF
exit 0
}

gpio_sysentry_get_item()  {
  GPIO_NUM=$1
  ITEM=$2

  VAL=`cat $GPIO_SYSFS_DIR/gpio${GPIO_NUM}/${ITEM}`
  echo "$VAL"
}

gpio_sysentry_set_item() {
  if [ $# -lt 3 ]; then
    echo "Error: Invalid Argument Count"
    echo "Syntax: $0 <gpio_num> <item like 'direction', 'value', 'edge'> <item value>"
    exit 1
  fi

  GPIO_NUM=$1
  ITEM=$2
  ITEM_VALUE=$3

  ORIG_VAL=`gpio_sysentry_get_item ${GPIO_NUM} ${ITEM}`
  test_print_trc "The value was ${ORIG_VAL} before setting ${ITEM}"

  do_cmd "echo "$ITEM_VALUE" > $GPIO_SYSFS_DIR/gpio${GPIO_NUM}/${ITEM}"
  VAL_SET=`gpio_sysentry_get_item ${GPIO_NUM} ${ITEM}`
  if [ "${VAL_SET}" != "${ITEM_VALUE}" ]; then
    die "Value for GPIO ${GPIO_NUM} was not set to ${ITEM_VALUE}"
  else
    test_print_trc "GPIO ${GPIO_NUM} was set to ${ITEM_VALUE}"
  fi
}

#Function: gpio_sysentry_chip_info
#Description: get gpiochip info under sysfs
#Input: N/A
#Output:: $GPIO_BASES $GPIO_NGPIOS,$GPIO_LABELS (global veriables)
#Return: 0 for success, 1 for failure

GPIOBASES=""
gpio_sysentry_chip_info() {
	[ -d "$GPIO_SYSFS_DIR" ] || return 1
	chips=`ls "$GPIO_SYSFS_DIR" | grep gpiochip`
	[ "x$chips" == "x" ] && return 1
	for chip in $chips
	do
		[ "x$GPIO_BASES" == "x" ] && \
		GPIO_BASES=`cat $GPIO_SYSFS_DIR/$chip/base` || \
		GPIO_BASES="$GPIO_BASES,`cat $GPIO_SYSFS_DIR/$chip/base`"
	done
	echo $GPIO_BASES
	return 0
}

gpio_sysentry_drv_check() {
	gpios=`gpio_sysentry_chip_info | sed 's/,/ /g'`
	for gpio in $gpios
	do
		#get the symbol link
		drv_path=`readlink -e $GPIO_SYSFS_DIR/gpiochip$gpio/device/driver`
		if [ -d $drv_path ];then
			test_print_trc "gpiochip$gpio's driver is register, path is $drv_path"
		else
			test_print_trc "gpiochip$gpio's driver is not register, path is $drv_path"
			return 1
		fi
	done
	return 0
}

gpio_sysentry_acpi_enum() {
	gpios=`gpio_sysentry_chip_info | sed 's/,/ /g'`
	for gpio in $gpios
	do
		#get the device name, we should enumerate it under acpi sysentry
		dev_acpi_alias=`readlink -e $GPIO_SYSFS_DIR/gpiochip$gpio/device | awk -F'/' '{print $NF}'`
		#enumeration under acpi folder
		if [ -d "$GPIO_SYSFS_ACPI_ENUM_DIR/$drv_acpi_alias" ];then
			test_print_trc "gpiochip$gpio device $dev_acpi_alias,acpi enumeration succeeded"
		else
			test_print_trc "gpiochip$gpio device $dev_acpi_alias,acpi enumeration failed"
			return 1
		fi
	done
	return 0
}

#Function: get_all_gpios_from_chips
#Description: get a list of gpios handled by all present gpiochips
#Input: N/A
#Output:: $GPIOS (return value)
#Return: 0 for success, 1 for failure
get_all_gpios_from_chips() {
	[ -d "$GPIO_SYSFS_DIR" ] || return 1
  local CHIPS=`ls "$GPIO_SYSFS_DIR" | grep gpiochip`
  local GPIOS=""
  local CUR_GPIO=0
  local LAST_GPIO=0

	for chip in $CHIPS
	do
    CUR_GPIO=`cat $GPIO_SYSFS_DIR/$chip/base`
    LAST_GPIO=`cat $GPIO_SYSFS_DIR/$chip/ngpio`
    for (( i=0; i < $LAST_GPIO; i++ ))
    do
      [ -n "$GPIOS" ] && GPIOS+=","
      GPIOS+="$(( $CUR_GPIO + $i ))"
    done
	done
  echo "$GPIOS"
  return 0
}

############################### CLI Params ###################################
while getopts  :l:t:i:n:s:ha arg
do case $arg in
  l)  TEST_LOOP="$OPTARG";;
  t)  SYSFS_TESTCASE="$OPTARG";;
  i)  TEST_INTERRUPT="$OPTARG";;
  n)  GPIO_NUMS="$OPTARG";;
  s)  GPIO_NUM_SKIPPED="$OPTARG";;
  a)  GPIOCHIP_ALL=1;;
  h)  usage;;
  :)  test_print_trc "$0: Must supply an argument to -$OPTARG." >&2
    exit 1
    ;;

  \?)  test_print_trc "Invalid Option -$OPTARG ignored." >&2
    usage
    exit 1
    ;;
esac
done

########################### DYNAMICALLY-DEFINED Params ########################
: ${TEST_LOOP:='1'}
: ${TEST_INTERRUPT:='0'}
: ${GPIOCHIP_ALL:='0'}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
test_print_trc "STARTING GPIO Test... "
test_print_trc "TEST_LOOP:${TEST_LOOP}"
test_print_trc "SYSFS_TESTCASE:${SYSFS_TESTCASE}"

case $MACHINE in
  ecs|ECS)
    GPIO_NUMS="354,398,475"
    GPIO_NUM_SKIPPED="342,348"
    ;;
  ecs2_8a|ECS2_8A)
    GPIO_NUMS="354,398,475"
    GPIO_NUM_SKIPPED="342,348"
    ;;
  ecs2_7b|ECS2_7B)
    GPIO_NUMS="354,398,475"
    GPIO_NUM_SKIPPED="342,348"
    ;;
  malata8|MALATA8)
    GPIO_NUMS="354,398,476"
    GPIO_NUM_SKIPPED="348,365"
    ;;
  malata8_low|MALATA8_LOW)
    GPIO_NUMS="354,398,476"
    GPIO_NUM_SKIPPED="348,365"
    ;;
  ecs2_10a|ECS2_10A)
    GPIO_NUMS="354,398,475"
    GPIO_NUM_SKIPPED="342,348"
    ;;
  t100)
	GPIO_NUMS=`gpio_sysentry_chip_info` || die "Failed to get GPIO NUMS"
	GPIO_NUM_SKIPPED="410"
    ;;
  edison)
    GPIO_NUMS=`gpio_sysentry_chip_info` || die "Failed to get GPIO NUMS"
    ;;
  glv-simics)
    GPIO_NUMS=`gpio_sysentry_chip_info` || die "Failed to get GPIO NUMS"
    ;;
  simics-vp)
    test_print_trc "Adding all GPIOs from present chip controllers"
    GPIO_NUMS+=`get_all_gpios_from_chips`
    ;;
  *)
    if [ -z "$GPIO_NUMS" ]; then
      die "The gpio numbers are not specified for $MACHINE !"
    fi
  ;;
esac


# Add all GPIOs handled by present gpiochips
if [ "$GPIOCHIP_ALL" -eq 1 ]; then
  test_print_trc "Adding all GPIOs from present chip controllers"
  GPIO_NUMS+=`get_all_gpios_from_chips`
fi

if [ -z "$GPIO_NUMS" ]; then
  die "The gpio numbers are not specified"
fi

OIFS=$IFS
IFS=","

# Test GPIOs
for GPIO_NUM in $GPIO_NUMS; do

    for gpio_skip in $GPIO_NUM_SKIPPED; do
      if [ $GPIO_NUM = $gpio_skip ];then
        test_print_trc "Skip gpio num: $GPIO_NUM"
        GPIO_NUM=`expr $GPIO_NUM + 1`
        continue 2
      fi
    done

    test_print_trc "GPIO_NUM:${GPIO_NUM}"

    if [ "$TEST_INTERRUPT" = "1" ]; then
      do_cmd lsmod | grep gpio_test
      if [ $? -eq 0 ]; then
        test_print_trc "Module already inserted; Removing the module"
        do_cmd rmmod gpio_test.ko
        sleep 2
      fi
    fi

    if [ -n "$SYSFS_TESTCASE" ]; then
      if [ -e $GPIO_SYSFS_DIR/gpio"$GPIO_NUM" ]; then
        do_cmd "echo ${GPIO_NUM} > $GPIO_SYSFS_UNEXPORT"
        do_cmd ls $GPIO_SYSFS_DIR
        sleep 1
      fi
    fi

    if [ "$TEST_INTERRUPT" = "1" ]; then
      test_print_trc "Inserting gpio test module. Please wait..."
      do_cmd "cat /proc/interrupts"
      # wait TIMEOUT for app to finish; if not finished by TIMEOUT, kill it
      # gpio_test module return sucessfully only after the interrupt complete.
      # do_cmd "timeout 30 insmod ddt/gpio_test.ko gpio_num=${GPIO_NUM} test_loop=${TEST_LOOP} ${EXTRA_PARAMS}"
      ( do_cmd insmod ddt/gpio_test.ko gpio_num=${GPIO_NUM} test_loop=${TEST_LOOP} ${EXTRA_PARAMS} ) & pid=$!
      sleep 5; kill -9 $pid
      wait $pid
      if [ $? -ne 0 ]; then
        die "No interrupt is generated and gpio interrupt test failed."
      fi
      do_cmd cat /proc/interrupts |grep -i gpio
      #do_cmd check_debugfs

      test_print_trc "Removing gpio test module. Please wait..."
      do_cmd rmmod gpio_test.ko
      sleep 3
      do_cmd cat /proc/interrupts
    fi

    # run sys entry tests if asked
    if [ -n "$SYSFS_TESTCASE" ]; then
      test_print_trc "Running sysfs test..."

      # test loop
      i=0
      while [ $i -lt $TEST_LOOP ]; do
        test_print_trc "===LOOP: $i==="
        do_cmd "echo ${GPIO_NUM} > $GPIO_SYSFS_EXPORT"
        do_cmd ls $GPIO_SYSFS_DIR
        if [ -e $GPIO_SYSFS_DIR/gpio"$GPIO_NUM" ]; then
          case "$SYSFS_TESTCASE" in
          neg_reserve)
            test_print_trc "Try to reserve the same gpio again"
            test_print_trc "echo ${GPIO_NUM} > $GPIO_SYSFS_EXPORT"
            echo ${GPIO_NUM} > $GPIO_SYSFS_EXPORT
            if [ $? -eq 0 ]; then
              die "gpio should not be able to reserve gpio ${GPIO_NUM} which is already being reserved"
            fi
            ;;
          out)
            gpio_sysentry_set_item "$GPIO_NUM" "direction" "out"
            if [ $? -ne 0 ]; then
              die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to out"
            fi
            gpio_sysentry_set_item "$GPIO_NUM" "value" "0"
            if [ $? -ne 0 ]; then
              die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to 0"
            fi
            gpio_sysentry_set_item "$GPIO_NUM" "value" "1"
            if [ $? -ne 0 ]; then
              die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to 1"
            fi
            ;;
          in)
            gpio_sysentry_set_item "$GPIO_NUM" "direction" "in" || die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to in"
            VAL=`gpio_sysentry_get_item "$GPIO_NUM" "value"` || die "gpio_sysentry_set_item failed to get the value of ${GPIO_NUM} "
            test_print_trc "The value is ${VAL} for $GPIO_NUM"
            ;;
          edge)
		  if [ -f $GPIO_SYSFS_DIR/gpio${GPIO_NUM}/edge ]; then
			gpio_sysentry_set_item "$GPIO_NUM" "direction" "in" || die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to in"
			gpio_sysentry_set_item "$GPIO_NUM" "edge" "falling"
			if [ $? -ne 0 ]; then
				die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to falling"
			fi
				gpio_sysentry_set_item "$GPIO_NUM" "edge" "rising"
			if [ $? -ne 0 ]; then
				die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to rising"
			fi
			gpio_sysentry_set_item "$GPIO_NUM" "edge" "both"
			if [ $? -ne 0 ]; then
				die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to both"
			fi
		else
			test_print_trc "gpio${GPIO_NUM} does not support edge setting, so that test is skipped"
		fi
			;;
          pm_context_restore)
            gpio_sysentry_set_item "$GPIO_NUM" "direction" "out" || die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to out"
            gpio_sysentry_set_item "$GPIO_NUM" "value" "1" || die "gpio_sysentry_set_item failed to set ${GPIO_NUM} to 1"
            VAL_BEFORE=`gpio_sysentry_get_item "$GPIO_NUM" "value"` || die "gpio_sysentry_set_item failed to get the value of ${GPIO_NUM} "
            test_print_trc "The value was ${VAL_BEFORE} for $GPIO_NUM before suspend"

            simple_suspend_w_stats 'mem' 10 2

            # check if the value is still the same as the one before suspend
            VAL_AFTER=`gpio_sysentry_get_item "$GPIO_NUM" "value"` || die "gpio_sysentry_set_item failed to get the value of ${GPIO_NUM} "
            test_print_trc "The value was ${VAL_AFTER} for $GPIO_NUM after suspend"

            # compare
            if [ $VAL_BEFORE -ne $VAL_AFTER ]; then
              die "The value for gpio $GPIO_NUM is different before and after suspend"
            else
              test_print_trc "The values are the same before and after"
            fi
            ;;
			drv_check)
				gpio_sysentry_drv_check || die "gpio_sysentry_drv_check failed"
			;;
			acpi_enum)
				gpio_sysentry_acpi_enum || die "gpio_sysentry_acpi_enum failed"
			;;
          esac
        else
          die "$GPIO_SYSFS_DIR/gpio${GPIO_NUM} does not exist!"
        fi

        # remove gpio sys entry
        do_cmd "echo ${GPIO_NUM} > $GPIO_SYSFS_UNEXPORT"
        do_cmd "ls $GPIO_SYSFS_DIR/"

        i=`expr $i + 1`
      done  # while loop
    fi
done
IFS=$OIFS
