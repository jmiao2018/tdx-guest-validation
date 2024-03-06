#!/bin/bash
###############################################################################
# Copyright (C) 2013 Texas Instruments Incorporated - http://www.ti.com/
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

# @desc prepares target by setting up nfs_mount
# @params mount_point (example "/mnt/nfs_mount)
# @history 2013-08-13: First version

source "eth_common.sh"
if [ -n "$1" ]
then
  mount_point=$1
  mount | grep $mount_point && umount -l $mount_point
  rm -rf $mount_point
else
  die "Please provide argument: ${0##*/} <MOUNT POINT>"
fi
