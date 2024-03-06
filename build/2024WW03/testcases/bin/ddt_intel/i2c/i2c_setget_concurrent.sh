#! /bin/bash
#
# Copyright (C) 2014 Intel Corporation - http://www.intel.com/
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

# This script is to test i2c read write concurrently on one bus.
# Input

source "common.sh"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
        usage: ./${0##*/} [-d SLAVE_DEVICES] [-l TEST_LOOP}
        -d SLAVE_DEVICES  slave device name list
        -l TEST_LOOP    test loop for r/w. default is 100.
        -h Help         print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts  :d:l:h arg
do case $arg in
        d)
            SLAVE_DEVICES="$OPTARG";;
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
LOG_DIR="$LTPROOT/results"
[ -d "$LOG_DIR" ] || mkdir -p $LOG_DIR
[ -n "$SLAVE_DEVICES" ] || die "You have to provide slave devices' names."

############# Do the work ###########################################
test_print_trc "Running i2c concurrent test for $TEST_LOOP times"

error=0
for SLAVE_DEVICE in $SLAVE_DEVICES
do
  test_print_trc "=====i2c set/get on SLAVE_DEVICE: $SLAVE_DEVICE====="
  do_cmd i2c_setget.sh -d "$SLAVE_DEVICE" -l "$TEST_LOOP" > $LOG_DIR/i2c_concurrent_$SLAVE_DEVICE.log 2>&1 &
  cpid_list="$cpid_list $!"
  sleep 1
done

for cpid in $cpid_list
do
    cpid_stat=$(ps | grep -q $cpid)
    if [ "$cpid_stat" -eq 0 ]
    then
      test_print_trc "=====i2c set/get concurrent test: waiting pid: $cpid====="
      wait $cpid
      if [ $? -ne 0 ];then
        error=$(($error+1))
      fi
    fi
done

if [ "$error" -ne 0 ]
then
  test_print_trc "I2C set/get concurrent test is FAIL, please check $LTPROOT/results/i2c_concurrent_xxx.log in detail"
  exit 1
else
  test_print_trc "I2C set/get concurrent test is PASS"
  exit 0
fi
