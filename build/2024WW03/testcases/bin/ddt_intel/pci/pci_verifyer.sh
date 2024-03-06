#!/bin/bash

###############################################################################
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

# Author: Juan Pablo Gomez (juan.p.gomez@intel.com)
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#   - Create script to run PCIe Sanity BATs tests.
#
# Feb, 2018. Juan Pablo Gomez <juan.p.gomez@intel.com>
#   - Improve the logic to obtain the Enumeration ID and Device ID

############################ DESCRIPTION ######################################

# This script does:
#   - Verify PCIe port Kernel Driver is loaded.
#   - Verify PCIe root port class code.
#   - Verify GBE Intel Card enumeration on PCIe root port.
#   - List PCIe modules loaded.
#   - Verify number of PCIe roots ports.
#   - Verify PCI root port vendor ID

############################ FUNCTIONS ########################################

############################ DO THE WORK ######################################

source "pciport_common.sh"

while getopts :kcemnih arg
do case $arg in
  k)  PORT_DRIVER=1;;
  c)  PORT_CLASS=1;;
  e)  ENUM_DEV=1;;
  m)  LIST=1;;
  n)  PORT_NUMBER=1;;
  i)  PORT_ID=1;;
  h)  usage;;
  \?) test_print_trc "Invalid Option -$OPTARG ignored." >&2
      usage
      exit 1 ;;
  esac
done

# DEFAULT VALUES IF NOT SET IN 'getopts'
: ${PORT_DRIVER:='0'}
: ${PORT_CLASS:='0'}
: ${ENUM_DEV:='0'}
: ${LIST:='0'}
: ${PORT_NUMBER:='0'}
: ${PORT_ID:='0'}

PCI_ID_LIST=$(lspci -nn | grep PCI | cut -d '[' -f3 | cut -d ']' -f1)
for ids in ${PCI_ID_LIST}; do
  PCIPORT=$(lspci -d "$ids" -vv | grep "Kernel driver in use: pcieport")
  if [ -n "$PCIPORT" ]; then
    PCI_ID=$(lspci -d "$ids" | cut -d ' ' -f1)
    RDID=$ids
  fi
done

# LOOK FOR PCI PORT KERNEL DRIVER
if [ $PORT_DRIVER -eq 1 ]; then
  do_cmd "ls -l $PCI_DIR/0000:$PCI_ID > /dev/null 2>&1"
  if [ $? -eq 0 ]; then
    test_print_trc "This has a pciport kernel driver bound: $ids"
    test_print_trc "PCIe Port Kernel Driver is loaded"
  else
    test_print_trc "This device ID does not have kernel driver bound: $ids"
    die "No PCI port was found"
  fi
fi

# LOOK FOR PCI ROOT PORT CLASS
if [ $PORT_CLASS -eq 1 ]; then
  CODE=$(cat "$PCI_DIR"/0000:"$PCI_ID"/class)
  CODE_NUMBER="0x060400"
  if [ "$CODE" == "$CODE_NUMBER" ]; then
    test_print_trc "PCI Root Port Class Code: $CODE  was verifed "
  else
    die "No PCI root port was found or was not verified"
  fi
fi

# LOOK FOR PCI MODULES LOADED
if [ $LIST -eq 1 ]; then
  PCI_MODULE=$(lspci -Dk | grep "$PCI_ID")
  if [ $? -eq 0 ]; then
    test_print_trc "PCIe Module is loeaded: $PCI_MODULE"
  else
    die "PCIe Module is not loaded"
  fi
fi

# VERIFY NUMBER OF PCI ROOT PORT
if [ $PORT_NUMBER -eq 1 ]; then
  PCI_ROOT_PORT=$(lspci -Dns "$PCI_ID" | grep -c "8086")
  if [ $? -eq 0 ]; then
    test_print_trc "Numbers od PCIe Root Ports are verified: $PCI_ROOT_PORT "
  else
    die "Numbers of PCIe Root Ports are not verified"
  fi
fi

# VERIFY ROOT PORT VENDO ID
if [ $PORT_ID -eq 1 ]; then
  VID=$(cat "$PCI_DIR"/0000:"$PCI_ID"/vendor)
  VENDOR_ID=0x8086
  if [ "$VID" = "$VENDOR_ID" ]; then
    test_print_trc "PCI Root Port Vendor ID is verified: $VID "
  else
    die "Vendor ID is not verified"
  fi
fi

# LOOK FOR PCI ROOT PORT CLASS
if [ "$ENUM_DEV" -eq 1 ]; then
  if [ -n "$RDID" ]; then
    test_print_trc "The PCI Enumeration is: $PCI_ID The Device ID is: $RDID"
   else
     die "No Device ID Found"
  fi
fi
