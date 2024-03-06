#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
#     Copyright (C) 2021 Intel Corporation
#
# File:         get_core_info.sh
#
# Description:  Get core type info fro hybrid CPU
#
# Author(s):        Ammy Yi <ammy.yi@intel.com>
#
# Date:         10/28/2021
#

get_core_ids() {
  local list="thread_siblings_list"
  CORE_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
    | grep - | cut -d \- -f 1 | sort | uniq)
  SMT_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
    | grep - | cut -d \- -f 2 | sort | uniq)
  ATOM_IDS=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
    | grep -v - | sort | uniq)
  CORE_NUM=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
    | grep - | sort | uniq | wc -l)
  ATOM_NUM=$(find $CPU_SYS_PATH -type f -name $list -exec cat {} + \
    | grep -v - | sort | uniq | wc -l)
  let SMT_NUM=CORE_NUM
  test_print_trc "CORE_IDS=$CORE_IDS; SMT_IDS=$SMT_IDS; ATOM_IDS=$ATOM_IDS"
  test_print_trc "CORE_NUM=$CORE_NUM, ATOM_NUM=$ATOM_NUM, SMT_NUM=$SMT_NUM"
  find $CPU_SYS_PATH -type f -name $list -exec cat {} + | grep - \
    | sort | uniq > $CORE_GROUPS
  cat $CORE_GROUPS
}

