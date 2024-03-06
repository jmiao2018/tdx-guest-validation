#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# File:         hybrid_tests.sh
#
# Description:  hybrid CPU test script
#
# Author(s):    Ammy Yi <ammy.yi@intel.com>
#
# Date:         03/04/2020
#


source "common.sh"
source "functions.sh"
source "blk_device_common.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

CPU_SYS_PATH="/sys/devices/system/cpu/"
# file names
json_template="ddt_intel/hybrid_cpu/hgs-rtapp-template.json"
json_target="ddt_intel/hybrid_cpu/hgs_rtapp.json"
test_log="ddt_intel/hybrid_cpu/hgs_rtapp_test.log"


# default value
RECORD_LOG="ddt_intel/hybrid_cpu/"$TAG"_hgs_record.log"
HGS_LOG="ddt_intel/hybrid_cpu/"$TAG"_hgs.log"
CORE_GROUPS="ddt_intel/hybrid_cpu/core_groups.log"
TABLE_LOG="ddt_intel/hybrid_cpu/hgs_table.log"
BOUNDRY=40
CORE_IDS=0
ATOM_IDS=0
SMT_IDS=0
CORE_NUM=0
ATOM_NUM=0
SMT_NUM=0
instance=1
duration=100
run=10000
sleep=0
wtime=1
core_pid=0
atom_pid=0
smt_pid=0
thread_name=""
delay=0.5

#counters
rtimes=0
etimes=0
dup_times=0
e_atom_time_non_zero=0
e_atom_times=0
e_core_times=0
e_no_core_free=0
e_same_cpu_times=0


hwp_sysfs_test() {
  nodes=$(ls $CPU_SYS_PATH)
  for node in $nodes
  do
    do_cmd "cat $CPU_SYS_PATH/$node/acpi_cppc/status"
  done
}

cpuinfo_hgs_test() {
  do_cmd "grep flags /proc/cpuinfo \
         | grep hfi"
  do_cmd "grep flags /proc/cpuinfo \
         | grep itd"
}

cpuinfo_hgs_plus_test() {
  do_cmd "grep flags /proc/cpuinfo \
         | grep hreset"
}

sysfs_test() {
  do_cmd "cat /sys/devices/system/cpu/types/intel_core*/cpulist"
  do_cmd "cat /sys/devices/system/cpu/types/intel_atom*/cpulist"
  ids=$(ls /sys/devices/system/cpu/ | grep -c cpu[0-9])
  sys_p="/sys/devices/system/cpu"
  for((i=0;i<ids;i++)); do
    do_cmd "find $sys_p/cpu$i/topology -type f -exec cat {} + > /dev/null"
  done
}

cpuid_hgs_test() {
  #CPUID[6].EAX[19]: Legacy HGS support
  #CPUID[6].EDX[7:0]: Bitmap of supported hardware feedback interface capabilities.
  #Bit 0 indicates support for performance capability reporting
  #bit 1 and energy capability reporting
  #CPUID[6].EDX[11:8]: Enumerates the size of the HGS table
  #CPUID[6].EDX[31:16]: Index (starting at 0) of this logical processor's row in the HGS Table
  do_cmd "cpuid_check 6 0 0 0 a 19"
  for((i=0;i<=1;i++)); do
    do_cmd "cpuid_check 6 0 0 0 d $i"
  done
}

cpuid_hgs_plus_test() {
  #CPUID[6].EAX[23] HGS+ support, it includes the enumeration support
  #for the IA32_HW_FEEDBACK_THREAD_CONFIG  and IA32_HW_FEEDBACK _CHAR MSRs
  #CPUID[6].ECX[11:8] Number of HGS+ classes as represent in the HGS memory table
  do_cmd "cpuid_check 6 0 0 0 a 23"
}

cpuid_hgs_plus_hreset_test() {
  do_cmd "cpuid_check 7 0 1 0 a 22"
  do_cmd "cpuid_check 20 0 0 0 b 0"
}

get_core_ids() {
  local list="thread_siblings_list"
  CORE_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
             | grep '\-\|,' | cut -d \- -f 1 | cut -d \, -f 1 | sort | uniq)
  SMT_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
            | grep '\-\|,' | cut -d \- -f 2 | cut -d \, -f 2 | sort | uniq)
  ATOM_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
             | grep -v '\-\|,' | sort | uniq)
  CORE_NUM=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
             | grep '\-\|,' | sort | uniq | wc -l)
  ATOM_NUM=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
             | grep -v '\-\|,' | sort | uniq | wc -l)
  let SMT_NUM=CORE_NUM
  test_print_trc "CORE_IDS=$CORE_IDS; SMT_IDS=$SMT_IDS; ATOM_IDS=$ATOM_IDS"
  test_print_trc "CORE_NUM=$CORE_NUM, ATOM_NUM=$ATOM_NUM, SMT_NUM=$SMT_NUM"
  find $CPU_SYS_PATH -type f -name $list -exec cat {} + | grep '\-\|,' \
              | sort | uniq > $CORE_GROUPS
  cat $CORE_GROUPS
}

hgs_table_test() {
  do_cmd "cat /sys/kernel/debug/intel_hw_feedback/hw_state0 > $TABLE_LOG"
  perfcap=$(grep -A 50 CPU $TABLE_LOG \
            | grep -A 50 0 \
            | grep -c ^ \
            | awk '{print $3}')
  efficiencycap=$(grep -A 50 CPU $TABLE_LOG \
                  | grep -A 50 0 \
                  | grep -c ^ \
                  | awk '{print $4}')
  for value in $perfcap; do
    [[ $value -gt 0 ]] || die "PerfCap in HGS table is incorrect!"
  done
  for value in $efficiencycap; do
    [[ $value -gt 0 ]] || die "EfficiencyCap in HGS table is incorrect!"
  done
}

hgs_plus_table_test() {
  do_cmd "cat /sys/kernel/debug/intel_hw_feedback/hw_state0 > $TABLE_LOG"
  class_num=$(cat $TABLE_LOG | grep Class | head -1 | awk '{print NF}')
  [[ $class_num -le 1 ]] && die "CLass in HGS+ table is incorrect!"

}


check_cpu_group() {
  task_ids=$1
  test_print_trc "check if 2 thread are running on same CPU core+smt"
  test_print_trc "task_ids=$task_ids"
  lines=$(grep -c '\-\|,' $CORE_GROUPS)
  test_print_trc "lines=$lines"
  for((line=1;line<=lines;line++)); do
    count=0
    for task_id in $task_ids; do
      test_print_trc "task_id=$task_id"
      test_print_trc "count=$count"
      cat $CORE_GROUPS | awk 'NR=="'$line'"' | grep -w $task_id
      [[ $? -eq 0 ]] && let count=count+1
      test_print_trc "count=$count"
      if [[ $count -eq 2 ]]; then
        let etimes=etimes+1
        let e_same_cpu_times=e_same_cpu_times+1
        log_print "2 threads are running on same CPU core+smt!"
        return
      fi
    done
  done
  test_print_trc "core_pid=$core_pid, atom_pid=$atom_pid, smt_pid=$smt_pid"
}

get_task_ids() {
  lines=$1
  name=$2
  echo "===========================================" >> $HGS_LOG
  ps -aT -o comm,pid,spid,cpuid,%cpu | grep "$name" >> $HGS_LOG
  task_ids=$(tail -n $lines $HGS_LOG | awk '{print $4}')
  test_print_trc "Get task_id -----> $task_ids"
  core_pid=0
  atom_pid=0
  smt_pid=0
  #task_ids=$1
  for task_id in $task_ids; do
    test_print_trc "task_id=$task_id"
    echo $CORE_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let core_pid=core_pid+1
      test_print_trc "Get core_pid=$core_pid with $task_id!"
    fi
    echo $ATOM_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let atom_pid=atom_pid+1
      test_print_trc "Get atom_pid=$atom_pid with $task_id!"
    fi
    echo $SMT_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let smt_pid=smt_pid+1
      test_print_trc "Get smt_pid=$smt_pid with $task_id!"
    fi
  done
  test_print_trc "core_pid=$core_pid, atom_pid=$atom_pid, smt_pid=$smt_pid"
}

get_task_ids_rt_app() {
  begin=$1
  end=$2
  echo "===========================================" >> $HGS_LOG
  cat $test_log | grep scalar | sed -n "$begin,"${end}"p" >> $HGS_LOG
  task_ids=$(cat $test_log | grep scalar | awk '{print $2}' | sed -n "$begin,"${end}"p")
  test_print_trc "Get task_id -----> $task_ids"
  core_pid=0
  atom_pid=0
  smt_pid=0
  #task_ids=$1
  for task_id in $task_ids; do
    test_print_trc "task_id=$task_id"
    echo $CORE_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let core_pid=core_pid+1
      test_print_trc "Get core_pid=$core_pid with $task_id!"
    fi
    echo $ATOM_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let atom_pid=atom_pid+1
      test_print_trc "Get atom_pid=$atom_pid with $task_id!"
    fi
    echo $SMT_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let smt_pid=smt_pid+1
      test_print_trc "Get smt_pid=$smt_pid with $task_id!"
    fi
  done
  test_print_trc "core_pid=$core_pid, atom_pid=$atom_pid, smt_pid=$smt_pid"
}


get_task_ids_fspin() {
  lines=$1
  log=$2
  task_ids=$(tail -n $lines $log | awk '{print $2}')
  test_print_trc "Get task_id -----> $task_ids"
  core_pid=0
  atom_pid=0
  smt_pid=0
  #task_ids=$1
  for task_id in $task_ids; do
    test_print_trc "task_id=$task_id"
    echo $CORE_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let core_pid=core_pid+1
      test_print_trc "Get core_pid=$core_pid with $task_id!"
    fi
    echo $ATOM_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let atom_pid=atom_pid+1
      test_print_trc "Get atom_pid=$atom_pid with $task_id!"
    fi
    echo $SMT_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let smt_pid=smt_pid+1
      test_print_trc "Get smt_pid=$smt_pid with $task_id!"
    fi
  done
  test_print_trc "core_pid=$core_pid, atom_pid=$atom_pid, smt_pid=$smt_pid"
}

get_task_ids_fspin_package() {
  lines=$1
  log=$2
  task_ids=$(tail -n $lines $log | awk '{print $2}')
  test_print_trc "Get task_id -----> $task_ids"
  core_pid=0
  atom_pid=0
  smt_pid=0
  #task_ids=$1
  for task_id in $task_ids; do
    test_print_trc "task_id=$task_id"
    echo $CORE_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let core_pid=core_pid+1
      test_print_trc "Get core_pid=$core_pid with $task_id!"
    fi
    echo $ATOM_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let atom_pid=atom_pid+1
      test_print_trc "Get atom_pid=$atom_pid with $task_id!"
        start=0
        end=1
        while [ $start -lt $cluset_num ]
        do
          if [[ $task_id -ge ${cluset_group[$start]} ]] && [[ $task_id -lt ${cluset_group[$end]} ]]; then
            let atom_cluset_group[$start]=atom_cluset_group[$start]+1
            test_print_trc "-----> atom_cluset_group[$start]=${atom_cluset_group[$start]}"
          fi          
          test_print_trc "-----> cluset_group[$i]=${cluset_group[$i]}"
          let start=start+1
          let end=end+1
        done
    fi
    echo $SMT_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let smt_pid=smt_pid+1
      test_print_trc "Get smt_pid=$smt_pid with $task_id!"
    fi
  done
  test_print_trc "core_pid=$core_pid, atom_pid=$atom_pid, smt_pid=$smt_pid"
}

dup_check() {
  name=$1
  # check if 2 threads running on same core
  dup=$(echo ${task_ids[*]} | sed 's/ /\n/g' | sort | uniq -d | wc -l)
  if [[ $dup -ne 0 ]]; then
    let etimes=etimes+1
    let dup_times=dup_times+1
    log_print "Seems some workloads are running on one CPU!"
    return 255
  fi
}

counters_start_print() {
  log_print "##########start############"
}

log_print() {
  echo "$1" >> $RECORD_LOG
  echo "$1" >> $HGS_LOG
  test_print_trc "$1"
}

counters_clear() {
  counters_start_print
  rtimes=0
  etimes=0
  dup_times=0
  e_atom_time_non_zero=0
  e_atom_times=0
  e_core_times=0
  e_no_core_free=0
  e_same_cpu_times=0
}

generate_csv() {
  path=$(pwd)
  bin_path=$path"/ddt_intel/hybrid_cpu/"
  gen_result.sh $RECORD_LOG $bin_path
}

results_check(){
  target=$1
  let result=etimes*100
  let result=result/rtimes
  log_print "percentage is $result"
  generate_csv
  [[ $result -le $target ]] || \
    die "Error count percentage is over $target %, current error is $result %!"
}

counters_end_print() {
  echo "percent = $percent" >> $RECORD_LOG
  echo "instance = $instance" >> $RECORD_LOG
  echo "rtimes = $rtimes" >> $RECORD_LOG
  echo "etimes = $etimes" >> $RECORD_LOG
  echo "dup_times = $dup_times" >> $RECORD_LOG
  echo "e_core_times = $e_core_times" >> $RECORD_LOG
  echo "e_atom_times = $e_atom_times" >> $RECORD_LOG
  echo "e_atom_time_non_zero = $e_atom_time_non_zero" >> $RECORD_LOG
  echo "e_no_core_free = $e_no_core_free" >> $RECORD_LOG
  echo "e_same_cpu_times = $e_same_cpu_times" >> $RECORD_LOG
  log_print "########end##############"
}

heavy_atom_check() {
  if [[ $atom_pid -ne 0 ]]; then
    let etimes=etimes+1
    let e_atom_time_non_zero=e_atom_time_non_zero+1
  # die "Seems rt-app running on atom!"
    log_print "Seems rt-app running on atom!"
  fi
  if [[ $instance -gt 1 ]] && [[ $instance -le $CORE_NUM ]]; then
    check_cpu_group "$task_ids"
  fi
}

common_check() {
  let cores_pid=core_pid+smt_pid
  let cores=CORE_NUM+SMT_NUM
  if [[ $cores -eq $cores_pid ]]; then
    let etimes=etimes+1
    let e_no_core_free=e_no_core_free+1
    log_print "Seems no SMT or Core free!"
  fi
}

heavy_core_check() {
  let extra=instance-CORE_NUM
  test_print_trc "Check atom with core=$core_pid, atom=$atom_pid, smt=$smt_pid,
  extra=$extra, instance=$instance!"
  if [[ $atom_pid -eq $extra ]]; then
    echo "aa"
  else
    let etimes=etimes+1
    log_print "Seems atoms threads are not expected!"
    if [[ $atom_pid -gt $extra ]]; then
      let e_core_times=e_core_times+1
      log_print "Seems some cpu are not used!"
    fi
    if [[ $atom_pid -lt $extra ]]; then
      let e_atom_times=e_atom_times+1
      log_print "Seems some atoms are not used!"
    fi
  fi
}

workload_h_test() {
  test_print_trc "**************************************heavy worklaod test************************************!"
  rtimes=0
  type=$1
  w_name="fspin-"
  get_core_ids
  core_aa=0
  atom_aa=0
  t_log="ddt_intel/hybrid_cpu/temp.txt"
  case $type in
    core)
      min=1
      let num=CORE_NUM+1
      ;;
    atom)
      let min=CORE_NUM+1
      let num=ATOM_NUM+min
      ;;
    *)
      die "NO tyes type defined!"
      ;;
  esac
  test_print_trc "min = $min num=$num"
  for((instance=min;instance<num;instance++)); do
    counters_clear
    # start workload at backgroud
    test_print_trc "Start to test $instance threads"
    fspin -t $instance -i $duration -s 1 -q > $t_log
    test_print_trc "Start to generate logs"
    cat $t_log >> $HGS_LOG
    begin=1
    let end=begin+$instance+1
    tt_log="ddt_intel/hybrid_cpu/temp_$begin"
    awk 'n==1{print} $0~/Residency/{n=1}' $t_log > $tt_log
    cat $tt_log >> $RECORD_LOG
    cat $tt_log > $t_log
    total_lines=$(awk '{print NR}' $t_log |tail -n1)
    test_print_trc "begin=$begin, end=$end total_lines=$total_lines"
    while [[ $end -le $total_lines ]];do
      let rtimes=rtimes+1
      tt_log="ddt_intel/hybrid_cpu/temp_$begin"
      awk -v s="$begin" -v e="$end" 'NR>s&&NR<e' $t_log > $tt_log
      cat $tt_log >> $RECORD_LOG
      get_task_ids_fspin $instance $tt_log
      begin=$end
      let end=begin+$instance+1
      test_print_trc "begin=$begin, end=$end total_lines=$total_lines"
      dup_check $w_name
      common_check
      if [[ $dup -eq 0 ]]; then
        test_print_trc "core=$core_pid, atom=$atom_pid, \
              smt=$smt_pid, instance=$instance!"
        case $type in
          core)
            heavy_atom_check
            ;;
          atom)
            heavy_core_check
            ;;
          *)
            die "No type $type defined!"
            ;;
        esac
      fi
    done
    counters_end_print
    results_check 10
  done
}

rt-app_setting() {
  local OPTIND
  while getopts "t:r:p:" opt; do
    case $opt in
      t)
        instance=$OPTARG
        test_print_trc "set threads $instance"
        ;;
      p)
        util=$OPTARG
        test_print_trc "set cpu utilization $util%"
        let "total = 10000"
        let "run = $total * $util / 100"
        let "sleep = $total * (100 - $util) / 100"
        test_print_trc "set sleep $sleep"
        test_print_trc "set run $run"
        ;;
      r)
        seconds=$OPTARG
        let "duration = $seconds"
        test_print_trc "set test to run $duration second"
        ;;
    esac
  done
  shift $((OPTIND-1))
  # create json file from template
  sed	-e "s/\$instance/$instance/g" \
   -e "s/\$run_duration/$run/g"  \
   -e "s/\$sleep_duration/$sleep/g" \
   -e "s/\$duration/$duration/g"    \
   $json_template > $json_target
}

rt-app_start() {
  flag=$1
  # start, redirect i/o and sed the test to background
  rt-app $json_target > $test_log 2>&1
  # check all treads are running
  threads=0
  mesg="starting thread ..."
  [[ $flag -eq 1 ]] && let "instance = $instance + 1 "
  while [[ $threads -ne $instance ]]; do
    sleep 2
    threads=$(grep "$mesg" $test_log |wc -l)
    test_print_trc "threads started: $threads, threads expected: $instance"
  done
  sleep 1
  threads=$(grep "$mesg" $test_log |wc -l)
  [[ $threads -ne $instance ]] \
    && die "number of threads is not same as command line spacification"
  total_lines=$(cat $test_log | grep -c scalar)
  test_print_trc "***********total_lines=$total_lines!"
}

rt-app_start_bg() {
  flag=$1
  # start, redirect i/o and sed the test to background
  rt-app $json_target > $test_log 2>&1 &
  # check all treads are running
  threads=0
  mesg="starting thread ..."
  [[ $flag -eq 1 ]] && let "instance = $instance + 1 "
  while [[ $threads -ne $instance ]]; do
    sleep 2
    threads=$(grep "$mesg" $test_log |wc -l)
    test_print_trc "threads started: $threads, threads expected: $instance"
  done
  sleep 1
  threads=$(grep "$mesg" $test_log |wc -l)
  [[ $threads -ne $instance ]] \
    && die "number of threads is not same as command line spacification"
}

get_boundry(){
  cat /sys/kernel/debug/intel_hw_feedback/hw_state > $TABLE_LOG
  ee_cores=$(grep -A 50 CPU $TABLE_LOG | grep -A 50 0 | awk '{print $4}'| sort | uniq | head -1)
  ee_atoms=$(grep -A 50 CPU $TABLE_LOG | grep -A 50 0 | awk '{print $4}'| sort | uniq | tail -1)
  let BOUNDRY=ee_cores*100/ee_atoms*80/100
  test_print_trc "ee_cores = $ee_cores, ee_atoms = $ee_atoms BOUNDRY = $BOUNDRY"
}

get_most_ee_cores() {
  cat /sys/kernel/debug/intel_hw_feedback/hw_state > $TABLE_LOG
  ee_max=$(grep -A 50 CPU $TABLE_LOG | grep -A 50 0 | awk '{print $4}' | awk 'BEGIN{max=0} {if($1+0>max+0) max=$1 fi} END {print max}')
  test_print_trc "ee_max = $ee_max"
  ee_cores=$(grep -A 50 CPU $TABLE_LOG | grep -A 50 0 | grep $ee_max | awk '{print $1}')
  test_print_trc "ee_cores = $ee_cores"
}

workload_h_rt_app_test() {
  get_core_ids
  max=ATOM_NUM+CORE_NUM
  for((instance=1;instance<=max;instance++)); do
    for((percent=100;percent<=100;percent=$percent+5)); do
      test_print_trc "rt-app with instance: $instance, percent: $percent!"
      rt-app_setting -t $instance -p $percent
      test_print_trc "start rt-app!"
      rt-app_start
      counters_clear
      log_line=1
      while [[ $log_line -le $total_lines ]]; do
        test_print_trc "******************check log_line=$log_line!"
        echo "percent = $percent" >> $HGS_LOG
        let rtimes=rtimes+1
        # check cpuid
        let end=log_line+instance-1
        get_task_ids_rt_app $log_line $end
        # check if 2 threads running on same core
        dup_check
        common_check
        if [[ $dup -eq 0 ]]; then
          # check cpuid
          let cores_num=core_pid+smt_pid
          if [[ $instance -le CORE_NUM ]]; then
            heavy_atom_check
          else
            heavy_core_check
          fi
        fi
        let log_line=log_line+instance
      done
      counters_end_print
      results_check 15
    done
  done
}

workload_l_test() {
  get_core_ids
  type=$1
  w_name="rt-app-thr0-"
  case $type in
    atom)
      max=$ATOM_NUM
      min=1
      ;;
    core)
      let max=ATOM_NUM+CORE_NUM+SMT_NUM
      let min=ATOM_NUM+1
      ;;
    *)
      die "No type $type defined!"
      ;;
  esac
  test_print_trc "max = $max!"
  get_boundry
  BOUNDRY=35
  for((instance=min;instance<max;instance++)); do
    for((percent=5;percent<=BOUNDRY;percent=$percent+5)); do
      test_print_trc "rt-app with instance: $instance, percent: $percent!"
      echo "*********************percent = $percent*****************" >> $HGS_LOG
      rt-app_setting -t $instance -p $percent
      test_print_trc "start rt-app!"
      rt-app_start
      counters_clear
      log_line=1
      while [[ $log_line -le $total_lines ]]; do
        let rtimes=rtimes+1
        # check cpuid
        let end=log_line+instance-1
        get_task_ids_rt_app $log_line $end
        get_most_ee_cores
        # check cpuid
        case $type in
          atom)
            if [[ $atom_pid -eq $instance ]]; then
              test_print_trc "All threads are running on atom!"
            else
              echo $ee_cores | grep -w $task_id
              if [[ $? -ne 0 ]]; then
                let etimes=etimes+1
                let e_core_times=e_core_times+1
                log_print "Seems rt-app are not all running on atom and most ee cores!"
              fi
            fi
          ;;
        esac
        let log_line=log_line+instance
      done
    counters_end_print
    results_check 40
    done
  done
}

hotplug_core_test() {
  get_core_ids
  thread_flag=0
  w_name="fspin-"
  fspin -t 1 -i 1 -s 20 &
  # check if all threads are running
  while [[ $thread_flag -lt 1 ]]; do
    thread_flag=$(ps -aT| grep -c $w_name)
  done
  test_print_trc "All threads are created!"
  # wait threads migrate to Cores
  sleep $wtime
  get_task_ids 1 $w_name
  # thread should assign to core
  [[ $atom_pid -eq 1 ]] \
    && die "Seems fspin are not running on core!"
  #let core offline
  for id in $CORE_IDS; do
    set_offline "cpu$id"
  done
  for id in $SMT_IDS; do
    set_offline "cpu$id"
  done
  sleep $wtime
  # thread should assign to atom
  get_task_ids 1 $w_name
  #let core online
  for id in $CORE_IDS; do
    set_online "cpu$id"
  done
  for id in $SMT_IDS; do
    set_online "cpu$id"
  done
  [[ $atom_pid -eq 1 ]] \
    || die "Seems fspin are not on atom after core offline!"
  sleep $wtime
  # thread should assign to core
  get_task_ids 1 $w_name
  [[ $atom_pid -eq 1 ]] \
    && die "Seems fspin are not on core after core online!"
}

hotplug_atom_test() {
  get_core_ids
  thread_flag=0
  w_name="rt-app-thr0-"
  rt-app_setting -t 1 -p 5
  test_print_trc "start rt-app!"
  rt-app_start_bg
  # wait threads migrate to atoms
  sleep $wtime
  get_task_ids 1 $w_name
  # thread should assign to atom
  [[ $atom_pid -eq 1 ]] \
    || die "Seems rt-app are not running on atom!"
  #let core offline
  for id in $ATOM_IDS; do
    set_offline "cpu$id"
  done
  sleep $wtime
  # thread should assign to core
  get_task_ids 1 $w_name
  #let atom online
  for id in $ATOM_IDS; do
    set_online "cpu$id"
  done
  [[ $atom_pid -eq 1 ]] \
    && die "Seems rt-app are not on core after atom offline!"
  sleep $wtime
  # thread should assign to atom
  get_task_ids 1 $w_name
  [[ $atom_pid -eq 1 ]] \
    || die "Seems rt-app are not on atom after atom online!"
}

workload_switch_test() {
  get_core_ids
  w_name="rt-app-thr0"
  test_print_trc "2-phases with cpu utilization %5 and %80"
  json_target="ddt_intel/hybrid_cpu/hgs-rtapp-2-phases.json"
  rt-app_start_bg
  sleep $wtime
  # check cpuid
  get_task_ids 1 $w_name
  [[ $atom_pid -eq 1 ]] \
    && die "rt-app not running on core with high cpu utilization!"
  sleep 12
  get_task_ids 1 $w_name
  [[ $atom_pid -eq 1 ]] \
    || die "rt-app not running on atom with low cpu utilization!"
}


##need get task_ids before this
get_core_migrate_times() {
  core_migrate=0
  c_flag=0
  core_flag=0
  type=$1
  for task_id in $task_ids; do
    core_type_check $task_id
    test_print_trc "core_type=$core_type"
    case $type in
      ramp_down)
        start_flag="core"
        if [[ $c_flag -eq 0 ]]; then
          start="core"
        fi
        ;;
      ramp_up)
        start_flag="atom"
        if [[ $c_flag -eq 0 ]]; then
          start="atom"
        fi
        ;;
      *)
        die "NO tyes type defined!"
        ;;
    esac
    if [[ $core_type = $start_flag ]]; then
      core_flag=1
    fi
    if [[ $core_type != $start ]] && [[ $c_flag -eq 0 ]]; then
      c_flag=1
    fi
    if [[ $core_type != $start ]] && [[ $c_flag -eq 1 ]]; then
      let core_migrate=core_migrate+1
      if [[ $start = "atom" ]]; then
        start="core"
      elif [[ $start = "core" ]]; then
        start="atom"
      fi
      test_print_trc "core migrate 1 time, start=$start"
    fi
  done
  test_print_trc "core_migrate=$core_migrate, core_flag=$core_flag "
}

workload_rampup_test() {
  get_core_ids
  w_name="rt-app-thr0"
  test_print_trc "multi-phases, utilization %10 to %90"
	json_target="ddt_intel/hybrid_cpu/hgs-rtapp-n-up-phases.json"
  rt-app_start
  task_ids=$(cat $test_log | grep scalar | awk '{print $2}' )
  get_core_migrate_times "ramp_up"
  [[ $core_migrate -eq 1 ]] || die "Core migrate times is not expected!"
  [[ $core_flag -eq 0 ]] && die "workloads never runs different type of cores!"
}

workload_decrease_test() {
  get_core_ids
  w_name="rt-app-thr0"
  test_print_trc "multi-phases, utilization %90 to %10"
	json_target="ddt_intel/hybrid_cpu/hgs-rtapp-n-down-phases.json"
  rt-app_start
  task_ids=$(cat $test_log | grep scalar | awk '{print $2}' )
  get_core_migrate_times "ramp_down"
  [[ $core_migrate -eq 1 ]] || die "Core migrate times is not expected!"
  [[ $core_flag -eq 0 ]] && die "workloads never runs different type of cores!"
}

fb_setting() {
	local OPTIND
	while getopts "b:" opt; do
		case $opt in
		b)
			instance=$OPTARG
			echo "set backend threads $instance"
			;;
		esac
	done
	shift $((OPTIND-1))
	#create json file from template
	sed	-e "s/\$instance/$instance/g" \
		$json_template > $json_target
}

workload_fb_test() {
  get_core_ids
  w_name="rt-app-thr0"
  json_template="ddt_intel/hybrid_cpu/hgs-rtapp-fb-template.json"
  let max=ATOM_NUM/2
  for i in "1" "$max"; do
    counts=0
    f_counts=0
    fb_setting -b $i
    rt-app_start_bg 1
    sleep $wtime
    # check cpuid
    pid=1
    while [[ $pid -ne 0 ]]; do
      let counts=counts+1
      w_name="rt-app-thr0"
      get_task_ids 1 $w_name
      if [[ $atom_pid -eq 1 ]]; then
        let f_counts=f_counts+1
        test_print_trc "rt-app not running on core with high cpu utilization!"
      fi
      w_name="rt-app-thr1"
      get_task_ids $i $w_name
      if [[ $atom_pid -ne $i ]]; then
        let f_counts=f_counts+1
        test_print_trc "rt-app not running on atom with low cpu utilization!"
      fi
      sleep $wtime
      let f_counts=f_counts+1
      pid=$(ps | grep "rt-app" | wc -l)
    done
    let f_rate=f_counts/counts
    test_print_trc "f_rate = $f_rate"
    [[ $f_rate -gt 10 ]] \
      && "rt-app failure rate is higher than target 10%! f_rate = $f_rate"
  done
}

threads_block_test() {
  get_core_ids
  w_name="rt-app-thr"
  json_target="ddt_intel/hybrid_cpu/hgs-rtapp-sync.json"
  instance=2
  rt-app_start_bg
  sleep $wtime
  pid=2
  counts=0
  f_counts=0
  while [[ $pid -eq 2 ]]; do
    let counts=counts+1
    get_task_ids 2 $w_name
    # check cpuid
    if [[ $atom_pid -eq 2 ]]; then
        let f_counts=f_counts+1
        test_print_trc "Seems rt-app are not all running on atom!"
    fi
    sleep 1
    pid=$(ps | grep "rt-app-thr" | wc -l)
  done
  pid=$(ps | grep "rt-app" | awk '{print $1}')
  kill -9 $pid
  let f_rate=f_counts/counts
  test_print_trc "f_rate = $f_rate"
  [[ $f_rate -gt 10 ]] \
    && "rt-app failure rate is higher than target 10%! f_rate = $f_rate"
}

mkl_dnn_start() {
  type=$1
  num=$2
  bin_name=$3
  export LD_LIBRARY_PATH=./:$LD_LIBRARY_PATH
  export MKLDNN_JIT_DUMP=1
  export OMP_NUM_THREADS=$num
  case $type in
    avx2)
      unset DNNL_MAX_CPU_ISA
      ;;
    vnni)
      export DNNL_MAX_CPU_ISA=AVX2
      ;;
  esac
  test_print_trc "Start mkl-dnn threads"
  ./$bin_name --conv --mode=c --mb=2 --cfg=u8s8s8 --dir=FWD_D \
    --batch=./shapes_resnet_50 &
  while [[ $thread_flag -lt $num ]]; do
    thread_flag=$(ps -aT| grep -c $bin_name)
  done
  test_print_trc "All mkl-dnn threads are created!"
}

workload_s_test() {
  type=$1
  get_core_ids
  thread_name="benchdnn"
  fspin -t $CORE_NUM -i 1 -s 1000 &
  # check if all threads are running
  while [[ $thread_flag -lt $i ]]; do
    thread_flag=$(ps -aT| grep -c "fspin-")
  done
  test_print_trc "All threads are created!"
  # wait threads migrate to Cores
  sleep 1
  pid=1
  #check if fspin is assigned to right cores
  get_task_ids $CORE_NUM "fspin-"
  dup_check "fspin-"
  [[ $core_pid -eq $instance ]] \
   || die "Seems fspin are not all running on core!"
  #start avx2/vnni thread
  mkl_dnn_start $type $CORE_NUM $thread_name
  #check if mkl_dnn is assigned to right cores
  sleep 1
  pid=1
  while [[ $pid -ne 0 ]];do
    get_task_ids $CORE_NUM $thread_name
    dup_check $thread_name
    [[ $core_pid -eq $instance ]] \
      || die "Seems $thread_name are not all running on core!"
    # sleep sometime
    sleep 1
    pid=$(ps | grep $thread_name | wc -l)
  done
  sleep 1
  #check if fspin is assigned to cores again
  get_task_ids $CORE_NUM "fspin-"
  if [[ -n $task_ids ]]; then
    [[ $core_pid -eq $instance ]] \
      || die "Seems fspin are not all running on core!"
  fi
}

msc_start() {
  device=$1
  #start, redirect i/o and send the test to background
  $thread_name -n -o $device -c 1024 -t 0 -s 1024k &

	#check all treads are running
	threads=0
	while [ $threads -ne 1 ]; do
		sleep 0.5
		threads=`ps -aT| grep "$thread_name" | wc -l`
		test_print_trc "threads started: $threads, threads expected: 1"
	done
}

disk_io_test() {
  thread_name="msc"
  DEV_NODE=$(get_blk_device_node.sh -d "usb")
  if [[ -z $DEV_NODE ]]; then
    DEV_NODE=$(get_blk_device_node.sh -d "sata")
    if [[ -z $DEV_NODE ]]; then
      DEV_NODE=$(get_blk_device_node.sh -d "nvme")
    fi
  fi
  [[ -z $DEV_NODE ]] && block_test "No avaliable usb/sata/nvme to test!"
  test_print_trc "DEV_NODE = $DEV_NODE!"
  msc_start $DEV_NODE
  pid=0
  while [[ $pid -ne 0 ]];do
    get_task_ids 1 $thread_name
    [[ $atom_pid -eq 1 ]] \
      || die "Seems $thread_name are not all running on atom!"
  done
}

workload_avx2_fspin_test() {
  get_core_ids
  thread_name="fspin-"
  let num=CORE_NUM+SMT_NUM
  rt-app_setting -t $num -p 95
  test_print_trc "start rt-app!"
  rt-app_start_bg
  # wait threads migrate to Cores
  sleep $wtime
  fspin -t $num -i 1 -s 1000 -w avx2 &
  # check if all threads are running
  while [[ $thread_flag -lt $i ]]; do
    thread_flag=$(ps -aT| grep -c $thread_name)
  done
  test_print_trc "All threads are created!"
  sleep $wtime
  pid=1
  #check if fspin is assigned to right cores
  while [[ $pid -ne 0 ]];do
    get_task_ids $num $thread_name
    dup_check $thread_name
    [[ $atom_pid -eq 0 ]] \
      || die "Seems $thread_name are not all running on big core!"
    # sleep sometime
    sleep 1
    pid=$(ps | grep $thread_name | wc -l)
  done
}

workload_vnni_avx2_test() {
  get_core_ids
  thread_name_vnni="benchdnn_vnni"
  thread_name_avx2="benchdnn_avx2"
  cp benchdnn $thread_name_vnni
  cp benchdnn $thread_name_avx2
  #create vnni and avx2 threads
  mkl_dnn_start "avx2" $CORE_NUM $thread_name_avx2
  sleep 1
  mkl_dnn_start "vnni" $CORE_NUM $thread_name_vnni
  sleep 1
  get_task_ids $CORE_NUM $thread_name_avx2
  dup_check $thread_name_avx2
  get_task_ids $CORE_NUM $thread_name_vnni
  dup_check $thread_name_vnni
  id=1
  pid_avx2=1
  pid_vnni=1
  while [[ $pid_avx2 -ne 0 ]] && [[ $pid_vnni -ne 0 ]];do
    get_task_ids $CORE_NUM $thread_name_vnni
    [[ $atom_pid -eq 0 ]] \
      || die "Seems $thread_name_vnni are not all running on core!"
    # sleep sometime
    sleep 1
    pid_avx2=$(ps | grep $thread_name_avx2 | wc -l)
    pid_vnni=$(ps | grep $thread_name_vnni | wc -l)
  done
}

soc_atom_test() {
  hgs_table_log="hgs_table.log"
  cat /sys/kernel/debug/intel_hw_feedback/hw_state0 > $hgs_table_log
  cpu_type=$(sed -n '/^HFI table:/,/IPCC scores:$/p' $hgs_table_log | \
    awk '{print $3}' | grep -v "^$"| grep -v Pe | uniq | wc -l)
  [[ $cpu_type -eq 3 ]] \
      || die "Seems no 2 types atom there!"
}

run_yogini() {
  yogini_$test_type
}

core_type_check() {
  #core and smt core_type is core, atom core type is atom
  task_id=$1
  test_print_trc "task_id=$task_id"
  echo $CORE_IDS | grep -w $task_id
  if [[ $? -eq 0 ]]; then
    core_type="core"
    test_print_trc "Get core_pid=$core_pid with $task_id!"
  fi
  echo $ATOM_IDS | grep -w $task_id
  if [[ $? -eq 0 ]]; then
    core_type="atom"
    test_print_trc "Get atom_pid=$atom_pid with $task_id!"
  fi
  echo $SMT_IDS | grep -w $task_id
  if [[ $? -eq 0 ]]; then
    core_type="core"
    test_print_trc "Get smt_pid=$smt_pid with $task_id!"
  fi
}

yogini_log_check() {
  l_file=$1
  type=$2
  log_type=$3
  temp_log="temp.log"
  #get CPU Residency Trace log in whole log
  y_log="yogini_$type.log"
  begin=$(cat $l_file | grep -n "Task CPU Residency Trace" | awk -F ":" '{print $1}')
  end=$(cat $l_file | grep -n "RAW Throughput Scores" | awk -F ":" '{print $1}')
  let begin=begin+2
  let end=end-2
  test_print_trc "begin=$begin, end=$end!"
  sed -n ''$begin','$end'p' $l_file > $temp_log
  sed s/[[:space:]]/:/g $temp_log | awk -F ":" '{print $2}' | awk '!/^$/' > $y_log
  if [[ $log_type -eq 2 ]]; then
    sed s/[[:space:]]/:/g $temp_log | awk -F ":" '{print $3}' | awk '!/^$/' > $y_log
  fi
  #check cores and atoms
  task_ids=$(cat $y_log)

  #task_ids=$1
  get_core_migrate_times $type
  [[ $core_migrate -ne 6 ]] && die "Core migrate times is not expected!"
  [[ $core_flag -eq 0 ]] && die "workloads never runs different type of cores!"
}


yogini_pyramid_check() {
  l_file=$1
  type=$2
  log_type=$3
  temp_log="pyramid_temp.log"
  #get CPU Residency Trace log in whole log
  y_log="yogini_$type.log"
  begin=$(cat $l_file | grep -n "Task CPU Residency Trace" | awk -F ":" '{print $1}')
  end=$(cat $l_file | grep -n "RAW Throughput Scores" | awk -F ":" '{print $1}')
  let begin=begin+2
  let end=end-2
  test_print_trc "begin=$begin, end=$end!"
  sed -n ''$begin','$end'p' $l_file > $temp_log
  array=2
  test_print_trc "CORE_NUM=$CORE_NUM, ATOM_NUM=$ATOM_NUM, SMT_NUM=$SMT_NUM!"
  let total_array=array+CORE_NUM+ATOM_NUM+SMT_NUM
  while [[ $array -lt $total_array ]];do
    test_print_trc "##################################array=$array#####################################"
    y_log="yogini_$type_$array.log"
    sed s/[[:space:]]/:/g $temp_log | awk -v array=$array -F ":" '{print $array}' | awk '!/^$/' > $y_log
    let array=array+1
    #check cores and atoms
    task_ids=$(cat $y_log)
    core_migrate=0
    c_flag=0
    core_flag=0
    start="core"
    #task_ids=$1
    for task_id in $task_ids; do
      core_type_check $task_id
      test_print_trc "core_type=$core_type"
      if [[ $core_type == $start ]] && [[ $c_flag -eq 0 ]]; then
        c_flag=1
      fi
      if [[ $core_type != $start ]] && [[ $c_flag -eq 1 ]]; then
        let core_migrate=core_migrate+1
        if [[ $start == "core" ]]; then
          start="atom"
        fi
        if [[ $start == "atom" ]]; then
          start="core"
        fi
        test_print_trc "core migrate 1 time, start=$start"
      fi
    done
    test_print_trc "core_migrate=$core_migrate"
    [[ $core_migrate -gt 0 ]] && die "Core migrate times is not expected!"
  done
}

yogini_test() {
  get_core_ids
  rm -r result.schedyogi*
  run.schedyogi
  ##ramp up check
  yogini_logs=$(ls result.schedyogi* | grep ramp-up)
  test_print_trc "yogini_logs=$yogini_logs!"
  for yogini_log in $yogini_logs; do
    test_print_trc "yogini_log=$yogini_log!"
    yogini_log_check "result.schedyogi*/$yogini_log" "ramp_up"
  done
  ##ramp down check
  yogini_logs=$(ls result.schedyogi* | grep ramp-down)
  test_print_trc "yogini_logs=$yogini_logs!"
  for yogini_log in $yogini_logs; do
    test_print_trc "yogini_log=$yogini_log!"
    yogini_log_check "result.schedyogi*/$yogini_log" "ramp_down"
  done
  ##bow-tie check
  yogini_logs=$(ls result.schedyogi* | grep ramp-down)
  test_print_trc "yogini_logs=$yogini_logs!"
  for yogini_log in $yogini_logs; do
    test_print_trc "yogini_log=$yogini_log!"
    yogini_log_check $yogini_log "ramp_up"
    yogini_log_check $yogini_log "ramp_down" 2
  done
  ##pyramid100 check
  yogini_logs=$(ls result.schedyogi* | grep pyramid100-)
  test_print_trc "yogini_logs=$yogini_logs!"
  for yogini_log in $yogini_logs; do
    test_print_trc "yogini_log=$yogini_log!"
    yogini_pyramid_check "result.schedyogi*/$yogini_log" "pyramid100"
  done
}

get_class_id() {
  workload=$1
  # check if all threads are running
  pid=$(ps -aT | grep $workload |  awk '{print $2}')
  sleep 5
  classid=$(cat /proc/$pid/classid)
  test_print_trc "pid=$pid, classid=$classid!"
  kill -9 $pid
}

classid_test() {
  ##class 0 worklaod
  Class0 &
  get_class_id Class0
  [[ $classid -eq 0 ]] || die "Class0 class id is not 0!"

  ##class 1 worklaod
  Class1 &
  get_class_id Class1
  [[ $classid -eq 1 ]] || die "Class1 class id is not 1!"

  ##class 3 worklaod
  PAUSE3 &
  get_class_id PAUSE3
  [[ $classid -eq 3 ]] || die "PAUSE class id is not 3!"

  UserMWait3 &
  get_class_id UserMWait3
  [[ $classid -eq 3 ]] || die "UserMWait class id is not 3!"

  ##class 2 worklaod
  VNNI2 &
  get_class_id VNNI2
  [[ $classid -eq 2 ]] || die "VNNI class id is not 2!"
}

class_workload_launch() {
  workload=$1
  get_core_ids
  let num=CORE_NUM
  for((num=0;num<CORE_NUM;num++)); do
    $workload &
  done
}

kill_workloads() {
  workload=$1
  task_ids=$(ps | grep "$workload" | awk '{print $1}')
  for task_id in $task_ids; do
    kill -9 $task_id
  done
}

kill_one_workload() {
  workload=$1
  task_id_one=$(ps | grep "$workload" | awk '{print $1}' | head -1)
  kill -9 $task_id_one
}

get_task_ids_class() {
  name=$1
  ps -aT -o comm,pid,spid,cpuid,%cpu
  task_ids=$(ps -aT -o comm,pid,spid,cpuid,%cpu | grep "$name" | awk '{print $4}')
  test_print_trc "Get task_id -----> $task_ids"
  core_pid=0
  atom_pid=0
  smt_pid=0
  #task_ids=$1
  for task_id in $task_ids; do
    test_print_trc "task_id=$task_id"
    echo $CORE_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let core_pid=core_pid+1
      test_print_trc "Get core_pid=$core_pid with $task_id!"
    fi
    echo $ATOM_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let atom_pid=atom_pid+1
      test_print_trc "Get atom_pid=$atom_pid with $task_id!"
    fi
    echo $SMT_IDS | grep -w $task_id
    if [[ $? -eq 0 ]]; then
      let smt_pid=smt_pid+1
      test_print_trc "Get smt_pid=$smt_pid with $task_id!"
    fi
  done
  test_print_trc "core_pid=$core_pid, atom_pid=$atom_pid, smt_pid=$smt_pid"
}

workload_high_priority_check() {
  w_target=$1
  workload=$2
  $w_target &
  class_workload_launch $workload
  sleep 5s
  kill_one_workload $workload
  sleep 5s
  get_task_ids_class $w_target
  kill_workloads $workload
  kill_workloads $w_target
  [[ $core_pid -eq 1 ]] || die "$w_target is not running on core with busy $workload!"
}

workload_low_priority_check() {
  w_target=$1
  workload=$2
  $w_target &
  class_workload_launch $workload
  sleep 5s
  get_task_ids_class $w_target
  kill_workloads $workload
  kill_workloads $w_target
  [[ $atom_pid -eq 1 ]] || die "$w_target is not running on atom with busy $workload!"
}


#Class 2 > class 1 > class 0 > class3 .
workload_class0_test() {
  w_target="Class0"
  workload="PAUSE3"
  workload_high_priority_check $w_target $workload
  workload="Class1"
  workload_low_priority_check $w_target $workload
  workload="VNNI2"
  workload_low_priority_check $w_target $workload
}

#Class 2 > class 1 > class 0 > class3 .
workload_class1_test() {
  w_target="Class1"
  workload="PAUSE3"
  workload_high_priority_check $w_target $workload
  workload="Class0"
  workload_high_priority_check $w_target $workload
  workload="VNNI2"
  workload_low_priority_check $w_target $workload
}

#Class 2 > class 1 > class 0 > class3 .
workload_class2_test() {
  w_target="VNNI2"
  workload="PAUSE3"
  workload_high_priority_check $w_target $workload
  workload="Class0"
  workload_high_priority_check $w_target $workload
  workload="Class1"
  workload_high_priority_check $w_target $workload
}

#Class 2 > class 1 > class 0 > class3 .
workload_class3_test() {
  w_target="PAUSE3"
  workload="Class1"
  workload_low_priority_check $w_target $workload
  workload="Class0"
  workload_low_priority_check $w_target $workload
  workload="VNNI2"
  workload_low_priority_check $w_target $workload
}

itmt_basic_test() {
  val=$(cat /proc/sys/kernel/sched_itmt_enabled)
  [[ $val -eq 1 ]] || die "ITMT is not enabled!"
  grep ASYM_PACKING /sys/kernel/debug/sched/domains/cpu*/domain*/flags
  [[ $? -eq 0 ]] || die "ASYM_PACKING is not correct!"
}

workload_high_priority_single_check() {
  w_target=$1
  test_print_trc "Start to run $w_target and fflag=$fflag!"
  $w_target &
  sleep 5s
  get_task_ids_class $w_target
  [[ $core_pid -eq 1 ]] || fflag=1
}

workload_low_priority_single_check() {
  w_target=$1
  test_print_trc "Start to run $w_target and fflag=$fflag!"
  $w_target &
  sleep 5s
  kill_one_workload $workload
  sleep 5s
  get_task_ids_class $w_target
  [[ $atom_pid -eq 1 ]] || fflag=1
}


workload_class2_mix_test() {
  fflag=0
  workload="VNNI2"
  class_workload_launch $workload
  sleep 2s
  w_target_1="Class1"
  workload_low_priority_single_check $w_target $workload
  w_target_2="Class0"
  workload_low_priority_single_check $w_target $workload
  w_target_3="PAUSE3"
  workload_low_priority_single_check $w_target $workload

  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
  [[ $fflag -eq 0 ]] || die "Workload is not running on right core/atom!"
}

workload_class3_mix_test() {
  fflag=0
  workload="PAUSE3"
  class_workload_launch $workload
  sleep 2s
  w_target_1="Class1"
  workload_high_priority_single_check $w_target $workload
  w_target_2="Class0"
  workload_high_priority_single_check $w_target $workload
  w_target_3="VNNI2"
  workload_high_priority_single_check $w_target $workload

  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
  [[ $fflag -eq 0 ]] || die "Workload is not running on right core/atom!"
}

workload_class1_mix_test() {
  fflag=0
  workload="Class1"
  class_workload_launch $workload
  sleep 2s
  w_target_1="PAUSE3"
  workload_low_priority_single_check $w_target $workload
  w_target_2="Class0"
  workload_low_priority_single_check $w_target $workload
  w_target_3="VNNI2"
  workload_high_priority_single_check $w_target $workload

  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
  [[ $fflag -eq 0 ]] || die "Workload is not running on right core/atom!"
}

workload_class0_mix_test() {
  fflag=0
  workload="Class0"
  class_workload_launch $workload
  sleep 2s
  w_target_1="PAUSE3"
  workload_low_priority_single_check $w_target $workload
  w_target_2="Class1"
  workload_high_priority_single_check $w_target $workload
  w_target_3="VNNI2"
  workload_high_priority_single_check $w_target $workload

  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
  [[ $fflag -eq 0 ]] || die "Workload is not running on right core/atom!"
}

workload_class0_mix_id_test() {
  fflag=0
  workload="Class0"
  class_workload_launch $workload
  sleep 2s
  w_target_1="PAUSE3"
  $w_target_1 &
  w_target_2="Class1"
  $w_target_2 &
  w_target_3="VNNI2"
  $w_target_3 &
  sleep 5s
  get_class_id $w_target_1
  [[ $classid -eq 3 ]] || die "$w_target_1 class id is $classid and it is not expected!"
  get_class_id $w_target_2
  [[ $classid -eq 1 ]] || die "$w_target_2 class id is $classid and it is not expected!"
  get_class_id $w_target_3
  [[ $classid -eq 2 ]] || die "$w_target_3 class id is $classid and it is not expected!"
  get_class_id $workload
  [[ $classid -eq 0 ]] || die "$workload class id is $classid and it is not expected!"
  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
}

workload_class1_mix_id_test() {
  fflag=0
  workload="Class1"
  class_workload_launch $workload
  sleep 2s
  w_target_1="PAUSE3"
  $w_target_1 &
  w_target_2="Class0"
  $w_target_2 &
  w_target_3="VNNI2"
  $w_target_3 &
  sleep 5s
  get_class_id $w_target_1
  [[ $classid -eq 3 ]] || die "$w_target_1 class id is $classid and it is not expected!"
  get_class_id $w_target_2
  [[ $classid -eq 0 ]] || die "$w_target_2 class id is $classid and it is not expected!"
  get_class_id $w_target_3
  [[ $classid -eq 2 ]] || die "$w_target_3 class id is $classid and it is not expected!"
  get_class_id $workload
  [[ $classid -eq 1 ]] || die "$workload class id is $classid and it is not expected!"
  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
}

workload_class2_mix_id_test() {
  fflag=0
  workload="VNNI2"
  class_workload_launch $workload
  sleep 2s
  w_target_1="PAUSE3"
  $w_target_1 &
  w_target_2="Class0"
  $w_target_2 &
  w_target_3="Class1"
  $w_target_3 &
  sleep 5s
  get_class_id $w_target_1
  [[ $classid -eq 3 ]] || die "$w_target_1 class id is $classid and it is not expected!"
  get_class_id $w_target_2
  [[ $classid -eq 0 ]] || die "$w_target_2 class id is $classid and it is not expected!"
  get_class_id $w_target_3
  [[ $classid -eq 1 ]] || die "$w_target_3 class id is $classid and it is not expected!"
  get_class_id $workload
  [[ $classid -eq 2 ]] || die "$workload class id is $classid and it is not expected!"
  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
}

workload_class3_mix_id_test() {
  fflag=0
  workload="PAUSE3"
  class_workload_launch $workload
  sleep 2s
  w_target_1="VNNI2"
  $w_target_1 &
  w_target_2="Class0"
  $w_target_2 &
  w_target_3="Class1"
  $w_target_3 &
  sleep 5s
  get_class_id $w_target_1
  [[ $classid -eq 2 ]] || die "$w_target_1 class id is $classid and it is not expected!"
  get_class_id $w_target_2
  [[ $classid -eq 0 ]] || die "$w_target_2 class id is $classid and it is not expected!"
  get_class_id $w_target_3
  [[ $classid -eq 1 ]] || die "$w_target_3 class id is $classid and it is not expected!"
  get_class_id $workload
  [[ $classid -eq 3 ]] || die "$workload class id is $classid and it is not expected!"
  kill_workloads $workload
  kill_workloads $w_target_1
  kill_workloads $w_target_2
  kill_workloads $w_target_3
}

class_workload_launch_m() {
  workload=$1
  get_core_ids
  num=$2
  for((i=0;i<num;i++)); do
    $workload &
  done
}

workload_class2_smt_test() {
  workload="VNNI2"
  let num=CORE_NUM*2
  class_workload_launch_m $workload $num
  ##all should be running on pcores
  sleep 5s
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] || die "Not all workloads are running on pcore!"
}

workload_classx_smt_test() {
  workload=$1
  let num=CORE_NUM+ATOM_NUM
  let num=num+1
  class_workload_launch_m $workload $num
  ##all should be running on pcore+ecore, no smt
  sleep 5s
  get_task_ids $num $workload
  [[ $atom_pid -eq ATOM_NUM ]] || die "Some workloads are on smt and atoms are not all occupied!"
  dup_times=0
  dup_check $workload
  [[ $dup_times -eq 0 ]] || die "Some workloads are running on same core!"
}

workload_class2_atom_test() {
  workload="VNNI2"
  let num=CORE_NUM+ATOM_NUM
  class_workload_launch_m $workload $num
  sleep 5s
  get_task_ids $num $workload
  ##all should be running on pcore+ecore, no smt
  [[ $atom_pid -eq ATOM_NUM ]] || die "Some workloads are on smt and atoms are not all occupied!"
  dup_times=0
  dup_check $workload
  [[ $dup_times -eq 1 ]] || die "Not only 2 workloads are running on same core!"
}

workload_classx_atom_test() {
  workload=$1
  let num=CORE_NUM+ATOM_NUM
  class_workload_launch_m $workload $num
  ##all should be running on pcore+ecore, no smt
  sleep 5s
  get_task_ids $num $workload
  [[ $atom_pid -eq ATOM_NUM ]] || die "Some workloads are on smt and atoms are not all occupied!"
  dup_times=0
  dup_check $workload
  [[ $dup_times -eq 1 ]] || die "Not only 2 workloads are running on same core!"
}

workload_class2_class1_test() {
  workload="VNNI2"
  let num=CORE_NUM*2
  class_workload_launch_m $workload $num
  wid=$(ps -aT -o comm,pid,spid,cpuid,%cpu | grep "$workload" | sed -n "1p" | awk '{print $2}' )
  test_print_trc "wid = $wid"
  sleep 5s
  w_class1="Class1"
  class_workload_launch_m $workload 1
  class_workload_launch_m $w_class1 1
  sleep 5s
  kill -9 $wid
  sleep 5s
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] || die "Some VNNI workload is running on atom!"
  get_task_ids 1 $w_class1
  [[ $atom_pid -eq 1 ]] || die "Class1 workload is not running on atom!"
}

hfi_test() {
  temp_log="hfi.log"
  do_cmd "intel-speed-select -d --oob -o $temp_log &"
  sleep 1s
  do_cmd "intel-speed-select perf-profile set-config-level -l 3"
  sleep 1s
  ppid=$(ps -al | grep intel-speed | awk '{print $4}')
  sleep 5s
  sync
  kill $ppid
  do_cmd "grep 'hfi is initialized' $temp_log"
  do_cmd "grep 'online cpu' $temp_log"
}

workload_class2_classx_test() {
  workload="VNNI2"
  w_class1="Class1"
  w_class0="Class0"
  w_class3="PAUSE3"
  let num=CORE_NUM
  class_workload_launch_m $workload $num
  sleep 5s
  class_workload_launch_m $w_class1 1
  class_workload_launch_m $w_class0 1
  class_workload_launch_m $w_class3 1
  sleep 5s

  kill_one_workload $workload
  sleep 5s
  let num=num-1
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] && die "Some $workload is running on atom!"
  [[ $dup_times -eq 0 ]] && die "2 workloads are running on same core!"
  get_task_ids 1 $w_class1
  [[ $core_pid -eq 1 ]] || die "$w_class1 is still running on atom!"
 
  kill_one_workload $workload
  sleep 5s
  let num=num-1
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] && die "Some $workload is running on atom!"
  [[ $dup_times -eq 0 ]] && die "2 workloads are running on same core!"
  get_task_ids 1 $w_class0
  [[ $core_pid -eq 1 ]] || die "$w_class0 is still running on atom!"  

  kill_one_workload $workload
  sleep 5s
  let num=num-1
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] && die "Some $workload is running on atom!"
  [[ $dup_times -eq 0 ]] && die "2 workloads are running on same core!"
  get_task_ids 1 $w_class3
  [[ $core_pid -eq 1 ]] || die "$w_class3 is still running on atom!" 
}

workload_class0_classx_test() {
  workload="Class0"
  w_class1="Class1"
  w_class2="VNNI2"
  w_class3="PAUSE3"
  let num=CORE_NUM
  class_workload_launch_m $workload $num
  sleep 5s
  class_workload_launch_m $w_class1 1
  class_workload_launch_m $w_class2 1
  class_workload_launch_m $w_class3 1
  sleep 5s

  kill_one_workload $workload
  sleep 5s
  let num=num-1
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] && die "Some $workload is running on atom!"
  [[ $dup_times -eq 0 ]] && die "2 workloads are running on same core!"
  get_task_ids 1 $w_class2
  [[ $core_pid -eq 1 ]] || die "$w_class2 is still running on atom!"
 
  kill_one_workload $workload
  sleep 5s
  let num=num-1
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] && die "Some $workload is running on atom!"
  [[ $dup_times -eq 0 ]] && die "2 workloads are running on same core!"
  get_task_ids 1 $w_class1
  [[ $core_pid -eq 1 ]] || die "$w_class1 is still running on atom!"  

  kill_one_workload $workload
  sleep 5s
  let num=num-1
  get_task_ids $num $workload
  [[ $atom_pid -eq 0 ]] && die "Some $workload is running on atom!"
  [[ $dup_times -eq 0 ]] && die "2 workloads are running on same core!"
  get_task_ids 1 $w_class3
  [[ $core_pid -eq 1 ]] || die "$w_class3 is still running on atom!"
}

package_policy_test() {
  get_core_ids
  duration=10000
  log="package_policy_test.log"
  temp_log="temp.log"
  #create fspin for each atom and assigned to atoms
  let instance=ATOM_NUM
  fspin -t $instance -i $duration -s 1 -q &
  atom_fspin_id=$(ps -aT | grep fspin |  awk '{print $1}' | uniq -c |  awk '{print $2}')
  test_print_trc "***********ATOM_NUM=$ATOM_NUM*********atom_fspin_id=$atom_fspin_id"
  atom_fspin_sub_ids=$(ps -aT | grep $atom_fspin_id | grep fspin-th |  awk '{print $2}')
  p_id=1
  for id in $ATOM_IDS; do
    atom_fspin_sub_id=$(echo $atom_fspin_sub_ids | tail -n 1 | awk -v p_id=$p_id '{print $p_id}')
    test_print_trc "id=$id, atom_fspin_sub_id=$atom_fspin_sub_id"
    taskset -pc $id $atom_fspin_sub_id
    let p_id=p_id+1
  done
  sleep 5
  #get atom cluset number
  f_id=$(echo $ATOM_IDS | tail -n 1 | awk '{print $1}')
  clusets=$(cat $CPU_SYS_PATH/cpu*/topology/cluster_cpus_list  | cut -d \- -f 1  | uniq)
  test_print_trc "f_id=$f_id,clusets=$clusets"
  cluset_num=0
  i=0;
  for id in $clusets; do
    if [[ $id -ge $f_id ]]; then
      let cluset_num=cluset_num+1
      cluset_group[i]=$id
      test_print_trc "cluset_group[$i]=${cluset_group[$i]}"
      let i=i+1
    fi  
  done
  test_print_trc "cluset_num=$cluset_num"
  #create fspin for each big core+cluset_num smt
  let instance_big_core=CORE_NUM+cluset_num
  fspin -t $instance_big_core -i $duration -s 1 -q &
  #kill fspin on atom
  sleep 5
  kill -9 $atom_fspin_id
  #check if fspin on smt migrate to different cluset of atom
  core_fspin_id=$(ps -aT | grep fspin |  awk '{print $1}' | uniq -c |  awk '{print $2}')
  sleep 5
  test_print_trc "atom_fspin_id=$atom_fspin_id,core_fspin_id=$core_fspin_id"
  i=0
  ps -aT -o comm,cpuid,%cpu | grep fspin-th > $log
  while [ $i -lt 10 ]
  do
    ps -aT -o comm,cpuid,%cpu | grep fspin-th > $temp_log
    echo "\n" >> $log
    cat $temp_log >> $log
    get_task_ids_fspin_package $instance_big_core $temp_log
    [[ $atom_pid -eq $cluset_num ]] || die "Workload on atom number is not correct!"
    while [ $i -lt $cluset_num ]
    do
      test_print_trc "check atom_cluset_group[$i]=${atom_cluset_group[$i]}"
      [[ ${atom_cluset_group[$i]} -ne 1 ]] && die "Workload on atoms are not in different package!"
    done  
    i=$((i + 1))
    sleep 2
  done
}

hybrid_test() {
  [[ -f $HGS_LOG ]] && rm $HGS_LOG
  [[ -f $RECORD_LOG ]] && rm $RECORD_LOG

  echo "comm pid spid cpuid cpu > $HGS_LOG"
  case $TEST_SCENARIO in
    hwp_sysfs)
      hwp_sysfs_test
      ;;
    cpuinfo_hgs)
      cpuinfo_hgs_test
      ;;
    cpuinfo_hgs_plus)
      cpuinfo_hgs_plus_test
      ;;
    sysfs)
      sysfs_test
      ;;
    cpuid_hgs)
      cpuid_hgs_test
      ;;
    cpuid_hgs_plus)
      cpuid_hgs_plus_test
      ;;
    hgs_table)
      hgs_table_test
      ;;
    hgs_plus_table)
      hgs_plus_table_test
      ;;
    workload_h_core)
      workload_h_test "core"
      ;;
    workload_h_atom)
      workload_h_test "atom"
      ;;
    workload_l_atom)
      workload_l_test "atom"
      ;;
    hotplug_core)
      hotplug_core_test
      ;;
    hotplug_atom)
      hotplug_atom_test
      ;;
    workload_switch)
      workload_switch_test
      ;;
    workload_rampup)
      workload_rampup_test
      ;;
    workload_decrease)
      workload_decrease_test
      ;;
    workload_fb)
      workload_fb_test
      ;;
    threads_block)
      threads_block_test
      ;;
    disk_io)
      disk_io_test
      ;;
    workload_avx2)
      workload_s_test "avx2"
      ;;
    workload_vnni)
      workload_s_test "vnni"
      ;;
    workload_vnni_avx2)
      workload_vnni_avx2_test
      ;;
    workload_avx2_fspin)
      workload_avx2_fspin_test
      ;;
    cpuid_hgs_plus_hreset)
      cpuid_hgs_plus_hreset_test
      ;;
    workload_h_rt_app)
      workload_h_rt_app_test
      ;;
    soc_atom)
      soc_atom_test
      ;;
    classid)
      classid_test
      ;;
    yogini)
      yogini_test
      ;;
    workload_class0)
      workload_class0_test
      ;;
    workload_class1)
      workload_class1_test
      ;;
    workload_class2)
      workload_class2_test
      ;;
    workload_class3)
      workload_class3_test
      ;;
    itmt_basic)
      itmt_basic_test
      ;;
    workload_class2_mix)
      workload_class2_mix_test
      ;;
    workload_class3_mix)
      workload_class3_mix_test
      ;;
    workload_class1_mix)
      workload_class1_mix_test
      ;;
    workload_class0_mix)
      workload_class0_mix_test
       ;;
    workload_class2_mix_id)
      workload_class2_mix_id_test
      ;;
    workload_class3_mix_id)
      workload_class3_mix_id_test
      ;;
    workload_class1_mix_id)
      workload_class1_mix_id_test
      ;;
    workload_class0_mix_id)
      workload_class0_mix_id_test
      ;;
    workload_class2_smt)
      workload_class2_smt_test
      ;;
    workload_class0_smt)
      workload_classx_smt_test "Class0"
      ;;
    workload_class1_smt)
      workload_classx_smt_test "Class1"
      ;;
    workload_class3_smt)
      workload_classx_smt_test "PAUSE3"
      ;;
    workload_class2_atom)
      workload_classx_atom_test "Class2"
      ;;
    workload_class0_atom)
      workload_classx_atom_test "Class0"
      ;;
    workload_class1_atom)
      workload_classx_atom_test "Class1"
      ;;
    workload_class3_atom)
      workload_classx_atom_test "PAUSE3"
      ;;
    workload_class2_class1)
      workload_class2_class1_test
      ;;
    workload_class2_classx)
      workload_class2_classx_test
      ;;
    workload_class0_classx)
      workload_class0_classx_test
      ;;
    hfi)
      hfi_test
      ;;
    package_policy)
      package_policy_test
      ;;
    esac
  return 0
}

while getopts :t:w:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    H)
      usage && exit 0
      ;;
    \?)
      usage
      die "Invalid Option -$OPTARG"
      ;;
    :)
      usage
      die "Option -$OPTARG requires an argument."
      ;;
  esac
done

hybrid_test
# Call teardown for passing case
exec_teardown
