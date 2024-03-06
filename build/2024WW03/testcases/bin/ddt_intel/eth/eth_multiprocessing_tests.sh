#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate ethernet component
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
#             Ning Han <ningx.han@intel.com>
#
# History:
#             Aug. 02, 2017 - (Ning Han)Creation

source "eth_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -c  specify case id.
    -H  show this.
EOF
}

while getopts c:l:H arg
do
  case $arg in
    c) CID=$OPTARG ;;
    H) usage && exit ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

case $CID in
  func)
    prepare_nfs_mount.sh -m "/nfs_mount" || die "Mounting NFS failed!"
    run_test_args="-t ETH_XS_FUNC_PING_ON -f ddt_intel/eth_ping_func_tests#"
    dd_cmd="dd if=/dev/urandom of=/nfs_mount/dd_test bs=1M count=100"
    multi_run_processes.sh -s "run_test.sh $run_test_args $dd_cmd" \
                           -l "-n 2 -a 0x1 -d 1"
    rm /nfs_mount/dd_test
    unmount_nfs.sh "/nfs_mount"
    ;;
  stress)
    prepare_nfs_mount.sh -m "/nfs_mount" || die "Mounting NFS Failed"
    run_test_args="-t ETH_S_FUNC_PING_ALL -f ddt_intel/eth_ping_func_tests#"
    dd_cmd="dd if=/dev/urandom of=/nfs_mount/dd_test bs=1M count=500"
    multi_run_processes.sh -s "run_test.sh $run_test_args $dd_cmd" \
                           -l "-n 2 -a 0x1 -d 1"
    rm /nfs_mount/dd_test
    unmount_nfs.sh "/nfs_mount"
    ;;
  *)
    die "Invalied case id!"
    ;;
esac
