#!/bin/bash
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#   -Changed shebang and script description.
#   -Fixed identation.
#   -Added logic to obtain IRDA's video device nodes correctly.
#   -Added option to get either front to rear capture device
###############################################################################
# @desc Obtain v4l2 device nodes (capture and display).
# @params d) y/n
# @returns Display/capture device node
# @history 2011-03-05: First version
# @history 2015-06-02: Ported to work with IA.

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage()
{
cat <<-EOF >&1
        usage: ./${0##*/} [-c CAPTURE_SIDE] [-d DISPLAY] [-i INTEL] [-o OVERLAY]
        -c CAPTURE_SIDE choose among from / rear camera for IA.
        -d DISPLAY  	  y/n depending on whether a display or capture device driver node is required.
        -o OVERLAY      y/n wether overlay video device is needed.
        -h Help         print this usage.
EOF
exit 0
}

############################ Script Variables ##################################
DISPLAY="y"
INTEL=0
VIDEO_DEV_PREFIX="/dev/video"
CAM_DEV_NODE_STR=""
DISP_DEV_NODE_STR=""
OVERLAY="n"
FRONT_CAM_IDX=0
REAR_CAM_IDX=0

################################ CLI Params ####################################
# Please use getopts
while getopts  :c:d:o:h arg
do case $arg in
  c)  CAPTURE_SIDE="$OPTARG";;
  d)  DISPLAY="$OPTARG";;
  o)  OVERLAY="$OPTARG";;
  h)  usage;;
  :)  die "$0: Must supply an argument to -$OPTARG.";;
 \?)  die "Invalid Option -$OPTARG ";;
esac
done

############################ USER-DEFINED Params ###############################
# Try to avoid defining values here, instead see if possible
# to determine the value dynamically. ARCH, DRIVER, SOC and MACHINE are
# initilized and exported by runltp script based on platform option (-P)

# Define default values for variables being overriden

case $ARCH in
   x86)  INTEL=1;;
  omap)  INTEL=0;;
esac
case $DRIVER in
esac
case $SOC in
  sofia|sofia-lte)
    INTEL_VIDEO_DEVS_PER_CAM=2
    [ "$OVERLAY" = "n" ] && CAM_DEV_NODE_STR="CIF ISP20 MP"
    [ "$OVERLAY" = "y" ] && CAM_DEV_NODE_STR="CIF ISP20 SP"
  ;;
  baytrail)
    INTEL_VIDEO_DEVS_PER_CAM=4
    CAM_DEV_NODE_STR="ATOMISP ISP CAPTURE output"
    DISP_DEV_NODE_STR="ATOMISP ISP VIEWFINDER output"
  ;;
esac
case $MACHINE in
esac

########################### DYNAMICALLY-DEFINED Params #########################
# Try to use /sys and /proc information to determine values dynamically.
# Alternatively you should check if there is an existing script to get the
# value you want

########################### REUSABLE TEST LOGIC ###############################

# The driver names are for omap3 and IA.
NODE=0
CAPTURE_DEV_CNT=0
INTEL_CAMS_PRESENT=`ls /sys/class/video4linux/video?/name | wc -l`
INTEL_CAMS_PRESENT=$(( $INTEL_CAMS_PRESENT / $INTEL_VIDEO_DEVS_PER_CAM ))
INTEL_CUR_CAM=1


# Search v4l2 device node
for devicenode in $(echo `ls /sys/class/video4linux/video?/name`)
do
  ISP_DRIVER=`cat /sys/class/video4linux/video$NODE/name`
  # Retrieve Intel device node
  if [ $INTEL -eq 1 ]; then

    # Have we passed front cam yet ?
    [ $NODE -eq $INTEL_VIDEO_DEVS_PER_CAM ] && \
      INTEL_CUR_CAM=$(( $INTEL_CUR_CAM + 1 ))

    # Retrieve display device node
    if [ "$DISPLAY" == "y" -a "$ISP_DRIVER" == "$DISP_DEV_NODE_STR" ]; then
      case $SOC in
        sofia|sofia-lte)
          [ "$CAPTURE_SIDE" == "front" -a $INTEL_CUR_CAM -eq 2 ] && \
          [ "$OVERLAY" = "n" ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0

          [ "$CAPTURE_SIDE" == "rear" -a $INTEL_CUR_CAM -eq 1 ] && \
          [ "$OVERLAY" = "y" ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0
        ;;
        baytrail)
          [ "$CAPTURE_SIDE" == "front" -a $INTEL_CUR_CAM -eq 1 ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0

          [ "$CAPTURE_SIDE" == "rear" -a $INTEL_CUR_CAM -eq 2 ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0
        ;;
      esac

    # Retrieve capture device node
    elif [ "$DISPLAY" == "n" -a "$ISP_DRIVER" == "$CAM_DEV_NODE_STR" ]; then
      case $SOC in
        sofia|sofia-lte)
          [ "$OVERLAY" == "n" -a $INTEL_CUR_CAM -eq 2 ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0

          [ "$OVERLAY" == "y" -a $INTEL_CUR_CAM -eq 1 ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0
        ;;
        baytrail)
          [ "$CAPTURE_SIDE" == "front" -a $INTEL_CUR_CAM -eq 1 ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0

          [ "$CAPTURE_SIDE" == "rear" -a $INTEL_CUR_CAM -eq 2 ] && \
            echo "${VIDEO_DEV_PREFIX}$NODE" && exit 0
        ;;
      esac
    fi

  # Retrieve TI device node
  else

    # Retrieve display device node
    if [ "$DISPLAY" == "y" ];then
      if [ "$ISP_DRIVER" == "omap_vout" ];then
        DEVICE_DISP="${VIDEO_DEV_PREFIX}$NODE"
	      echo "$DEVICE_DISP"
			  exit 0
      fi

    # Retrieve capture device node
    else
      if [ "$ISP_DRIVER" == "OMAP3 ISP CCDC output" ];then
		    DEVICE_CAP="${VIDEO_DEV_PREFIX}$NODE"
        echo "$DEVICE_CAP"
			  exit 0
	    fi
    fi
  fi

  # Let's go to next device node
  NODE=$((NODE+1))
done
