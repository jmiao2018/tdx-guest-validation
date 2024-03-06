#!/bin/bash

###############################################################################
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
###############################################################################
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -First version.
#     -Added three new varibales to add extra arguments for certain scripts to
#      support for SoFIA SoC's.
###############################################################################

# @desc Launch SD/eMMC tests like: mount/umount dev_node, format partitions,
#       read/write operations, etc...
# @params [-t TEST_TYPE] [-a TEST_ARGS]
# @returns None
# @history 2015-05-05: First version.
# @history 2015-09-28: Added support for SoFIA SoC's.

# Import (), die() and other functions
source "common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
  usage: ./${0##*/} <-t TEST_TYPE> <-a TEST_ARGS> <-l LOOP_CNT>
    -a TEST_ARGS  Sring containing all options for the especified TEST_TYPE.
    -l LOOP_CNT   Number of itereations the test will be run.
    -t TEST_TYPE  Type of test to run which may be one of:
      -DDRW   To launch a read write test using 'dd' cmd using blk_device_dd_readwrite_test.sh script.
      -FSCK   To check a blk dev_node / partition 's FS health.
      -MKFS   To format a blk dev_node / partition with certain FS.
      -MNT    To mount a certain dev_node with certain FS type.
      -FDISK  To format a blk dev_node with specific partition layout.
      -PERF   To launch a performance test using blk_device_filesystem_perf_test.sh script.
      -SDIO   To launch a buswidth check test using sdio_buswidth.sh script.
      -TARB   To launch a tarball decompression test using blk_device_tarball_write_test.sh script.
      -UMNT   To umount a mounted FS.
      e.g.
      $0  -t "DDRW"  -a "-f 'ext3' -b '1' -c '1' -d 'mmc'" -l 4
      Multiple TEST_TYPE's  can be run.
      e.g.
      $0  -t "PART" -a "-p '2' -e '1' -l '2'" -t "MKFS" -a "-f 'vfat' -d '/dev/block/mmcblk1p1'" -l 3
      Tests will be executed in left to right order.
    -h Help         Print this usage
EOF
  exit 0
}

############################ Script Variables ##################################
CUR_TEST_ARGS=""
CUR_TEST_TYPE=""
CUR_LOOP_CNT=""
IDX=0
DDRW_EXTRA_AGRS=""
PERF_EXTRA_ARGS=""
TARB_EXTRA_ARGS=""

################################ CLI Params ####################################
while getopts :a:l:t:h arg; do
case "${arg}" in
  a)   TEST_ARGS_ARRAY+=( "$OPTARG" ) ;;
  l)   LOOP_CNT_ARRAY+=( "$OPTARG" ) ;;
  t)   TEST_TYPE_ARRAY+=( "$OPTARG" ) ;;
  h)   usage ;;
  :)   die "$0: Must supply an argument to -$OPTARG.";;
  \?)  die "Invalid Option -$OPTARG ";;
  esac
done

############################ USER-DEFINED Params ###############################
case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
esac

########################### DYNAMICALLY-DEFINED Params #########################
TEST_ARGS_ARRAY_SIZE="${#TEST_ARGS_ARRAY[@]}"
LOOP_CNT_ARRAY_SIZE="${#LOOP_CNT_ARRAY[@]}"
TEST_TYPE_ARRAY_SIZE="${#TEST_TYPE_ARRAY[@]}"

########################### REUSABLE TEST LOGIC ###############################
[[ "${TEST_ARGS_ARRAY_SIZE}" -ne "${TEST_TYPE_ARRAY_SIZE}" ]] \
  && die "Arguments missing !"

[[ "${TEST_TYPE_ARRAY_SIZE}" -ne "${LOOP_CNT_ARRAY_SIZE}" ]]  \
  && die "Arguments missing !"

for CUR_TEST_TYPE in "${TEST_TYPE_ARRAY[@]}"; do

  # Get cmd's
  CUR_TEST_ARGS="${TEST_ARGS_ARRAY[$IDX]}"
  CUR_LOOP_CNT="${LOOP_CNT_ARRAY[$IDX]}"

  # Exec test
  while [[ "${CUR_LOOP_CNT}" -gt 0 ]]; do
    test_print_trc "CUR_LOOP_CNT = ${CUR_LOOP_CNT}  CUR_TEST_TYPE = ${CUR_TEST_TYPE}"
    test_print_trc "CUR_TEST_ARGS = ${CUR_TEST_ARGS}"

    # Add extra args when needed
    case "${SOC}" in
      # Nothing to add for BYT
      baytrail)  ;;
      sofia|sofia-lte)
        # On SoFIA platforms we need to skip mount and format
        case "${CUR_TEST_TYPE}" in
          DDRW)  DDRW_EXTRA_AGRS="-S" ;;
          PERF)  PERF_EXTRA_ARGS="-K" ;;
          TARB)  TARB_EXTRA_ARGS="-K" ;;
        esac
      ;;
    esac

    case "${CUR_TEST_TYPE}" in
      DDRW)  do_cmd blk_device_dd_readwrite_test.sh "${CUR_TEST_ARGS}" "${DDRW_EXTRA_AGRS}" ;;
      FSCK)  do_cmd blk_device_filesystem_check.sh "${CUR_TEST_ARGS}" ;;
      MKFS)  do_cmd blk_device_erase_format_part.sh "${CUR_TEST_ARGS}" ;;
      MNT)   do_cmd blk_device_do_mount.sh "${CUR_TEST_ARGS}" ;;
      FDISK) do_cmd blk_device_create_erase_partition.sh "${CUR_TEST_ARGS}" ;;
      PERF)  do_cmd blk_device_filesystem_perf_test.sh "${CUR_TEST_ARGS}" "${PERF_EXTRA_ARGS}" ;;
      SDIO)  do_cmd sdio_buswidth.sh "${CUR_TEST_ARGS}" ;;
      TARB)  do_cmd blk_device_tarball_write_test.sh "${CUR_TEST_ARGS}" "${TARB_EXTRA_ARGS}" ;;
      UMNT)  do_cmd blk_device_umount.sh "${CUR_TEST_ARGS}" ;;
         *)  die "Invalid option ${CUR_TEST_TYPE}"
    esac
    CUR_LOOP_CNT=$(( CUR_LOOP_CNT - 1 ))
  done
  IDX=$(( IDX + 1 ))
done
test_print_trc "Test Stat: [PASS]"
exit 0
