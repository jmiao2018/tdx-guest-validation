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
#             Jun. 11, 2018 - (Ammy Yi)Creation


# @desc This script verify perf unit test
# @returns Fail the test if return code is non-zero (value set not found)

source "ipt_common.sh"
source "common.sh"
source "dmesg_functions.sh"

: ${CASE_NAME:=""}

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

perf_log="perf_record.log"
temp_log="perf.log"

result_check() {
  grep lost $perf_log
  [[ $? -eq 1 ]] || die "There is data lost during perf record!"
}

filter_package_test() {
  do_cmd "perf record -e intel_pt/mtc=0,tsc=0/ sleep 1 >& $perf_log"
  temp_pid=$!
  sleep 1
  sync
  sync
  do_cmd "perf script -D > $temp_log"

  should_fail "grep \"MTC 0x\" $temp_log"
  should_fail "grep \"TSC 0x\" $temp_log"
  result_check
  rm -f $perf_log
  rm -f $temp_log
}

disable_branch_test() {
  do_cmd "perf record -e intel_pt/branch=0/ sleep 1 >& $perf_log"
  sleep 1
  sync
  sync
  do_cmd "perf script -D > $temp_log"

  should_fail "grep \"TNT 0x\" $temp_log"
  should_fail "grep \"TIP 0x\" $temp_log"
  should_fail "grep \"FUP 0X\" $temp_log"
  result_check
  rm -f $perf_log
  rm -f $temp_log
}

disable_branch_w_pt_test() {
  do_cmd "perf record -e intel_pt/pt=0,branch=0/ sleep 1 >& $perf_log"
  sleep 1
  sync
  sync
  do_cmd "perf script -D > $temp_log"

  should_fail "grep \"TNT 0x\" $temp_log"
  should_fail "grep \"TIP 0x\" $temp_log"
  should_fail "grep \"FUP 0x\" $temp_log"
  result_check
  rm -f $perf_log
  rm -f $temp_log
}

pwr_evt_test() {
  do_cmd "power_v=$(cat /sys/bus/event_source/devices/intel_pt/caps/power_event_trace)"
  [[ $power_v -eq 0 ]] && na_test "power_event_trace is not supported in this platform"
  if [[ $power_v -eq 1 ]]; then
    do_cmd "perf record -a -e intel_pt/pwr_evt/ sleep 1 >& $perf_log"
    sleep 1
    sync
    sync
    do_cmd "perf script -D > $temp_log"
    result_check
    rm -f $perf_log
    rm -f $temp_log
  fi
}

pwr_evt_test_wo_branch() {
  do_cmd "power_v=$(cat /sys/bus/event_source/devices/intel_pt/caps/power_event_trace)"
  [[ $power_v -eq 0 ]] && na_test "power_event_trace is not supported in this platform"
  if [[ $power_v -eq 1 ]]; then
    do_cmd "perf record -a -e intel_pt/pwr_evt,branch=0/ sleep 1 >& $perf_log"
    sleep 1
    sync
    sync
    do_cmd "perf script -D > $temp_log"
    result_check
    rm -f $perf_log
    rm -f $temp_log
  fi
}


pwr_evt_test_w_itrace() {
  power_v=$(cat /sys/bus/event_source/devices/intel_pt/caps/power_event_trace)
  [[ $power_v -eq 0 ]] && na_test "power_event_trace is not supported in this platform"
  do_cmd "perf record -a -e intel_pt/pwr_evt,branch=0/ sleep 1 >& $perf_log"
  sleep 1
  sync
  sync
  do_cmd "perf script --itrace=p > $temp_log"
  if [[ $power_v -eq 0 ]]; then
    test_print_trc "Platform is not supported power_event_trace, will check --itrace=p is null!"
    [[ -s $temp_log ]] && die "$temp_log is not NULL!"
  elif [[ $power_v -eq 1 ]]; then
    test_print_trc "Platform is supported power_event_trace, will check --itrace=p is not null!"
    [[ -s $temp_log ]] || die "$temp_log is NULL!"
    ##TODO will add more logic after confirm with Adrian
  fi
  result_check
  rm -f $perf_log
  rm -f $temp_log
}

ptwrite_test() {
  do_cmd "power_v=$(cat /sys/bus/event_source/devices/intel_pt/caps/ptwrite)"
  [[ $power_v -eq 0 ]] && na_test "ptwrite is not supported in this platform"
  if [[ $power_v -eq 1 ]]; then
    do_cmd "perf record -e intel_pt/ptw,branch=0/u ptwrite_test >& $perf_log"
    sleep 1
    sync
    sync
    do_cmd "perf script > $temp_log"
    do_cmd "grep -o ptwrite_test $temp_log | grep -o ptwrite"
    result_check
    rm -f $perf_log
    rm -f $temp_log
  fi
}

cpl_user_test() {

  #save package address logs
  local p_log="package.log"
  #save first bytes of packages for decode address
  local ipbyte_log="ip.log"
  local ipbyte
  local count=0
  local addr
  local length
  rm -f $perf_log
  perf record -e intel_pt//u sleep 1 >& $perf_log
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script -D > $temp_log"
  #get TIP/FUP/TIPPGD higest address
  grep -E 'TIP|FUP|TIP.PGD|TIP.PGE' $temp_log | awk '{print $NF}'  | awk -F '0x' '{print $2}'> $p_log
  grep -E 'TIP|FUP|TIP.PGD|TIP.PGE' $temp_log | awk '{print $3}' > $ipbyte_log
  #decode ipbyte as ipbyte is bit 5,6,7
  #if 001b/010b/100b then use last IP
  #if 011b then IP payload extended
  #if FUP/TIP/TIP.PGE/TIP.PGD follow a PSB, then last IP as zero
  sync
  sync
  test_print_trc "check 011b as IP payload extended!"
  while read line
  do
    count=$((count + 1))
    ipbyte=$((16#${line}))
    ipbyte=$(echo "obase=2;${ipbyte}"|bc)
    ipbyte=$((2#${ipbyte}  >> 5))
    #count means line number for ipbyte found, addr means detailed address
    #011b IP payload will extern as [47]bit
    if [[ $ipbyte -eq 3 ]]; then
      addr=$(sed -n ${count}p $p_log)
      length=${#addr}
      if [[ $length -eq 12 ]]; then
        [[ ${addr} > "7fffffffffff" ]] && die "Get address > 7fffffffffff with user trace!"
      fi
      if [[ $length -eq 16 ]]; then
        [[ ${addr} > "7fffffffffffffff" ]] && die "Get address > 7fffffffffffffff with user trace!"
      fi
    fi


  done < $ipbyte_log
  rm -f $temp_log
  rm -f $p_log
  rm -f $ipbyte_log
}

cpl_kernel_test() {
  #save package address logs
  local p_log="package.log"
  #save first bytes of packages for decode address
  local ipbyte_log="ip.log"
  local ipbyte
  local count=0
  local addr
  local length
  rm -f $perf_log
  perf record -e intel_pt//k sleep 1 >& $perf_log
  result_check
  sleep 1

  do_cmd "perf script -D > $temp_log"
  #get TIP/FUP/TIPPGD higest address
  grep -E 'TIP|FUP|TIP.PGD|TIP.PGE' $temp_log | awk '{print $NF}'  | awk -F '0x' '{print $2}'> $p_log
  grep -E 'TIP|FUP|TIP.PGD|TIP.PGE' $temp_log | awk '{print $3}' > $ipbyte_log
  #decode ipbyte as ipbyte is bit 5,6,7
  #if 001b/010b/100b then use last IP
  #if 011b then IP payload extended
  #if FUP/TIP/TIP.PGE/TIP.PGD follow a PSB, then last IP as zero
  sync
  sync
  test_print_trc "check 011b as IP payload extended!"
  while read line
  do
    count=$((count + 1))
    ipbyte=$((16#${line}))
    ipbyte=$(echo "obase=2;${ipbyte}"|bc)
    ipbyte=$((2#${ipbyte}  >> 5))
    #count means line number for ipbyte found, addr means detailed address
    #011b IP payload will extern as [47]bit
    if [[ $ipbyte -eq 3 ]]; then
      addr=$(sed -n ${count}p $p_log)
      length=${#addr}
      if [[ $length -eq 12 ]]; then
        # shellcheck disable=SC2071
        [[ ${addr} < "800000000000" ]] && die "Get address < 7f with kernel trace!"
      fi
      if [[ $length -eq 16 ]]; then
        # shellcheck disable=SC2071
        [[ ${addr} < "8000000000000000" ]] && die "Get address < 7f with kernel trace!"
      fi
    fi


  done < $ipbyte_log
  test_print_trc "check PSB with last IP!"
  #001b, 010b, 100b once follow PSB will fail, since PSB will set last IP as 0
  grep -A 1 -w 'PSB' $temp_log \
    | grep -E 'TIP|FUP|TIP.PGD|TIP.PGE' \
    | awk '{print $3}' \
    > $ipbyte_log
  sync
  sync
  while read line
  do
    count=$((count + 1))
    ipbyte=$((16#${line}))
    ipbyte=$(echo "obase=2;${ipbyte}"|bc)
    ipbyte=$((2#${ipbyte}  >> 5))
    test_print_trc "ipbyte = $ipbyte"
    #count means line number for ipbyte found, addr means detailed address
    [[ $ipbyte -eq 1 || $ipbyte -eq 2 || $ipbyte -eq 4 ]] && die "Get address < 7f with kernel trace follow by PSB!"

  done < $ipbyte_log
  test_print_trc "cpl_kernel_test done!"
  rm -f $temp_log
  rm -f $p_log
  rm -f $ipbyte_log
}

time_cyc_test() {
  local cyc
  cyc=$(cat /sys/bus/event_source/devices/intel_pt/caps/psb_cyc)
  [[ $cyc -eq 0 ]] && block_test "Platform is not supported cyc "
  if [[ $cyc -eq 1 ]]; then
    test_print_trc "Platform is supported cyc, will check CYC package is found!"
    do_cmd "perf record -e intel_pt/cyc/ sleep 1 >& $perf_log"
    result_check
    sleep 1
    sync
    sync
    do_cmd "perf script -D > $temp_log"
    do_cmd "grep \"CYC 0x\" $temp_log"
    ##TODO will add more logic after confirm with Adrian
  fi
  rm -f $perf_log
  rm -f $temp_log
}

time_mtc_test() {
  local cyc
  cyc=$(cat /sys/bus/event_source/devices/intel_pt/caps/psb_cyc)
  [[ $cyc -eq 0 ]] && block_test "Platform is not supported cyc "
  if [[ $cyc -eq 1 ]]; then
    test_print_trc "Platform is supported cyc, will check CYC package will be disbaled if mtc is disabled!"
    do_cmd "perf record -e intel_pt/mtc=0/ sleep 1 >& $perf_log"
    result_check
    sleep 1
    sync
    sync
    do_cmd "perf script -D > $temp_log"
    should_fail "grep \"CYC 0x\" $temp_log"
    should_fail "grep \"MTC 0x\" $temp_log"
    ##TODO will add more logic after confirm with Adrian
  fi
  rm -f $perf_log
  rm -f $temp_log
}

time_test() {
  local cyc
  cyc=$(cat /sys/bus/event_source/devices/intel_pt/caps/psb_cyc)
  [[ $cyc -eq 0 ]] && block_test "Platform is not supported cyc "
  if [[ $cyc -eq 1 ]]; then
    test_print_trc "Platform is supported cyc, will check CYC package is not enabled by default!"
    do_cmd "perf record -e intel_pt//u sleep 1 >& $perf_log"
    result_check
    sleep 1
    sync
    sync
    do_cmd "perf script -D > $temp_log"
    should_fail "grep \"CYC 0x\" $temp_log"
    ##TODO will add more logic after confirm with Adrian
  fi
  rm -f $perf_log
  rm -f $temp_log
}


pebs_test() {
  local cyc
  perf record -e '{intel_pt/branch=0/,cycles/aux-output/ppp,instructions}' -c 128 -m,4 ls -lt / >& $perf_log
  result_check
  [[ $? -eq 0 ]] || die "perf record failed!"
  sleep 1
  sync
  sync
  do_cmd "perf script -D | grep -w 'B.P'> $temp_log"
  rm -f $perf_log
  rm -f $temp_log
}



inject_test() {
  local perf_inj_log="inj.data"
  do_cmd " perf record -e intel_pt//u sort_test >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd " perf inject -i perf.data -o $perf_inj_log --itrace=i100usle --strip"
  do_cmd "perf script -i $perf_inj_log > $temp_log"
  should_fail "grep -E 'TNT|TIP|FUP|TIP.PGD|TIP.PGE|MTC'  $temp_log"
  rm -f $perf_log
  rm -f $temp_log
  rm -f $perf_inj_log
}

trace_teardown() {
  rm -f "$HOME/.perfconfig"
}

inject_time_test() {
  local perf_inj_log="inj.data"
  local pre_t
  local end_t
  teardown_handler="trace_teardown"
  do_cmd "sort_test > $temp_log"
  pre_t=$(grep ms $temp_log |  awk '{print $1}')
  do_cmd "echo  '[intel-pt]' > $HOME/.perfconfig"
  do_cmd "echo  '   mispred-all = on' >> $HOME/.perfconfig"
  do_cmd "perf record -e intel_pt//u sort_test > $perf_log"
  sleep 1
  sync
  sync
  do_cmd "perf inject -i perf.data -o $perf_inj_log --itrace=i100usle --strip"
  do_cmd "create_gcov --binary=sort_test --profile=$perf_inj_log --gcov=sort.gcov -gcov_version=1"
  do_cmd "gcc -o3  -fauto-profile=sort.gcov sort_test.c -o sort_autofdo"
  do_cmd "sort_autofdo > $temp_log"
  end_t=$(grep ms $temp_log |  awk '{print $1}')
  [[ $pre_t -le $end_t ]] || die "autofdo is not working!!"
  rm -f $perf_log
  rm -f $temp_log
  rm -f $perf_inj_log
}


lbr_test() {
  local temp1_log="perf1.log"
  local temp2_log="perf2.log"
  do_cmd "perf record -e cycles:u,intel_pt//u -b sleep 1 >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script -F +brstack > $temp1_log"

  do_cmd "perf record -e cycles:u,intel_pt//u sleep 1 >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script -F +brstack > $temp2_log"

  count_1=$(awk 'END{print NR}' $temp1_log)
  count_2=$(awk 'END{print NR}' $temp2_log)
  [[ $count_1 -le $count_2 ]] && die "LBR is not working!!"
  rm -f $perf_log
  rm -f $temp1_log
  rm -f $temp2_log
}

tracestop_test() {
  local path
  path=$(pwd)
  path=$path"/ddt_intel/ipt/sort_test"
  do_cmd "perf record -e intel_pt//u '--filter=tracestop main @ $path' sort_test >& $perf_log"
  result_check
  rm -f $perf_log
}


tracefilter_test() {
  local path
  path=$(pwd)
  path=$path"/ddt_intel/ipt/sort_test"
  do_cmd "perf record -e intel_pt//u '--filter=filter main @ $path' sort_test >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script --itrace=ibxwe | tail > $temp_log"
  count_e=$(grep -c main $temp_log)
  count_cbr=$(grep -c "cbr" $temp_log)
  count_p=$(grep -c "branch" $temp_log)
  test_print_trc "count_e=$count_e, count_cbr=$count_cbr, count_p=$count_p"
  [[ $count_e -eq $count_p ]] || die "main count is not right, trace filter with main is failed!"
  should_fail "sed -n $count_p'p' $temp_log | grep unknown"
  rm -f $perf_log
  rm -f $temp_log
}

filter_kernel_test() {
  local path
  rm perfdata -rf
  do_cmd "perf record --kcore -e intel_pt// --filter 'filter __schedule / __schedule' -a  -- sleep 1 >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script ./perfdata/ --itrace=ibxwpe | tail > $temp_log"
  count_e=$(grep -c "__sched" $temp_log)
  count_cbr=$(grep -c "cbr" $temp_log)
  count_p=$(awk 'END{print NR}'  $temp_log)
  test_print_trc "count_e = $count_e count_cbr=$count_cbr count_p=$p"

  [[ $count_e -eq $count_p ]] || die "__sched count is not right, trace filter with __sched for kernel is failed!"
  should_fail "sed -n $count_p'p' $temp_log | grep unknown"
  rm perfdata -rf
  rm -f $perf_log
  rm -f $temp_log
}

filter_kernel_cpu_test() {
  local path
  rm perfdata -rf
  do_cmd "perf record --kcore -e intel_pt// --filter 'filter __schedule / __schedule' -a  -- sleep 1 >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script --itrace=ibxwpe | tail > $temp_log"
  count_e=$(grep -c "__sched" $temp_log)
  count_cbr=$(grep -c "cbr" $temp_log)
  count_p=$(awk 'END{print NR}'  $temp_log)
  test_print_trc "count_e = $count_e count_cbr=$count_cbr count_p=$count_p"

  [[ $count_e -eq $count_p ]] || die "__sched count is not right, trace filter with __sched for kernel is failed!"
  should_fail "sed -n $count_p'p' $temp_log | grep unknown"
  rm perfdata -rf
  rm -f $perf_log
  rm -f $temp_log
}

mtopa_test() {
  do_cmd "topa_m=$(cat /sys/bus/event_source/devices/intel_pt/caps/topa_multiple_entries)"
  [[ $topa_m -eq 0 ]] && block_test "topa_multiple_entries is not supported in this platform"
  if [[ $topa_m -eq 1 ]]; then
    do_cmd "perf record -e intel_pt//u sleep 1 >& $perf_log"
    result_check
    sleep 1
    sync
    sync
    rm -f $perf_log
  fi
}

pwr_evt_test_python() {
  do_cmd "perf record -e intel_pt//u sleep 1 >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  do_cmd "perf script -s ./ddt_intel/ipt/intel-pt-events.py > $temp_log"
  do_cmd "grep 'Intel PT Power Events and PTWRITE' $temp_log"
  rm -f $perf_log
  rm -f $temp_log
}

md_nonroot_test() {
  user_do "perf record -e intel_pt//u bash -c 'uname' >& $perf_log"
  result_check
  [[ $? -ne 0 ]] && die "md_nonroot_test failed for perf record failure!"
  sleep 1
  sync
  sync
  user_do "perf report --itrace=i1us --sort=comm --stdio > $temp_log"
  [[ $? -ne 0 ]] && die "md_nonroot_test failed for trace decode failure!"
  user_do "grep -E 'bash|uname' $temp_log"
  [[ $? -ne 0 ]] && die "md_nonroot_test failed for not found words in trace!"
  clean_temp_users
}


sample_test() {
  do_cmd "perf record --aux-sample=8192 -e '{intel_pt//u,branch-misses:u}' "\
         "sleep 1 >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  rm -f $perf_log
}

java_test(){
  local m_lib=$(pwd)"/ddt_intel/ipt/libperf-jvmti.so"
  javac
  [[ $? -ne 2 ]] && block_test "javac do not found, block this test!"
  do_cmd "javac HelloWorldApp.java"
  do_cmd "perf record -e intel_pt//u -o java.perf.data java -agentpath:$m_lib HelloWorldApp"
  sleep 1
  do_cmd "perf inject -i java.perf.data --jit -o java.perf.data.jitted"
  rm -f java.perf.data
  rm -f java.perf.data.jitted
}

user_m() {
  do_cmd  "perf record -e intel_pt//u -m1,128 uname >& $perf_log"
  result_check
  do_cmd  "perf record -e intel_pt//u -m1,128 uname >& $perf_log"
  result_check
}


kernel_m_test() {
  do_cmd  "perf record -e intel_pt//k -m1,128 uname >& $perf_log"
  result_check
  do_cmd  "perf record -e intel_pt//k -m1,128 uname >& $perf_log"
  result_check
}

nmi_watchdog_test() {
  echo $1 > /proc/sys/kernel/watchdog
  do_cmd "perf record -e intel_pt/mtc=1,cyc=1/ -m,4 ls -lt /"
  do_cmd "perf record -e intel_pt/branch=0/ -m,4 ls -lt /"
  do_cmd  "extract_case_dmesg | grep -v unknown"
}

miss_frequency_test() {
  #This is for LCK-4289
  times=10
  do_cmd "perf record -e intel_pt//u uname >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  param="-F-comm,-tid,-period,-event,-dso,+addr,-cpu --ns"
  total_miss=$(perf script --itrace=bps$times $param | grep -c ":")
  total=$(perf script --itrace=bp $param | grep -c ":")
  test_print_trc "total_miss = $total_miss"
  test_print_trc "toal = $total"
  let diff=total-total_miss
  [[ $diff -ne $times ]] && die "-s miss frequency is worng!"
}

virtual_lbr_test() {
  #This is for LCK-3629
  times=10
  do_cmd "perf record --aux-sample -e '{intel_pt//,cycles}:u' uname >& $perf_log"
  result_check
  sleep 1
  sync
  sync
  times=$(perf report | head -30 | grep -v 'Event count (approx.): 0' | grep -A 15 Event | grep -c '|')
  [[ $times -lt 2 ]] && die "no virtual lbr!"
}

lost_data_test() {
  #https://git.kernel.org/pub/scm/linux/kernel/git/tip/tip.git/commit/?h=perf/core&id=874fc35cdd55e2d46161901de43ec58ca2efc5fe
  #it is for some regression for data loss
  do_cmd "perf record -e intel_pt//u -m,8 uname >& $perf_log"
  result_check
}

notnt_test() {
  do_cmd "notnt=$(cat /sys/bus/event_source/devices/intel_pt/caps/tnt_disable)"
  [[ $notnt -eq 0 ]] && block_test "tnt_disable is not supported in this platform"
  perfdata="notnt.log"
  do_cmd "perf record -e intel_pt/notnt/u uname >& $perf_log"
  perf report -D -i $perfdata
  grep TNT $perfdata
  [[ $? -eq 0 ]] && die "Still get TNT!"
}

event_trace_test() {
  local event_trace
  event_trace=$(cat /sys/bus/event_source/devices/intel_pt/caps/event_trace)
  [[ $event_trace -eq 0 ]] && block_test "Platform is not supported event_trace "
  if [[ $event_trace -eq 1 ]]; then
    test_print_trc "Platform is supported event_trace, will check event_trace!"
    do_cmd "perf record -e intel_pt/event/u sleep 1 >& $perf_log"
    result_check
    sleep 1
    sync
    sync
    do_cmd "perf script --itrace=Ie > $temp_log"
    do_cmd "grep 'evt' $temp_log"
  fi
  rm -f $perf_log
  rm -f $temp_log
}

pt_tool_test() {
    do_cmd "test_intel_pt.sh"
}

pttt_cpuid_test() {
  #014H.0.EBX[9]
  do_cmd "cpuid_check 14 0 0 0 b 9"
}

pttt_enable_test() {
	# Check if trigger tracing is supported.
	trigger_tracing=$(cat /sys/bus/event_source/devices/intel_pt/caps/trigger_tracing)
  if [ "${trigger_tracing}" != "1" ] ; then
		na_test "Trigger tracing is not supported!"
	fi
	# Check if trigger tracing working.
	do_cmd perf record -e "{intel_pt//,cycles/aux-output=on-overflow:trigger/}:u" uname > /dev/null
}

pttt_trigger_num_test() {
  # Get trigger tracing msr numbers.
	num_trigger_msrs=$(/sys/devices/intel_pt/caps/num_trigger_msrs)
	event_param=""
	event="cycles/aux-output=on-overflow:trigger::on-event:trigger/, "

	while [ $i -lt "$num_trigger_msrs" ]; do
		while [ $j -lt 4 ]; do
    	event_param="$event_param $event "
  	done
		i=$((i+1))
		j=$((j+1))
	done

	# Check if maximum trigger tracing working.
	do_cmd "perf record -e event "{intel_pt//,$event_param}" uname > /dev/null"

	# Check if >maximum trigger tracing will be failure.
	event_param="$event_param $event "
	do_cmd "perf record -e event "{intel_pt//,$event_param}" uname > /dev/null"

}

pttt_pause_resume_test() {
  flag=0
  perfdatafile="perf.data"
  # Check if pause/resume of trigger tracing is supported.
	pause_resume=$(cat /sys/bus/event_source/devices/intel_pt/caps/pause_resume)
  if [ "${pause_resume}" != "1" ] ; then
		na_test "pause_resume of trigger tracing is not supported!"
	else
		./pttt 1 | tee "$tmplog" &
		sleep 1
		pttt_pid=$(pgrep "pttt" | awk '{print $1}')
		func0_addr=$(grep "func0" "$tmplog" | awk '{print $2}')
		func1_addr=$(grep "func1" "$tmplog" | awk '{print $2}')
		func2_addr=$(grep "func2" "$tmplog" | awk '{print $2}')
		echo "func0_addr=$func0_addr, func1_addr=$func1_addr, func2_addr=$func2_addr"
		if ! perf record -o "${perfdatafile}" -e event "{intel_pt//,mem:$func0_addr:x/aux-output=on-event:trigger-pause/,mem:$func2_addr:x/aux-output=on-event:trigger-resume/}:u" -p "$pttt_pid" -- sleep 0.5 > /dev/null ; then
				echo "perf record trigger tracing with pause/resume is failed!"
				kill -9 "$pttt_pid"
        flag=1
				exit
			else
				if perf script -i "${perfdatafile}" -D | grep "$func1_addr" > /dev/null ; then
					echo "perf record trigger tracing with pause is failed!"
					kill -9 "$pttt_pid"
          flag=1
          exit
				else
					if perf script -i "${perfdatafile}" -D | grep "$func2_addr" > /dev/null ; then
						echo "perf record trigger tracing with resume is failed!"
						kill -9 "$pttt_pid"
            flag=1
            exit
					fi
				fi
		fi
	fi
	kill -9 "$pttt_pid"
  [[ $flag -eq 0 ]] || die "pttt pause/resume test is failed!" 
}

pttt_dr_match_test() {
  flag=0
  perfdatafile="perf.data"
  #Check if PTTT dr match is working
	dr_match=$(cat /sys/bus/event_source/devices/intel_pt/caps/dr_match)
  if [ "${dr_match}" != "1" ] ; then
		na_test "dr_match of trigger tracing is not supported!"
	else
		./pttt | tee "$tmplog" &
		sleep 1
		pttt_pid=$(pgrep "pttt" | awk '{print $1}')
		func0_addr=$(grep "func0" "$tmplog" | awk '{print $2}')
		if ! perf record -e event "{intel_pt//,mem:$func0_addr:x/aux-output=on-event:trigger/}:u" -p "$pttt_pid" -- sleep 0.5 > /dev/null ; then
			echo "perf record trigger tracing with dr_match is failed!"
			kill -9 "$pttt_pid"
      flag=1
      exit
		else
			perf script -i "${perfdatafile}" --itrace=poe
			if perf script -i "${perfdatafile}" -D | grep TRIG > /dev/null ; then
				echo "perf record trigger tracing with dr_match is failed!"
				kill -9 "$pttt_pid"
        flag=1
        exit
			fi
		fi
	fi
	kill -9 "$pttt_pid"
  [[ $flag -eq 0 ]] || die "pttt dr_match test is failed!"
}

perftest() {
  case $TEST_SCENARIO in
    fp)
      filter_package_test
      ;;
    disablebranch)
      disable_branch_test
      ;;
    pt)
      disable_branch_w_pt_test
      ;;
    pwr_evt)
      pwr_evt_test
      ;;
    pwr_evt_branch)
      pwr_evt_test_wo_branch
      ;;
    pwr_evt_itrace)
      pwr_evt_test_w_itrace
      ;;
    ptwrite)
      ptwrite_test
      ;;
    user)
      cpl_user_test
      ;;
    kernel)
      cpl_kernel_test
      ;;
    cyc)
      time_cyc_test
      ;;
    mtc)
      time_mtc_test
      ;;
    time)
      time_test
      ;;
    pebs)
      pebs_test
      ;;
    inject)
      inject_test
      ;;
    inject_time)
      inject_time_test
      ;;
    lbr)
      lbr_test
      ;;
    stop)
      tracestop_test
      ;;
    filter)
      tracefilter_test
      ;;
    filter_kernel)
      filter_kernel_test
      ;;
    filter_kernel_cpu)
      filter_kernel_cpu_test
      ;;
    mtopa)
      mtopa_test
      ;;
    python)
      pwr_evt_test_python
      ;;
    md_nonroot)
      md_nonroot_test
      ;;
    sample)
      sample_test
      ;;
    java)
      java_test
      ;;
    user_m)
      user_m_test
      ;;
    kernel_m)
      kernel_m_test
      ;;
    nmi_watchdog_disable)
      nmi_watchdog_test 0
      ;;
    nmi_watchdog_enable)
      nmi_watchdog_test 1
      ;;
    miss_frequency)
      miss_frequency_test
      ;;
    virtual_lbr)
      virtual_lbr_test
      ;;
    lost_data)
      lost_data_test
      ;;
    notnt)
      notnt_test
      ;;
    event_trace)
      event_trace_test
      ;;
    tool_test)
      pt_tool_test
      ;;
    pttt_cpuid)
      pttt_cpuid_test
      ;;
    pttt_enable)
      pttt_enable_test
      ;;
    pttt_trigger_num)
      pttt_trigger_num_test
      ;;
    pttt_pause_resume)
      pttt_pause_resume_test
      ;;
    pttt_dr_match)
      pttt_dr_match_test
      ;;
  esac
  return 0
}

while getopts :t:H arg; do
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

perftest
# Call teardown for passing case
exec_teardown
