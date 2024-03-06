#!/bin/bash
#
# - linux
#
#  (c) Intel Corporation 2015
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
#
#  Author: Christophe.Prigent@intel.com
#
#  Version: 0.1
#
#

mem_total=$(free |grep Mem |grep -oE [0-9]+ |head -n 1);
swap_size=$(free |grep Swap |grep -oE [0-9]+ |head -n 1);

#We check swap size is greater than or equal to memory size
if [[ $swap_size -ge $mem_total ]]; then
	echo 0
else
	echo 1
fi
