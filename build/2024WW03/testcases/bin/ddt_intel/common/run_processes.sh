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
#   -Added usage function and help case.
#   -Removed useless log traces.
#   -Modify empty pids check ([ -n "$pid" ]).
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
    Execute multiple processes in parallel
    returns 1 if any process returns non-zero value
    returns 0 otherwise
    usage: run_processes.sh -c <separated commands>
                            -n <num_of_instances>
                            -a <cpu_affinity_mask>
                            -d <delay_in_sec>
                            -p <priority>
                            -h show this
    if cpu affinity is set, then taskset is used to spawn the processes
_EOF
}

############################ Script Variables ##################################
pids=''
RET=0
OFS=$IFS
IFS="#"
tmp_dir="$TMPBASE"
i=0

COMMANDS_SET=0
INSTANCE_SET=0
AFFINITY_SET=0
DELAY_SET=0
PRIORITY_SET=0

p_instances=1
p_mask='0xFFFFFFFF'
p_delay=1
p_priority=0

################################ CLI Params ####################################
while getopts ":c:n:a:d:p:h" opt; do
  case $opt in
    h) usage  && exit ;;
    c)
      if [[ $COMMANDS_SET = 0 ]]; then
        COMMANDS_SET=1
        p_commands=$OPTARG
      else
        echo "Option -commmands already was used."
        exit 1
      fi
      ;;
    n)
      if [[ $INSTANCE_SET = 0 ]]; then
        INSTANCE_SET=1
        p_instances=$OPTARG
      else
        echo "Option -num_instances already was used."
        exit 1
      fi
      ;;
    a)
      if [[ $AFFINITY_SET = 0 ]]; then
        AFFINITY_SET=1
        p_mask=$OPTARG
      else
        echo "Option -cpu_affinity_mask was already used."
        exit 1
      fi
      ;;
    d)
      if [[ $DELAY_SET = 0 ]]; then
        DELAY_SET=1
        p_delay=$OPTARG
      else
        echo "Option -inter_process_start_delay was already used."
        exit 1
      fi
      ;;
    p)
      if [[ $PRIORITY_SET = 0 ]]; then
        PRIORITY_SET=1
        if [[ $OPTARG -lt 20 ]] && [[ $OPTARG -ge -20 ]]; then
          p_priority=$OPTARG
        else
          die "Valid priority values are between -20 and +20, $OPTARG is not in valid range"
        fi
      else
        echo "Option -task_priority was already used."
        exit 1
      fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Syntax is -c <#-separated commands> -n <num_of_instances> -a <cpu_affinity_mask> -d <inter_process_start_delay in sec> -p <task_priority>"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

############################ USER-DEFINED Params ##############################
# Define default values for variables being overriden

########################### DYNAMICALLY-DEFINED Params #########################

########################### REUSABLE TEST LOGIC ###############################


# Start processes
for w in $p_commands; do
  for (( j=0 ; j < p_instances ; j++ )); do
    echo "INSTANCE is $j COMMAND is $w"
    sleep "$p_delay"
    # if cpu affinity is set, use taskset
    if [[ $AFFINITY_SET = 1 ]]; then
      c="taskset $p_mask $w"
      eval "$c" > "$tmp_dir"/log$i.$j.tmp 2>&1 &
    else
      eval "$w" > "$tmp_dir"/log$i.$j.tmp 2>&1 &
    fi
    process_id=$!
    declare -A hash
    hash[$process_id]=$p_priority
    echo "${hash[$process_id]}"
    echo "PROCESS ID is $process_id"
    if [[ $PRIORITY_SET = 1 ]]; then
      renice "$p_priority" -p "$process_id"
    fi
    pids="$pids:$!"
    pid_table+=( "$process_id" )
  done
  i=$(( i + 1 ))
done
cnt=$i
IFS=':'

# Wait for all process to complete and check return value of process
for p in $pids; do
  if [ -n "$p" ]; then
    wait ${p}
    rc=$?
    if [ "$rc" -ne "0" ]; then
      RET=1
      echo "*****************From run_processes.sh***********************"
      echo "Process $p exit with non-zero value at time " "$(date)"
      echo ""
      break
    fi
  fi
done

IFS=$OFS

# Print logs in console
i=0
while [ "$i" -lt "$cnt" ]; do
  for (( j=0 ; j < p_instances ;  j++ )); do
    process_id=${pid_table[$j]}
    echo "$process_id"
    echo "*************  start of $tmp_dir/log$i.$j.tmp    ***************"
    echo "Task priority is ${hash[$process_id]}"
    cat "$tmp_dir"/log$i.$j.tmp
    echo "*************  end of $tmp_dir/log$i.$j.tmp    ***************"
  done
  i=$(( i + 1 ))
done
exit $RET
