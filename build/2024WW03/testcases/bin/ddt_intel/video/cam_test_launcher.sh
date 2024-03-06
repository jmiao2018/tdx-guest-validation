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
###############################################################################

# @desc    Launch camera tests like: v4l2 ioclts, video capture, etcetera.
# @params  [-t TEST_TYPE] [-a TEST_ARGS] [-l LOOP_CNT] [-c CAM_SIDE]
# @returns None
# @history 2015-06-24: First version

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
  usage: ./${0##*/} <-t TEST_TYPE> <-a TEST_ARGS> <-l LOOP_CNT> <-c CAM_SIDE>
  -a TEST_ARGS    Sring containing all options for the especified TEST_TYPE.
  -c CAM_SIDE     Which camera to test: front / rear.
  -l LOOP_CNT     Number of itereations the test will be run.
  -t TEST_TYPE    Type of test to run which may be one of:
                    -V4L2_CAP   To launch a V4L2 capture test using v4l2_capture_tests tool.
  -h Help         Print this usage
EOF
  exit 0

}

############################ Script Variables ##################################
CUR_TEST_ARGS=""
CUR_TEST_TYPE=""
CUR_LOOP_CNT=""
CUR_CAM_SIDE=""
CUR_ISP=""
CAP_DEV=""
OVERLAY_CAP_DEV=""
IDX=0

################################ CLI Params ####################################
while getopts :a:c:d:l:t:h arg
do
  case $arg in
    a)  TEST_ARGS_ARRAY+=( "$OPTARG" );;
    c)  TEST_CAM_SIDE_ARRAY+=( "$OPTARG" );;
    l)  LOOP_CNT_ARRAY+=( "$OPTARG" );;
    t)  TEST_TYPE_ARRAY+=( "$OPTARG" );;
    h)  usage;;
    :)  die "$0: Must supply an argument to -$OPTARG.";;
   \?)  die "Invalid Option -$OPTARG ";;
  esac
done

############################ USER-DEFINED Params ###############################

# Define default values for variables being overriden

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
TEST_CAM_SIDE_ARRAY_SIZE="${#TEST_CAM_SIDE_ARRAY[@]}"

########################### REUSABLE TEST LOGIC ###############################
[ $TEST_ARGS_ARRAY_SIZE -ne $TEST_TYPE_ARRAY_SIZE ] && die "Arguments missing !"

[ $TEST_TYPE_ARRAY_SIZE -ne $LOOP_CNT_ARRAY_SIZE ]  && die "Arguments missing !"

[ $LOOP_CNT_ARRAY_SIZE -ne $TEST_CAM_SIDE_ARRAY_SIZE ] && \
  die "Arguments missing !"


for CUR_TEST_TYPE in "${TEST_TYPE_ARRAY[@]}"
do

  # Get cmd's
  CUR_TEST_ARGS="${TEST_ARGS_ARRAY[$IDX]}"
  CUR_LOOP_CNT="${LOOP_CNT_ARRAY[$IDX]}"
  CUR_CAM_SIDE="${TEST_CAM_SIDE_ARRAY[$IDX]}"

  # Prepare test custom arguments
  case $SOC in
    baytrail)
      CUR_ISP="atomisp2"
      CAP_DEV=`get_video_node.sh -d "n" -c "$CUR_CAM_SIDE"`
    ;;
    sofia|sofia-lte)
      CUR_ISP="cifisp20"
      OVERLAY_CAP_DEV=`get_video_node.sh -d "n" -c "$CUR_CAM_SIDE" -o "y"`
      CAP_DEV=`get_video_node.sh -d "n" -c "$CUR_CAM_SIDE"`
    ;;
    *)  CUR_ISP="";;
  esac

  # Exec test
  while [ $CUR_LOOP_CNT -gt 0 ]
  do
    test_print_trc "CUR_LOOP_CNT = $CUR_LOOP_CNT   CUR_TEST_TYPE = $CUR_TEST_TYPE"
    test_print_trc "CUR_TEST_ARGS = ${CUR_TEST_ARGS}"
    test_print_trc "CUR_CAM_SIDE = $CUR_CAM_SIDE"
    test_print_trc "CAP_DEV = $CAP_DEV"

    case $CUR_TEST_TYPE in
      V4L2_CAP)  do_cmd v4l2_capture_tests \
                   "-isp $CUR_ISP -device_cap $CAP_DEV" \
                   "-device_cap_overlay $OVERLAY_CAP_DEV $CUR_TEST_ARGS"
      ;;
         *)  die "Invalid option $CUR_TEST_TYPE" ;;
    esac
    CUR_LOOP_CNT=$(( $CUR_LOOP_CNT - 1 ))
  done
  IDX=$(( $IDX + 1 ))
done
test_print_trc "Test Stat: [PASS]"
exit 0
