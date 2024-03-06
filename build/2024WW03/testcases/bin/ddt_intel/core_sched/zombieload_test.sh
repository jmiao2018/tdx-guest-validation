#!/bin/bash
###############################################################################
# Copyright (C) 2019, Intel - http://www.intel.com
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

############################ CONTRIBUTORS #####################################
# @Author   Hongyu, Ning <hongyu.ning@intel.com>

############################ DESCRIPTION ######################################
# @desc     Execution ZombieLoad testing based on open source ZombieLoad PoC code
# @returns

############################# FUNCTIONS #######################################
source "core_sched_common.sh"
source "common.sh"

#get default cpu governor setting
cpu_governor=$(getgov.sh)

#check on the hyper threading is enabled or not
lscpu | grep ht || die "hyper threading not enabled, can't do zombieload test"
[[ $(lscpu | grep "Thread(s) per core:" | awk '{print $NF}') -ge 2 ]] \
  || die "hyper threading not enabled, threads per core is less than 2, can't do zombieload test"

#register teardown_handler to governor_teardown, restore governor setting to default
export teardown_handler="governor_teardown ${cpu_governor}"

#set performance test environment
test_print_trc "set all CPU governor to performance mode"
setgov.sh performance

#function to create control groups via cgcreate
cg_create cpu g1 c1
cg_create cpu g2 c2
cg_create cpuset g1 c1
cg_create cpuset g2 c2

#for a given cpu_id, get the cpu_sibling_pair
cpu_id=0
cpu_sibling_pair=$(cpu_sibling ${cpu_id})
test_print_trc "cpu sibling pair of cpu ${cpu_id} : ${cpu_sibling_pair}"

#set sibling pair to new cgroup under cpuset (required by new core_sched enabling)
test_print_trc "set cpuset.cpus with sibling pair"
echo ${cpu_id},${cpu_sibling_pair} > /sys/fs/cgroup/cpuset/g1/c1/cpuset.cpus
echo ${cpu_id},${cpu_sibling_pair} > /sys/fs/cgroup/cpuset/g2/c2/cpuset.cpus
echo ${cpu_id},${cpu_sibling_pair} > /sys/fs/cgroup/cpuset/g1/cpuset.cpus
echo ${cpu_id},${cpu_sibling_pair} > /sys/fs/cgroup/cpuset/g2/cpuset.cpus

#Launch zombieload test binary leak and userspace secret
#program_launch_pad -h
test_print_trc "launch leak & userspace secret ZombieLoad test binary"
program_launch_pad -p "leak" -c "${cpu_id}" -g "cpu:g1/c1" -a "threads --threads=1 run" &
sleep 3
program_launch_pad -p "secret" -c "${cpu_sibling_pair}" -g "cpu:g2/c2" -a "A --cpu 1 -t 60m" &
perf sched record -- sleep 1
sleep 2
perf sched map > perf_sched_map.log
test_print_trc "perf_sched_map.log:"
cat perf_sched_map.log

#set cpu.tag to enable core scheduler patch
test_print_trc "set cpu.tag to enable core scheduler"
echo 1 > /sys/fs/cgroup/cpu/g1/c1/cpu.tag
echo 1 > /sys/fs/cgroup/cpu/g2/c2/cpu.tag
echo 1 > /sys/fs/cgroup/cpu/g1/cpu.tag
echo 1 > /sys/fs/cgroup/cpu/g2/cpu.tag

perf sched record -- sleep 1
sleep 2
perf sched map > perf_sched_map_cs_en.log
test_print_trc "perf_sched_map_cs_en.log:"
cat perf_sched_map_cs_en.log

program_cpu_id "leak" > /dev/null && leak_cpu_id=$(program_cpu_id "leak")
[[ -n ${leak_cpu_id} ]] && test_print_trc "leak is running on cpu: ${leak_cpu_id}"
program_cpu_id "secret" > /dev/null && secret_cpu_id=$(program_cpu_id "secret")
[[ -n ${secret_cpu_id} ]] && test_print_trc "secret is running on cpu: ${secret_cpu_id}"
killall "leak"
killall "secret"

#set cpu.tag to disable core scheduler patch
test_print_trc "set cpu.tag to disable core scheduler"
echo 0 > /sys/fs/cgroup/cpu/g1/c1/cpu.tag
echo 0 > /sys/fs/cgroup/cpu/g2/c2/cpu.tag
echo 0 > /sys/fs/cgroup/cpu/g1/cpu.tag
echo 0 > /sys/fs/cgroup/cpu/g2/cpu.tag

#checking on the perf sched log about leak/secret cpu core mapping info
leak_pid=$(cat "perf_sched_map.log" | grep "=> leak" | awk '{print $(NF-2)}')
secret_pid=$(cat "perf_sched_map.log" | grep "=> secret" | awk '{print $(NF-2)}')
leak_pid_cs_en=$(cat "perf_sched_map_cs_en.log" | grep "=> leak" | awk '{print $(NF-2)}')
secret_pid_cs_en=$(cat "perf_sched_map_cs_en.log" | grep "=> secret" | awk '{print $(NF-2)}')

[[ -z ${leak_pid} ]] || [[ -z ${secret_pid} ]] || [[ -z ${leak_pid_cs_en} ]] || [[ -z ${secret_pid_cs_en} ]] \
  && die "FAIL to capture leak or secret process in perf sched map log, please re-run test!"

#before core_sched enabled, there is leak and secret sched on the same physical core of HTs at same time
cat "perf_sched_map.log" | grep "${leak_pid}" | grep "${secret_pid}" > /dev/null \
  && test_print_trc "core_sched NOT enabled, leak & secret sched on same phy_core of HTs at same time as expected"

#after core_sched enabled, there should be no leak and secret sched on the same physical core of HTs at same time
cat "perf_sched_map_cs_en.log" | grep "{leak_pid_cs_en}" | grep "{secret_pid_cs_en}" \
  && die "FAIL, core_sched enabled, leak & secret should NOT sched on same phy_core of HTs at same time,\
  please dump full dmesg for further anlyzing"
test_print_trc "core_sched enabled, leak & secret NOT sched on same phy_core of HTs at same time as expected"

#remove perf sched map log of this test cycle
rm -rf perf_sched_map.log
rm -rf perf_sched_map_cs_en.log

#for passed case, call cpu governor_teardown to restore default governor setting
exec_teardown
