#! /bin/bash
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

# This script is to use i2cset and i2cget to i2c read write
# Input

source "common.sh"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
        usage: ./${0##*/} [-d SLAVE_DEVICE] [-l TEST_LOOP}
        -d SLAVE_DEVICE  slave device name; it is optional; if not provided, the slave address will take the default one from 'get_i2c_slave_addr.sh'
        -l TEST_LOOP    test loop for r/w. default is 1.
        -h Help         print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts  :d:l:h arg
do case $arg in
        d)
            SLAVE_DEVICE="$OPTARG";;
        l)
            TEST_LOOP="$OPTARG";;
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
############################ DEFAULT Params #######################
: ${TEST_LOOP:='1'}
test_print_trc "SLAVE_DEVICE: $SLAVE_DEVICE"
test_print_trc "if SLAVE_DEVICE is empty, slave device will use the one defined in get_i2c_slave_addr.sh"

############# Do the work ###########################################
test_print_trc "Running i2c setget test for $TEST_LOOP times"
SLAVE_ADDRESS=`get_i2c_slave_addr.sh "$SLAVE_DEVICE"` || die "error getting slave address for i2c: $SLAVE_ADDRESS"
REGOFFSET=`get_i2c_slave_regoffset.sh "$SLAVE_DEVICE"` || die "error getting slave regoffset"
REGVALUE=`get_i2c_slave_regvalue.sh "$SLAVE_DEVICE"` || die "error getting slave regvalue"
I2CBUS=`get_i2cbus_number.sh` || die "error getting i2cbus number: $I2CBUS"

x=0
while [ $x -lt $TEST_LOOP ]
do
  test_print_trc "=====i2c set get loop: $x====="

  # I2C R/W on ALS slave device is different than others
  if [ "$SLAVE_DEVICE" = "als" -o "$SLAVE_DEVICE" = "ALS" ];then
  case $MACHINE in
    ecs|ECS)
	# save the original value so it can be restored after the test
	orig_val=`i2cget -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET"`

	do_cmd i2cset -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET" "$REGVALUE"
	do_cmd "i2cget -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET" | grep "$REGVALUE""

	# restore the value
	do_cmd i2cset -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET" "$orig_val"
    ;;
    anchor8|ANCHOR8)
    # save the original value so it can be restored after the test
	orig_val=`i2cget -y "$I2CBUS" "$SLAVE_ADDRESS"`

	do_cmd i2cset -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGVALUE"
	do_cmd "i2cget -y "$I2CBUS" "$SLAVE_ADDRESS" | grep "$REGVALUE""

	# restore the value
	do_cmd i2cset -y "$I2CBUS" "$SLAVE_ADDRESS" "$orig_val"
    ;;
    *)
    # do nothing
    ;;
  esac
  else
	case $MACHINE in
		t100|rvp|nuc5i5ryh|rvp-skly03|rvp-bxt|rvp-kblu|rvp*|simics)
			if [ $SLAVE_DEVICE == "i915" ];then
				#if nomodeset has been set in cmdline, block it
				is_nomodeset=`cat /proc/cmdline | grep -o nomodeset`
				[ "x$is_nomodeset" == "xnomodeset" ] && {
					test_print_trc "nomodeset has been set, i915 won't be loaded"
					exit 2
				}
				MONITOR_REGOFFSET=`get_i2c_slave_regoffset.sh "monitor"`
				#handle the string returned by i2cdump. the final outputs have been combined into 1 line
				MONITOR_DATA=`i2cdump -y -r $MONITOR_REGOFFSET $I2CBUS $SLAVE_ADDRESS b | cut -c 56- |sed "s/0123456789abcdef//;/^$/d;:a;N;s/\n//;ta;"`
				test_print_trc "The Display Monitor's data are: $MONITOR_DATA"
			else
				die "$SLAVE_DEVICE is not supported"
			fi
		;;
		*)
		# display the orignal values before running test
		do_cmd "i2cdump -y -r 0x0-0x7f "$I2CBUS" "$SLAVE_ADDRESS" b"

		# save the original value so it can be restored after the test
		orig_val=`i2cget -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET"`

		do_cmd i2cset -y -r "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET" "$REGVALUE"
		do_cmd "i2cget -y "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET" | grep "$REGVALUE""

		# display the modified value after the test
		do_cmd "i2cdump -y -r 0x0-0x7f "$I2CBUS" "$SLAVE_ADDRESS" b"

		# restore the value
		do_cmd i2cset -y -r "$I2CBUS" "$SLAVE_ADDRESS" "$REGOFFSET" "$orig_val"

		# display the value after restore
		do_cmd "i2cdump -y -r 0x0-0x7f "$I2CBUS" "$SLAVE_ADDRESS" b"
		;;
	esac
	fi
	x=$((x+1))
done

