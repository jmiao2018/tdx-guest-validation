#!/bin/bash

###############################################################################
#
# Copyright (C) 2016 Intel - http://www.intel.com/
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
###############################################################################

############################ CONTRIBUTORS #####################################

# Author: sylvainx.heude@intel.com
#
# Jan, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from 'otc_kernel_qa-tp_tc_scripts_linux_core_kernel' project to
#     LCK project since France stop working on it. GDC started work on it.
#   - Modified script in order to align it to LCK repository standard.
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from LCK-GDC suite to LTP-DDT.
#   - Added 'source ec_paths.sh' to export and use driver paths.

############################ DESCRIPTION ######################################

# @desc    Look for ec driver path in '/sys/bus/acpi/drivers/'
# @params
# @return
# @history 2016-01-10: Ported from LCK suite to LCK-DGC suite.
# 		       Modified script to aling it to LCK-GDC suite.
# @history 2016-12-01: Integrated to LTP-DDT.
#		       Added 'source ec_paths.sh'

############################ FUNCTIONS ########################################

############################ DO THE WORK ######################################

source "common.sh"
source "ec_paths.sh"

# LOOK FOR EC DIRECTORY
do_cmd ls -l $EC_DIR
if [ $? -eq 0 ]; then
  test_print_trc "Path to EC directory exists"
else
  die "Path to EC directory not found"
fi
