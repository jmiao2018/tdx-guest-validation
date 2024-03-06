#!/bin/bash
###############################################################################
# Copyrigh (C) 2015 Intel - http://www.intel.com
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
# @params mount point (example "/mnt/nfs_mount")
# @history 2013-08-13: First version
#          2015-11-09: refactor the script

source "eth_common.sh"

#get argments. -m for mount point of nfs, -s for nfs server ip address
#-r for nfs server root directory
while getopts m:s:r arg
do
	case $arg in
		m)
			mount_point="$OPTARG"
		;;
		s)
			nfs_server="$OPTARG"
		;;
		r)
			nfs_root_path="$OPTARG"
		;;
	esac
done
#define default value
: ${mount_point:="/nfs_mount"}
#default value defined in eth_common.sh
: ${nfs_server:="$NFS_SERVER"}
: ${nfs_root_path:="$NFS_ROOT_PATH"}

#if mount point does not exist, create it
[ ! -d $mount_point ] && mkdir -p $mount_point
#if the mount point has been mounted, umount it
mount | grep -q "$mount_point" && umount -l "$mount_point"
#mount the nfs to mount point
mount -t nfs -o nolock,addr=$nfs_server $nfs_server':'$nfs_root_path $mount_point
#only succeeded returns 0, or some other values may be returned.such as 32 for timeout
if [ $? -ne 0 ];then
	die "mount nfs $nfs_server:$nfs_root_path to $mount_point failed"
else
	exit 0
fi
