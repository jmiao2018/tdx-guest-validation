#!/usr/bin/env bash

###############################################################################
#
# Copyright (C) 2018 Intel - http://www.intel.com
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
# @Author   Ning Han (ningx.han@intel.com)
# @desc     Automate intel_pstate freq test cases designed by Wendy Wang(wendy.wang@intel.com)
# @returns  0 if the execution was finished successfully, else 1
# @history  2018-05-10: First Version (Ning Han)

source "powermgr_common.sh"

usage() {
  cat <<_EOF
  -t turbo on? yes or no
  -m governor type
  -c core(s), one or all or atom(for hybrid cpu)
  -h show this
_EOF
}

while getopts t:m:c:h arg; do
  case $arg in
  t) turbo_on=$OPTARG ;;
  m) mode=$OPTARG ;;
  c) core=$OPTARG ;;
  h) usage && exit 1 ;;
  \?) die "You must supply an argument, ${0##*/} -h" ;;
  *) die "Invalid argument, ${0##*/} -h" ;;
  esac
done

: "${turbo_on:="no"}"
: "${mode:="powersave"}"
: "${core:="one"}"

# enable or disable turbo according argument
if [[ "$turbo_on" == "yes" ]]; then
  echo 0 >"$CPU_NO_TURBO_NODE"
  if [[ $? -ne 0 ]]; then
    do_cmd "modprobe msr"
    turbo_value=$(rdmsr 0x1a0 -f 38:38)
    test_print_trc "turbo_value:$turbo_value"
    [[ $turbo_value -eq 0 ]] || die "Failed to write 0 to $CPU_NO_TURBO_NODE"
    test_print_trc "Turbo disabled by BIOS or unavailable on processor."
  fi
elif [[ "$turbo_on" == "no" ]]; then
  echo 1 >"$CPU_NO_TURBO_NODE"
  if [[ $? -ne 0 ]]; then
    do_cmd "modprobe msr"
    turbo_value=$(rdmsr 0x1a0 -f 38:38)
    test_print_trc "turbo_value:$turbo_value"
    [[ $turbo_value -eq 0 ]] || die "Failed to write 1 to $CPU_NO_TURBO_NODE"
    test_print_trc "Turbo disabled by BIOS or unavailable on processor."
  fi
else
  block_test "invalid value for cpu no_turbo node"
fi

# select which scaling governor mode to be set
if [[ "$mode" == "powersave" ]]; then
  set_scaling_governor "powersave"
elif [[ "$mode" == "performance" ]]; then
  set_scaling_governor "performance"
elif [[ "$mode" == "passive_perf" ]]; then
  set_intel_pstate_mode "passive"
  set_scaling_governor "performance"
elif [[ "$mode" == "passive_sched" ]]; then
  set_intel_pstate_mode "passive"
  set_scaling_governor "schedutil"
else
  block_test "invalid mode for scaling governor"
fi

if [[ "$core" == "one" ]]; then
  checking_single_cpu_freq
elif [[ "$core" == "all" ]]; then
  checking_max_cores_freq
elif [[ "$core" == "atom" ]]; then
  checking_hybrid_atom_single_cpu_freq
else
  block_test "invalid core argument"
fi
