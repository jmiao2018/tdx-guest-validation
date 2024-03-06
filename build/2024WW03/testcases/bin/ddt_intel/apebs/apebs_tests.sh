#!/bin/bash
#
# Copyright 2018 Intel Corporation
#
# This file is part of LTP-DDT for IA
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Ammy Yi <ammy.yi@intel.com>
#
# History:
#             Nov. 14, 2018 - (Ammy Yi)Creation


# @desc This script verify Adaptive PEBS test
# @returns Fail the test if return code is non-zero (value set not found)


source "common.sh"
: ${CASE_NAME:=""}
: ${WATCHDOG:=0}
: ${RAWFILE:="perf.data"}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

check_report_data() {
  report_log=$1
  c_target=$2
  cat $report_log
  data=$(cat $report_log | grep % | grep f3 | awk '{print $1}' | awk '{sum+=$1} END {print sum}')
  test_print_trc "percentage in perf report is $data!"
  [ $(echo "$data > $c_target" | bc) -eq 1 ] || die "percentage $data is lower than $c_target!"
}

lbr_test() {
  level=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  perf record -o $perfdata -b -e cycles:$level -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  lbr_count=$(perf report -D -i $perfdata| grep -c "branch stack")
  test_print_trc "sample_count = $sample_count; lbr_count = $lbr_count"
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $lbr_count ]] || die "samples does not match!"
}

lbr_test() {
  level=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  perf record -o $perfdata -b -e cycles:$level -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "branch stack")
  test_print_trc "sample_count = $sample_count; count = $count"
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

xmm_test() {
  level=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  perf record -o $perfdata -IXMM0 -e cycles:$level -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "XMM0")
  test_print_trc "before sample_count = $sample_count; count = $count"
  let sample_count=sample_count*2
  test_print_trc "after sample_count = $sample_count; count = $count"
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

ip_test() {
  level=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  task="mem-loads"
  model=$(cat /proc/cpuinfo | grep model | awk '{print $3}' | head -1)
  [[ $model -eq 150 ]] && task="cycles"
  [[ $model -eq 156 ]] && task="cycles"
  test_print_trc "task=$task"
  #perf record -o $perfdata -e $task:$level -d -a sleep 1 2> $logfile
  perf mem record -o $perfdata  -t load -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "data_src")
  test_print_trc "sample_count = $sample_count; count = $count"
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

get_func_file() {
  addfile=$1
  addfile_f=$2
  grep -A 17 "<f3>:" $addfile > $addfile_f
  sync
  sync
  sleep 1
  grep -A 14 "<f2>:" $addfile >> $addfile_f
  sync
  sync
  sleep 1
  grep -A 14 "<f1>:" $addfile >> $addfile_f
  sync
  sync
  sleep 1
  grep -A 14 "<main>:" $addfile >> $addfile_f
  sync
  sync
  sleep 1
}

benchmark_test() {
  perf_report="perf_report.log"
  perfdata="pebs.data"
  addfile="add.txt"
  addfile_f="add_f.txt"
  logfile="temp.txt"
  target=95
  path=$(pwd)
  benchmark=$path"/ddt_intel/apebs/tchain_edit_zero"
  # do record and get report
  perf record -o $RAWFILE -j u -e cycles:up $benchmark 2> $logfile
  # get address
  do_cmd "objdump -dx $benchmark > $addfile"
  perf report -D > $perfdata
  perf report > $perf_report
  check_report_data $perf_report $target
  sync
  sync
  sleep 1
  get_func_file $addfile $addfile_f
  sample=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  [[ $sample -eq 0 ]] && die "samples = 0!"
  cat $logfile
  # check samples/branch/thread/dso
  branch=$(grep -c "branch" $path/$perfdata)
  thread=$(grep -c "thread: tchain_edit_zer" $path/$perfdata)
  dso=$(grep -c "/tchain_edit_zero" $path/$perfdata)
  percent=$dso
  let thread_taget=branch*target/100
  test_print_trc "sample=$sample branch=$branch thread=$thread dso=$dso, thread_taget=$thread_taget"
  [[ $sample -eq $branch ]] || die "samples does not match branch!"
  [[ $branch -gt $thread_taget ]] || die "branch does not match 95% thread!"
  let percent=dso*100
  let percent=percent/branch
  test_print_trc "percent=$percent"
  [[ $percent -gt $target ]] || die "percentage is lower than $target!"
  # check thread/dso address
  count_sum=0
  count=0
  thread_add="thread.log"
  dso_add="dso.log"
  thread_add_s="thread_s.log"
  dso_add_s="dso_s.log"
  grep "\->" $perfdata | awk '{print $3}' > $thread_add
  grep "\->" $perfdata | awk '{print $5}' > $dso_add
  sync
  sync
  sleep 1
  count_sum=$(sed -n '$=' $thread_add)
  test_print_trc "count_sum=$count_sum"
  sort -n $thread_add | uniq > $thread_add_s
  sort -n $dso_add | uniq > $dso_add_s
  sync
  sync
  sleep 1
  while read line; do
    temp=0
    d_add=$(echo ${line:10})
    test_print_trc "line=$line"
    test_print_trc "d_add=$d_add"
    if [[ -n "$d_add" ]]; then
      grep $d_add $addfile_f
      if [[ $? -eq 0 ]]; then
        temp=$(grep -c "$line" $thread_add)
        let count=count+temp
        test_print_trc "add find: count=$count temp=$temp"
      fi
    fi
  done < $thread_add_s
  let percent=count*100
  let percent=percent/count_sum
  [[ $percent -gt $target ]] || die "percentage is lower than $target of thread address!"
  test_print_trc "percent=$percent"
  sleep 1
  count=0
  percent=0
  while read line; do
    temp=0
    d_add=$(echo ${line:10})
    test_print_trc "line=$line"
    test_print_trc "d_add=$d_add"
    if [[ -n "$d_add" ]]; then
      grep $d_add $addfile_f
      if [[ $? -eq 0 ]]; then
        temp=$(grep -c "$line" $dso_add)
        let count=count+temp
        test_print_trc "add find: count=$count temp=$temp"
      fi
    fi
  done < $dso_add_s
  let percent=count*100
  let percent=percent/count_sum
  [[ $percent -gt $target ]] || die "percentage is lower than $target of dso address!"
  test_print_trc "percent=$percent"
}

large_pebs_test() {
  perf_report="perf_report.log"
  perfdata="pebs.data"
  addfile="add.txt"
  addfile_f="add_f.txt"
  logfile="temp.txt"
  target=95
  path=$(pwd)
  benchmark=$path"/ddt_intel/apebs/tchain_edit_zero"
  # do record and get report
  perf record -o $RAWFILE -c 2000003 -e cycles:p $benchmark 2> $logfile
  perf report -D > $perfdata
  # get address
  do_cmd "objdump -dx $benchmark > $addfile"
  perf report > $perf_report
  check_report_data $perf_report $target
  get_func_file $addfile $addfile_f
  sample=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  [[ $sample -eq 0 ]] && die "samples = 0!"
  cat $logfile
  # check samples/branch/thread/dso
  thread=$(grep -c "thread: tchain_edit_zer" $path/$perfdata)
  dso=$(grep -c "/tchain_edit_zero" $path/$perfdata)
  test_print_trc "sample=$sample branch=$branch thread=$thread dso=$dso"
  percent=$dso
  [[ $sample -eq $thread ]] || die "thread does not match sample!"
  let percent=dso*100
  let percent=percent/sample
  test_print_trc "percent=$percent"
  [[ $percent -gt $target ]] || die "percentage is lower than $target!"
  # check thread/dso address
  count_sum=0
  count=0
  # get samples address
  period_log="period.log"
  period_log_s="period_log_s.log"
  grep "period:" $perfdata | awk '{print $7}' > $period_log
  sort -n $period_log | uniq > $period_log_s
  count_sum=$(sed -n '$=' $period_log)
  while read line; do
    temp=0
    add=$(echo ${line:2})
    test_print_trc "line=$line"
    test_print_trc "add=$add"
    if [[ -n "$add" ]]; then
      grep $add $addfile_f
      if [[ $? -eq 0 ]]; then
        temp=$(grep -c "$line" $period_log)
        let count=count+temp
        test_print_trc "add find: count=$count temp=$temp"
      fi
    fi
  done < $period_log_s
  let percent=count*100
  let percent=percent/count_sum
  [[ $percent -gt $target ]] || die "percentage is lower than $target of dso address!"
  test_print_trc "percent=$percent"
}

data_src_test() {
  level=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  perf record -o $perfdata -b -e cycles:$level -d -a sleep 1 2> $logfile
  sync
  sync
  sleep 1
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "data_src")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

readonly POWER_STATE_NODE="/sys/power/state"
readonly POWER_DISK_NODE="/sys/power/disk"
readonly POWER_PM_TEST_NODE="/sys/power/pm_test"

suspend_to_resume() {
  local state=$1
  local rtc_time=20

  echo platform > "$POWER_DISK_NODE"
  echo none > "$POWER_PM_TEST_NODE"

  case $state in
    freeze)
      echo freeze > "$POWER_STATE_NODE" &
      rtcwake -m no -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      wait $!
      [[ $? -eq 0 ]] || die "fail to echo $state > $POWER_STATE_NODE!"
      ;;
    mem|disk)
      echo deep > /sys/power/mem_sleep
      rtcwake -m "$state" -s "$rtc_time"
      [[ $? -eq 0 ]] || die "fail to resume from $state!"
      ;;
    *)
      die "state: $state not supported!"
      ;;
  esac
}

sr_test() {
  level=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  test_print_trc "will enter s/r!!"
  perf record -o $perfdata -b -e cycles:$level -a sleep 60 2> $logfile& suspend_to_resume disk
  wait
  test_print_trc "exit s/r!!"
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  lbr_count=$(perf report -D -i $perfdata| grep -c "branch stack")
  test_print_trc "sample_count = $sample_count; lbr_count = $lbr_count"
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $lbr_count ]] || die "samples does not match!"
}

cet_test() {
  perfdata="pebs.data"
  addfile="add.txt"
  addfile_f="add_f.txt"
  logfile="temp.txt"
  target=95
  path=$(pwd)
  benchmark="${path}/ddt_intel/apebs/${BIN}"
  test_print_trc "benchmark=$benchmark"
  model=$(cat /proc/cpuinfo | grep model | awk '{print $3}' | head -1)
  grep shstk /proc/cpuinfo
  if [[ $? -eq 0 ]]; then
    if [[ $model -eq 151 ]] || [[ $model -eq 154 ]] || [[ $model -eq 183 ]] || [[ $model -eq 186 ]]; then
      echo 1 > /sys/devices/cpu_atom/cet_shadow_stack_call_chain
      echo 1 > /sys/devices/cpu_core/cet_shadow_stack_call_chain
    else
      echo 1 > /sys/devices/cpu/cet_shadow_stack_call_chain
    fi
    value=("nr:6" "nr:7" "nr:8")
  elif [[ $? -eq 1 ]]; then
    value=("nr:2" "nr:3" "nr:4")
  fi
  # do record and get report
  perf record -o $RAWFILE --call-graph fp $benchmark 2> $logfile
  perf report -D > $perfdata
  # get address
  sync
  sync
  sleep 1
  sample=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  [[ $sample -eq 0 ]] && die "samples = 0!"
  fp_total=0
  fp=0
  for val in "${value[@]}"; do
    test_print_trc "val=$val"
    fp=$(grep -c "FP chain: $val" $path/$perfdata)
    test_print_trc "fp=$fp fp_total=$fp_total"
    let fp_total=fp_total+fp
  done

  test_print_trc "sample=$sample fp_total=$fp_total"
  percent=$fp_total
  let percent=fp_total*100
  let percent=percent/sample
  test_print_trc "percent=$percent"
  [[ $percent -gt $target ]] || die "percentage is lower than $target!"
}

apebs_test() {
  echo $WATCHDOG > /proc/sys/kernel/nmi_watchdog
  wd_value=$(cat /proc/sys/kernel/nmi_watchdog)
  test_print_trc "nmi_watchdog = $wd_value"
  case $TEST_SCENARIO in
    lbr_1)
      lbr_test p
      ;;
    lbr_2)
      lbr_test P
      ;;
    xmm_1)
      xmm_test p
      ;;
    xmm_2)
      xmm_test P
      ;;
    ip_1)
      ip_test p
      ;;
    ip_2)
      ip_test P
      ;;
    benchmark)
      benchmark_test
      ;;
    large_pebs)
      large_pebs_test
      ;;
    data_src)
      data_src_test p
      ;;
    sr)
      sr_test p
      ;;
    cet)
      cet_test
      ;;
    esac
  return 0
}

while getopts :t:b:w:l:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    w)
      WATCHDOG=$OPTARG
      ;;
    b)
      BIN=$OPTARG
      ;;
    l)
      STRESS_TIMES=$OPTARG
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

apebs_test
# Call teardown for passing case
exec_teardown
