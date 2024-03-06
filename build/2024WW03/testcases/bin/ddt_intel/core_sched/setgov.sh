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
#     - Initial version, to set cpu governor

############################ DESCRIPTION ######################################
# @desc     Set cpu governor for all cpus
# @returns
# @history  2019-07-23: First version

############################# FUNCTIONS #######################################

#function to get available governor values
get_avail_gov() {
  local cpu_num=$1
  local gov_path=/sys/devices/system/cpu/cpu${cpu_num}/cpufreq
  if [ -d ${gov_path} ]; then
    avail_gov=$(cat ${gov_path}/scaling_available_governors)
  else
    die "No ${gov_path}, please check sysfs"
  fi
  test_print_trc "Available governors for cpu${cpu_num}: ${avail_gov}"
}

#function to check if governor belongs to available governors
check_avail_gov() {
  local cpu_num=$1
  local check_gov=$2
  local gov_path=/sys/devices/system/cpu/cpu${cpu_num}/cpufreq
  if [ -d ${gov_path} ]; then
    local avail_gov=$(cat ${gov_path}/scaling_available_governors)
  else
    die "No ${gov_path}, please check sysfs"
  fi
  local i
  for i in ${avail_gov}; do [[ "$i" == "${check_gov}" ]] && return 0; done
  return 1
}

#function to set governor on specific cpuX with valid governor value
set_governor_on_cpu() {
  if [ "$#" -ne 2 ]; then
    echo $"Usage: set_governor_on_cpu {cpu_num} {governor}"
    return 1
  else
    local cpu_num=$1
    local governor=$2
  fi
  local gov_path=/sys/devices/system/cpu/cpu${cpu_num}/cpufreq
  #check if governor belongs to available governors
  check_avail_gov ${cpu_num} ${governor} || test_print_trc "governor value: ${governor} is not valid"
  if [ -d ${gov_path} ]; then
    echo $governor > ${gov_path}/scaling_governor
    if [ "$(cat ${gov_path}/scaling_governor)" == ${governor} ]; then
      echo "set governor to ${governor}"
      echo "dir is ${gov_path}"
      echo "CPU ${cpu_num} policy set to ${governor} governor"
      echo -n "maximum frequency:"
      cat ${gov_path}/scaling_max_freq
      echo -n "minimum frequency:"
      cat ${gov_path}/scaling_min_freq
    else
      die "CPU ${cpu_num} policy setting to ${governor} governor FAILED"
    fi
  else
    die "No ${gov_path}, please check sysfs"
  fi
  return 0
}

################################ DO THE WORK ##################################
source "common.sh"
source "functions.sh"

if [ "$#" -ne 1 ]; then
  echo $"Usage: setgov.sh {governor}"
  exit 1
else
  governor=$1
fi

num_cpus=$(cat /proc/cpuinfo | grep "^processor"| wc -l)
for (( i=0; i < num_cpus; i++ )); do
  get_avail_gov $i
  set_governor_on_cpu $i ${governor} && test_print_trc "Set governor ${governor} is done on cpu$i"
done
exit 0
