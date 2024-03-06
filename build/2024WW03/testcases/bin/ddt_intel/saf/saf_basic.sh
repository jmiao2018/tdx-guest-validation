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
source "saf-common.sh" # Import do_cmd(), die() and other functions
############################# Functions #######################################
#  usage
basic_usage() {
  cat <<-EOF >&2
  Basic test Scan at field ;
  usage: ./${0##*/} -m x  <para list>
   -m: 0 run all; 1: cpu list
   -w: cycle wait timer (0-1440) - in minutes (default = 0)
   -p: CSV list of all cpu to test (-1 means all)
   -f: additional items on failure results (0 to 3)
   -i: noint (0 = no interrupts during scan, 1 = interrupts ok)
   -R: retry (1-20)
   -o: the list of offline cpu; -1:  random generate the list of cpu
  example:
  ./${0##*/} -m 1 -q 1 -w 1440 -p 0,1,2,4,5,9 -i 0
EOF
  echo ""
}

CLI_PARA_STRING="para"

#####################################################
# BASIC test:
#  para list:
#    r: reload scan blob into each cpu scan processor's memory
#    w: cycle wait timer (0-1440) - in minutes (default = 0)
#    p: CSV list of all cpu to test (-1 means all)
#    f: additional items on failure results (0 to 3)
#    i: noint (0 = no interrupts during scan, 1 = interrupts ok)
#    o: the list of offline cpu; -1:  random generate the list of cpu
####################################################
#    m: test mode
#      0: using default para list; need not to set parameter
#      1: using specific para
#      2: using random parameter expect interrupts
#####################################################
basic_test_handler() {
  local funName="[BASIC TEST]  "
  test_print_trc " Basic test"
  echo "${funName}::: $*"
  # test model; default 0: run all
  local cModel=-1
  # the list of cpus which is offline
  local offLine=""
  local hasoffLine=0
  # Display verbose or minimal messages
  # system interrupts are allowed to interrupt a scan
  local noInt=$DEFAULT_NOINT
  local hasnoInt=0
  # Initiate next cycle in x minutes
  local cWait=$DEFAULT_CYCLE_WAIT
  local hascWait=0
  # list of all cpu to test
  local cList="-1"
  local hascList=0
  # inject failure
  local hasInject=0

  local fAct=0
  local hasfAct=0

  # retry
  local retry=$DEFAULT_RETRY
  local hasRetry=0

  # list of all cpu to test
  local aStop=0
  local hasaStop=0

  OPTIND=1
  while getopts "$SAF_PARAMETER_LIST" arg; do
    test_print_trc "$arg : $OPTARG"
    echo "====$arg======"
    case $arg in
    m) cModel="$OPTARG" ;;
    o)
      offLine="$OPTARG"
      hasoffLine=1
      ;;
    s)
      aStop="$OPTARG"
      hasaStop=1
      ;;
    w)
      cWait="$OPTARG"
      hascWait=1
      ;;
    p)
      cList="$OPTARG"
      hascList=1
      ;;
    f)
      fAct="$OPTARG"
      hasfAct=1
      ;;
    i)
      noInt="$OPTARG"
      hasnoInt=1
      ;;
    R)
      retry="$OPTARG"
      hasRetry=1
      ;;
    I) hasInject=1 ;;
    q) ;;
    d) ;;
    *)
      basic_usage
      exit -1
      ;;

    esac
  done
  if [ $cModel -eq -1 ]; then
    basic_usage
    exit -1
  fi

  local para_string=""
  case $cModel in
  0) #0 all default parameter
    echo "${funName}::: WARNNING :  this mode 0 skips all of parameter!!!!!"
    saf_restore_default_all_parameter
    # system interrupts are allowed to interrupt a scan
    #noInt=$DEFAULT_NOINT
    #retry=$DEFAULT_RETRY
    ## Initiate next cycle in x minutes
    cWait=$DEFAULT_CYCLE_WAIT
    # list of all cpu to test
    hascList=1
    cList="-1"

    ;;
  1) #basic test with specific opt
    #first restore dedault setting
    echo "${funName}::: case 1: specific parameter list"
    saf_restore_default_all_parameter
    #then set the opt list
    para_string="${para_string} -w $cWait"
    saf_set_cycle_wait $cWait
    para_string="${para_string} -i $noInt"
    saf_set_noint $noInt
    para_string="${para_string} -p $cList"

    ;;
  2) # random gen para list
    echo "${funName}::: case 2: random opt"

    [ $hascWait -eq 0 ] && cWait=$(saf_get_random_number 0 1440)
    saf_set_cycle_wait $cWait
    para_string="${para_string} -w $cWait"

    [ $hasnoInt -eq 0 ] && noInt=$(saf_get_random_number 0 1)
    saf_set_noint $noInt
    para_string="${para_string} -i $noInt"

    [ $hasfAct -eq 0 ] && fAct=$(saf_get_random_number 0 3)
    ;;

  esac

  ############################################################
  ## cpu list for scan test
  ## if no option; generate random cpu list
  ## if -1: all cpu
  ## others: specific cpu list
  if [ $hascList -eq 0 ]; then
    # random generate a cpu list
    local lst=$(saf_gen_cpu_list)
    cList=$(echo $lst | sed 's/ /,/g')
  fi
  echo "------------[$cList]--------------------------"
  #check cpu list and remove one of sibings both in the list
  if [ "$cList" != "-1" ]; then
    local lst=$(echo $cList | sed 's/,/ /g')
    lst=$(saf_remove_sibling_cores "${lst[*]}")
    cList=$(echo $lst | sed 's/ /,/g')
  fi
  echo "------------[$cList]--------------------------"
  ######################### set offline cpus####################
  # IF No offline opt then generate the random list of cpu tobe offline
  # if the offline is -1; no cpu to be offline
  # x,y,z  specific a list of cpus to be offline
  if [ $hasoffLine -eq 1 ]; then
    if [ "$offLine" = "-1" ]; then
      offLine=""
    else
      #remove ','
      offLine=$(echo $offLine | sed 's/,/ /g')
    fi
  else
    # random generate a offline list from cpu list
    offLine=$(saf_gen_offline_list $cList)
  fi
  saf_set_online 0 "$offLine"
  echo "!!!!!!!!!!!!!!!!!!!! $hasoffLine !!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "CPU LIST :"$cList
  echo "OFFLINE  :"$offLine
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  ############################Set parameter string########
  para_string=""
  #para_string="${para_string} -q $quiet"
  para_string="${para_string} -s $aStop"
  para_string="${para_string} -w $cWait"
  para_string="${para_string} -p $cList"
  para_string="${para_string} -i $noInt"
  para_string="${para_string} -R $retry"
  [ $hasInject -eq 1 ] && {
    para_string="${para_string} -I"
  }

  echo "=========== TEST CASE:$testCase mode:$cModel =========="
  echo "PARA: $para_string"
  echo "=========== parameter list ============="
  echo "s $aStop  stop cyclic scans (1 = stop)"
  echo "w $cWait  cycle wait timer (0-1440) - in minutes (default = 0)"
  echo "f $fAct  additional items on failure results (0 to 3) 1 = add clock, 2 = add iterations, 3 = both"
  echo "i $noInt  noint (0 = no interrupts during scan, 1 = interrupts ok)"
  echo "p $cList  CSV list of all cpu to test (-1 means all)"
  echo "R $retry  retry [1-20]"
  echo "======= parameter list end!============"

  ################### Call utility to scan ###################
  CLI_PARA_STRING=$para_string
  saf_run_cli "$para_string -D -W -E -P"
  local ret=$?
  test_print_trc "CLI return $ret"
  #ifs_catch_event_trace_info ${log_file}.trc

  ################### Check message ###################
  [ $hasInject -eq 1 ] && {
    if [ $ret -ne 0 ]; then
      test_print_trc "The failure is expected!!!"
      #ret=0
    else
      test_print_trc "Should return failure!!!!"
      #ret=-1
    fi
  }
  #restore offline cpu to online
  #saf_set_online 1 "$offLine"

  echo "[basic_test_handler RESULT]: $ret"
  return $ret

}
