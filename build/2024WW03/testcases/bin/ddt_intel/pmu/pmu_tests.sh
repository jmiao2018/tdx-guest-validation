#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2019 Intel Corporation
#
# File:         pmu_tests.sh
#
# Description:  PMU test script
#
# Author(s):    Ammy Yi <ammy.yi@intel.com>
#
# Date:         11/18/2019
#


source "common.sh"
source "apebs_tests.sh"
: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

model=0

fix_counter_test() {
  # platform before ICL: uncore_cbox_0/clockticks/
  flag=0
  clockticks="uncore_cbox_0/clockticks/"
  logfile="temp.txt"

  perf stat -e $clockticks -a -x, sleep 1 2> $logfile
  if [[ $? -ne 0 ]]; then
    let flag=flag+1
  else
    sync
    sync
    sleep 1
    value=$(cat $logfile)
    test_print_trc "value = $value"
    value=$(echo $value | cut -d "," -f 1)
    test_print_trc "value_2 = $value"
    if [[ $value -le 1000000 ]] || [[ $value -gt 10000000000 ]]; then
      die "Counters are not correct!"
    fi
  fi

  # platform after ICL: uncore_clock/clockticks
  clockticks="uncore_clock/clockticks/"
  model=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  case $model in
    170)
      clockticks="uncore_sncu/clockticks/"
      perf stat -e $clockticks -a -x, sleep 1 2> $logfile
      if [[ $? -ne 0 ]]; then
        let flag=flag+1
      else
        sync
        sync
        sleep 1
        value=$(cat $logfile)
        test_print_trc "value = $value"
        value=$(echo $value | cut -d "," -f 1)
        test_print_trc "value_2 = $value"
        if [[ $value -le 1000000 ]] || [[ $value -gt 10000000000 ]]; then
          die "Counters are not correct!"
        fi
      fi
      clockticks="uncore_cncu/clockticks/"
      ;;
  esac

  perf stat -e $clockticks -a -x, sleep 1 2> $logfile
  if [[ $? -ne 0 ]]; then
    let flag=flag+1
  else
    sync
    sync
    sleep 1
    value=$(cat $logfile)
    test_print_trc "value = $value"
    value=$(echo $value | cut -d "," -f 1)
    test_print_trc "value_2 = $value"
    if [[ $value -le 1000000 ]] || [[ $value -gt 10000000000 ]]; then
      die "Counters are not correct!"
    fi
  fi

  test_print_trc "flag = $flag"
  [[ $flag -eq 2 ]] && die "Fix counter is not working!"

}

get_model() {
  model=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  case $model in
    150)
      folder="ehl"
      ;;
    143)
      folder="spr"
      ;;
    151)
      folder="adl"
      ;;
    154)
      folder="adl"
      ;;
###rpl-s
    183)
      folder="adl"
      ;;
  esac
}

events_check() {
  suffix=$1
  path=$(pwd)
  test_print_trc "suffix = $suffix"
  cd ddt_intel/pmu/ && tar -xvf pmu_events$suffix.tar
  cd $path
  events_file="event$suffix.list"
  get_model
  events_path=$path"/ddt_intel/pmu/pmu_events$suffix/"
  events_path=$events_path$folder
  files=$(ls $events_path | grep json)
  test_print_trc "files = $files"
  rm -rf $events_file
  for f in $files;
  do
    grep -e "EventName" $events_path/$f | awk '{print $2}'| cut -d ',' -f 1 >> $events_file
  done
  events=$(cat $events_file)
  test_print_trc "events = $events"
  [[ -z $events ]] && die "No events"
  case $suffix in
    "")
      m_suffix="-e"
      ;;
    "_metrics")
      m_suffix="-M"
      ;;
    esac
  for event in $events;
  do  
      do_cmd "perf stat $m_suffix $event -a sleep 0.1"
  done
}

basic_test() {
  do_cmd "dmesg | grep 'Intel PMU driver'"
  inverted_return="true"
  do_cmd "dmesg | grep 'generic architected perfmon'"
}

mrslist_cpuid_test() {
  #07H.01H:EAX[d27]: RDMSRLIST_WRMSRLIST
  #EAX=07H ECX=01H EAX[d19]: WRMSRNS
  do_cmd "cpuid_check 7 0 1 0 a 27"
  do_cmd "cpuid_check 7 0 1 0 a 19"
}

lbr_events_cpuid_test() {
  #CPUID leaf 0x1c  ECX (19:16) must be all 1 for SRF.
  for((i=16;i<=19;i++)); do
    do_cmd "cpuid_check 1c 0 0 0 c $i"
  done
}

lbr_events_test() {
  perf_log="perf_record.log"
  temp_log="perf.log"
  perf record -b -e "{instructions,instructions:p}:B" -C0 sleep 1 >& $perf_log
  [[ $? -eq 0 ]] || die "perf record failed!"
  do_cmd "perf report -D > $temp_log"
  val1=$(grep 'cycles' $temp_log | grep -c '\-')
  val2=$(grep 'cycles' $temp_log | awk '{print $9}' | grep -c "0x")
  [[ $val1 -eq $val2 ]] || die "perf record failed!"
  lbr_vals=$(grep 'cycles' $temp_log | awk '{print $9}')
  for lbr_val in $lbr_vals; do
    temp=$(echo ${lbr_val:2})
    temp=$(echo $((16#$temp)))
    test_print_trc "address=$temp, lbr_val=$lbr_val!"
    [[ $temp -ge 0 && $temp -le 15 ]] || die "lbr address is not correct!"
  done
}

lbr_events_instructions_test() {
  perf_log="perf_record.log"
  temp_log="perf.log"
  perf record -b -e "instructions:B" -C0 sleep 1 >& $perf_log
  [[ $? -eq 0 ]] || die "perf record failed!"
  do_cmd "perf report -D > $temp_log"
  val1=$(grep 'cycles' $temp_log | grep -c '\-')
  val2=$(grep 'cycles' $temp_log | awk '{print $9}' | grep -c "0x")
  [[ $val1 -eq $val2 ]] || die "perf record failed!"
  lbr_vals=$(grep 'cycles' $temp_log | awk '{print $9}')
  for lbr_val in $lbr_vals; do
    temp=$(echo ${lbr_val:2})
    temp=$(echo $((16#$temp)))
    test_print_trc "address=$temp, lbr_val=$lbr_val!"
    [[ $temp -ge 0 && $temp -le 3 ]] || die "lbr address is not correct!"
  done
}

lbr_events_instructions_p_test() {
  perf_log="perf_record.log"
  temp_log="perf.log"
  perf record -b -e "instructions:pB" -C0 sleep 1 >& $perf_log
  [[ $? -eq 0 ]] || die "perf record failed!"
  do_cmd "perf report -D > $temp_log"
  val1=$(grep 'cycles' $temp_log | grep -c '\-')
  val2=$(grep 'cycles' $temp_log | awk '{print $9}' | grep -c "0x")
  [[ $val1 -eq $val2 ]] || die "perf record failed!"
  lbr_vals=$(grep 'cycles' $temp_log | awk '{print $9}')
  for lbr_val in $lbr_vals; do
    temp=$(echo ${lbr_val:2})
    temp=$(echo $((16#$temp)))
    test_print_trc "address=$temp, lbr_val=$lbr_val!"
    [[ $temp -ge 0 && $temp -le 3 ]] || die "lbr address is not correct!"
  done
}

lbr_events_s_test() {
  perfdata="perf.data"
  logfile="temp.txt"
  perf record -o $perfdata -e "{branch-instructions,branch-misses}:S" -j any,counter sleep 1 >& $logfile
  [[ $? -eq 0 ]] || die "perf record failed!"
  sample_count=$(grep "sample" $logfile| awk '{print $10}' | tr -cd "[0-9]")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  val=$(perf report -D -i $perfdata | grep -c "branch stack counters")
  [[ $val -eq 0 ]] && die "branch stack counters val = 0!"
  lbr_vals=$(perf report -D -i $perfdata | grep "branch stack counters" | awk '{print $5}')
  for lbr_val in $lbr_vals; do
    temp=$(echo $lbr_val | cut -d ":" -f 2)
    test_print_trc "counts=$temp, lbr_val=$lbr_val!"
    [[ $temp -eq 0 ]] && die "branch stack counters = 0!"
  done
}

lbr_events_all_test() {
  perfdata="perf.data"
  logfile="temp.txt"
  perf record -o $perfdata -e "{cpu/branch-instructions,branch_type=any/, cpu/branch-misses,branch_type=counter/}" sleep 1 >& $logfile
  [[ $? -eq 0 ]] || die "perf record failed!"
  sample_count=$(grep "sample" $logfile| awk '{print $10}' | tr -cd "[0-9]")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  val=$(perf report -D -i $perfdata | grep -c "branch stack counters")
  [[ $val -eq 0 ]] && die "branch stack counters val = 0!"
  lbr_vals=$(perf report -D -i $perfdata | grep "branch stack counters" | awk '{print $5}')
  for lbr_val in $lbr_vals; do
    temp=$(echo $lbr_val | cut -d ":" -f 2)
    test_print_trc "counts=$temp, lbr_val=$lbr_val!"
    [[ $temp -eq 0 ]] && die "branch stack counters = 0!"
  done 
}

timed_pebs_msr_test() {
  #MSR_IA32_PERF_CAPABILITIES(0x345) bit 17 for Timed PEBs
  msr_val=$(rdmsr 0x345)
  msr_val=$((16#${msr_val}))
  val="65536"
  tp_msr=$((msr_val & val))
  test_print_trc "msr_val=$msr_val, tp_msr=$tp_msr, val=$val"
  [[ $tp_msr -eq val ]] || die "Timed PEBS msr bit is not set!"  
}

Uncore_DID0_test() {
  #case for https://jira.devtools.intel.com/browse/LFE-6892
  perf_log="perf_record.log"
  perf stat -e uncore_imc/event=0x1/ sleep 1 >& $perf_log
  [[ $? -eq 0 ]] || die "perf record failed!"  
}

uncore_dmesg_check() {
  ##Uncore is failed when there is following dmesg:
  ##“Invalid address is detected for uncore type %d box %d, Disable the uncore unit.”
  ##“A spurious uncore type %d is detected, Disable the uncore type.”
  ##“Duplicate uncore type %d box ID %d is detected, Drop the duplicate uncore unit.”
  should_fail "dmesg | grep 'Disable the uncore'"
  should_fail "dmesg | grep 'Drop the duplicate uncore unit'"
  should_fail "dmesg | grep 'Invalid address is detected for uncore type'"
}

arch_pebs_cpuid_test() {
  ##CPUID.0x23.0.EAX[5] == 1
  do_cmd "cpuid_check 23 0 0 0 a 5"
}

reg_group_test(){
  reg=$1
  perfdata="pebs.data"
  logfile="temp.txt"
  perf record -o $perfdata -I$reg -e cycles:$level -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c ". $reg")
  test_print_trc "before sample_count = $sample_count; count = $count"
  let sample_count=sample_count
  test_print_trc "after sample_count = $sample_count; count = $count"
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

arch_pebs_gp_reg_group_test() {
  ##CPUID.0x23.4.EBX.GPR[29] == 1
  do_cmd "cpuid_check 23 0 4 0 b 29"
  level="p"
  reg_group_test "AX"
  reg_group_test "BX"
  reg_group_test "CX"
  reg_group_test "DX"
  reg_group_test "SI"
  reg_group_test "DI"
  reg_group_test "BP"
  reg_group_test "SP"
  reg_group_test "IP"
  reg_group_test "FLAGS"
  reg_group_test "CS"
  reg_group_test "SS"
  reg_group_test "DS"
  reg_group_test "ES"
  reg_group_test "FS"
  reg_group_test "GS"
  reg_group_test "R8" 
}

arch_pebs_xer_group_test() {
  level="p"
  reg_group_test "OPMASK0"
  reg_group_test "YMMH0"
  reg_group_test "ZMMH0"
}

arch_pebs_counter_group_test() {
  perfdata="pebs.data"
  logfile="temp.txt"
  perfdata_s="pebs_s.data"
  logfile_s="temp_s.txt"
  mode=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  case $mode in
    cwf)
      perf record -o $perfdata_s -e '{cycles:p,cache-misses,cache-references, topdown-bad-spec,topdown-fe-bound,topdown-retiring}:S' -- sleep 1 2> $logfile_s
      perf record -o $perfdata -e '{cycles,cache-misses,cache-references, topdown-bad-spec,topdown-fe-bound,topdown-retiring}:p' -- sleep 1 2> $logfile
      ;;
    dmr)
      perf record -o $perfdata_s -e '{slots:p,cache-misses,cache-references, topdown-bad-spec,topdown-fe-bound,topdown-retiring}:S' -- sleep 1 2> $logfile_s
      perf record -o $perfdata -e '{slots,cache-misses,cache-references, topdown-bad-spec,topdown-fe-bound,topdown-retiring}:p' -- sleep 1 2> $logfile      
      ;;
  esac
  sample_count=$(grep "sample" $logfile_s | awk '{print $10}' | tr -cd "[0-9]")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "PERF_RECORD_SAMPLE")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

arch_pebs_counter_group_stress_test() {
  perfdata="pebs.data"
  logfile="temp.txt"
  #because nmi_watchdog will occupy one fix counter, so disable it
  echo 0 > /proc/sys/kernel/nmi_watchdog
  perf record -o $perfdata -e '{branches,branches,branches,branches,branches,branches, branches,branches,cycles,instruction,ref-cycle,topdown-bad-spec,topdown-fe-bound,topdown-retiring }:p' -- sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "PERF_RECORD_SAMPLE")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!"
}

arch_pebs_gp_counter_test() {
  perfdata="pebs.data"
  logfile="temp.txt" 
  perf record -o $perfdata -e branches:p -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile| awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "PERF_RECORD_SAMPLE")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!" 
}

arch_pebs_basic_group_test() {
  perfdata="pebs.data"
  logfile="temp.txt" 
  perf record -o $perfdata -e cycles:pp -a sleep 1 2> $logfile
  sample_count=$(grep "sample" $logfile | awk '{print $10}' | tr -cd "[0-9]")
  count=$(perf report -D -i $perfdata| grep -c "PERF_RECORD_SAMPLE")
  [[ $sample_count -eq 0 ]] && die "samples = 0!"
  [[ $sample_count -eq $count ]] || die "samples does not match!" 
}

arch_pebs_stress_test() {
  test_print_trc "STRESS_TIMES = $STRESS_TIMES!!!!!"
  for((i=0;i<$STRESS_TIMES;i++)); do
    arch_pebs_gp_reg_group_test
    arch_pebs_xer_group_test
    arch_pebs_counter_group_test
    arch_pebs_counter_group_stress_test
    arch_pebs_gp_counter_test
    arch_pebs_basic_group_test 
    data_src_test p
    lbr_test p
  done
}

version_test() {
  version=$(dmesg | grep -A 8  "Intel PMU" | grep version | awk '{print $5}')
  [[ $version -eq 6 ]] || die "version = $version not expected!"
}

bitmap_6_test() {
  gbitmap=$(dmesg | grep -A 8  "Intel PMU" | grep "generic bitmap" | awk '{print $6}')
  fbitmap=$(dmesg | grep -A 8  "Intel PMU" | grep "fixed-purpose bitmap" | awk '{print $6}')
  [[ $gbitmap = "00000000000000ff" ]] || die "gbitmap = $gbitmap not expected!"
  [[ $fbitmap = "0000000000000077" ]] || die "fbitmap = $fbitmap not expected!"
}

umask2_cpuid_test() {
  ##EAX=023H, ECX=0, EBX=0=1
  do_cmd "cpuid_check 23 0 0 0 b 0"
}

zbit_cpuid_test() {
  ##EAX=023H, ECX=0, EBX=1=1
  do_cmd "cpuid_check 23 0 0 0 b 1"
}

umask2_test() {
  perf_log="perf.log"
  model=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  if [[ $model -eq 189 ]]; then
    do_cmd "perf stat -e cpu_atom/event=0xd1,umask=0x0201,name=MEM_LOAD_RETIRED.L1_L2_HIT/ sleep 1 >& $perf_log"
    counts=$(grep "MEM_LOAD_RETIRED" $perf_log | awk '{print $1}' | tr -cd "[0-9]")
    [[ $counts != 0 ]] || die "atom counts not > 0!" 
    do_cmd "perf stat -e cpu_core/event=0xd1,umask=0x0201,name=MEM_LOAD_RETIRED.L1_L2_HIT/ sleep 1 >& $perf_log"
    counts=$(grep "MEM_LOAD_RETIRED" $perf_log | awk '{print $1}' | tr -cd "[0-9]")
    [[ $counts != 0 ]] || die "counts not > 0!" 
  else
    do_cmd "perf stat -e cpu/event=0xd1,umask=0x0201,name=MEM_LOAD_RETIRED.L1_L2_HIT/ sleep 1 >& $perf_log"
  fi
  counts=$(grep "MEM_LOAD_RETIRED" $perf_log | awk '{print $1}' | tr -cd "[0-9]")
  [[ $counts != 0 ]] || die "counts not > 0!" 
}

zbit_test() {
  perf_log="perf.log"
  model=$(cat /proc/cpuinfo | grep mode | awk '{print $3}' | awk 'NR==1')
  if [[ $model -eq 189 ]]; then
    do_cmd "perf stat -e cpu_atom/event=0x11,umask=0x10,cmask=1,eq=1,name=ITLB_MISSES.WALK_ACTIVE_1/ sleep 1 >& $perf_log"
    do_cmd "perf stat -e cpu_core/event=0x11,umask=0x10,cmask=1,eq=1,name=ITLB_MISSES.WALK_ACTIVE_1/ sleep 1 >& $perf_log"
  else
    do_cmd "perf stat -e cpu/event=0x11,umask=0x10,cmask=1,eq=1,name=ITLB_MISSES.WALK_ACTIVE_1/ sleep 1 >& $perf_log"
  fi
}

counting_test() {
  perf_log="perf.log"
  do_cmd "perf stat -e cpu/event=0x3c,umask=0x0,name=CYCLES/ \
    -e cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/ \
    -e cpu/event=0x9c,umask=0x01,name=TOPDOWN_FE_BOUND/ \
    -e cpu/event=0xc2,umask=0x02,name=TOPDOWN_RETIRING/ \
    -e cpu/event=0xa4,umask=0x02,name=TOPDOWN_BE_BOUND/ sleep 1 >& $perf_log"
  CYCLES=$(grep "CYCLES" $perf_log | awk '{print $1}')
  TOPDOWN_BAD_SPEC=$(grep "TOPDOWN_BAD_SPEC" $perf_log | awk '{print $1}')
  TOPDOWN_RETIRING=$(grep "TOPDOWN_RETIRING" $perf_log | awk '{print $1}')
  TOPDOWN_BE_BOUND=$(grep "TOPDOWN_BE_BOUND" $perf_log | awk '{print $1}')
  [[ $CYCLES != 0 ]] || die "counts = 0 for CYCLES!"
  [[ $TOPDOWN_BAD_SPEC != 0 ]] || die "counts = 0 for TOPDOWN_BAD_SPEC!"
  [[ $TOPDOWN_RETIRING != 0 ]] || die "counts = 0 for TOPDOWN_RETIRING!"
  [[ $TOPDOWN_BE_BOUND != 0 ]] || die "counts = 0 for TOPDOWN_BE_BOUND!"
}

sampling_test() {
  perf_log="perf.log"
  do_cmd "perf record -e topdown-bad-spec sleep 1 >& $perf_log"
  samples=$(grep "sample" $perf_log | awk '{print $10}' | tr -cd "[0-9]")
  test_print_trc "topdown-bad-spec sample = $samples"
  [[ $samples -eq 0 ]] && die "samples = 0 for topdown-bad-spec!"

  do_cmd "perf record -e topdown-fe-bound sleep 1 >& $perf_log"
  samples=$(grep "sample" $perf_log | awk '{print $10}' | tr -cd "[0-9]")
  test_print_trc "topdown-fe-bound sample = $samples"
  [[ $samples -eq 0 ]] && die "samples = 0 for topdown-fe-bound!"

  do_cmd "perf record -e topdown-retiring sleep 1 >& $perf_log"
  samples=$(grep "sample" $perf_log | awk '{print $10}' | tr -cd "[0-9]")
  test_print_trc "topdown-retiring sample = $samples"
  [[ $samples -eq 0 ]] && die "samples = 0 for topdown-retiring!"

  do_cmd "perf record -e topdown-be-bound sleep 1 >& $perf_log"
  samples=$(grep "sample" $perf_log | awk '{print $10}' | tr -cd "[0-9]")
  test_print_trc "topdown-be-bound sample = $samples"
  [[ $samples -eq 0 ]] && die "samples = 0 for topdown-be-bound!"

}

counting_multi_test() {
  perf_log="perf.log"
  do_cmd "perf stat -e '{cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BAD_SPEC/}' sleep 1 >& $perf_log"
  counts=$(grep "TOPDOWN_BE_BOUND" $perf_log | awk '{print $1}')
  for count in $counts; do
    val=$(echo $count | tr -cd "[0-9]")
    [[ $val != 0 ]] || die "counts = 0 for TOPDOWN_BAD_SPEC!"
  done

  do_cmd "perf stat -e '{cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_FE_BOUND/}' sleep 1 >& $perf_log"
  counts=$(grep "TOPDOWN_FE_BOUND" $perf_log | awk '{print $1}')
  for count in $counts; do
    val=$(echo $count | tr -cd "[0-9]")
    [[ $val != 0 ]] || die "counts = 0 for TOPDOWN_FE_BOUND!"
  done

  do_cmd "perf stat -e '{cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_BE_BOUND/}' sleep 1 >& $perf_log"
  counts=$(grep "TOPDOWN_BE_BOUND" $perf_log | awk '{print $1}')
  for count in $counts; do
    val=$(echo $count | tr -cd "[0-9]")
    [[ $val != 0 ]] || die "counts = 0 for TOPDOWN_BE_BOUND!"
  done

  do_cmd "perf stat -e '{cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/, \
    cpu/event=0x73,umask=0x0,name=TOPDOWN_RETIRING/}' sleep 1 >& $perf_log"
  counts=$(grep "TOPDOWN_RETIRING" $perf_log | awk '{print $1}')
  for count in $counts; do
    val=$(echo $count | tr -cd "[0-9]")
    [[ $val != 0 ]] || die "counts = 0 for TOPDOWN_RETIRING!"
  done

}

pmu_test() {
  echo $WATCHDOG > /proc/sys/kernel/nmi_watchdog
  value=$(cat /proc/sys/kernel/nmi_watchdog)
  test_print_trc "nmi_watchdog = $value"
  case $TEST_SCENARIO in
    fix_counter)
      fix_counter_test
      ;;
    basic)
      basic_test      
      ;;
    events)
      events_check ""
      ;;
    metrics)
      events_check "_metrics"
      ;;
    uncore)
      do_cmd "ls /sys/devices/ | grep uncore"
      ;;
    mrslist_cpuid)
      mrslist_cpuid_test
      ;;
    lbr_events_cpuid)
      lbr_events_cpuid_test
      ;;
    lbr_events)
      lbr_events_test
      ;;
    timed_pebs_msr)
      timed_pebs_msr_test
      ;;
    Uncore_DID0)
      Uncore_DID0_test
      ;;
    lbr_events_instructions)
      lbr_events_instructions_test
      ;;
    lbr_events_instructions_p)
      lbr_events_instructions_p_test
      ;;
    lbr_events_s)
      lbr_events_s_test
      ;;
    lbr_events_all)
      lbr_events_all_test
      ;;
    uncore_dmesg)
      uncore_dmesg_check
      ;;
    arch_pebs_cpuid)
      arch_pebs_cpuid_test
      ;;
    arch_pebs_gp_reg_group)
      arch_pebs_gp_reg_group_test
      ;;
    arch_pebs_xer_group)
      arch_pebs_xer_group_test
      ;;
    arch_pebs_counter_group)
      arch_pebs_counter_group_test
      ;;
    arch_pebs_counter_group_stres)
      arch_pebs_counter_group_stress_test
      ;;
    arch_pebs_gp_counter)
      arch_pebs_gp_counter_test
      ;;
    arch_pebs_basic_group)
      arch_pebs_basic_group_test
      ;;
    arch_pebs_stress)
      arch_pebs_stress_test
      ;;
    version)
      version_test
      ;;
    bitmap_6)
      bitmap_6_test
      ;;
    umask2_cpuid)
      umask2_cpuid_test
      ;;
    zbit_cpuid)
      zbit_cpuid_test
      ;;
    umask2)
      umask2_test
      ;;
    zbit)
      zbit_test
      ;;
    counting)
      counting_test
      ;;
    sampling)
      sampling_test
      ;;
    counting_multi)
      counting_multi_test
      ;;
    esac    
  return 0
}

while getopts :t:w:l:H arg; do
  case $arg in
    t)
      TEST_SCENARIO=$OPTARG
      ;;
    w)
      WATCHDOG=$OPTARG
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

pmu_test
# Call teardown for passing case
exec_teardown
