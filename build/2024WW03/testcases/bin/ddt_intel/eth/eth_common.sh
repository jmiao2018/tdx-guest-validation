#!/bin/bash
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
################################################################################
#
# This script defines some general variables that may be used by differenct scripts
#
# @history 2015-11-05: First version

source "common.sh"

#Define common global varifies
#network sysfs path
NETWORK_SYSFS_PATH="/sys/class/net"
#network sysfs names pattern
NETWORK_SYSFS_NAME_PATTERNS="^eno|^ens|^enp|^enx|^eth"

#procfs of virtual lan
VLAN_PROCFS_PATH="/proc/net/vlan"

# Default NFS Server address and export directory.
# They can be overwriten in the param file, which is platform dependent.
: ${NFS_SERVER:="inn"}
: ${NFS_ROOT_PATH:="/export/test"}
