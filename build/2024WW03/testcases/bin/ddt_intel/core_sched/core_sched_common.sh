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

############################ DESCRIPTION ######################################
# @desc     Define common functions used in core scheduler test
# @returns

############################# FUNCTIONS #######################################
source "common.sh"
source "functions.sh"

#function to create control groups via cgcreate
cg_create() {
  if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: cg_create {controller} {gpath} {cpath (optional)}"
    return 1
  else
    #cgroup subsystem to add new group into
    local controller=$1
    #relative path to add for new group
    local gpath=$2
    [[ -n $3 ]] && local cpath=$3
  fi
  test_print_trc "start to create new cgroup under controller: ${controller}"
  cgcreate -g ${controller}:${gpath}/${cpath} && \
    test_print_trc "successfully created new cgroup ${gpath}/${cpath} under controller: /sys/fs/cgroup/${controller}"
}

#function to get cpu sibling pair info for a given cpu_id
cpu_sibling() {
  if [ "$#" -ne 1 ]; then
    echo "Usage: cpu_sibling {cpu_id}"
    return 1
  else
    local cpu_id=$1
    local thread_siblings_list=$(cat /sys/bus/cpu/devices/cpu${cpu_id}/topology/thread_siblings_list)
    local cpu_sibling_pair
    local i
    local j
    i=$(echo $thread_siblings_list | awk -F, '{print $1}')
    j=$(echo $thread_siblings_list | awk -F, '{print $2}')
    [[ -n $i ]] && [[ ${cpu_id} !=  "$i" ]] && cpu_sibling_pair=$i
    [[ -n $j ]] && [[ ${cpu_id} !=  "$j" ]] && cpu_sibling_pair=$j
    [[ -n ${cpu_sibling_pair} ]] && echo ${cpu_sibling_pair}
  fi
}

#usage function of program_launch_pad
usage_program_launch_pad() {
  cat <<-EOF
  usage: program_launch_pad [-p program] [-c cpu_id (optional)] [-g cgroup (optional)] [-a arguments (optional)]
  -p program to launch
  -c cpu_id to launch program on
  -g cgroup to launch program in
  -a arguments to launch program with
  -h Help        print this usage
EOF
}

#function to launch program with arguments on specific cpu_id and under specific cgroup
program_launch_pad() {
  local OPTIND arg
  while getopts :p:c:g:a:h arg; do
    case $arg in
      p)
        #program to launch
        local program=$OPTARG
        ;;
      c)
        #cpu_id to launch the program
        local cpu_id=$OPTARG
        ;;
      g)
        #cgroup controller:gpath/cpath to launch the program
        local cgroup=$OPTARG
        ;;
      a)
        #arguments to launch the program
        local arguments=$OPTARG
        ;;
      h)
        usage_program_launch_pad && return 0
        ;;
      :)
        #test_print_err "Must supply an argument to -$OPTARG."
        usage_program_launch_pad && return 1
        ;;
      \?)
        #test_print_err "Invalid Option -$OPTARG ignored."
        usage_program_launch_pad && return 1
        ;;
    esac
  done

  if [[ -n ${cpu_id} ]]; then
    if [[ -n ${cgroup} ]]; then
      if [[ -n ${arguments} ]]; then
        taskset -c ${cpu_id} cgexec -g ${cgroup} ${program} ${arguments}
      else
        taskset -c ${cpu_id} cgexec -g ${cgroup} ${program}
      fi
    else
      if [[ -n ${arguments} ]]; then
        taskset -c ${cpu_id} ${program} ${arguments}
      else
        taskset -c ${cpu_id} ${program}
      fi
    fi
  else
    if [[ -n ${cgroup} ]]; then
      if [[ -n ${arguments} ]]; then
        cgexec -g ${cgroup} ${program} ${arguments}
      else
        cgexec -g ${cgroup} ${program}
      fi
    else
      if [[ -n ${arguments} ]]; then
        ${program} ${arguments}
      else
        ${program}
      fi
    fi
  fi
}

#function to check program running cpu id info
program_cpu_id() {
  local program=$1
  local cpu_id
  pgrep ${program} > /dev/null && cpu_id=$(cat /proc/`pgrep ${program}`/stat | awk '{print $39}')
  if [[ -n ${cpu_id} ]]; then
    echo ${cpu_id}
  else
    return 1
  fi
}

#teardown function to restore cpu governor setting to default
governor_teardown (){
  local cpu_governor=$1
  setgov.sh ${cpu_governor}
}
