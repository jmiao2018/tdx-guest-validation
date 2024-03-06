#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2011, Linaro Limited.
# Copyright (C) 2013 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2015, Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Contributors:
#     Daniel Lezcano <daniel.lezcano@linaro.org> (IBM Corporation)
#       - initial API and implementation
#     Carlos Hernandez <ceh@ti.com>
#       - Add new functions
#     Alejandro Hernandez <ajhernandez@ti.com>
#       - Add new functions
#     Luis Rivas <luis.miguel.rivas.zepeda@intel.com>
#       - Fixed suspend function to support multiple calls
#       - Added logic to detect failures on functions set_online and set_offline
#       - Changed bc command for awk
#       - Changed for_each functions to verify the results of each execution
#       - Added func is_cpu0_hotplug_allowed to detect if cpu0 supports hotplug
#

source "common.sh"     # include ltp-ddt common functions

CPU_PATH="/sys/devices/system/cpu"
RTC0_PATH="/sys/class/rtc/rtc0"
ALARM="wakealarm"
TEST_NAME=$(basename "${0%.sh}")
PREFIX=$TEST_NAME
INC=0
CPU=
pass_count=0
fail_count=0

test_status_show() {
  test_print_trc "-------- total = $((pass_count + fail_count))"
  test_print_trc "-------- pass = $pass_count"
  # report failure only if it is there
  if [[ $fail_count -ne 0 ]] ; then
    test_print_trc "-------- fail = $fail_count"
    exit 1
  fi
}

if [[ -f /sys/power/wake_lock ]]; then
  use_wakelock=1
else
  use_wakelock=0
fi

log_begin() {
  printf "%-76s" "$TEST_NAME.$INC$CPU: $*... "
  ((INC++))
}

log_end() {
  printf "$*\n"
}

log_skip() {
  log_begin "$@"
  log_end "skip"
}

check() {
  local descr=$1
  local func=$2
  shift 2;

  log_begin "checking $descr"

  $func "$@" || {
    log_end "fail"
    ((fail_count++))
    return 1
  }

  log_end "pass"
  ((pass_count++))

  return 0
}

check_file() {
  local file=$1
  local dir=$2
  check "$file exists on $dir" "test -f" "$dir/$file"
}


for_each_cpu() {
  local func=$1
  shift 1

  local cpus
  cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")

  for cpu in $cpus; do
    INC=0
    CPU=/$cpu
    $func "$cpu" "$@" || return 1
  done
  return 0
}

get_num_cpus() {
  local cpus
  cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")
  echo ${#cpus[@]}
}

for_each_governor() {
  local cpu=$1
  local func=$2
  shift 2

  local dirpath="$CPU_PATH/$cpu/cpufreq"
  local governors
  governors=$(cat "$dirpath/scaling_available_governors")

  if [[ -z "$governors" ]]; then
    return 1
  fi

  for governor in $governors; do
    $func "$cpu" "$governor" "$@" || return 1
  done
  return 0
}

for_each_frequency() {
  local cpu=$1
  local func=$2
  shift 2

  local dirpath="$CPU_PATH/$cpu/cpufreq"
  local frequencies
  frequencies=$(cat "$dirpath/scaling_available_frequencies")

  for frequency in $frequencies; do
    $func "$cpu" "$frequency" "$@" || return 1
  done

  return 0
}

set_governor() {
  local cpu=$1
  local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_governor
  local newgov=$2

  echo "$newgov" > "$dirpath"
}

get_governor() {
  local cpu=$1
  local dirpath=$CPU_PATH/$cpu/cpufreq/scaling_governor

  cat "$dirpath"
}

wait_latency() {
  local cpu=$1
  local dirpath=$CPU_PATH/$cpu/cpufreq
  local latency=
  local nrfreq=

  latency=$(cat "$dirpath/cpuinfo_transition_latency") || return 1

  nrfreq=$(wc -w < "$dirpath/scaling_available_frequencies") || return 1

  ((nrfreq++))
  nanosleep $(( nrfreq * latency ))
}

frequnit() {
  local freq=$1
  shift 1

  local ghz
  local mhz
  ghz=$(echo "$freq 1000000" |awk '{printf "%.1f", $1/$2}')
  mhz=$(echo "$freq 1000" |awk '{printf "%.1f", $1/$2}')

  res=$(echo "$ghz 1.0" | awk '{print ($1 > $2)}')
  if [[ "$res" = "1" ]]; then
    echo "$ghz GHz"
    return 0
  fi

  res=$(echo "$mhz 1.0" | awk '{print ($1 > $2)}')
  if [[ "$res" = "1" ]];then
    echo "$mhz MHz"
    return 0
  fi

  echo "$freq KHz"
}

set_frequency() {
  local cpu=$1
  local dirpath=$CPU_PATH/$cpu/cpufreq
  local newfreq=$2
  local setfreqpath=$dirpath/scaling_setspeed

  echo "$newfreq" > "$setfreqpath"
  wait_latency "$cpu"
}

get_frequency() {
  local cpu=$1
  local dirpath="$CPU_PATH/$cpu/cpufreq/scaling_cur_freq"
  cat "$dirpath"
}

get_max_frequency() {
  local cpu=$1
  local dirpath="$CPU_PATH/$cpu/cpufreq/scaling_max_freq"
  cat "$dirpath"
}

get_min_frequency() {
  local cpu=$1
  local dirpath="$CPU_PATH/$cpu/cpufreq/scaling_min_freq"
  cat "$dirpath"
}

set_online() {
  local cpu=$1
  shift 1

  local curstate=0
  local dirpath="$CPU_PATH/$cpu"

  echo 1 > "$dirpath/online"
  curstate=$(get_online "$cpu")
  if [[ $curstate -eq 1 ]]; then
    report "$cpu online"
    return 0
  else
    test_print_trc "Cannot set $cpu to online"
    return 1
  fi
}

set_offline() {
  local cpu=$1
  shift 1

  local dirpath=$CPU_PATH/$cpu
  local curstate=0

  echo 0 > "$dirpath/online"
  curstate=$(get_online "$cpu")
  if [[ $curstate -eq 0 ]]; then
    report "$cpu offline"
    return 0
  else
    test_print_trc "Cannot set $cpu to offline"
    return 1
  fi
}

get_online() {
  local cpu=$1
  local dirpath="$CPU_PATH/$cpu"
  cat "$dirpath/online"
}

# Online/offline CPU1 or higher - mess with governor
cpu_online_random() {
  local num_cpu
  num_cpu=$(get_num_cpus)
  local random_cpu
  random_cpu=cpu$(random_ne0 "$num_cpu")
  local k
  k=$(random 1)
  if [[ -f $CPU_PATH/$random_cpu/online && $k -eq 1 ]]; then
    set_online "$random_cpu"
  fi
}

# IF WE HAVE A BUG CREATION LOGIC, TRIGGER IT
bug_random() {
  if [[ -f $DEBUGFS_LOCATION/pm_debug/bug ]]; then
    k=$(random 1)
    echo -n "$k"> "$DEBUGFS_LOCATION/pm_debug/bug"
    report "BUG : $k"
  fi
}

# Do off or not
offmode_random() {
  k=$(random 1)
  echo -n "$k"> "$DEBUGFS_LOCATION/pm_debug/enable_off_mode"
  report "enable_off_mode : $k"
}

# automated waker.. dont want hitting keyboards..
wakeup_time_random() {
  # add this variable to have bigger wakeup time
  max_wtime=$1
  if [[ -z $max_wtime ]]; then
    max_wtime=10
  fi
  k=$(random_ne0 $max_wtime)
  sec=$(( k % 1000 ))
  msec=$(( k / 1000 ))
  if [[ -e $DEBUGFS_LOCATION/pm_debug/wakeup_timer_seconds ]]; then
    echo $sec > "$DEBUGFS_LOCATION/pm_debug/wakeup_timer_seconds"
    echo $msec > "$DEBUGFS_LOCATION/pm_debug/wakeup_timer_milliseconds"
  fi
  report "wakeup - $sec sec $msec msec"
}

# give me some idle time
idle_random() {
  time=$(random_ne0 10)
  report "smallidle: $time seconds"
  sleep "$time"
}

# give me some idle time
idlebig_random() {
  time=$(random_ne0 300)
  report "bigidle: $time seconds"
  report "Processes running:"
  ps
  report "cpu1 status:"
  cat /sys/devices/system/cpu/cpu1/online
  sleep "$time"
}

# dont suspend
no_suspend() {
  if [[ $use_wakelock -ne 0 ]]; then
    echo "$PSID" >/sys/power/wake_lock
    report "wakelock $PSID"
  fi
}

# suspend / standby me
# input
#   -p power_state  optional; power state like 'mem' or 'standby'; default to 'mem'
#   -t max_stime    optional; maximum suspend or standby time; default to 10s; the suspend time will be a random number
#   -i iterations   optional; iterations to suspend/resume; default to 1
#   -u usb_remove   optional; usb_state to indicate if usb module needs to be removed prior to suspend; default to '0'
#                              0 indicates 'dont care'; 1 indicates 'remove usb module'; 2 indicates 'do not remove usb module'
#   -m usb_module   optional; usb_module to indicate the name of usb module to be removed; default to ''
suspend() {
  local OPTIND
  local arg=""
  local power_state=""
  local max_stime=""
  local iterations=""
  local usb_remove=""
  local usb_module=""
  local dmesg_time=0

  while getopts :p:t:i:u:m: arg; do
    case $arg in
      p)  power_state="$OPTARG";;
      t)  max_stime="$OPTARG";;
      i)  iterations="$OPTARG";;
      u)  usb_remove="$OPTARG";;
      m)  usb_module="$OPTARG";;
      \?)  test_print_trc "Invalid Option -$OPTARG ignored." >&2
           exit 1
           ;;
    esac
  done

  # for backward compatible
  : ${power_state:='mem'}
  : ${max_stime:='10'}
  : ${iterations:='1'}
  # for am335x-based soc force the usb_remove flag to be set i
  # if not explicitly mentioned in test case and take care of
  # module name also
  case $MACHINE in
    am335x-evm|am335x-sk|beaglebone|beaglebone-black)
      : ${usb_remove:='1'}
      modname=$(get_modular_name.sh usb)
      : ${usb_module:=$modname}
      ;;
    *)
      : ${usb_remove:='0'}
      : ${usb_module:=''}
      ;;
  esac

  test_print_trc "suspend function: power_state: $power_state"
  test_print_trc "suspend function: max_stime: $max_stime"
  test_print_trc "suspend function: iterations: $iterations"
  test_print_trc "suspend function: usb_remove: $usb_remove"
  test_print_trc "suspend function: usb_module: $usb_module"

  if [[ $use_wakelock -ne 0 ]]; then
    report "removing wakelock $PSID (sec=$sec msec=$msec off=$off bug=$bug)"
    echo "$PSID" > /sys/power/wake_unlock 2> /dev/null
  fi

  local i=0
  while [[ $i -lt $iterations ]]; do
    test_print_trc "===suspend iteration $(( i + 1 ))==="
    wakeup_time_random "$max_stime"
    local suspend_time=$sec
    if [[ $usb_remove = 1 ]]; then
      if [[ "$usb_module" = '' ]]; then
        die "No usb_module in command line although usb module remove flag has been selected"
      fi
      modprobe -r "$usb_module"
    elif [[ $usb_remove = 2 ]]; then
      inverted_return='true'
    fi

    # Get last dmesg time before entering suspend state
    dmesg_time=$(dmesg | tail -1 | grep -oE '\[.*[0-9]+\.[0-9]+.*\]' | tr -d []' ')
    test_print_trc "Last dmesg time: $dmesg_time"

    local suspend_failures
    suspend_failures=$(get_value_for_key f fail : /sys/kernel/debug/suspend_stats) \
      || die "key 'fail' not found!"

    if [[ -e $RTC0_PATH/$ALARM ]]; then
      report "Use wakeup_timer"
      echo 0 > $RTC0_PATH/$ALARM    # clear alarm
      echo $(( $(cat $RTC0_PATH/since_epoch) + "${suspend_time}" )) > $RTC0_PATH/$ALARM # set alarm
      if (echo "${power_state}" > /sys/power/state) 2>&1 | grep -q "Device or resource busy"; then
        test_print_trc "/sys/power/state shows EBUSY, waiting 30 seconds to try again"
        sleep 30
        echo 0 > $RTC0_PATH/$ALARM    # clear alarm
        echo $(( $(cat $RTC0_PATH/since_epoch) + "${suspend_time}" )) > $RTC0_PATH/$ALARM # set alarm
        echo "${power_state}" > /sys/power/state # set power state
      fi
    elif [[ -e /dev/rtc0 ]]; then
      report "Use rtc to suspend resume"
      # sending twice in case a late interrupt aborted the suspend path.
      # since this is not common, it is expected that 2 tries should be enough
      do_cmd "rtcwake -d /dev/rtc0 -m ${power_state} -s ${suspend_time}" \
        || do_cmd "rtcwake -d /dev/rtc0 -m ${power_state} -s ${suspend_time}"
    else
      # Stop the test if there is no rtcwake or wakeup alarm support
      die "There is no automated way (wakeup_timer or /dev/rtc0) to wakeup the board. No suspend!"
    fi

    if [[ $usb_remove = 2 ]]; then
      check_suspend_fail
    else
      check_suspend "$dmesg_time"
      check_resume "$dmesg_time"
      check_suspend_stats "$suspend_failures"
      check_suspend_errors "$dmesg_time"
      if [[ $usb_remove = 1 ]]; then
        echo "USB_REMOVE flag is $usb_remove"
        modprobe "$usb_module"
      fi
    fi

    ((i++))
  done

  no_suspend
}

# check if suspend/standby is ok by checking the kernel messages
check_suspend() {
  local last_time=$1
  shift 1

  local expect="PM: suspend of devices complete"
  if dmesg | sed "1,/$last_time/d" | grep -i "$expect"; then
    report "suspend successfully"
  else
    die "suspend failed"
  fi
}

# check if suspend/standby failed as expected by checking the kernel messages
check_suspend_fail() {
  local last_time=$1
  shift 1

  local expect="PM: Some devices failed to suspend"
  if dmesg | sed "1,/$last_time/d" | grep -i "$expect"; then
    report "suspend failed as expected"
  else
    die "suspend did not fail as expected"
  fi
}

# check if resume is ok by checking the kernel messages
check_resume() {
  local last_time=$1
  shift 1

  local expect="PM: resume of devices complete"
  if dmesg | sed "1,/$last_time/d" | grep -i "$expect"; then
    report "resume successfully"
  else
    die "resume failed"
  fi
}

check_suspend_errors() {
  local last_time=$1
  shift 1

  local expect="Could not enter target state in pm_suspend|_wait_target_disable failed"
  dmesg | sed "1,/$last_time/d" | egrep -i "$expect" && die "$expect errors observed"
}

# $1: previous failures
check_suspend_stats() {
  local failures
  failures=$(get_value_for_key f fail : /sys/kernel/debug/suspend_stats)
  [[ $failures -eq $1 ]] || die "/sys/kernel/debug/suspend_stats reports failures"
}

check_cpufreq_files() {
  local dirpath=$CPU_PATH/$1/cpufreq
  shift 1

  for i in "$@"; do
    check_file "$i" "$dirpath" || return 1
  done
  return 0
}

check_sched_mc_files() {
  local dirpath=$CPU_PATH

  for i in "$@"; do
    check_file "$i" "$dirpath" || return 1
  done
  return 0
}

check_topology_files() {
  local dirpath=$CPU_PATH/$1/topology
  shift 1

  for i in "$@"; do
    check_file "$i" "$dirpath" || return 1
  done
  return 0
}

check_cpuhotplug_files() {
  local cpu=$1
  shift 1

  local dirpath=$CPU_PATH/$cpu

  for i in "$@"; do
    # If cpu0 does not support hotplug, the "online" attribute does not
    # exists on Sysfs. So, first we must verify if cpu0 supports hotplug
    if [[ "$cpu" = "cpu0" ]] && [[ "$i" == "online" ]]; then
      is_cpu0_hotplug_allowed || {
        test_print_trc "CPU0 hotplug not allowed, skipping online sysfs"
        continue
      }
    fi
    check_file "$i" "$dirpath" || return 1
  done
  return 0
}

save_governors() {
  local index=0
  local gov=""

  governors_backup=
  for i in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
    gov=$(cat "$CPU_PATH/$i/cpufreq/scaling_governor")
    if [[ -z $gov ]]; then
      return 1
    fi
    governors_backup[$index]=$gov
    ((index++))
  done
  return 0
}

restore_governors() {
  local index=0
  local oldgov=

  for i in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
    oldgov=${governors_backup[$index]}
    echo "$oldgov" > "$CPU_PATH/$i/cpufreq/scaling_governor" || return 1
    ((index++))
  done
  return 0
}

save_frequencies() {
  local index=0
  local cpus
  cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")
  local freq=""

  frequencies_backup=
  for cpu in $cpus; do
    freq=$(cat "$CPU_PATH/$cpu/cpufreq/scaling_cur_freq")
    if [[ -z $freq ]]; then
      return 1
    fi
    frequencies_backup[$index]=$freq
    ((index++))
  done
  return 0
}

restore_frequencies() {
  local index=0
  local oldfreq=
  local cpus
  cpus=$(ls $CPU_PATH | grep "cpu[0-9].*")

  for cpu in $cpus; do
    oldfreq=${frequencies_backup[$index]}
    echo "$oldfreq" > "$CPU_PATH/$cpu/cpufreq/scaling_setspeed" || return 1
    ((index++))
  done
  return 0
}

# give me detailed report
report_stats() {
  local num_cpus
  num_cpus=$(get_num_cpus)
  report "============================================="
  report " $*"
  report "STATS: "
  report "$DEBUGFS_LOCATION/pm_debug/count"
  cat "$DEBUGFS_LOCATION/pm_debug/count"
  report "$DEBUGFS_LOCATION/pm_debug/time"
  cat "$DEBUGFS_LOCATION/pm_debug/time"
  report "$DEBUGFS_LOCATION/wakeup_sources"
  cat "$DEBUGFS_LOCATION/wakeup_sources"
  report "Core domain stats:"
  grep "^core_pwrdm" "$DEBUGFS_LOCATION/pm_debug/count"
  if [[ -f $DEBUGFS_LOCATION/suspend_time ]]; then
    report "Suspend times:"
    cat "$DEBUGFS_LOCATION/suspend_time"
  fi
  report "CPUFREQ STATS: "
  report "/sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state"
  cat /sys/devices/system/cpu/cpu0/cpufreq/stats/time_in_state
  report "/sys/devices/system/cpu/cpu0/cpufreq/stats/total_trans"
  cat /sys/devices/system/cpu/cpu0/cpufreq/stats/total_trans
  report "/sys/devices/system/cpu/cpu0/cpufreq/stats/trans_table"
  cat /sys/devices/system/cpu/cpu0/cpufreq/stats/trans_table
  report "CPUIDLE STATS: "

  for cpu in $(seq 0 $(( num_cpus - 1 )) ); do
    cpuidledir=/sys/devices/system/cpu/cpu$cpu/cpuidle
    if [[ -d "$cpuidledir" ]]; then
      report "CPU$cpu IDLE STATS: "
      k=$(pwd)
      cd "$cpuidledir" || return 1
      report "NAME | DESCRIPTION | USAGE (number of entry)  | TIME | POWER | LATENCY"
      for state in *; do
        DESC=$(cat "$state/desc")
        NAME=$(cat "$state/name")
        POWER=$(cat "$state/power")
        TIME=$(cat "$state/time")
        USAGE=$(cat "$state/usage")
        LATENCY=$(cat" $state/usage")
        report "$NAME | $DESC | $USAGE | $TIME | $POWER | $LATENCY"
      done
      cd "$k" || return 1
    fi
  done
  report "============================================="
}

# write pm counters into log file. The log will have something like "RET:0 \n RET-LOGIC-OFF:6"
# $1: power domain
# $2: power states seperated by delimiter Ex, "OFF:RET:INA","RET:RET-LOGIC-OFF" etc showing in pm count stat
# $3: power states delimiter
# $4: log name to save the counter
log_pm_count() {
  pwrdm=$1
  pwr_states=$2
  states_delimiter=$3
  log_name=$4
  pwr_state_place=0

  tmp_ifs="$IFS"
  IFS=$states_delimiter
  for pwr_state in $pwr_states; do
    if [[ "$pwr_state" = "DEVICE-OFF" ]]; then
      pwr_state_place=1
    elif [[ "$pwr_state" = "OFF" ]]; then
      pwr_state_place=2
    elif [[ "$pwr_state" = "RET" ]]; then
      pwr_state_place=3
    elif [[ "$pwr_state" = "INA" ]]; then
      pwr_state_place=4
    elif [[ "$pwr_state" = "ON" ]]; then
      pwr_state_place=5
    elif [[ "$pwr_state" = "RET-LOGIC-OFF" ]]; then
      pwr_state_place=6
    elif [[ "$pwr_state" = "RET-MEMBANK1-OFF" ]]; then
      pwr_state_place=7
    elif [[ "$pwr_state" = "RET-MEMBANK2-OFF" ]]; then
      pwr_state_place=8
    else
      die "Unknown power status name: $pwr_state"
    fi

    pwrdm_stat=$(grep "^$pwrdm" "$DEBUGFS_LOCATION/pm_debug/count" \
                | cut -d "," -f $pwr_state_place)
    report "Power domain stats requested: ${pwrdm}: $pwrdm_stat==========="
    echo "$pwrdm_stat" >> "${TMPDIR}/$log_name"
  done
  IFS="$tmp_ifs"
}

# Compare two counters from two logs for pwrdm and pwr-state
#  The log contains something like "RET:0 \n RET-LOGIC-OFF:6 \n"
#  $1: pwrdm
#  $2: power states
#  $3: power states delimiter;
#  $4: log name before
#  $5: log name after
compare_pm_count() {
  pwrdm=$1
  pwr_state=$2
  state_delimiter=$3
  log_name_before=$4
  log_name_after=$5

  log_before=${TMPDIR}/"$log_name_before"
  log_after=${TMPDIR}/"$log_name_after"

  num_lines_1=$(wc -l < "$log_before")
  num_lines_2=$(wc -l < "$log_after")
  if [[ $num_lines_1 -ne $num_lines_2 ]]; then
    die "There is differnt number of pairs between log file $log_name_before and log file $log_name_after; can not compare these two logs"
  fi

  tmp_ifs="$IFS"
  IFS=$state_delimiter
  for pwr_state in $pwr_states; do
    val_before=$(get_value_for_key f "$pwr_state" ":" "$log_before") || \
      die "Error getting value from $log_before for ${pwr_state}: $val_before"
    val_after=$(get_value_for_key f "$pwr_state" ":" "$log_after") || \
      die "Error getting value from $log_after for ${pwr_state}: $val_after"

    report "$pwrdm: Initial Value -> $pwr_state: $val_before"
    report "$pwrdm: Final Value -> $pwr_state: $val_after"

    # Verify the power domain counter increases
    report "Verifying $pwrdm: $pwr_state counter increases ..."
    sleep 1

    if [[ "$val_after" -gt "$val_before" ]]; then
      report "SUCCESS: $pwrdm: $pwr_state counters increased"
    else
      die "ERROR: $pwrdm: $pwr_state counters did not increase. Please review power states counters"
    fi

  done
  IFS="$tmp_ifs"

}

sigtrap() {
    exit 255
}

# Execute on exit - cleanup actions
on_exit() {
    echo "Cleaning actions"
}

trap on_exit EXIT

#Function to validate a condition, takes the
# following parameters
#    $1: Condition to assert, i.e [[ 1 -ne 2 ]]
#If the conditions is not true the function exits the program and prints
#the backtrace
assert() {
  eval "${@}" || {
    echo "Assertion $* failed"
    i=0
    while caller $i; do
      ((i++))
    done
    exit 2
  }
}

#Funtion to parse text into sections.
#Inputs:
#  $1: pattern to match for a start of section
#  $2: text to parse
#  $3: separator to use for the elements returned in $4
#  $4: variable to assign the result list that will contain
#Output:
#A list named $4 whose element are text that match
#<text that matched $1><$3><section text>
get_sections() {
  assert [[ ${#} -eq 4 ]]
  local key_val_indexer=$3
  local current_section
  local old_IFS=$IFS
  local sections_dict
  IFS=$'\n'
  i=0
  for line in $2; do
    if [[ "$line" =~ $1 ]]; then
      if [[ -n "$current_section" ]]; then
        eval "$4[$i]=\"$current_section\""
        ((i++))
      fi
      current_section="${BASH_REMATCH[0]}${key_val_indexer}"
      if [[ ${#BASH_REMATCH[@]} -gt 1 ]]; then
        current_section="${BASH_REMATCH[1]}${key_val_indexer}"
      fi
    elif [[ -n "$current_section" ]]; then
      current_section="${current_section}${line}"'\n'
    fi
  done
  if [[ -n "$current_section" ]]; then
    eval "$4[$i]=\"$current_section\""
  fi
  IFS=$old_IFS
}

#Function to obtain the value referenced by a key from a
#sections list returned by get_sections.
#Inputs:
#  $1: key whose value will be returned
#  $2: the list to search in, i.e sections_dict[@]
#  $3: the separator used when creating the elements in
#      list $2
#Output:
#The text associated with the key if any
get_section_val() {
  assert [[ ${#} -eq 3 ]]
  local key="$1"
  local dict=("${!2}")
  local current_tuple
  local old_IFS=$IFS
  for idx in $(seq 0 $((${#dict[@]}-1))); do
    IFS=$3
    current_tuple=( ${dict[$idx]} )
    if [[ "$key" == "${current_tuple[0]}" ]]; then
      echo -e "${current_tuple[@]:1}"
      break
    fi
  done
  IFS=$old_IFS
}

#Function to obtain a list of keys from a
#sections_dict like list returned by get_sections.
#Inputs:
#  $1: the list to search in, i.e sections_dict[@]
#  $2: the separator used when creating the elements in
#      list $1
#  $3: name of the result list
#  $4: (optional) pattern to match in keys, when this
#      parameters is set only the keys that match $4 are
#      included in $3. If $4 has a grouping construct
#      then only the captured group is included in $3
#Output:
#a list named $3 with all the keys found in $1
get_sections_keys() {
  assert [[ ${#} -eq 3 -o ${#} -eq 4 ]]
  local dict=("${!1}")
  local current_tuple
  local old_IFS=$IFS
  local filter_idx=0
  for idx in $(seq 0 $((${#dict[@]}-1))); do
    IFS=$2
    current_tuple=( ${dict[$idx]} )
    if [[ ${#} -eq 4 ]]; then
      if [[ "${current_tuple[0]}" =~ $4 ]]; then
        if [[ ${#BASH_REMATCH[@]} -gt 1 ]]; then
          eval "$3[$filter_idx]=\"${BASH_REMATCH[1]}\""
        else
          eval "$3[$filter_idx]=\"${BASH_REMATCH[0]}\""
        fi
      fi
      ((filter_idx++))
    else
      eval "$3[$idx]=\"${current_tuple[0]}\""
    fi
  done
  IFS=$old_IFS
}

is_cpu0_hotplug_allowed() {
  local path=$CPU_PATH/cpu0/online
  if [[ -f $path ]]; then
    return 0
  else
    return 1
  fi
}
