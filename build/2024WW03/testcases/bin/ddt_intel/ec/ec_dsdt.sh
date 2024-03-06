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

# Jan, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from 'otc_kernel_qa-tp_tc_scripts_linux_core_kernel' project to
#     LCK project.
#   - Modified script in order to align it to LCK-GDC standard.
# Dec, 2016. Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#   - Ported from LCk-GDC suite to LTP-DDT.

############################ DESCRIPTION ######################################

# @desc This script disassemble and assemble DSDT ACPI tables with 'iasl'
#       command.'iasl' commnad is an ACPI Source Language compiler/decompiler.
# @params
# @return
# @history 2016-01-10: Ported from LCK suite to LCK-GDC suite.
#		       Updated script to use correctly in LCK-GDC suite.
# @history 2016-12-01: Integrated to LTP-DDT
#		       Added 'source ec_paths.sh'.

############################ FUNCTIONS ########################################

############################ DO THE WORK ######################################

source "common.sh"
source "ec_paths.sh"

DSL_FILE="/var/tmp/dsdt.dsl"
DAT_FILE="/var/tmp/dsdt.dat"

# DELETE dsdt.dsl AND dsdt.dat FILES
rm $DSL_FILE $DAT_FILE 2>/dev/null

# DECOMPILE DTDT SOURCE
cat /sys/firmware/acpi/tables/DSDT > $DAT_FILE
iasl -d $DAT_FILE

# CHECK IF dsdt.dat FILE WAS CREATED
if [ -e "$DSL_FILE" ]; then
  test_print_trc "dsdt.dsl file created"
else
  die "dsdt.dsl file cannot be created"
fi

# LOOK FOR "EmbeddedControl" STRING IN dsdt.dsl FILE
grep -i "EmbeddedControl" $DSL_FILE
if [ $? -eq 0 ]; then
  test_print_trc "EmbeddedControl was found"
else
  die "EmbeddedControl wasn't found"
fi
