#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019 Intel - http://www.intel.com/
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
# Contributors:
#   Siliang Yu <siliangx.yu@intel.com> (Intel)
#     -Initial draft.
###############################################################################
# @desc Search for device nodes under sysfs (/sys/kernel/).
# @returns None.
# @history 2019-08-22: First version.

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Global variables ################################
EDAC_BUS_DIR="/sys/bus/edac"
############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
    usage: ./${0##*/}  [-l TEST_LOOP] [-t TESTCASE_ID]
    -t TESTCASE_ID test case id, which case to be run
    -h Help   print this usage
EOF
  exit 0
}

edac_probe_check() {
  lsmod | grep -q edac
  if [ $? -ne 0 ]; then
    test_print_err "EDAC related modules aren't found."
    return 1
  fi
}

edac_sys_bus_check() {
  edac_chs=$(ls $EDAC_BUS_DIR)
  [ -n "$edac_chs" ] || {
    test_print_err "No edac controller is registered under $EDAC_BUS_DIR"
    return 1
  }
}
############################### CLI Params ###################################
while getopts :l:t:p:i:b:c:h arg; do
  case $arg in
    t)  CASE_ID="$OPTARG";;
    h)  usage;;
    :)  test_print_err "$0: Must supply an argument to -$OPTARG."
        exit 1
    ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage
        exit 1
    ;;
  esac
done

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.
test_print_trc "STARTING EDAC Test... "

case $CASE_ID in
  1)  edac_probe_check || die "Failed to check edac driver under sysfs"
  ;;
  2)  edac_sys_bus_check || die "Failed to edac driver under sysfs"
  ;;
esac
