#!/bin/bash
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
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
source "eth_common.sh"

############################# Functions #######################################

########################### REUSABLE TEST LOGIC ###############################
# Usage information: eth_multi.sh -l <num_of_iterations>
#                                 -t <type_of_test - example,
#                                        ifupdown for ifdown/ifup on all interfaces,
#                                        ping for pinging each of the interfaces
#                                        ping_updown for pinging one interface while doing ifdown/ifup on
#                                           all other interfaces,
#                                        ping_down for pinging on interface while bringing down
#                                           all other interfaces
#                                 -d <duration of ping in seconds>
#                                 -p <packetsize for ping in bytes>
#################################################################################

p_iterations=10
p_type='ifupdown'
p_duration=10
p_pktsize=64
p_sequence='all'
OFS=$IFS
while getopts ":l:t:d:p:" opt; do
  case $opt in
  l)
    p_iterations=$OPTARG
    ;;
  t)
    p_type="$OPTARG"
    ;;
  d)
    p_duration=$OPTARG
    ;;
  p)
    p_pktsize=$OPTARG
    ;;
  esac
done

# check for all eth interfaces supported and create an array
interfaces=`get_eth_iface_name.sh -t all`
[ $? -ne 0 ] && die "Failed to get eth interface name"
int_name=($interfaces)

# for each eth interface, find the corresponding gateway
for (( j=0; j < ${#int_name[@]}; j++ ))
do
 do_eth_up_down.sh -d "up" -i "${int_name[j]}" || die "Failed to up ${int_name[j]}"
 eth_gateway[j]=`get_eth_gateway.sh -i ${int_name[j]}` || die "Error getting eth gateway for ${int_name[j]},the error value is ${eth_gateway[j]}"
done

# now run the test based on command-line parameters
if [ "$p_type" = 'ping_updown' ] || [ "$p_type" = 'ping_down' ]
then
# for every interface
# start ping in background
# for every other interface
# do ifdown (and ifup, if applicable) on all other interfaces
  for (( i=0; i < ${#int_name[@]}; i++ ))
  do
    do_eth_up_down.sh -d "up" -i "${int_name[i]}" || die "Failed to up ${int_name[i]}"
    [ -f nohup.out ] && do_cmd rm nohup.out
    do_cmd nohup ping ${eth_gateway[i]} -s $p_pktsize -w $p_duration > nohup.out 2>&1 &
    pid=$!
    for (( k=0; k<$p_iterations; k++ ))
    do
       if [ "$p_type" = 'ping_updown' ]
       then
         for (( j=0; j<${#int_name[@]}; j++ ))
         do
           if [[ $j != $i ]]
           then
             do_eth_up_down.sh -d "down" -i "${int_name[j]}" || die "Failed to up ${int_name[j]}"
             do_eth_up_down.sh -d "up" -i "${int_name[j]}" || die "Failed to up ${int_name[j]}"
           fi
         done
       elif [ "$p_type" = 'ping_down' ]
       then
         for (( j=0; j<${#int_name[@]}; j++ ))
         do
             if [[ $j != $i ]]
             then
               do_eth_up_down.sh -d "down" -i "${int_name[j]}" || die "Failed to up ${int_name[j]}"
             fi
           done
           k=$p_iterations
         fi
    done # for each iteration
    # wait for ping process to be completed
    if [ "x$pid" != "x" ]
    then
      wait ${pid}
      rc=$?
      if [ "$rc" -ne "0" ]
      then
        die "Ping Process failed"
        break
      fi
    fi
    result=`cat nohup.out | grep " 100% packet loss"`
    if [[ -n "$result" ]]
    then
      echo "$result"
      die "${int_name[i]} - Ping resulted in packet loss"
    fi
    result=`cat nohup.out | grep "Network is unreachable"`
    if [[ -n "$result" ]]
    then
      echo "$result"
      die "${int_name[i]} - Network is unreachable"
    fi
  done
# for each interface
#### done with ping_updown and ping_down, so perform other cases now
   elif [ "$p_sequence" = 'all' ]
   then
     for (( i=0; i<$p_iterations ; i++ ))
     do
       for (( k=0; k<${#int_name[@]}; k++ ))
       do
         case $p_type in
         'ifupdown')
           do_eth_up_down.sh -d "down" -i "${int_name[k]}" || die "Failed to up ${int_name[k]}"
           do_eth_up_down.sh -d "up" -i "${int_name[k]}" || die "Failed to up ${int_name[k]}"
          ;;

          'ping')
             do_cmd "ping ${eth_gateway[k]} -c 3 -w $p_duration -s $p_pktsize"
          ;;
         esac
       done
     done
   fi

IFS=$OFS
