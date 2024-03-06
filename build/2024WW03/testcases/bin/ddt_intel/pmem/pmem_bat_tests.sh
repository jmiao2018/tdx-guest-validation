#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2020 Intel Corporation
#
# Description:  Persistent memory bat test script

source "common.sh"

############################# FUNCTIONS #######################################

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

# Check if there is pmem device under /dev
check_pmem_dev_nodes() {
  pmem_dev_nodes=($(ls /dev/pmem*))
  if [[ "${#pmem_dev_nodes[@]}" -eq 0 ]]; then
    die "No pmem device node found."
  fi
  test_print_trc "Found ${#pmem_dev_nodes[@]} pmem character device nodes:"
  for node in "${pmem_dev_nodes[@]}"; do
    test_print_trc "$node"
  done
}

main() {
  case $TESTCASE_ID in
    check_dev_node)
      check_pmem_dev_nodes
      ;;
    *)
      usage
      die "Invalid Test ID!"
      ;;
    esac
  return 0
}

################################ DO THE WORK ##################################

TESTCASE_ID=""

while getopts :t:w:H arg; do
  case $arg in
    t)
      TESTCASE_ID=$OPTARG
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

main
