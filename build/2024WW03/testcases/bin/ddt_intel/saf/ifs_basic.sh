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
#
#     2021/05/11 -Initial draft.
###############################################################################
# @desc do test Scan at fields
#      files: under /sys/devices/system/cpu(or cpus)
#      saf CLI application(scan_field_app)
#      stress tool: stressapptest
#
# @returns None.
# @history
#    2021-05-11: First version -draft!!!!
#    2021-05-14: add usage and reload test!

#source "common.sh"  # Import do_cmd(), die() and other functions
source "ifs_func.sh" # Import do_cmd(), die() and other functions

############################# Functions #######################################
#  usage
basic_usage() {
  cat <<-EOF >&2
  Basic test Scan at field ;
  usage: ./${0##*/} -m x  <para list>
   -m: 0 run all; 1: cpu list
   -w: cycle wait timer (0-1440) - in minutes (default = 0)
   -p: CSV list of all cpu to test (-1 means all)
   -o: the list of offline cpu; -1:  random generate the list of cpu
   -n: the index of intel_ifs_x; 0: scan; 1: Array; 2: SBFT;
  example:
  ./${0##*/} -n 0 -m 1 -q 1 -w 1440 -p 0,1,2,4,5
EOF
  echo ""
}

CLI_PARA_STRING="para"

CPU_LIST=""
OFF_LIST=""

#####################################################
# BASIC test:
#  PARA list:
#    w: cycle wait timer (0-1440) - in minutes (default = 0)
#    p: CSV list of all cpu to test (null: all; -1: random )
#    o: the list of offline cpu; -1:  random generate the list of cpu
#    m: test mode
#      0: using default para list; need not to set parameter
#      1: using specific para
#      2: using random parameter expect interrupts
#####################################################
basic_test_handler() {
  local funName="[BASIC TEST]  "
  test_print_trc " Basic test"
  # test model; default 0: run all
  local cModel=-1
  # the list of cpus which is offline
  local offList=""
  # list of all cpu to test
  local cList=""

  echo "${funName}::: $*"
  OPTIND=1
  while getopts "m:o:p:n:" arg; do
    test_print_trc "$arg : $OPTARG"
    echo "====$arg======"
    case $arg in
    m) cModel="$OPTARG" ;;
    o) offList="$OPTARG" ;;
    p) cList="$OPTARG" ;;
    n) ;;
    *)
      basic_usage
      exit 1
      ;;
    esac
  done

  if [[ $cModel -eq -1 ]]; then
    basic_usage
    exit 1
  fi

  off=$(cat /sys/devices/system/cpu/offline)
  if [ ! "$off" == "" ]; then
    echo "Restore all core enable!"
    saf_get_all_cpus
    saf_set_online 1 "$ALL_CORES"
  fi

  local para_string=""
  case $cModel in
  0) #0 all default parameter
    echo "${funName}::: WARNNING : Run scan on all cores!!!"
    saf_restore_default_all_parameter
    # list of all cpu to test
    ;;
  1) #basic test with specific opt
    #first restore dedault setting
    echo "${funName}::: case 1: specific parameter list"
    saf_restore_default_all_parameter
    #then set the opt list
    ;;
  2) # random gen para list
    ;;
  esac

  if [ "${cList}" == "" ]; then
    # all cpu
    cList=$(saf_get_all_cpus)
  elif [ "${cList}" == "-1" ]; then
    # random generate a cpu list
    cList=$(saf_gen_cpu_list)
    #cList=$lst
  else
    #cList=$(echo $cList | sed 's/,/ /g')
    cList="${cList//,/ }"
  fi
  #local cnt=${#cList[@]}
  cList=$(saf_remove_sibling_cores "${cList[*]}")

  ######################### set offline cpus####################
  # IF No offline opt then generate the random list of cpu tobe offline
  # if the offline is -1; no cpu to be offline
  # x,y,z  specific a list of cpus to be offline
  if [ "$offList" == "" ]; then
    offList=""
  elif [ "$offList" == "-1" ]; then
    #saf_gen_offline_list "$cList"
    offList=$(saf_gen_offline_list "$cList")
  else
    #remove ','
    #offList=`echo $offList | sed 's/,/ /g'`
    offList="${offList//,/ }"
  fi
  #echo "OFFLINE  :"$offList

  if [ ! "$offList" == "" ]; then
    saf_set_online 0 "$offList"
  fi

  cList=$(saf_remove_sibling_cores "${cList[*]}")
  #local lst=`saf_remove_sibling_cores "${cList[*]}"`
  #cList=$lst

  #echo "Get cpulist [$cnt] : "${cList[*]}"-------------"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  #local cpustr=$(echo $cList | sed "s/ / /g")
  #cnt=${#cpustr[@]}
  #echo "CPU LIST :[$cnt] "$cList
  echo "CPU LIST :$cList"

  #cpustr=(`echo $offList | sed 's/ / /g'`)
  #cnt=${#offList[@]}
  if [ ! "$offList" == "" ]; then
    #echo "OFFLINE  :[$cnt] "$offList
    echo "OFFLINE  :$offList"
  fi
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

  echo "=========== TEST CASE:$testCase mode:$cModel =========="
  echo "PARA: $para_string"
  echo "=========== parameter list ============="
  ################### Call utility to scan ###################
  ifs_run_scan "$cList"
  #return fail counter
  local ret=$?

  if [ ! "$offList" == "" ]; then
    saf_set_online 1 "$offList"
  fi
  echo "[basic_test_handler RESULT]: $ret"

  return $ret
}
