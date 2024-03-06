#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2017, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         cpu_fred_bat.sh
#
# Description:  it's for cpu fred bat test
#
# Authors:      Shan Kang - shan.kang@intel.com
#
# History:      April 21 2023 - created - Shan Kang

# @desc check fred is support or not
# @returns Fail if return code is non-zero

source "common.sh"
source "functions.sh"
source "cpu_common.sh"

: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

fred_cmdline_enable() {
  do_cmd "grep -q 'fred' '/proc/cmdline'"
}

fred_test_module_install() {
    DIR_DDT_INTEL=$LTPROOT/testcases/bin/ddt_intel/
    DIR_LKVS=$DIR_DDT_INTEL/lkvs

    cd $DIR_DDT_INTEL
    tar xvf lkvs.tar
    cd lkvs
    make docker_image
    make docker-build fred
    #cp fred/fred_test_driver.ko $DIR_DDT_INTEL/

    driver_file=$DIR_DDT_INTEL/fred_test_driver.ko
    do_cmd "insmod $driver_file"
    sleep 1
    do_cmd "lsmod | grep 'fred_test_driver'"
}

fred_enable_cr4_test() {
    do_cmd " echo \"fred_enable 1\" > /dev/fred_test_device"
    dmesg_check "fred_enable test PASS" "$CONTAIN"
}

fred_bat_test() {
  case $TEST_SCENARIO in
    fred_cmdline)
      fred_cmdline_enable
      ;;
    fred_test_module)
      fred_test_module_install
      ;;
    fred_enable_cr4)
      fred_enable_cr4_test
      ;;
    esac
  return 0
}

while getopts :t:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
      usage && exit 0
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

fred_bat_test
# Call teardown for passing case
exec_teardown
