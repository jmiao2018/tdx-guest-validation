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
#     LCK project.
#   - Modified script in order to align it to LCK repository standard.
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from LCK-GDC suite to LTP-DDT.

############################ DESCRIPTION ######################################

# @desc This script verify EC reference count.
# @params
# @return
# @history 2016-01-10: Ported from LCK suite to LCK-GDC suite.
#                      Uptaded script to use correctly in LCK-GDC suite.
# @history 2016-12-01: Integrated to LTP-DDT.
#                      Added 'source ec_paths.sh'.

############################ FUNCTIONS ########################################

############################ DO THE WORK ######################################

source "common.sh"
source "ec_paths.sh"

# LOOK FOR "decrease command"
DEC=$(dmesg | grep -i "decrease command" | wc -l)
test_print_trc  "DEC = $DEC"

# LOOK FOR "increase command"
INC=$(dmesg | grep -i "increase command" | wc -l)
test_print_trc "INC = $INC"

# CHECK IF "decrease command" AND "increase command" WAS FOUND
if [ "$DEC" -lt "1" ] && [ "$INC" -lt "1" ]; then
  test_print_trc "no decrease nor increase command found, be sure to have enabled EC_DEBUG option in drivers/acpi/ec.c before compiling kernel"
  exit 1
fi

# GET THE DIFFERENCE BETWEEN "decrease command" AND "increase command"
DIFF=$((DEC-INC))
VALDIFF=${DIFF#-}
test_print_trc "DIFF = $VALDIFF"

# FOR EVERY "decrease command" WE NEED AN "increase command", SO THE DIFFERENCE
# MUST BE 0
if [ "$VALDIFF" -ge "1" ]; then
  die "EC transactions should be 0"
else
  test_print_trc "EC transactions equal to 0"
fi
