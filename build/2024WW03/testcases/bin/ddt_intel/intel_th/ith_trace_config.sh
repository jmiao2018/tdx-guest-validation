#!/bin/bash

###############################################################################
# Copyright (C) 2017, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################

# @Author   Juan Pablo Gomez <juan.p.gomez@intel>
#
# Aug, 2017. Juan Pablo Gomez <juan.p.gomez@intel.com>
#     - Initial draft.

############################ DESCRIPTION ######################################

# @desc     This 'check_trace_cfg()' function checks a simple trace using ITH driver
# @returns
# @history  2017-08-05: First version

############################# FUNCTIONS #######################################
source "common.sh"
source "ith_common.sh"

check_trace_cfg() {

  #Load all modules needed for Intel_TH
  do_cmd "load_unload_module.sh -l -d intel_th_gth"
  do_cmd "load_unload_module.sh -l -d intel_th"
  do_cmd "load_unload_module.sh -l -d intel_th_pti"
  do_cmd "load_unload_module.sh -l -d intel_th_msu"
  do_cmd "load_unload_module.sh -l -d intel_th_sth"
  do_cmd "load_unload_module.sh -l -d intel_th_gth"
  do_cmd "load_unload_module.sh -l -d stm_console"
  do_cmd "load_unload_module.sh -l -d stm_ftrace"
  do_cmd "load_unload_module.sh -l -d stm_heartbeat"
  do_cmd "load_unload_module.sh -l -d stmmac"
  do_cmd "load_unload_module.sh -l -d stmmac-platform"
  do_cmd "load_unload_module.sh -l -d dummy_stm"

  #Check if platform have been configured with STP_Policies
  test -d ${SP_SYSFS_PATH}
  if [ "$?" -ne 0 ]; then
    test_print_trc "STP Policy is not configured"
    test_print_trc "Configuring STP Policy"
    do_cmd "mount -t configfs none /config"
    masters=$(cat ${SP_SYSFS_PATH}/0-sth.my-policy/user/masters)
    channels=$(cat ${SP_SYSFS_PATH}/0-sth.my-policy/user/channels)
    test_print_trc "Master range: $masters"
    test_print_trc "Channels range: $channels"
    test_print_trc "STP Policy has been configured"
  else
    test_print_trc "STP Policy is alredy configured and mounted"
    masters1=$(cat ${SP_SYSFS_PATH}/0-sth.my-policy/user/masters)
    channels1=$(cat ${SP_SYSFS_PATH}/0-sth.my-policy/user/channels)
    test_print_trc "Master range: $masters1"
    test_print_trc "Channels range: $channels1"
  fi
}

check_trace_cfg
