#!/bin/bash
###############################################################################
##                                                                           ##
## Copyright (c) 2018, Intel Corporation.                                    ##
##                                                                           ##
## This program is free software; you can redistribute it and/or modify it   ##
## under the terms and conditions of the GNU General Public License,         ##
## version 2, as published by the Free Software Foundation.                  ##
##                                                                           ##
## This program is distributed in the hope it will be useful, but WITHOUT    ##
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or     ##
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for ##
## more details.                                                             ##
###############################################################################
#
# File:         cet_func.sh
#
# Description: it's for cet(Control-flow Enforcement Technology) function test:
#
# Will contain shadow stack test and indirect branch tracking test.
#
# Authors:      Pengfei Xu - pengfei.xu@intel.com
#
# History:      May 4 2018 - created - Pengfei Xu

# @desc check cet function
# @returns Fail if return code is non-zero

source "cpu_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-n BIN_NAME][-p parameter][-h]
  -n  Test cpu bin name like shadow_test_fork and so on
  -p  PARM like null
  -h  show This
__EOF
}

main() {
  local func_name="cet"
  local shstk="shstk"
  local ibt="ibt"
  local legacy="legacy"
  local cet_file=""
  # CET will not support 32bit, and comment it if it's supported in future
  # local cet_files="ibt_stress ibt_stress_32 shstk_stress shstk_stress_32"
  local cet_files="ibt_stress shstk_stress"
  local cet_compare="cet_compare"
  local times="100000000"
  local cet_path="/tmp/$cet_compare"
  local cet_compare_path="/tmp/$CET_PARM"
  local err_cnt=0
  local bin=""
  local cpus=""
  local cet_type=""

  # cpu info should contain shstk and ibt, otherwise block cet function tests
  # cpu_info_check "$shstk"
  # Present only support shstk in kernel, will not check ibt cpu info
  # cpu_info_check "$ibt"
  sleep 2
  case $TYPE in
    test)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$func_name"
      ;;
    cet_pass)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    kmod_shstk|kmod_ibt)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      load_cet_driver
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "${func_name}_${TYPE}"
      ;;
    kmodn_ibt)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      load_cet_driver
      do_cmd "$BIN_NAME $CET_PARM"
      ;;
    kmod_ibt_msr)
      local msr_kmod_cet="0x6a2"
      local high_bit="2"
      local low_bit="2"
      local exp_value="1"
      check_msr "$msr_kmod_cet" "$high_bit" "$low_bit" "$exp_value"
      ;;
    cet_noseg)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    cet_seg)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    ibt32)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    kmod_pass)
      TYPE="cet_pass"
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      load_cet_driver
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    cet_legacy)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    elf_cet)
      elf_check "$BIN_NAME" "$func_name"
      ;;
    objdump)
      obj_dump "$BIN_NAME" "$INSTRUCTION"
      ;;
    cet_ssp)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    cet_stress)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    legacy_stress)
      test_print_trc "Test bin:$BIN_NAME $CET_PARM"
      elf_check "$BIN_NAME" "$legacy"
      cpu_func_parm_test "$BIN_NAME" "$CET_PARM" "$TYPE"
      ;;
    cet_compare)
      for cet_file in $cet_files; do
        sleep 1
        cpu_func_parm_test "$cet_file" "$times" "$cet_compare"
        sleep 1
        cpu_func_parm_test "${cet_file}_${legacy}" "$times" "$cet_compare"
        sleep 1
        cet_perf_compare "${cet_file}_${times}.log" \
          "${cet_file}_${legacy}_${times}.log" "$cet_path"
        [[ $? -eq 0 ]] || err_cnt=$((err_cnt+1))
      done
      [[ "$err_cnt" -eq 0 ]] || die "cet perf test met err, err_cnt:$err_cnt"
      ;;
    cet_perf_compare)
      sleep 1
      cpu_func_parm_test "$CET_PARM" "$times" "$CET_PARM"
      sleep 1
      cpu_func_parm_test "${CET_PARM}_${legacy}" "$times" "$CET_PARM"
      sleep 1
      cet_perf_compare "${CET_PARM}_${times}.log" \
        "${CET_PARM}_${legacy}_${times}.log" "$cet_compare_path" || \
        die "cet $CET_PARM perf test with issue."
      ;;
    cet_all_cpu)
      bin=$(which $BIN_NAME)
      cpus=$(cat /proc/cpuinfo | grep "processor" | tail -n 1 | cut -d ':' -f 2)

      for((i=0;i<=cpus;i++)); do
        $bin $i
        [[ $? -eq 0 ]] || err_cnt=$((err_cnt+1))
      done
      [[ "$err_cnt" -eq 0 ]] || die "All cpu cet test with err_cnt:$err_cnt"
      dmesg_check "control protection" "$NULL"
      dmesg_check "Call Trace" "$NULL"
      dmesg_check "segfault" "$NULL"
      dmesg_check "error" "$NULL"
      ;;
    all_cpu_perf)
      # make sure all CPU are online before all CPUs performance tests
      online_all_cpu
      cpus=$(cat /proc/cpuinfo | grep "processor" | tail -n 1 | cut -d ':' -f 2)

      test_print_trc "perf stat $CET_PARM"
      perf stat "$CET_PARM"
      test_print_trc "perf stat ${CET_PARM}_legacy"
      perf stat "${CET_PARM}_legacy"

      test_print_trc "perf stat -e instructions,cycles $CET_PARM"
      perf stat -e instructions,cycles "$CET_PARM"
      test_print_trc "perf stat -e instructions,cycles ${CET_PARM}_legacy"
      perf stat -e instructions,cycles "${CET_PARM}_legacy"

      for((i=0;i<=cpus;i++)); do
        sleep 1
        cpu_func_parm_test "$CET_PARM" "$i" "$CET_PARM"
        sleep 1
        cpu_func_parm_test "${CET_PARM}_${legacy}" "$i" "$CET_PARM"
        sleep 1
        cet_perf_compare "${CET_PARM}_${i}.log" \
          "${CET_PARM}_${legacy}_${i}.log" "$cet_compare_path"
        [[ $? -eq 0 ]] || {
          test_print_wrg "CPU$i met $CET_PARM perf regression!"
          err_cnt=$((err_cnt+1))
        }
      done
      [[ "$err_cnt" -eq 0 ]] || die "All cpu cet test with err_cnt:$err_cnt"
      dmesg_check "control protection" "$NULL"
      dmesg_check "Call Trace" "$NULL"
      dmesg_check "segfault" "$NULL"
      ;;
    criu)
      criu_test "$BIN_NAME"
      ;;
    all_cpu)
      all_cpu_test "$BIN_NAME" "$CET_PARM" "$KEY"
      ;;
    all_cpu_kmod)
      load_cet_driver
      all_cpu_test "$BIN_NAME" "$CET_PARM" "$KEY"
      ;;
    shstk_status)
      check_arch_status "$BIN_NAME" "$CET_PARM"
      ;;
    *)
      block_test "Invalid TYPE:$TYPE"
      ;;
  esac
}

while getopts :i:t:n:p:k:h arg; do
  case $arg in
    i)
      INSTRUCTION=$OPTARG
      ;;
    t)
      TYPE=$OPTARG
      ;;
    n)
      BIN_NAME=$OPTARG
      ;;
    p)
      CET_PARM=$OPTARG
      ;;
    k)
      KEY=$OPTARG
      ;;
    h)
      usage
      exit 0
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

main
exec_teardown
