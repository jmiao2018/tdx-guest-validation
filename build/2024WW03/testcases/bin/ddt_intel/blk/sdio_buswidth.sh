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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Modified mount point and R/W ops folder due to permission restriction in
#      Android rootfs, change to /data.
#     -Modify cmd's to get mmc entries in /bebugfs.
#     -Modify logic to check all bus_width in all mmc entries in /debugfs.
#     -Removed duplicated 'source' scripts.
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#     -Add parameters to get buswidht or timing specs separately.
#     -Add logic to check all timing specifications of mmc entries in /debugfs.
#	Zelin Deng <zelinx.deng@intel.com> (Intel)
#	  -Removed $BUSYBOX_DIR since it will be exported before start test
#	  -Modified way to get SDIO_INTANCE, the old way can't get the right intance
###############################################################################

# @desc Check the bus width of mmc or sdio
# @params [ -m MAX_BUSWIDTH] [ -d DEV_TYPE ][ -b ] [ -t ]
# @returns None
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-17: Ported to work with Android on IA.
# @history 2015-02-17: Add logic to get timing specs.
# @history 2015-04-27: Removed duplicated 'source' scripts.
# @history 2015-08-10: Modified to get right SDIO_INTANCE and remove unnecessary
#					   varibles

source "blk_device_common.sh"


############################# Functions #######################################
usage()
{
cat <<-EOF >&2
	usage: ./${0##*/} [ -m MAX_BUSWIDTH] [ -d DEV_TYPE ] [ -b ] [ -t ]
 	-m MAX_BUSWIDTH   Maximum bus width the sdio card support
	-d DEV_TYPE	  Device Type like 'emmc', 'mmc', etc
	-b 		  Look for bus width specifications
	-t 		  Look for timing specificacions
	-h Help           print this usage
EOF
exit 0
}
############################### CLI Params ###################################
while getopts  :m:d:b:th arg
do case $arg in
        m)      MAX_BUSWIDTH="$OPTARG";;
	d)	DEV_TYPE="$OPTARG";;
	b)	BUS="yes";;
	t)	TIME="yes";;
        h)      usage;;
        :)      test_print_trc "$0: Must supply arguments to -$OPTARG." >&2
                exit 1
                ;;

        \?)     test_print_trc "Invalid Option -$OPTARG ignored." >&2
                usage
                exit 1
                ;;
esac
done

############################ DEFAULT Params #######################
: ${MAX_BUSWIDTH:="4"}
: ${DEV_TYPE:="mmc"}

############# Do the work ###########################################
field=$(get_mnt_point_field)
DEBUGFS_MNT=`mount | grep 'debugfs' | cut -d' ' -f$field`
if [ -z "$DEBUGFS_MNT" ]; then
  DEBUGFS_MNT="$TEST_MNT_DIR/debugfs"
  mount -t debugfs debugfs $DEBUGFS_MNT
fi
# Get buswidth specs
if [ "$BUS" == "yes" ]; then
  # Get sdio buswidth specs for emmc
  if [ "$DEV_TYPE" == "emmc" ]; then
    SDIO_INSTANCES=`ls  ${DEBUGFS_MNT} | grep 'mmc[0-9]'`
    VALUE=''
    for SDIO_INSTANCE in $SDIO_INSTANCES
    do
      BUSWIDTH_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i 'bus width'`
      BUSWIDTH=`echo $BUSWIDTH_STR | awk '{print $4}' | sed 's/(//g'`

      if [ "$BUSWIDTH" -ge "$MAX_BUSWIDTH" ]; then
        VALUE="greater"
        echo "This test pass and emmc is operating at maximum bus width"
        break
      fi
    done
    if [ -z "$VALUE" ]; then
      echo "SDIO is not operating at maximum bus width: $MAX_BUSWIDTH"
    fi

  else
    # Get sdio buswidht specs for emmc
    #    1.616760] mmc0: new SDIO card at address 0001
    SDIO_INSTANCES=`ls  ${DEBUGFS_MNT} | grep 'mmc[1-9]' | cut -d':' -f1`
    SDIO_INSTANCES_COUNT=`ls  ${DEBUGFS_MNT}/mmc* | grep 'mmc[1-9]' | wc -l`
    if [ -z "$SDIO_INSTANCES" ]; then
      die "Could not find mmc instance for sdio"
    fi

    # Check Bus width on SDIO's instances
    for SDIO_INSTANCE in $SDIO_INSTANCES
    do
      BUSWIDTH_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios |grep -i 'bus width'`
      BUSWIDTH=`echo $BUSWIDTH_STR | awk '{print $4}' | sed 's/(//g'`

      if [ "$BUSWIDTH" -ge "$MAX_BUSWIDTH" ]; then
        let SDIO_INSTANCES_COUNT-=1
      else
        echo "SDIO is not operating at maximum bus width: $MAX_BUSWIDTH "
      fi
    done

    echo "This test pass and mmc is operating at maximum bus width"
  fi
# Get timing specs
elif [ "$TIME" == "yes" ]; then
  # Get timing sdio for emmc
  if [ "$DEV_TYPE" == "emmc" ]; then
    SDIO_INSTANCES=`ls  ${DEBUGFS_MNT} | grep 'mmc[0-9]'`
    VALUE=''
    for SDIO_INSTANCE in $SDIO_INSTANCES
    do
      CLOCK_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i '^clock'`
      ACTUAL_CLK_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i 'actual clock'`
      TIMING_SPEC_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i 'timing spec'`

      CLOCK=`echo $CLOCK_STR | awk '{print $2}'`
      ACTUAL_CLK=`echo $ACTUAL_CLK_STR | awk '{print $3}'`
      TIMING_SPEC=`echo $TIMING_SPEC_STR | cut -d' ' -f7,8`

      if [ "$TIMING_SPEC" != "(legacy)" ] && [ "$ACTUAL_CLK" == "$CLOCK" ]; then
        VALUE='PASS'
        echo "High Speed Timing in emmc is enabled at $ACTUAL_CLK"
        break
      fi
    done
    if [ -z "$VALUE" ]; then
      echo "High Speed Timing in emmc is not enabled. The actual clock is $ACTUAL_CLK"
    fi

  else
    # Get sdio timing specs for mmc
    #    1.616760] mmc0: new SDIO card at address 0001
	echo $DEBUGFS_MNT
    SDIO_INSTANCES=`ls  ${DEBUGFS_MNT} | grep 'mmc[1-9]' | cut -d':' -f1`
    SDIO_INSTANCES_COUNT=`ls  ${DEBUGFS_MNT} | grep 'mmc[1-9]' | wc -l`
    if [ -z "$SDIO_INSTANCES" ]; then
      die "Could not find mmc instance for sdio"
    fi

    # Check timing on SDIO's instances
    for SDIO_INSTANCE in $SDIO_INSTANCES
    do
      # Get mmc timing for sdio
      CLOCK_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i '^clock'`
      ACTUAL_CLK_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i 'actual clock'`
      TIMING_SPEC_STR=`cat ${DEBUGFS_MNT}/${SDIO_INSTANCE}/ios | grep -i 'timing spec'`

      CLOCK=`echo $CLOCK_STR | awk '{print $2}'`
      ACTUAL_CLK=`echo $ACTUAL_CLK_STR | awk '{print $3}'`
      TIMING_SPEC=`echo $TIMING_SPEC_STR | cut -d' ' -f7,8`

      if [ "$TIMING_SPEC" != "(legacy)" ] && [ "$ACTUAL_CLK" -eq "$CLOCK" ] ; then
        let SDIO_INSTANCES_COUNT-=1
      else
        echo "High Speed Timing in emmc is not enabled. The actual clock is $ACTUAL_CLK"
      fi
    done
   echo "High Speed Timing in emmc is enabled at $ACTUAL_CLK"
  fi
fi
