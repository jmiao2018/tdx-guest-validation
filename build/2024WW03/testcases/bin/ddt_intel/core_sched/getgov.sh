#!/bin/bash
###############################################################################
# Copyright (C) 2019, Intel - http://www.intel.com
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
# @Author   Hongyu, Ning <hongyu.ning@intel.com>
#
# Jul, 23, 2019. Hongyu, Ning <hongyu.ning@intel.com>
#     - Initial version, to get cpu current governor

############################ DESCRIPTION ######################################
# @desc     Get cpu governor for all cpus
#           Assumption: all cpus' governor value should be the same
#                       otherwise exit 1
# @returns
# @history  2019-07-23: First version

############################# FUNCTIONS #######################################

#function to get available governor values
get_curr_gov() {
  local cpu_num=$1
  local gov_path=/sys/devices/system/cpu/cpu${cpu_num}/cpufreq
  if [ -d ${gov_path} ]; then
    curr_gov_tmp=$(cat ${gov_path}/scaling_governor)
  else
    die "No ${gov_path}, please check sysfs"
  fi
  echo ${curr_gov_tmp}
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"

if [ "$#" -ne 0 ]; then
  echo $"Usage: getgov.sh, echo back current governor value"
  exit 1
fi

num_cpus=$(cat /proc/cpuinfo | grep "^processor"| wc -l)
for (( i=0; i < num_cpus; i++ )); do
  curr_gov=$(get_curr_gov $i)
  gov_cpu0=$(get_curr_gov 0)
  [[ "${curr_gov}" == "${gov_cpu0}" ]] || die "governor values differ, please check"
done
echo ${curr_gov}
