#!/bin/bash
#
# - linux
#
#   Copyright (c) Intel, 2015
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2.1 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
#
# File:         Precondition_enable_pci.sh
#
# Description:
#
# Author(s):    Helia Correia <helia.correia@intel.com>
#
# Date:         2015-07-15
#
#

# Final code result of test is PASS=0 / FAIL=1 / BLOCK=2
result=2

sudo lshw -class bus -enable pci
ret_val_1=$?

sudo lshw -enable pci
ret_val_2=$?

if [ "$ret_val_1" == 0 ] && [ "$ret_val_2" == 0 ]; then
	result=$ret_val_1
fi

exit $result
