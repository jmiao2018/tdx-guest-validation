#! /bin/bash
#
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

# This script is to test i2c basic tests
# Input

source "common.sh"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
        usage: ./${0##*/} [-c CASE_ID]
        -c CASE_ID which test case should be launched. default is 0
        -h Help         print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts  :c:h arg
do case $arg in
        c)
            CASE_ID="$OPTARG";;
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
: ${CASE_ID:='0'}
REQUEST_KCONFIG="CONFIG_I2C_DESIGNWARE_PLATFORM"
#check whether i2c_designware is configured as built-in or module
koption=`get_kconfig "$REQUEST_KCONFIG"`
if [ "$koption" == "y" ];then
  test_print_trc "$REQUEST_KCONFIG has been configured as built-in"
  I2C_DRV_PATH="/sys/bus/platform/drivers/i2c_designware"
  I2C_ACPI_ALIAS_LIST=`get_i2c_acpi_alias.sh`
elif [ "$koption" == "m" ];then
  test_print_trc "$REQUEST_KCONFIG has been configured as module"
  I2C_MODULE=`get_module_config_name.sh i2c $MACHINE`
  : ${I2C_MODULE:='i2c_designware_platform'}
  I2C_DRV_PATH="/sys/`ls -al /sys/module/$I2C_MODULE/drivers/* | awk -F' ' '{print $NF}' | sed 's/\.\.\///g'`"
  I2C_ACPI_ALIAS_LIST=`cat /lib/modules/$(uname -r)/modules.alias | grep $I2C_MODULE | grep acpi | \
  cut -d':' -f2`
else
  die "Failed to verify kernel config option"
fi
############# Do the work ###########################################
is_reg=0
case $CASE_ID in
  0)#check if driver has been loaded
    if [ -d "$I2C_DRV_PATH" ];then
      test_print_trc "$I2C_DRV_PATH does exist, i2c_designware driver succeeded to be loaded"
      exit 0
    else
      die "$I2C_DRV_PATH does not exist, i2c_designware driver load failed to be loaded"
    fi
  ;;
  1)#acpi enumeration
    if [ -d "$I2C_DRV_PATH" ];then
      for i2c_acpi_alias in $I2C_ACPI_ALIAS_LIST
      do
        ls $I2C_DRV_PATH | grep -E "$i2c_acpi_alias|$i2c_acpi_alias:[0-9A-Z][0-9A-Z]" &> /dev/null
        if [ $? -eq 0 ];then
          test_print_trc "I2C device $i2c_acpi_alias has been registered,\
            name is $(cat "$I2C_DRV_PATH"/"$i2c_acpi_alias"*/i2c*/name)"
          is_reg=$((is_reg+1))
        fi
      done
      #If $I2C_ACPI_ALIAS_LIST is empty it means that no i2c slave devices are connected
      #is_req will stay 0
      if [ $is_reg -eq "0" ];then
        test_print_trc "None i2d device has been register in $I2C_DRV_PATH"
        exit 2
      fi
    else
      die "$I2C_DRV_PATH does not exist, i2c_designware driver failed to be loaded"
    fi
  ;;
  2)#check if the device is matched
    if [[ -n "${I2C_DEV_ID}" ]]; then
      for dev_id in ${I2C_DEV_ID[*]}
      do
      lspci -nnv | grep -i "$dev_id"
      if ! lspci -nnv | grep -i "$dev_id"; then
        test_print_trc "New device id for device: ${dev_id} not match expectation, check Failed"
        exit 1
      fi
      done
    else
      test_print_trc "No I2C_DEV_ID info for platform ${PLATFORM}, " \
      "please check and add it to parameter files ${PLATFORM}"
    fi
  ;;
  *)
  ;;
esac

