#!/bin/bash
###############################################################################
# Copyright (C) 2018, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################
# @Author   Hongyu, Ning <hongyu.ning@intel.com>
#
# Nov, 19, 2018. Hongyu, Ning <hongyu.ning@intel.com>
#     - Initial version, calling spitest binary to execute different spi device test
#     - Revise to check spitest return value and stop test if it's not 0

############################ DESCRIPTION ######################################

# @desc     This script is based on spitest binary to deploy different
#           spi configurations and execute data packet transferring test
# @returns
# @history  2018-11-19: First version
#           2019-01-09: Revision to check spitest return value

############################# FUNCTIONS #######################################
usage() {
 cat <<-EOF
 usage: ./${0##*/} [-d DEVICE] [-r a|b|c|d|e CASE] [-h Help]
 -d DEVICE      DEVICE to test
 -r a|b|c|d|e   CASE to run
 -h Help        print this usage
EOF
}

run_test() {
  local bfsize=${1:-16}
  local speed=${2:-1000000}
  local mode=${3:-0}
  local width=${4:-8}
  local device=${5:-$dev}
  test_print_trc "Transferring ${bfsize} Bytes: "
  spitest -q -m $mode -b $bfsize -s $speed -l -w $width $device >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    test_print_trc "transfer ${bfsize}Bytes@${speed}Hz in mode${mode} with word size ${width} on ${device} [SUCCESS]"
  else
    test_print_trc "transfer ${bfsize}Bytes@${speed}Hz in mode${mode} with word size ${width} on ${device} [FAIL]"
    return 1
  fi
}

run_all_data_size_test() {
  local speed=$1
  local mode=$2
  local width=$3
  local device=$4
  test_print_trc "Running tests on ${dev}@${speed}Hz"
  for i in $(seq 1 $bufsize); do
    run_test $i $speed $mode $width $device || die "spi test fail on data size $i"
  done
}

run_pm_status_test() {
# Check if we have enough tools to perform the test
udevadm --help > /dev/null 2>&1 || return 0

upath=$(udevadm info --query=path --name=$dev)
rpm_path=$(echo $upath | sed 's!/spi_master/.*!/power/runtime_status!')
rpm_status=$(cat /sys/$rpm_path)

test_print_trc "Runtime PM status check: "
if [ "$rpm_status" = "suspended" ]; then
  test_print_trc "[SUCCESS] ($rpm_status)"
  exit 0
else
  test_print_trc "[FAIL] ($rpm_status)"
  exit 1
fi
}

run_final_test() {
  # Run one more transfer to return the device to the default state
  test_print_trc "One more 32Bytes@1MHz in mode 0 of 8-bit width transfer on $DEVICE"
  run_test 32 1000000 0 8 $DEVICE || die "spi test fail on final test 32Bytes@1MHz in mode 0 of 8-bit word size"
  # Wait a bit and check the device runtime PM status. It should be suspended by now.
  test_print_trc "Wait for 1 sec and check the spi device runtime PM status, 'suspended' expected"
  sleep 1
  run_pm_status_test
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"
source "spi_common.sh"

while getopts :d:r:h arg; do
  case $arg in
    d)
      DEVICE=$OPTARG
      ;;
    r)
      TESTCASE=$OPTARG
      ;;
    h)
      usage && exit 0
      ;;
    :)
      test_print_err "Must supply an argument to -$OPTARG."
      usage && exit 1
      ;;
    \?)
      test_print_err "Invalid Option -$OPTARG ignored."
      usage && exit 1
      ;;
  esac
done

bufsize_param=/sys/module/spidev/parameters/bufsiz

if [ "$SPI_FUNC" = "true" ]; then
  if [ -f $bufsize_param ]; then
    bufsize=$(cat /sys/module/spidev/parameters/bufsiz)
  else
    die "spidev module not present, please check bios setting or kconfig to enable /dev/spidevx.x"
  fi
else
  die "spi device is not supported on $PLATFORM, \
       please check bios setting and kconfig, \
       if bios setting not supported, \
       add the spi_func_tests cases into skip file"
fi

for i in "$DRV_SYS_PATH_1"/*;do
  if [ $DEVICE = /dev/$(basename $i) ]; then
    test_print_trc "spi device $DEVICE found for test"
  else
    test_print_trc "switch spi device to /dev/$(basename $i) for test"
    DEVICE="/dev/$(basename $i)"
  fi
  break
done

dev=${DEVICE:-/dev/spidev0.0}

case $TESTCASE in
  a)
    #run test with different speed (MHz)
    test_print_trc "Run spitest with different speed (1-25MHz)"
    for i in $(seq 1 25); do
      run_test 32 $(expr $i \* 1000000) 0 8 $DEVICE || die "spi test fail on speed $i MHz"
    done
    run_final_test
    ;;
  b)
    #run test with different data size (Bytes)
    test_print_trc "Run spitest with different data size (1-${bufsize}Bytes)"
    run_all_data_size_test 5000000 0 8 $DEVICE
    run_final_test
    ;;
  c)
    #run test with different modes (0~3)
    test_print_trc "Run spitest with different modes (0-3)"
    for i in $(seq 0 3); do
      run_test 256 15000000 $i 8 $DEVICE || die "spi test fail on mode $i"
    done
    run_final_test
    ;;
  d)
    #run test with different widths (word size in bits)
    test_print_trc "Run spitest with different widths (word size in bits, 8, 16, 32)"
    width_array=(8 16 32)
    for i in "${width_array[@]}"; do
      run_test 2048 25000000 0 $i $DEVICE || die "spi test fail on word size $i"
    done
    run_final_test
    ;;
  e)
    #run test of data size below and over bufsize parameter setting
    test_print_trc "Run spitest with data size below and over bufsize parameter: ${bufsize}, for over size, spitest should be FAIL as expected"
    run_test $(expr $bufsize / 2) 5000000 0 8 $DEVICE || die "spi test fail on data size ${bufsize}/2"
    run_test $bufsize 10000000 0 8 $DEVICE || die "spi test fail on data size ${bufsize}"
    run_test $(expr $bufsize + 1) 5000000 0 8 $DEVICE && die "spi test fail on data size limitation ${bufsize}+1"
    run_test $(expr $bufsize + 16) 15000000 0 8 $DEVICE && die "spi test fail on data size limitation ${bufsize}+16"
    run_test $(expr $bufsize \* 2) 25000000 0 8 $DEVICE && die "spi test fail on data size limitation ${bufsize}*2"
    run_final_test
    ;;
  :)
    test_print_err "Must specify the test case option by [-r a|b|c|d|e]"
    usage && exit 1
    ;;
  \?)
    test_print_err "Input test case option $CASE is not supported"
    usage && exit 1
    ;;
esac
