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
#             Jul. 27, 2017 - (Ning Han)Creation

source "eth_common.sh"

usage() {
  cat << EOF
  usage: ${0##*/}
    -c  specify case id.
    -l  loops.
    -H  show this.
EOF
}

get_host() {
  local host=""
  local iface=""

  iface=$(get_eth_iface_name.sh -t one)
  [[ -n "$iface" ]] || exit 2

  do_cmd "ifconfig ${iface} up" &> /dev/null

  host=$(get_eth_gateway.sh -i "$iface")
  [[ -n "$host" ]] || exit 2

  echo "$host"
}

while getopts c:l:H arg
do
  case $arg in
    c) CID=$OPTARG ;;
    l) LOOP=$OPTARG ;;
    H) usage && exit ;;
    \?) usage && die "Invalid Option -$OPTARG" ;;
    :) usage && die "Option -$OPTARG requires an argument." ;;
  esac
done

case $CID in
  ifupdown)
    eth_multi.sh -l "$LOOP" -t 'ifupdown'
    ;;
  pingon_func)
    host=$(get_host)
    do_cmd "ping ${host} -c 3"
    ;;
  pingon_stress_size)
    host=$(get_host)
    for size in 128 512 1024 4096 8192 16384; do
      do_cmd "ping ${host} -c 3 -s $size"
    done
    ;;
  pingon_stress_time)
    host=$(get_host)
    do_cmd "ping $host -w 300"
    ;;
  ping)
    eth_multi.sh -l "$LOOP" -t 'ping' -d 60
    ;;
  ping_updown)
    eth_multi.sh -l "$LOOP" -t 'ping_updown' -d 60
    ;;
  ping_down)
    eth_multi.sh -l "$LOOP" -t 'ping_down' -d 60
    ;;
  *)
    die "Invalied case id!"
    ;;
esac
