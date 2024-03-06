#!/bin/bash
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2015 Intel - http://www.intel.com/
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
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#   -Changed shebang and some cmd's to force the use busybox cmd set.
#   -Reestrucuture file to be compliant with ddt_intel scripts template.
#   -Added common.sh
#   -Added usage function and help case.
#   -Removed useless log traces.
###############################################################################

# @desc Execute multiple run_processes.sh in parallel
# @params <process list> [<process list2> ...]
# @returns 1  if any process returns non-zero value
#          0 otherwise
# @history 2015-03-15: Copied from ddt -> ddt_intel
# @history 2015-03-19: Ported to work with Android on IA.

source "common.sh"  # Import do_cmd(), die() and other functions

############################# Functions #######################################
usage() {
  cat << _EOF
    Execute multiple run_processes.sh in parallel
    returns 1 if any process returns non-zero value
    returns 0 otherwise"
    usage:
    multi_run_processes.sh <process list> [<process list2> ...] -v
      where -v is an optional flag and when present indicates that priority
      of two processes has to be verified using time taken for process execution
      process_list= -s "#-separated commands" -l "-n <num_instances>
                                                  -a <cpu affinity mask>
                                                  -d <inter-process start delay>
                                                  -p <priority>"
_EOF
}


############################ Script Variables ##################################
OFS=$IFS
RET=0
pids=''
i=0

################################ CLI Params ####################################
while getopts ":s:l:h" opt; do
  case $opt in
    h) usage ;;
    s)
      s_command=$OPTARG
      s_commands+=( "$s_command" )
      ;;
    l)
      l_command=$OPTARG
      l_commands+=( "$l_command" )
      ;;
    \?) die "Invalid Option -$OPTARG " ;;
    :) die "$0: Must supply an argument to -$OPTARG." ;;
  esac
done

############################ USER-DEFINED Params ##############################
# Define default values for variables being overriden

case $ARCH in
esac
case $DRIVER in
esac
case $SOC in
esac
case $MACHINE in
# Use machine parameters file instead
esac

########################### DYNAMICALLY-DEFINED Params #########################

########################### REUSABLE TEST LOGIC ###############################
j=0
for i in "${s_commands[@]}"; do
  cmd=${l_commands[$j]}
  run_processes.sh -c "$i" ${cmd[@]} & pids="$pids:$!"
  j=$(( j + 1 ))
done

IFS=':'

# Wait for all process to complete and check return value of process
for p in $pids; do
  if [ -n "$p" ]; then
    wait ${p}
    rc=$?
    if [ "$rc" -ne "0" ]; then
      RET=1
      echo "************************************************"
      echo "Process $p exit with non-zero value at time $(date)"
      echo "************************************************"
      break
    fi
  fi
done

IFS=$OFS
echo "Return is "$RET
exit $RET
