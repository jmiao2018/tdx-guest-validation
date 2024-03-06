#!/bin/bash
#
# - linux
#
#  (c) Intel Corporation 2014 - 2015
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

#We read the image and memory sizes
image_size=$(cat /sys/power/image_size);
mem_total=$(cat /proc/meminfo | grep MemTotal | grep -oE [0-9]+);

#Conversion to bytes
let mem_total=$mem_total*1000;

#image size + and - 3%
let high_limit=$image_size+$image_size*3/100;
let low_limit=$image_size-$image_size*3/100;

let check=$mem_total*2/5;

#We check: image size -3% < 2/5 memory size < image size +3%
if [[ $check -gt $low_limit ]] && [[ $check -lt $high_limit ]]; then
	echo 0
else
	echo 1
fi
