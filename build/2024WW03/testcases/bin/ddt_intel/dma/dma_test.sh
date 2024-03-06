#! /bin/bash
#
# Copyright (C) 2015-2019 Intel - http://www.intel.com/
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
# @desc Script to run dma test

source "common.sh"

############################# Global variables ################################
DMA_SYSFS_DIR="/sys/class/dma"
DMA_MODULE="dmatest"
############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
    usage: ./${0##*/}  [-l TEST_LOOP] [-t TESTCASE_ID] [-p THREADS] [-i ITERATIONS] [-b BUFF_SIZE] [-c DMA_CH]
    -l TEST_LOOP  test loop
    -t TESTCASE_ID test case id, which case to be run
    -p THREADS how many threads use dma
    -i ITERATIONS transfer for how many times
    -b BUFF_SIZE DMA buffer size
    -c DMA_CH which channel to be test
    -h Help   print this usage
EOF
  exit 0
}

dma_sysfs_drv_check() {
  dma_chs=$(ls $DMA_SYSFS_DIR)
  [ -z "$dma_chs" ] && {
    test_print_err "No dma controller is registered under $DMA_SYSFS_DIR"
    return 1
  }
  for dma_ch in $dma_chs; do
    drv_path=$(readlink -e $DMA_SYSFS_DIR/$dma_ch/device/driver)
    if [ -d $drv_path ]; then
      test_print_trc "dma's driver is register, path is $drv_path"
    else
      test_print_err "dma's driver is not register, path is $drv_path"
      return 1
    fi
  done
}

dma_sysfs_acpi_enum() {
  dma_chs=$(ls $DMA_SYSFS_DIR)
  [ -z "$dma_chs" ] && {
    test_print_err "No dma controller is registered under $DMA_SYSFS_DIR"
    return 1
  }
  for dma_ch in $dma_chs; do
    dev_acpi_alias=$(readlink -e $DMA_SYSFS_DIR/$dma_ch/device)
    #enumeration under acpi folder
    if [ -d $dev_acpi_alias ]; then
      test_print_trc "DMA device $dev_acpi_alias, acpi enumeration succeeded"
    else
      test_print_err "DMA device $dev_acpi_alias, acpi enumeration failed"
      return 1
    fi
  done
}

dma_mem2mem_copy_test() {
  [ $# -ne 1 ] && return 1
  dma_ch=$1
  lsmod | grep dmatest
  [ $? -eq 0 ] && modprobe -r $DMA_MODULE
  #get timestamp
  lasttime=$(dmesg | tail -1 | cut -d']' -f1 | sed 's/.*\[\|\s//g')
  modprobe "$DMA_MODULE" run="$THREAD" iterations="$ITERATION" wait=1 test_buf_size="$BUFF_SIZE" channel="$dma_ch" || {
    test_print_err "Failed to modprobe $DMA_MODULE"
    return 1
  }
  #dmesg then delete lines before $lasttime
  result=$(dmesg | sed "1,/$lasttime/d" | grep dmatest | grep -w "0 failures")
  modprobe -r $DMA_MODULE
  [ -z "$result" ] && {
    test_print_err "DMA mem2mem copy failed, dmesg is:$(dmesg | sed "1,/$lasttime/d")"
    return 1
  }
}

############################### CLI Params ###################################
while getopts :l:t:p:i:b:c:h arg; do
  case $arg in
    l)  TEST_LOOP="$OPTARG";;
    t)  CASE_ID="$OPTARG";;
    p)  THREAD="$OPTARG";;
    i)  ITERATION="$OPTARG";;
    b)  BUFF_SIZE="$OPTARG";;
    c)  DMA_CH="$OPTARG";;
    h)  usage;;
    :)  test_print_err "$0: Must supply an argument to -$OPTARG."
        exit 1
    ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage
        exit 1
    ;;
  esac
done

########################### DYNAMICALLY-DEFINED Params ########################
: ${TEST_LOOP:='1'}
: ${THREAD:='1'}
: ${ITERATION:='10000'}
: ${BUFF_SIZE:='4096'}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
test_print_trc "STARTING DMA Test... "
test_print_trc "TEST_LOOP:${TEST_LOOP}"

# test loop
i=0
while [ $i -lt $TEST_LOOP ]; do
  test_print_trc "===LOOP: $i==="
  case $CASE_ID in
    1)
      dma_sysfs_drv_check || die "Failed to check dma driver under sysfs"
    ;;
    2)
      dma_sysfs_acpi_enum || die "Failed to acpi enumration dma devices under sysfs"
    ;;
    3)
      #Check if CONFIG_DMATEST has been configured as module.
      kconfig=$(get_kconfig "CONFIG_DMATEST") || die "CONFIG_DMATEST is not enabled"
      if [ $kconfig != 'm' ]; then
        test_print_err "Kernel config CONFIG_DMATEST were not configured as module"
        exit 2
      fi
      #mem2mem copy
      #if no DMA_CH argument, we test all of them
      if [ -z "$DMA_CH" ]; then
        dma_chs=$(ls $DMA_SYSFS_DIR)
        [ -z "$dma_chs" ] && {
          test_print_err "No dma controller is registered under $DMA_SYSFS_DIR"
          exit 2
        }
        for dma_ch in $dma_chs; do
          dma_mem2mem_copy_test "$dma_ch" || die "Failed to test dma mem2mem copy"
        done
      else
        #DMA_CH is not empty, test is
        dma_mem2mem_copy_test "$DMA_CH" || die "Failed to test dma mem2mem copy"
      fi
    ;;
  esac
  i=$((i+1))
done  # while loop
