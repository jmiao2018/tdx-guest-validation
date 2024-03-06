#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for Intel x86 CPU topology

# Authors:      wendy.wang@intel.com
# History:      June 6 2023 - Created - Wendy Wang

source "common.sh"
source "powermgr_common.sh"

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

numa_nodes_compare_with_package() {
  local numa_nodes
  local cpuinfo_nodes

  cpuinfo_nodes=$(lscpu | grep NUMA 2>&1)
  [[ -n $cpuinfo_nodes ]] || block_test "NUMA nodes info is not available from lscpu."
  test_print_trc "SUT NUMA nodes info from lscpu shows: $cpuinfo_nodes"

  numa_nodes=$(grep . /sys/devices/system/node/node*/cpulist 2>&1)
  [[ -n $numa_nodes ]] || block_test "NUMA nodes sysfs files is not available."
  test_print_trc "SUT NUMA nodes sysfs info: $numa_nodes"
  nodes_lines=$(grep . /sys/devices/system/node/node*/cpulist | wc -l 2>&1)

  for ((i = 1; i <= nodes_lines; i++)); do
    node_cpu_list=$(echo "$numa_nodes" | sed -n "$i, 1p" | awk -F ":" '{print $2}')
    node_num=$(lscpu | grep "$node_cpu_list" | awk -F " " '{print $2}')
    test_print_trc "node num: $node_num"
    test_print_trc "NUMA $node_num sysfs show cpu list: $node_cpu_list"
    cpu_num=$(echo "$node_cpu_list" | awk -F "-" '{print $1}')
    test_print_trc "cpu num for pkg cpu list:$cpu_num"
    pkg_cpu_list=$(grep . /sys/devices/system/cpu/cpu"$cpu_num"/topology/package_cpus_list)
    [[ -n "$pkg_cpu_list" ]] || block_test "CPU Topology sysfs for package_cpus_list is not available."
    test_print_trc "CPU$cpu_num located Package cpu list is: $pkg_cpu_list"
    if [ "$node_cpu_list" = "$pkg_cpu_list" ]; then
      test_print_trc "NUMA $node_num cpu list is aligned with package cpu list"
    else
      die "NUMA $node_num cpu list is NOT aligned with package cpu list"
    fi
  done
}

thread_per_core() {
  smt_enable=$(cat /sys/devices/system/cpu/smt/active)
  threads_per_core=$(lscpu | grep "Thread(s) per core" | awk '{print $4}')

  if [[ $smt_enable -eq 1 ]] && [[ $threads_per_core -eq 2 ]]; then
    test_print_trc "SMT is enabled, Thread(s) per core is 2, it's expected."
  elif [[ $smt_enable -eq 1 ]] && [[ $threads_per_core -eq 1 ]]; then
    die "SMT is enabled, Thread(s) per core is 1, it's not expected"
  elif [[ $smt_enable -eq 0 ]] && [[ $threads_per_core -eq 1 ]]; then
    test_print_trc "SMT is not enabled, Thread(s) per core is 1, it's expected."
  elif [[ $smt_enable -eq 0 ]] && [[ $threads_per_core -eq 1 ]]; then
    die "SMT is not enabled, Thread(s) per core is 2, it's not expected"
  else
    die "Unknown SMT status"
  fi
}

core_per_socket() {
  cores_per_socket_sys=$(grep ^"core id" /proc/cpuinfo | sort -u | wc -l)
  test_print_trc "sysfs shows cores per socket: $cores_per_socket_sys"
  socket_num_lscpu_parse=$(lscpu -b -p=Socket | grep -v '^#' | sort -u | wc -l)
  cores_per_socket_raw_lscpu=$(lscpu -b -p=Core,Socket | grep -v '^#' | sort -u | wc -l)
  cores_per_socket_lscpu=$(("$cores_per_socket_raw_lscpu" / "$socket_num_lscpu_parse"))
  test_print_trc "lscpu parse shows cores per socket: $cores_per_socket_lscpu"
  cores_per_socket=$(lscpu | grep "Core(s) per socket" | awk '{print $4}')
  test_print_trc "lscpu shows cores per socket: $cores_per_socket"
  core_per_socket_topo=$(grep . /sys/devices/system/cpu/cpu*/topology/core_id |
    awk -F ":" '{print $2}' | sort -u | wc -l)
  test_print_trc "CPU topology sysfs shows cores per socket: $core_per_socket_topo"

  if [[ $cores_per_socket_sys -eq $cores_per_socket_lscpu ]] &&
    [[ $cores_per_socket_sys -eq $cores_per_socket ]] &&
    [[ $cores_per_socket_sys -eq $core_per_socket_topo ]]; then
    test_print_trc "cores per sockets is aligned between sysfs and lscpu"
  elif [[ $cores_per_socket_sys -eq $cores_per_socket_lscpu ]] &&
    [[ $cores_per_socket_sys -ne $cores_per_socket ]]; then
    die "lscpu output for cores per socket is wrong."
  elif [[ $cores_per_socket_sys -eq $cores_per_socket_lscpu ]] &&
    [[ $core_per_socket_topo -ne $cores_per_socket ]]; then
    die "lscpu output for cores per socket is wrong."
  else
    die "cores per sockets is not aligned between sysfs and lscpu"
  fi
}

socket_num() {
  numa_num=$(lscpu | grep "NUMA node(s)" | awk '{print $3}')
  test_print_trc "lspci shows numa node num: $numa_num"
  sockets_num_lspci=$(lscpu | grep "Socket(s)" | awk '{print $2}')
  test_print_trc "lspci shows socket number: $sockets_num_lspci"
  sockets_num_sys=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
  test_print_trc "sysfs shows socket number: $sockets_num_sys"
  socket_num_topo_sysfs=$(grep . /sys/devices/system/cpu/cpu*/topology/physical_package_id |
    awk -F ":" '{print $2}' | sort -u | wc -l)
  [[ -n "$socket_num_topo_sysfs" ]] || block_test "CPU Topology sysfs for physical_package_id is not available."
  test_print_trc "topology sysfs shows socket number: $socket_num_topo_sysfs"

  if [[ $sockets_num_lspci -eq $sockets_num_sys ]] &&
    [[ $socket_num_topo_sysfs -eq $sockets_num_lspci ]] &&
    [[ $sockets_num_sys -eq $numa_num ]]; then
    test_print_trc "socket number is aligned between lspci and sysfs"
  else
    die "socket number is not aligned between lspci and sysfs"
  fi
}

# On CBB Topology supported platform, two cores are in one core module to share L2 cache
# So need to check cluster id and core id, make sure dual core module is detected
dual_core_module() {
  [[ -e /sys/devices/system/cpu/cpu0/topology/cluster_id ]] || block_test "cluster_id sysfs is not available."
  cluster_id_num=$(grep . /sys/devices/system/cpu/cpu*/topology/cluster_id | awk -F ":" '{print $2}' | sort -u | wc -l)
  test_print_trc "cluster_id_num lines: $cluster_id_num"
  core_id_num=$(grep . /sys/devices/system/cpu/cpu*/topology/core_cpus_list | awk -F ":" '{print $2}' | sort -u | wc -l)
  test_print_trc "core_id_num lines: $core_id_num"
  if [[ $(echo "$core_id_num/2" | bc) -eq "$cluster_id_num" ]]; then
    test_print_trc "core_cpus_list num is algined with dual core modules"
  else
    die "core_cpus_list num is not algined with dual core modules"
  fi
}

level_type() {
  # thread level type
  thread_type=$(cpuid -l 0x1f -s 0 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 0 shows $thread_type level type"
  thread_level_num=$(cpuid -l 0x1f -s 0 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 level number line: $thread_level_num"
  thread_type_num=$(cpuid -l 0x1f -s 0 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 level number line: $thread_type_num"
  bit_width_index_0=$(cpuid -l 0x1f -s 0 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 bit width line: $bit_width_index_0"

  # core level type
  core_type=$(cpuid -l 0x1f -s 1 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 1 shows $core_type level type"
  core_level_num=$(cpuid -l 0x1f -s 1 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 level number line: $core_level_num"
  core_type_num=$(cpuid -l 0x1f -s 1 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 level number line: $core_type_num"
  bit_width_index_1=$(cpuid -l 0x1f -s 1 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 bit width line: $bit_width_index_1"

  # module level type
  module_type=$(cpuid -l 0x1f -s 2 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 2 shows $module_type level type"
  module_level_num=$(cpuid -l 0x1f -s 2 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 level number line: $module_level_num"
  module_type_num=$(cpuid -l 0x1f -s 2 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 level number line: $module_type_num"
  bit_width_index_2=$(cpuid -l 0x1f -s 2 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 bit width line: $bit_width_index_2"

  # invalid level type
  invalid_type_sub3=$(cpuid -l 0x1f -s 3 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 3 shows $invalid_type_sub3 level type"
  bit_width_index_3=$(cpuid -l 0x1f -s 3 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 3 bit width line: $bit_width_index_3"
  invalid_type_sub4=$(cpuid -l 0x1f -s 4 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 4 shows $invalid_type_sub4 level type"

  if [[ $thread_type == thread ]] && [[ $bit_width_index_0 -eq 1 ]] &&
    [[ $thread_level_num -eq 1 ]] && [[ $thread_type_num -eq 1 ]]; then
    test_print_trc "CPUID: level type: thread is correctly detected, and all threads bit width are aligned"
  else
    die "CPUID: level type: thread is not correctly detected or bit width is not aligned"
  fi

  if [[ $core_type == core ]] && [[ $bit_width_index_1 -eq 1 ]] &&
    [[ $core_level_num -eq 1 ]] && [[ $core_type_num -eq 1 ]]; then
    test_print_trc "CPUID: level type: core is correctly detected, and all cores bit width are aligned"
  else
    die "CPUID: level type: core is not correctly detected or bit width is not aligned"
  fi

  if [[ $module_type == module ]] && [[ $invalid_type_sub3 == invalid ]] &&
    [[ $invalid_type_sub4 == invalid ]] && [[ $module_level_num -eq 1 ]] &&
    [[ $module_type_num -eq 1 ]] && [[ $bit_width_index_2 -eq 1 ]] &&
    [[ $bit_width_index_3 -eq 1 ]]; then
    test_print_trc "CPUID: module and invalid level type are detected, and bit width are aligned."
  elif [[ $module_type == invalid ]] && [[ $invalid_type_sub3 == invalid ]] &&
    [[ $bit_width_index_3 -eq 1 ]]; then
    test_print_trc "CPUID: platform does not support module, and invalid level type is detected,
bit width of level & previous levels are aligned."
  else
    die "CPUID: unexpected level type."
  fi
}

# On Core Building Block Topology supported platform, e.g. DMR
# Thread/core/module/die level type are requried
# Based on CPUID leaf 0x1F subleaf 0/1/2/3
cbb_topo_level_type() {
  # Thread level type
  thread_type=$(cpuid -l 0x1f -s 0 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 0 shows $thread_type level type"
  thread_level_num=$(cpuid -l 0x1f -s 0 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 level number line: $thread_level_num"
  thread_type_num=$(cpuid -l 0x1f -s 0 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 level number line: $thread_type_num"
  bit_width_index_0=$(cpuid -l 0x1f -s 0 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 bit width line: $bit_width_index_0"

  # Core level type
  core_type=$(cpuid -l 0x1f -s 1 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 1 shows $core_type level type"
  core_level_num=$(cpuid -l 0x1f -s 1 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 level number line: $core_level_num"
  core_type_num=$(cpuid -l 0x1f -s 1 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 level number line: $core_type_num"
  bit_width_index_1=$(cpuid -l 0x1f -s 1 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 bit width line: $bit_width_index_1"

  # Module level type
  module_type=$(cpuid -l 0x1f -s 2 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 2 shows $module_type level type"
  module_level_num=$(cpuid -l 0x1f -s 2 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 level number line: $module_level_num"
  module_type_num=$(cpuid -l 0x1f -s 2 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 level number line: $module_type_num"
  bit_width_index_2=$(cpuid -l 0x1f -s 2 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 bit width line: $bit_width_index_2"

  # Die level type
  die_type=$(cpuid -l 0x1f -s 3 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 3 shows $die_type level type"
  die_level_num=$(cpuid -l 0x1f -s 3 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 3 level number line: $die_level_num"
  die_type_num=$(cpuid -l 0x1f -s 3 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 3 level number line: $die_type_num"
  bit_width_index_3=$(cpuid -l 0x1f -s 3 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 3 bit width line: $bit_width_index_3"

  # Invalid level type
  invalid_type_sub4=$(cpuid -l 0x1f -s 4 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 4 shows $invalid_type_sub4 level type"
  invalid_level_num=$(cpuid -l 0x1f -s 4 | grep "level number" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 4 level number line: $invalid_level_num"
  invalid_type_num=$(cpuid -l 0x1f -s 4 | grep "level type" | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 4 level number line: $invalid_type_num"
  bit_width_index_4=$(cpuid -l 0x1f -s 4 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 3 bit width line: $bit_width_index_4"

  if [[ $thread_type == thread ]] && [[ $bit_width_index_0 -eq 1 ]] &&
    [[ $thread_level_num -eq 1 ]] && [[ $thread_type_num -eq 1 ]]; then
    test_print_trc "CPUID: level type: thread is correctly detected, and all threads bit width are aligned"
  else
    die "CPUID: level type: thread is not correctly detected or bit width is not aligned"
  fi

  if [[ $core_type == core ]] && [[ $bit_width_index_1 -eq 1 ]] &&
    [[ $core_level_num -eq 1 ]] && [[ $core_type_num -eq 1 ]]; then
    test_print_trc "CPUID: level type: core is correctly detected, and all cores bit width are aligned"
  else
    die "CPUID: level type: core is not correctly detected or bit width is not aligned"
  fi

  if [[ $module_type == module ]] && [[ $bit_width_index_2 -eq 1 ]] &&
    [[ $module_level_num -eq 1 ]] && [[ $module_type_num -eq 1 ]]; then
    test_print_trc "CPUID: level type: module is correctly detected, and all modules bit width are aligned"
  else
    die "CPUID: level type: module is not correctly detected or bit width is not aligned"
  fi

  if [[ $die_type == die ]] && [[ $bit_width_index_3 -eq 1 ]] &&
    [[ $die_level_num -eq 1 ]] && [[ $die_type_num -eq 1 ]]; then
    test_print_trc "CPUID: level type: die is correctly detected, and all dies bit width are aligned"
  else
    die "CPUID: level type: die is not correctly detected or bit width is not aligned"
  fi
}

get_lstopo_outputs() {
  test_print_trc "Enable the sched_domain verbose"
  do_cmd "echo Y > /sys/kernel/debug/sched/verbose"

  numa_num=$(lscpu | grep "NUMA node(s)" | awk '{print $3}')
  test_print_trc "lspci shows numa node num: $numa_num"

  sched_domain_names=$(grep . /sys/kernel/debug/sched/domains/cpu0/domain*/name | awk -F ":" '{print $NF}')
  test_print_trc "CPU0 sched_domain names: $sched_domain_names"
  sched_domain_proc=$(cat /proc/schedstat)
  [[ -n "$sched_domain_names" ]] || block_test "sched_domain debugfs is not available, need to check \
  /proc/schedstat: $sched_domain_proc"

  test_print_trc "Will run lstopo --no-io command to get topology outputs"
  lstopo --no-io 1>/dev/null 2>&1 || block_test "Please install hwloc-gui.x86_64 package to get lstopo tool"
  do_cmd "lstopo -v --no-io > topology_verbose.log"
  do_cmd "lstopo --no-io > topology.log"
  test_print_trc "lstopo output:"
  do_cmd "cat topology.log"
}

# Function to check sched_domain on CBB Topology platform
# Single package: CLS/MC/DIE
# Multi packages without SNC: CLS/MC/NUMA
# Multi packages with SNC: CLS/MC/NUMA level 0/ NUMA level 1 (SNC will be add back on DMR?)
cbb_topo_sched_domain() {
  get_lstopo_outputs

  if [[ $numa_num -eq 1 ]]; then
    cls_name=$(echo "$sched_domain_names" | sed -n "1,1p")
    if [[ $cls_name == CLS ]]; then
      test_print_trc "CLS sched_domain name is detected."
    else
      die "CLS sched_domain name is not detected."
    fi

    mc_name=$(echo "$sched_domain_names" | sed -n "2,1p")
    if [[ $mc_name == MC ]]; then
      test_print_trc "MC sched_domain name is detected."
    else
      die "MC sched_domain name is not detected."
    fi

    die_name=$(echo "$sched_domain_names" | sed -n "3,1p")
    if [[ $die_name == DIE ]]; then
      test_print_trc "DIE sched_domain name is detected."
    else
      die "DIE sched_domain name is not detected."
    fi

  elif [[ $numa_num -gt 1 ]]; then

    cls_name=$(echo "$sched_domain_names" | sed -n "1,1p")
    if [[ $cls_name == CLS ]]; then
      test_print_trc "CLS sched_domain name is detected."
    else
      die "CLS sched_domain name is not detected."
    fi

    mc_name=$(echo "$sched_domain_names" | sed -n "2,1p")
    if [[ $mc_name == MC ]]; then
      test_print_trc "MC sched_domain name is detected."
    else
      die "MC sched_domain name is not detected."
    fi

    numa_name=$(echo "$sched_domain_names" | sed -n "3,1p")
    if [[ $numa_name == NUMA ]]; then
      test_print_trc "NUMA sched_domain name is detected."
    else
      die "NUMA sched_domain name is not detected."
    fi
  fi
}

# Example: SRF, CWF, which does not support Pcore, does not support SMT
# SRF has SRF-SP and SRF-AP, especially SRF-AP may support two LLC (LL3) per package
# By default we assume SNC is disabled, case did not consider SNC enable scenairo
# SMT: SRF/CWF does not support SMT because ecore only
# CLS: CPUs with the same L2 id, SRF/CWF supports
# MC: CPUs with the same LLC (L3) id, SRF/CWF supports
# Die: CPUs with same numa node/pkg? id, on SRF-AP, there are two LL3 IDs per package
server_ecore_only_sched_domain() {
  get_lstopo_outputs

  test_print_trc "Check if the platform support multiple LLC in one package:"
  pkg_num=$(grep Package topology_verbose.log | grep depth | awk -F ":" '{print $2}' | sed 's/^ *//' | awk '{print $1}')
  test_print_trc "Package number is: $pkg_num"
  llc_num=$(grep L3Cache topology_verbose.log | grep depth | awk -F ":" '{print $2}' | sed 's/^ *//' | awk '{print $1}')
  test_print_trc "L3Cache number is: $llc_num"

  if [[ $numa_num -eq 1 ]]; then
    domain0_name=$(echo "$sched_domain_names" | sed -n "1,1p")
    test_print_trc "Domain0 name: $domain0_name"
    if [[ $domain0_name == CLS ]]; then
      test_print_trc "CLS sched_domain name is detected."
    else
      die "CLS sched_domain name is not detected."
    fi

    domain1_name=$(echo "$sched_domain_names" | sed -n "2,1p")
    test_print_trc "Domain1 name: $domain1_name"
    if [[ $domain1_name == MC ]]; then
      test_print_trc "MC sched_domain name is detected."
    else
      die "MC sched_domain name is not detected."
    fi

    domain2_name=$(echo "$sched_domain_names" | sed -n "3,1p")
    test_print_trc "Domain2 name: $domain2_name"
    if [[ $llc_num -gt $pkg_num ]]; then
      if [[ $domain2_name == DIE ]]; then
        test_print_trc "L3Cache number is larger than Package, so domain2 name shows DIE"
      else
        die "L3Cache number is larger than Package, but domain2 name is not DIE"
      fi
    elif [[ ! "$domain2_name" ]]; then
      test_print_trc "There is no sched_domain 2, it's expected."
    else
      die "Sched_domain 2 is not expected."
    fi

  elif [[ $numa_num -gt 1 ]]; then

    domain0_name=$(echo "$sched_domain_names" | sed -n "1,1p")
    test_print_trc "Domain0 name: $domain0_name"
    if [[ $domain0_name == CLS ]]; then
      test_print_trc "CLS sched_domain name is detected."
    else
      die "CLS sched_domain name is not detected."
    fi

    domain1_name=$(echo "$sched_domain_names" | sed -n "2,1p")
    test_print_trc "Domain1 name: $domain1_name"
    if [[ $domain1_name == MC ]]; then
      test_print_trc "MC sched_domain name is detected."
    else
      die "MC sched_domain name is not detected."
    fi

    domain2_name=$(echo "$sched_domain_names" | sed -n "3,1p")
    test_print_trc "Domain2 name: $domain2_name"
    if [[ $llc_num -gt $pkg_num ]]; then
      if [[ $domain2_name == DIE ]]; then
        test_print_trc "L3Cache number is larger than Package, so domain2 name shows DIE"
        domain3_name=$(echo "$sched_domain_names" | sed -n "4,1p")
        test_print_trc "Domain3 name: $domain3_name"
        if [[ $domain3_name == NUMA ]]; then
          test_print_trc "NUMA sched_domain is detected as domain3 name"
        else
          die "NUMA sched_domain is not detected as domain3 name"
        fi
      else
        die "L3Cache number is larger than Package, but domain2 name is not DIE"
      fi
    elif [[ ! "$domain2_name" ]]; then
      die "Expect to get Sched_domain name NUMA"
    elif [[ $domain2_name == NUMA ]]; then
      test_print_trc "NUMA sched_domain is detected as domain2 name"
    else
      die "NUMA sched_domain is not detected as domain2 name"
    fi
  fi
}

# Example GNR, EMR, which support Pcores, support SMT sched_domain
# SMT: CPUs with the same core_id, on GNR/EMR, two logical CPUs share one Core
# CLS: CPUs with the same L2 id, on GNR/EMR there is no CLS because one L2 per one Core
# MC: CPUs with the same LLC (L3) id, MC is supported on GNR/EMR
# Die: CPUs witht same numa node/pkg? id
# NUMA: if GNR/EMR support multiple package, NUMA is supported.
sever_pcore_smt_sched_domain() {
  get_lstopo_outputs

  if [[ $numa_num -eq 1 ]]; then
    domain0_name=$(echo "$sched_domain_names" | sed -n "1,1p")
    test_print_trc "Domain0 name: $domain0_name"
    if [[ $domain0_name == SMT ]]; then
      test_print_trc "SMT sched_domain name is detected."
    else
      die "SMT sched_domain name is not detected."
    fi

    domain1_name=$(echo "$sched_domain_names" | sed -n "2,1p")
    test_print_trc "Domain1 name: $domain1_name"
    if [[ $domain1_name == MC ]]; then
      test_print_trc "MC sched_domain name is detected."
    else
      die "MC sched_domain name is not detected."
    fi

  elif [[ $numa_num -gt 1 ]]; then

    domain0_name=$(echo "$sched_domain_names" | sed -n "1,1p")
    test_print_trc "Domain0 name: $domain0_name"
    if [[ $domain0_name == SMT ]]; then
      test_print_trc "CLS sched_domain name is detected."
    else
      die "CLS sched_domain name is not detected."
    fi

    domain1_name=$(echo "$sched_domain_names" | sed -n "2,1p")
    test_print_trc "Domain1 name: $domain1_name"
    if [[ $domain1_name == MC ]]; then
      test_print_trc "MC sched_domain name is detected."
    else
      die "MC sched_domain name is not detected."
    fi

    domain2_name=$(echo "$sched_domain_names" | sed -n "3,1p")
    test_print_trc "Domain2 name: $domain2_name"
    if [[ $domain2_name == NUMA ]]; then
      test_print_trc "NUMA sched_domain name is detected."
    else
      die "NUMA sched_domain name is not detected."
    fi
  fi
}

# Example: Arrow lake-S
# If SMT is enabled, then Pcore domain0 should be SMT, Pcore domain1 is MC
# If SMT is disabled, then SMT domain name will not support
# Usually Pcore will not share L2, so there is not CLS for Pcore
# Ecore will have both CLS(CPUs in L2) and MC (CPUs in LL3)
client_hybrid_no_lp_sched_domain() {
  get_lstopo_outputs

  # For Pcore, take the 1st Pcore (CPU0) for example
  pcore_domain0_name=$(echo "$sched_domain_names" | sed -n "1,1p")
  test_print_trc "Pcore Domain0 name: $pcore_domain0_name"

  pcore_domain1_name=$(echo "$sched_domain_names" | sed -n "2,1p")
  if [[ -n "$pcore_domain1_name" ]]; then
    test_print_trc "Pcore does not support sched_domain1"
  else
    test_print_trc "Pcore Domain1 name: $pcore_domain1_name"
  fi

  smt_enable=$(cat /sys/devices/system/cpu/smt/active)
  if [[ $smt_enable -eq 1 ]] && [[ $pcore_domain0_name == SMT ]]; then
    test_print_trc "SMT is enabled, and pcore domain0 shows SMT, is expected."
    if [[ $pcore_domain1_name == MC ]]; then
      test_print_trc "Pcore MC domain is detected"
    else
      die "Pcore MC domain is not detected"
    fi
  elif [[ $smt_enable -eq 1 ]] && [[ $pcore_domain0_name != SMT ]]; then
    die "SMT is enabled, but pcore domain0 did not show SMT, it's wrong"
  elif [[ $smt_enable -eq 0 ]] && [[ $pcore_domain0_name == MC ]]; then
    test_print_trc "SMT is disabled, pcore domain0 show MC is expected because L2 per Pcore"
  else
    die "SMT is disabled, pcore domain0 did not report MC"
  fi

  # For Ecore, take the 1st Ecore for example
  # Find Ecore through sysfs cluster_cpus_list, because ecores are sharing L2
  ecore_id=$(grep . /sys/devices/system/cpu/cpu*/topology/cluster_cpus_list |
    awk -F ":" '{print $2}' | grep "-" | sed -n '1,1p' | awk -F "-" '{print $1}')
  ecore_sched_domain_names=$(grep . /sys/kernel/debug/sched/domains/cpu"$ecore_id"/domain*/name |
    awk -F ":" '{print $NF}')
  test_print_trc "Ecore sched_domain names: $ecore_sched_domain_names"

  ecore_domain0_name=$(echo "$ecore_sched_domain_names" | sed -n "1,1p")
  test_print_trc "Ecore Domain0 name: $ecore_domain0_name"

  ecore_domain1_name=$(echo "$ecore_sched_domain_names" | sed -n "2,1p")
  test_print_trc "Ecore Domain1 name: $ecore_domain1_name"
  if [[ $ecore_domain0_name == CLS ]]; then
    test_print_trc "Ecore CLS sched_domain name is detected."
  else
    die "Ecore CLS sched_domain name is not detected."
  fi

  if [[ $ecore_domain1_name == MC ]]; then
    test_print_trc "Ecore MC sched_domain name is detected."
  else
    die "Ecore MC sched_domain name is not detected."
  fi
}

# Example: lunar lake-M
# On LNL-M, the low power CPUs do not have L3 Cache
# So the last domain name will be PKG
client_ecore_no_l3_cache_sched_domain() {
  get_lstopo_outputs

  # For Pcore, take the 1st Pcore (CPU0) for example
  pcore_domain0_name=$(echo "$sched_domain_names" | sed -n "1,1p")
  test_print_trc "Pcore Domain0 name: $pcore_domain0_name"

  pcore_domain1_name=$(echo "$sched_domain_names" | sed -n "2,1p")
  test_print_trc "Pcore Domain1 name: $pcore_domain1_name"

  pcore_domain2_name=$(echo "$sched_domain_names" | sed -n "3,1p")
  if [[ -n $pcore_domain2_name ]]; then
    test_print_trc "Pcore Domain2 name: $pcore_domain2_name"
  else
    test_print_trc "Pcore sched_domain2 does not exist."
  fi

  smt_enable=$(cat /sys/devices/system/cpu/smt/active)
  if [[ $smt_enable -eq 1 ]] && [[ $pcore_domain0_name == SMT ]]; then
    test_print_trc "SMT is enabled, and pcore domain0 shows SMT, is expected."
    if [[ $pcore_domain1_name == MC ]]; then
      test_print_trc "Pcore MC domain is detected"
      if [[ $pcore_domain2_name == pkg ]]; then
        test_print_trc "Pcore PKG sched_domain is detected."
      else
        die "Pcore PKG sched_domain is not detected."
      fi
    else
      die "Pcore MC domain is not detected"
    fi
  elif [[ $smt_enable -eq 1 ]] && [[ $pcore_domain0_name != SMT ]]; then
    die "SMT is enabled, but pcore domain0 did not show SMT, it's wrong"
  elif [[ $smt_enable -eq 0 ]] && [[ $pcore_domain0_name == MC ]]; then
    test_print_trc "SMT is disabled, pcore domain0 show MC is expected because L2 per Pcore"
    if [[ $pcore_domain1_name == PKG ]]; then
      test_print_trc "Pcore PKG sched_domain is detected."
    else
      die "Pcore PKG sched_domain is not detected."
    fi
  else
    die "SMT is disabled, pcore domain0 did not report MC"
  fi

  # For Ecore, take the 1st Ecore for example
  # Find Ecore through sysfs cluster_cpus_list, because ecores are sharing L2
  ecore_id=$(grep . /sys/devices/system/cpu/cpu*/topology/cluster_cpus_list |
    awk -F ":" '{print $2}' | grep "-" | sed -n '1,1p' | awk -F "-" '{print $1}')
  ecore_sched_domain_names=$(grep . /sys/kernel/debug/sched/domains/cpu"$ecore_id"/domain*/name |
    awk -F ":" '{print $NF}')
  test_print_trc "Ecore sched_domain names: $ecore_sched_domain_names"

  ecore_domain0_name=$(echo "$ecore_sched_domain_names" | sed -n "1,1p")
  test_print_trc "Ecore Domain0 name: $ecore_domain0_name"

  ecore_domain1_name=$(echo "$ecore_sched_domain_names" | sed -n "2,1p")
  test_print_trc "Ecore Domain1 name: $ecore_domain1_name"

  if [[ $ecore_domain0_name == CLS ]]; then
    test_print_trc "Ecore CLS sched_domain name is detected."
  else
    die "Ecore CLS sched_domain name is not detected."
  fi

  if [[ $ecore_domain1_name == PKG ]]; then
    test_print_trc "Ecore PKG sched_domain name is detected."
  else
    die "Ecore PKG sched_domain name is not detected."
  fi
}

# This funtion will verify CPUID for QEUM simulated socket, dies, clusters, core, thread CPU Topology for DMR platform
# The simulated logical CPU number calulatation example:
# CPUs_number(192)=threads(1) * cores(2) * clusters(24) * dies(4) * socket(1)
# CPUs_number(192)=threads(1) * cores(2) * clusters(24) * dies(2) * socket(2)
# In QEMU, the CPU Topology Hierachy from the lowest to the hightest are: Logical Process(Thread),Core,Cluster(Module),
# Die, Package/Socket(Which will not show up in CPUID subleaf level type)
qemu_dmr_cpuid_check() {
  local cpus_on_dies=$1
  # Thread level
  thread_type=$(cpuid -l 0x1f -s 0 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 0 shows $thread_type level type"
  bit_width_index_0=$(cpuid -l 0x1f -s 0 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 0 bit width line: $bit_width_index_0"
  num_cpus_at_thead_level=$(cpuid -l 0x1f -s 0 | grep "number of logical processors" | sort -u | awk '{print $NF}')
  # Remove ( ) around decimal value
  num_cpus_at_thead_level=${num_cpus_at_thead_level#\(}
  num_cpus_at_thead_level=${num_cpus_at_thead_level%\)}
  test_print_trc "0x1f leaf's subleaf 0 num logical cpus at thread level: $num_cpus_at_thead_level"

  # Core level
  core_type=$(cpuid -l 0x1f -s 1 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 1 shows $core_type level type"
  bit_width_index_1=$(cpuid -l 0x1f -s 1 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 1 bit width line: $bit_width_index_1"
  num_cpus_at_core_level=$(cpuid -l 0x1f -s 1 | grep "number of logical processors" | sort -u | awk '{print $NF}')
  # Remove ( ) around decimal value
  num_cpus_at_core_level=${num_cpus_at_core_level#\(}
  num_cpus_at_core_level=${num_cpus_at_core_level%\)}
  test_print_trc "0x1f leaf's subleaf 1 num logical cpus at core level: $num_cpus_at_core_level"

  # Cluster(Module) level
  module_type=$(cpuid -l 0x1f -s 2 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 2 shows $module_type level type"
  bit_width_index_2=$(cpuid -l 0x1f -s 2 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 2 bit width line: $bit_width_index_2"
  num_cpus_at_module_level=$(cpuid -l 0x1f -s 2 | grep "number of logical processors" | sort -u | awk '{print $NF}')
  # Remove ( ) around decimal value
  num_cpus_at_module_level=${num_cpus_at_module_level#\(}
  num_cpus_at_module_level=${num_cpus_at_module_level%\)}
  test_print_trc "0x1f leaf's subleaf 2 num logical cpus at module level: $num_cpus_at_module_level"

  # Die level
  die_type=$(cpuid -l 0x1f -s 3 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 3 shows $die_type level type"
  bit_width_index_3=$(cpuid -l 0x1f -s 3 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 3 bit width line: $bit_width_index_3"
  num_cpus_at_die_level=$(cpuid -l 0x1f -s 3 | grep "number of logical processors" | sort -u | awk '{print $NF}')
  # Remove ( ) around decimal value
  num_cpus_at_die_level=${num_cpus_at_die_level#\(}
  num_cpus_at_die_level=${num_cpus_at_die_level%\)}
  test_print_trc "0x1f leaf's subleaf 3 num logical cpus at die level: $num_cpus_at_die_level"

  # Invalid level type after Die level
  invalid_type_sub4=$(cpuid -l 0x1f -s 4 | grep "level type" | sort -u | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "0x1f leaf's subleaf 4 shows $invalid_type_sub4 level type"
  bit_width_index_4=$(cpuid -l 0x1f -s 4 | grep width | sort -u | wc -l)
  test_print_trc "0x1f leaf's subleaf 4 bit width line: $bit_width_index_4"

  if [[ $thread_type == thread ]] && [[ $bit_width_index_0 -eq 1 ]] && [[ $num_cpus_at_thead_level -eq 1 ]]; then
    test_print_trc "CPUID: level type: thread is correctly detected, all threads bit width are aligned \
number of logical processors at thread level is correct: $num_cpus_at_thead_level"
  else
    die "CPUID: level type: thread is not correctly detected or bit width is not aligned or \
number of logical processors at thread level is incorrect."
  fi

  if [[ $core_type == core ]] && [[ $bit_width_index_1 -eq 1 ]] && [[ $num_cpus_at_core_level -eq 2 ]]; then
    test_print_trc "CPUID: level type: core is correctly detected, and all cores bit width are aligned \
number of logical processors at core level is correct: $num_cpus_at_core_level"
  else
    die "CPUID: level type: core is not correctly detected or bit width is not aligned or \
number of logical processors at core level is incorrect."
  fi

  if [[ $module_type == module ]] && [[ $bit_width_index_2 -eq 1 ]] && [[ $num_cpus_at_module_level -eq 48 ]]; then
    test_print_trc "CPUID: level type: cluster(module) is correctly detected, and all modules bit width are aligned \
number of logical processors at module level is correct: $num_cpus_at_module_level"
  else
    die "CPUID: level type: module is not correctly detected or bit width is not aligned or \
number of logical processors at module level is incorrect."
  fi

  if [[ $die_type == die ]] && [[ $bit_width_index_3 -eq 1 ]] && [[ $num_cpus_at_die_level -eq $cpus_on_dies ]]; then
    test_print_trc "CPUID: level type: die is correctly detected, and all dies bit width are aligned \
number of logical processors at die level is correct: $num_cpus_at_die_level"
  else
    die "CPUID: level type: die is not correctly detected or bit width is not aligned or \
number of logical processors at die level is incorrect."
  fi

  if [[ $invalid_type_sub4 == invalid ]] && [[ $bit_width_index_4 -eq 1 ]]; then
    test_print_trc "CPUID: level type: invalid is correctly detected, and all dies bit width are aligned"
  else
    die "CPUID: level type: invalid is not correctly detected or bit width is not aligned"
  fi
}

# Function to verify cache topo in qemu, 0x04H is Cache parameter leaf
# EAX Bits 25-14: Maximum number of addressable IDs for logical processors sharing this cache.
# EAX Bits 31-26: Maximum number of addressable IDs for processor cores in the physical
# The case will check both EAX bits 25-14 and bits 31-26 for each cache type
# There are 4 cache type: subleaf 0: data cache, cache level is 0x1 (L1 d cache)
# Subleaf 1: instruction cache, cache level is 0x1 (L1 i cache)
# Subleaf 2: unified cache, cache level is 0x2 (L2 cache)
# Subleaf 3: unified cahce, cache level is 0x3 (L3 Cache)
qemu_dmr_cache_topo() {
  # subleaf 0: L1 data cache, cache level is 0x1 (L1 d cache), which is per core
  l1_d_cache_type=$(cpuid -1 -l 0x4H -s 0 | grep "type" | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l1_d_cache_type"
  l1_d_cache_level=$(cpuid -1 -l 0x4h -s 0 | grep "cache level" | sed -n '1,1p' | awk -F "=" '{print $2}')
  l1_d_level_num=${l1_d_cache_level#*(}
  l1_d_level_num=${l1_d_level_num%*)}
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l1_d_level_num"
  if [[ $l1_d_cache_type == data ]] && [[ $l1_d_level_num -eq 1 ]]; then
    test_print_trc "L1 data cache type and level is detected correctly."
  else
    die "Did not correctly detect L1 data cache type or level "
  fi

  # Calculate maximum number of addressable IDs for logical processors sharing each cache
  # Based on configures setting: -smp cpus=192,sockets=1,dies=4,clusters=24,cores=2,threads=1
  # L1 data cache is per core, L1 instruction is per core
  # L2 unified cache is per cluster, L3 unified cache is per die
  # socket bit: 1, dies bit: 2, clusters bit: 5, cores bit: 1, threads bit: 0
  # (When thread is 1, which means the index is 0, so the bit is 0)
  # test_l1_i_max_id_cpus_per_core=1 << apic_core_offset) -1=(1<<0)-1=0
  # test_l1_d_max_id_cpus_per_core=1 << apic_core_offset) -1=(1<<0)-1=0
  # test_l2_max_id_cpus_per_cluster=1 << apic_core_offset) -1=(1<<0+1)-1=1
  # test_l3_max_id_cpus_per_die=1 << apic_core_offset) -1=(1<<0+1+5)-1=63

  # Test maximum IDs for CPUs sharing L1 data cache, which is per core
  max_l1_d_cpus_sharing_cached=$(cpuid -1 -l 0x4H -s 0 | grep "maximum IDs for CPUs" | awk '{print $NF}')
  max_l1_d_cpus_sharing_cached=${max_l1_d_cpus_sharing_cached#\(}
  max_l1_d_cpus_sharing_cached=${max_l1_d_cpus_sharing_cached%\)}
  test_print_trc "CPUID Leaf subleaf 0 maximum IDs for CPUs sharing data cache: $max_l1_d_cpus_sharing_cached"
  if [[ $max_l1_d_cpus_sharing_cached -eq 0 ]]; then
    test_print_trc "maximum IDs for CPUs sharing L1 data cache is expected value: 0"
  else
    die "maximum IDs for CPUs sharing L1 data cache is not expected value: 0"
  fi

  # Test in L1 data cache, maximum IDs for cores in pkg
  max_cores_l1_d=$(cpuid -1 -l 0x4H -s 0 | grep "maximum IDs for cores in pkg" | awk '{print $NF}')
  max_cores_l1_d=${max_cores_l1_d#\(}
  max_cores_l1_d=${max_cores_l1_d%\)}
  test_print_trc "CPUID Leaf subleaf 0 maximum IDs for CPUs sharing data cache: $max_cores_l1_d"
  # test_max_cores_in_package=1 << (socket_level_offset - core_level_offset)) - 1=1<<(0+1+5+2-0)-1=255
  # But there is max bits for maximum IDs for cores in pkg is 6 bits
  # So if 255 > 63, then maximum IDs for cores in pkg will show 63
  if [[ $max_cores_l1_d -eq 63 ]]; then
    test_print_trc "In L1 data cache, maximum IDs for cores in pkg expected: 63"
  else
    die "maximum IDs for CPUs sharing L1 data cache is not expected value: 63"
  fi

  # subleaf 1: L1 instruction cache, cache level is 0x1 (L1 i cache), which is per core
  l1_i_cache_type=$(cpuid -1 -l 0x4H -s 1 | grep "type" | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l1_i_cache_type"
  l1_i_cache_level=$(cpuid -1 -l 0x4h -s 1 | grep "cache level" | sed -n '1,1p' | awk -F "=" '{print $2}')
  l1_i_level_num=${l1_i_cache_level#*(}
  l1_i_level_num=${l1_i_level_num%*)}
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l1_i_level_num"
  if [[ $l1_i_cache_type == instruction ]] && [[ $l1_i_level_num -eq 1 ]]; then
    test_print_trc "L1 instruction cache type and level is detected correctly."
  else
    die "Did not correctly detect L1 instruction cache type or level "
  fi

  # Test maximum IDs for CPUs sharing L1 instruction cache, which is per core
  max_l1_i_cpus_sharing_cached=$(cpuid -1 -l 0x4H -s 1 | grep "maximum IDs for CPUs" | awk '{print $NF}')
  max_l1_i_cpus_sharing_cached=${max_l1_i_cpus_sharing_cached#\(}
  max_l1_i_cpus_sharing_cached=${max_l1_i_cpus_sharing_cached%\)}
  test_print_trc "CPUID Leaf subleaf 1 maximum IDs for CPUs sharing instruction cache: $max_l1_i_cpus_sharing_cached"
  if [[ $max_l1_i_cpus_sharing_cached -eq 0 ]]; then
    test_print_trc "maximum IDs for CPUs sharing L1 instruction cache is expected value: 0"
  else
    die "maximum IDs for CPUs sharing L1 instruction cache is not expected value: 0"
  fi

  # Test in L1 instruction cache, maximum IDs for cores in pkg
  max_cores_l1_i=$(cpuid -1 -l 0x4H -s 1 | grep "maximum IDs for cores in pkg" | awk '{print $NF}')
  max_cores_l1_i=${max_cores_l1_i#\(}
  max_cores_l1_i=${max_cores_l1_i%\)}
  test_print_trc "CPUID Leaf subleaf 1 maximum IDs for CPUs sharing instruction cache: $max_cores_l1_i"
  if [[ $max_cores_l1_i -eq 63 ]]; then
    test_print_trc "In L1 instruction cache, maximum IDs for cores in pkg expected: 63"
  else
    die "maximum IDs for CPUs sharing L1 instruction cache is not expected value: 63"
  fi

  # Subleaf 2: unified cache, cache level is 0x2 (L2 cache), which is per cluster
  l2_cache_type=$(cpuid -1 -l 0x4H -s 2 | grep "type" | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l2_cache_type"
  l2_cache_level=$(cpuid -1 -l 0x4h -s 2 | grep "cache level" | sed -n '1,1p' | awk -F "=" '{print $2}')
  l2_level_num=${l2_cache_level#*(}
  l2_level_num=${l2_level_num%*)}
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l2_level_num"
  if [[ $l2_cache_type == unified ]] && [[ $l2_level_num -eq 2 ]]; then
    test_print_trc "L2 cache type and level is detected correctly."
  else
    die "Did not correctly detect L2 cache unified type or level "
  fi

  # Test maximum IDs for CPUs sharing L2 unified cache, which is per cluster
  max_l2_cpus_sharing_cached=$(cpuid -1 -l 0x4H -s 2 | grep "maximum IDs for CPUs" | awk '{print $NF}')
  max_l2_cpus_sharing_cached=${max_l2_cpus_sharing_cached#\(}
  max_l2_cpus_sharing_cached=${max_l2_cpus_sharing_cached%\)}
  test_print_trc "CPUID Leaf subleaf 2 maximum IDs for CPUs sharing cache: $max_l2_cpus_sharing_cached"
  # test_l2_max_id_cpus_per_cluster=1 << apic_core_offset) -1=(1<<0+1)-1=1
  if [[ $max_l2_cpus_sharing_cached -eq 1 ]]; then
    test_print_trc "maximum IDs for CPUs sharing L2 cache is expected value: 1"
  else
    die "maximum IDs for CPUs sharing L2 cache is not expected value: 1"
  fi

  # Test in L2 cache, maximum IDs for cores in pkg
  max_cores_l2=$(cpuid -1 -l 0x4H -s 2 | grep "maximum IDs for cores in pkg" | awk '{print $NF}')
  max_cores_l2=${max_cores_l2#\(}
  max_cores_l2=${max_cores_l2%\)}
  test_print_trc "CPUID Leaf subleaf 2 maximum IDs for CPUs sharing instruction cache: $max_cores_l2"
  if [[ $max_cores_l2 -eq 63 ]]; then
    test_print_trc "In L2 cache, maximum IDs for cores in pkg expected: 63"
  else
    die "maximum IDs for CPUs sharing L2 cache is not expected value: 63"
  fi

  # Subleaf 3: unified cache, cache level is 0x3 (L3 Cache)
  l3_cache_type=$(cpuid -1 -l 0x4H -s 3 | grep "type" | awk -F "=" '{print $2}' | awk '{print $1}')
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l3_cache_type"
  l3_cache_level=$(cpuid -1 -l 0x4h -s 3 | grep "cache level" | sed -n '1,1p' | awk -F "=" '{print $2}')
  l3_level_num=${l3_cache_level#*(}
  l3_level_num=${l3_level_num%*)}
  test_print_trc "Leaf 0x04H subleaf 0 cache type: $l3_level_num"
  if [[ $l3_cache_type == unified ]] && [[ $l3_level_num -eq 3 ]]; then
    test_print_trc "L3 cache type and level is detected correctly."
  else
    die "Did not correctly detect L3 cache unified type or level"
  fi

  # Test maximum IDs for CPUs sharing L3 unified cache, which is per die
  max_l3_cpus_sharing_cached=$(cpuid -1 -l 0x4H -s 3 | grep "maximum IDs for CPUs" | awk '{print $NF}')
  max_l3_cpus_sharing_cached=${max_l3_cpus_sharing_cached#\(}
  max_l3_cpus_sharing_cached=${max_l3_cpus_sharing_cached%\)}
  test_print_trc "CPUID Leaf subleaf 3 maximum IDs for CPUs sharing cache: $max_l3_cpus_sharing_cached"
  # test_l3_max_id_cpus_per_die=1 << apic_core_offset) -1=(1<<0+1+5)-1=63
  if [[ $max_l3_cpus_sharing_cached -eq 63 ]]; then
    test_print_trc "maximum IDs for CPUs sharing L3 cache is expected value: 63"
  else
    die "maximum IDs for CPUs sharing L3 cache is not expected value: 63"
  fi

  # Test in L3 cache, maximum IDs for cores in pkg
  max_cores_l3=$(cpuid -1 -l 0x4H -s 3 | grep "maximum IDs for cores in pkg" | awk '{print $NF}')
  max_cores_l3=${max_cores_l3#\(}
  max_cores_l3=${max_cores_l3%\)}
  test_print_trc "CPUID Leaf subleaf 3 maximum IDs for CPUs sharing instruction cache: $max_cores_l3"
  if [[ $max_cores_l3 -eq 63 ]]; then
    test_print_trc "In L3 cache, maximum IDs for cores in pkg expected: 63"
  else
    die "maximum IDs for CPUs sharing L3 cache is not expected value: 63"
  fi
}

cpu_topology_test() {
  case $TEST_SCENARIO in
  numa_nodes_compare)
    numa_nodes_compare_with_package
    ;;
  verify_thread_per_core)
    thread_per_core
    ;;
  verify_cores_per_socket)
    core_per_socket
    ;;
  verify_socket_num)
    socket_num
    ;;
  verify_cbb_dual_core_module)
    dual_core_module
    ;;
  verify_level_type)
    level_type
    ;;
  verify_cbb_topo_level_type)
    cbb_topo_level_type
    ;;
  verify_cbb_topo_sched_domain)
    cbb_topo_sched_domain
    ;;
  verify_server_ecore_only_sched_domain)
    server_ecore_only_sched_domain
    ;;
  verify_server_pcore_server_sched_domain)
    sever_pcore_smt_sched_domain
    ;;
  verify_client_hybrid_no_lp_sched_domain)
    client_hybrid_no_lp_sched_domain
    ;;
  verify_client_ecore_no_llc_sched_domain)
    client_ecore_no_l3_cache_sched_domain
    ;;
  verify_qemu_dmr_one_socket_cpuid)
    qemu_dmr_cpuid_check 192
    ;;
  verify_qemu_dmr_two_sockets_cpuid)
    qemu_dmr_cpuid_check 96
    ;;
  verify_qemu_dmr_cache_topo_cpuid)
    qemu_dmr_cache_topo
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

cpu_topology_test
