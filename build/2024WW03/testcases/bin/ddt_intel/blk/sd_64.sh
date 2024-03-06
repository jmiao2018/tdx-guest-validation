#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate USB component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Jul. 25, 2017 - (Ammy Yi)Creation


# @desc This script verify usb typec test
# @returns Fail the test if return code is non-zero (value set not found)

source "usb_common.sh"

# verify if sdcard support 64-bit DMA capability
sdcard_dma_check() {
  dmesg | grep "Missing 64-bit DMA capability"
  [[ $? -ne 0 ]] || die "Missing 64-bit DMA capability for sdcard"
}

sdcard_dma_check
