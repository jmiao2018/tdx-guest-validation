#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only

# Description:  Test script for Intel Low Power Mode Daemon feature,
# Which is supported on Meteolor lake
# The test cases will cover different configuration xml settings
# with different intel_lpmd tool's options

# Authors:      rui.zhang@intel.com,wendy.wang@intel.com
# History:      July 20 2023 - Created - Wendy Wang

source "common.sh"
source "dmesg_functions.sh"

LPMD_PATH="/root/intel_lpmd"
#save one default configuration xml file
[ -e "$LPMD_PATH"/data/intel_lpmd_config_default.xml ] ||
  do_cmd "cp $LPMD_PATH/data/intel_lpmd_config.xml $LPMD_PATH/data/intel_lpmd_config_default.xml"
[ ! -d "$LPMD_PATH"/logs ] && do_cmd "mkdir -p $LPMD_PATH/logs"

: "${CASE_NAME:=""}"

usage() {
  cat <<__EOF
  usage: ./${0##*/} [-t TESTCASE_ID] [-H]
  -t  TEST CASE ID
  -H  show this
__EOF
}

# Need to re_make after xml configuration setting change
re_make() {
  # clean the previous make
  cd $LPMD_PATH && make distclean
  sleep 5
  # Need to re-do make after configuration xml file change
  $LPMD_PATH/autogen.sh && make && make install
  sleep 5
}

# Function to entry or exit low power mode
test_one() {
  local sleep_time=$1

  sleep "$sleep_time"
  # Force enter LPM
  test_print_trc "Force enter LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 2"
  sleep "$sleep_time"

  # Force exit LPM
  test_print_trc "Force exit LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 3"
  sleep "$sleep_time"

  # Auto LPM
  test_print_trc "Auto LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 4"
  sleep "$sleep_time"

  # Enter SUV
  test_print_trc "Enter SUV:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 5"
  sleep "$sleep_time"

  # Exit SUV
  test_print_trc "Exit SUV:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 6"
  sleep "$sleep_time"

  # Terminate intel_lpmd
  test_print_trc "Terminate LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 1"
  sleep "$sleep_time"
}

# Seperate the function to change CPUs fixed in xml configuration
change_cpus_fixed_xml() {
  local key=$1
  local value=$2
  local fmode="<lp_mode_cpus>"
  local bmode="</lp_mode_cpus>"

  tar_val="${fmode}${value}${bmode}"
  test_print_trc "Setting: Target key and value: $tar_val"
  do_cmd "sed -i 's|$key|$tar_val|g' $LPMD_PATH/data/intel_lpmd_config.xml"
}

# Change configuration xml setting
update_xml() {
  local key=$1
  local value=$2
  local def_val

  def_val=$(grep "$key" $LPMD_PATH/data/intel_lpmd_config.xml | awk -F ">" '{print $2}' | awk -F "</" '{print $1}')
  test_print_trc "The $key default value is: $def_val"

  test_print_trc "Change $key to test value: $value"
  tar_val=$(grep "$key" $LPMD_PATH/data/intel_lpmd_config.xml | sed "s|$def_val|$value|g")
  # Remove space
  tar_val=$(echo "$tar_val" | tr -s ' ')
  test_print_trc "Setting: Target key and value: $tar_val"
  do_cmd "sed -i 's|$key|$tar_val|g' $LPMD_PATH/data/intel_lpmd_config.xml"
}

# Restore configuration xml setting
restore_xml() {
  cp $LPMD_PATH/data/intel_lpmd_config_default.xml $LPMD_PATH/data/intel_lpmd_config.xml 2>&1
}

# lpmd runs with default parameters
lpmd_default_run() {
  local xml_test=$1

  intel_lpmd -h 1>/dev/null || do_cmd "$LPMD_PATH/autogen.sh && make && make install"
  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 >$LPMD_PATH/logs/$xml_test.log"

  intel_lpmd --loglevel=debug --dbus-enable --no-daemon >>$LPMD_PATH/logs/"$xml_test".log &

  test_print_trc "Default options running in frontment"
  do_cmd "test_one 8 &"
  test_one_pid=$!
  wait "$test_one_pid"
}

# lpmd runs with default parameters
lpmd_default_run_stress() {
  local xml_test=$1
  local i=1

  # Do the make for the default configuration
  do_cmd "$LPMD_PATH/autogen.sh && make && make install"
  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 > $LPMD_PATH/logs/$xml_test.log"

  intel_lpmd --loglevel=debug --dbus-enable --no-daemon >>$LPMD_PATH/logs/"$xml_test".log &

  test_print_trc "Default options running in frontment"
  while [ "$i" -le 3 ]; do
    test_print_trc "Cycle $i:"
    do_cmd "test_one 5 &"
    test_one_pid=$!
    wait "$test_one_pid"
    i=$((i + 1))
  done
}

# lpmd runs with systemd parameter support
lpmd_systemd_run() {
  local xml_test=$1
  local i=1

  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 > $LPMD_PATH/logs/$xml_test.log"
  [ -e "/var/log/journal/*/*.journal" ] && do_cmd "rm /var/log/journal/*/*.journal"

  intel_lpmd --loglevel=debug --dbus-enable --no-daemon --systemd &

  test_print_trc "Systemd option running in background"
  while [ "$i" -le 3 ]; do
    test_print_trc "Cycle $i:"
    do_cmd "test_one 5 &"
    test_one_pid=$!
    wait "$test_one_pid"
    i=$((i + 1))
  done
  do_cmd "journalctl >> $LPMD_PATH/logs/$xml_test.log"

  journal_failure=$(grep -iE "fail|Call Trace|error|Invalid" $LPMD_PATH/logs/"$xml_test".log)
  if [ -n "$journal_failure" ]; then
    die "Journal shows unexpected message:$journal_failure"
  else
    test_print_trc "Journal message shows Okay."
  fi
}

# lpmd runs with daemonized parameter
lpmd_daemonized_run() {
  local xml_test=$1
  local i=1

  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 > $LPMD_PATH/logs/$xml_test.log"
  [ -e "/var/log/journal/*/*.journal" ] && do_cmd "rm /var/log/journal/*/*.journal"

  test_print_trc "Daemonized options, run in background"
  intel_lpmd --loglevel=debug --dbus-enable &

  while [ "$i" -le 2 ]; do
    test_print_trc "Cycle $i:"
    do_cmd "test_one 5 &"
    test_one_pid=$!
    wait "$test_one_pid"
    i=$((i + 1))
  done
  do_cmd "journalctl >> $LPMD_PATH/logs/$xml_test.log"

  journal_failure=$(grep -iE "fail|Call Trace|error|Invalid" $LPMD_PATH/logs/"$xml_test".log)
  if [ -n "$journal_failure" ]; then
    die "Journal shows unexpected message:$journal_failure"
  else
    test_print_trc "Journal message shows Okay."
  fi
}

# Verify /proc/stat IDLE and IOWAIT for non-low power CPUs
verify_non_lp_stat_idle() {
  local xml_test=$1
  local non_lp_idle_sum
  local non_lp_iowait_sum
  local lp_cpus
  local non_lp_all_sum=0

  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 >$LPMD_PATH/logs/$xml_test.log"

  intel_lpmd --loglevel=debug --dbus-enable --no-daemon >>$LPMD_PATH/logs/"$xml_test".log &

  test_print_trc "Default options running in frontment"
  # Force LPM entry
  sleep 5
  # Force enter LPM
  test_print_trc "Force enter LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 2 &"
  test_one_pid=$!
  sleep 30
  wait "$test_one_pid"

  # Get low power cpus from debug log
  lp_cpus=$(grep "Default Low Power CPUs" $LPMD_PATH/logs/"$xml_test".log | awk -F " " '{print $4}')
  test_print_trc "Low Power CPUs from debug log: $lp_cpus"

  # Read /proc/stat
  # STAT_CPU, STAT_USER,STAT_NICE,STAT_SYSTEM,STAT_IDLE,STAT_IOWAIT,STAT_IRQ,STAT_SOFTIRQ,
  # STAT_STEAL,STAT_GUEST,STAT_GUEST_NICE,STAT_MAX,STAT_VALID = STAT_MAX,STAT_EXT_MAX

  non_lp_idle_sum=$(grep "^cpu" /proc/stat | sed "/cpu[$lp_cpus]/d" | awk -F " " '{print $5}' | awk 'NR > 0 {sum += $0 } END { print sum }')
  non_lp_iowait_sum=$(grep "^cpu" /proc/stat | sed "/cpu[$lp_cpus]/d" | awk -F " " '{print $6}' | awk 'NR > 0 {sum += $0 } END { print sum }')
  grep "^cpu" /proc/stat | sed "/cpu[$lp_cpus]/d" >$LPMD_PATH/logs/state_file.log

  non_lp_sum=$(("$non_lp_idle_sum" + "$non_lp_iowait_sum"))
  test_print_trc "Non_low power CPU idle and iowait SUM is: $non_lp_sum"

  non_lp_all_sum=$(awk '{for (i=2;i<=NF; i++) sum+=$i} END{printf "%.2f", sum}' "$LPMD_PATH/logs/state_file.log")
  test_print_trc "Non_low power CPU all columns SUM is: $non_lp_all_sum"

  # Expect non_lp cpu idle and iowait sum should be > 99% of non_lp CPU all columns
  delta=$(echo "scale=4; $non_lp_sum/$non_lp_all_sum" | bc)
  test_print_trc "non_lp_idle_iowait_sum/non_lp_cpu_all_sum percentage is: $delta"
  delta_per=$(echo "scale=2; $delta*100" | bc)
  test_print_trc "non_lp_idle_iowait_sum/non_lp_cpu_all_sum final: $delta_per%"
  if (($(bc <<<"$delta_per >= 99.00"))); then
    test_print_trc "non_low power cpus idle and iowait sum is larger than 99.00% of all columns"
  else
    die "non_low power cpus idle and iowait sum is less than 99.00% of all columns"
  fi

  # Force exit LPM
  test_print_trc "Force exit LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 3"
  sleep 5

  # Terminate intel_lpmd
  test_print_trc "Terminate LPMD:"
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 1"
  sleep 5
}

# Funtion to test kill lpmd daemonized process then change xml to power setting
verify_daemonized_kill_process_change_power_0() {
  local xml_test=$1

  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 > $LPMD_PATH/logs/$xml_test.log"
  [ -e "/var/log/journal/*/*.journal" ] && do_cmd "rm /var/log/journal/*/*.journal"

  test_print_trc "Daemonized options, run in background"
  intel_lpmd --loglevel=debug --dbus-enable &
  lpmd_pid=$!

  # Auto LPM
  test_print_trc "Auto LPMD:"
  sleep 5
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 4"
  sleep 10

  # Kill lpmd daemon process
  kill -9 $lpmd_pid

  # Change xml config to set power setting to 0, then re-make
  update_xml "<PerformanceDef>-1</PerformanceDef>" 0
  update_xml "<BalancedDef>-1</BalancedDef>" 0
  update_xml "<PowersaverDef>-1</PowersaverDef>" 0
  re_make

  # Run LPMD daemon process after xml change
  intel_lpmd --loglevel=debug --dbus-enable &
  lpmd_pid=$!
  sleep 5 && kill -9 $lpmd_pid

  # Save journal log
  do_cmd "journalctl >> $LPMD_PATH/logs/$xml_test.log"

  sleep 2
  # Restore xml file
  restore_xml

  journal_failure=$(grep -iE "fail|Call Trace|error|Invalid|warnning" |
    grep -v " Failed to write entry to" $LPMD_PATH/logs/"$xml_test".log)
  if [ -n "$journal_failure" ]; then
    die "Journal shows unexpected message:$journal_failure"
  else
    test_print_trc "Journal message shows Okay."
  fi
}

# Funtion to test kill lpmd systemd process then change xml to power setting
verify_systemd_kill_process_change_power_1() {
  local xml_test=$1

  [ -e $LPMD_PATH/logs/"$xml_test".log ] && do_cmd "echo 0 > $LPMD_PATH/logs/$xml_test.log"
  [ -e "/var/log/journal/*/*.journal" ] && do_cmd "rm /var/log/journal/*/*.journal"

  test_print_trc "Systemd options, run in background"
  intel_lpmd --loglevel=debug --dbus-enable --no-daemon --systemd &
  lpmd_pid=$!

  # Auto LPM
  test_print_trc "Force enter LPMD:"
  sleep 5
  do_cmd "$LPMD_PATH/tests/lpm_test_interface.sh 2"
  sleep 5

  # Kill lpmd daemon process
  kill -9 $lpmd_pid

  # Change xml config to set power setting to 1, then re-make
  update_xml "<PerformanceDef>-1</PerformanceDef>" 1
  update_xml "<BalancedDef>-1</BalancedDef>" 1
  update_xml "<PowersaverDef>-1</PowersaverDef>" 1
  re_make

  # Run LPMD systemd process after xml change
  intel_lpmd --loglevel=debug --dbus-enable --no-daemon --systemd &
  lpmd_pid=$!
  sleep 5 && kill -9 $lpmd_pid

  # Save journal log
  do_cmd "journalctl >> $LPMD_PATH/logs/$xml_test.log"

  # Restore xml file
  restore_xml

  journal_failure=$(grep -iE "fail|Call Trace|error|Invalid|warnning" |
    grep -v " Failed to write entry to" $LPMD_PATH/logs/"$xml_test".log)
  if [ -n "$journal_failure" ]; then
    die "Journal shows unexpected message:$journal_failure"
  else
    test_print_trc "Journal message shows Okay."
  fi
}

verify_cpus_fixed_config() {
  local xml_test=$1
  local xml_value=$2

  fixed_cpu=$(grep "Util LP Mode CPUs" $LPMD_PATH/logs/"$xml_test".log | awk -F ":" '{print $2}')
  test_print_trc "Util LP Mode CPUs from debug log: $fixed_cpu"
  if [[ "$fixed_cpu" == "$xml_value" ]]; then
    test_print_trc "Util LP Mode CPUs is aligned with xml setting: $fixed_cpu"
  else
    die "Util LP Mode CPUs is not aligned with xml setting"
  fi
}

verify_mode1_config() {
  local xml_test=$1

  process_cpu=$(grep "Write \"member\" to /sys/fs/cgroup/lpm/cpuset.cpus.partition" $LPMD_PATH/logs/"$xml_test".log)
  if [[ -n "$process_cpu" ]]; then
    test_print_trc "LPMD mode 1 configuration pattern is detected."
  else
    die "Did not detect LPMD mode 1 configuration pattern"
  fi
}

verify_mode2_config() {
  local xml_test=$1

  process_cpu=$(grep "Write \"0000ffff\" to /sys/module/intel_powerclamp/parameters/cpumask" $LPMD_PATH/logs/"$xml_test".log)
  if [[ -n "$process_cpu" ]]; then
    test_print_trc "LPMD mode 2 configuration pattern is detected."
  else
    die "Did not detect LPMD mode 2 configuration pattern"
  fi
}

# Set power related setting to 0 means opportunistic Low Power Mode enter/exit
verify_power_setting_0_config() {
  local xml_test=$1

  power_setting_0=$(grep -E "usr auto|SYS util" $LPMD_PATH/logs/"$xml_test".log)
  if [[ -n "$power_setting_0" ]]; then
    test_print_trc "LPMD opportunistic Low Power Mode configuration pattern is detected."
  else
    die "Did not detect LPMD opportunistic Low Power Mode configuration pattern"
  fi
}

# Set power related setting to 1 means always stay in Low Power Mode
verify_power_setting_1_config() {
  local xml_test=$1

  power_setting_1=$(grep "usr enter" $LPMD_PATH/logs/"$xml_test".log)
  if [[ -n "$power_setting_1" ]]; then
    test_print_trc "LPMD always stay in Low Power Mode configuration pattern is detected."
  else
    die "Did not detect LPMD always stay in Low Power Mode configuration pattern"
  fi
}

# Use HFI LPM hints
verify_lpm_enable_config() {
  local xml_test=$1

  hfi_lpm_enable=$(grep "Detected HFI Low Power" $LPMD_PATH/logs/"$xml_test".log)
  if [[ -n "$hfi_lpm_enable" ]]; then
    test_print_trc "LPMD HFI LPM enable configuration pattern is detected."
  else
    die "Did not detect LPMD HFI LPM enable configuration pattern"
  fi
}

# Fix me later, currently we assume suv enable pattern check always PASS
verify_suv_enable_config() {
  test_print_trc "Assume suv enabling configuration change always PASS."
  return 0
}

#  System utilization threshold setting to enter LP mode
verify_util_entry_thres_config() {
  local xml_test=$1
  local xml_value=$2

  util_entry_thres=$(grep "Util entry threshold" $LPMD_PATH/logs/"$xml_test".log | awk -F ":" '{print $2}')
  if [[ "$util_entry_thres" == "$xml_value" ]]; then
    test_print_trc "LPMD util entry threshold set to 0 configuration pattern is detected."
  else
    die "Did not detect LPMD util entry threshold set to 0 configuration pattern"
  fi
}

# System utilization threshold to exit LP mode
verify_util_exit_thres_config() {
  local xml_test=$1
  local xml_value=$2

  util_exit_thres=$(grep "Util exit threshold" $LPMD_PATH/logs/"$xml_test".log | awk -F ":" '{print $2}')
  if [[ "$util_exit_thres" == "$xml_value" ]]; then
    test_print_trc "LPMD util exit threshold set to 0 configuration pattern is detected."
  else
    die "Did not detect LPMD util exit threshold set to 0 configuration pattern"
  fi
}

#  Entry Delay minimum delay in non Low Power mode to enter LPM mode
#  Exit Delay minimum delay in Low Power mode to exit to non LPM mode
verify_util_delay_config() {
  local xml_test=$1

  util_entry_exit_delay=$(grep "resample after  500 ms" $LPMD_PATH/logs/"$xml_test".log)
  test_print_trc "Detected util entry delay in debug log is: $util_entry_exit_delay"
  if [ -n "$util_entry_exit_delay" ]; then
    test_print_trc "LPMD util entry/exit delay 500ms configuration pattern is detected."
  else
    die "Did not detect LPMD util entry/exit delay 500ms configuration pattern"
  fi
}

# Fix me later, currently we assume the util hyst configuration change always PASS
# Entry hyst: Lowest hyst average in-LP-mode time in msec to enter LP mode
# Exit hyst: Lowest hyst average out-of-LP-mode time in msec to exit LP mode
verify_util_hyst() {
  test_print_trc "Assume util hyst configuration change PASS"
  return 0
}

verify_ignore_itmt_config() {
  local xml_test=$1

  ignore_itmt=$(grep "Process ITMT" $LPMD_PATH/logs/"$xml_test".log)
  if [[ -z "$ignore_itmt" ]]; then
    test_print_trc "Ignore ITMT setting pattern is detected"
  else
    die "Did not detect Ignore ITMT setting pattern"
  fi
}

verify_lpmd_running_logs() {
  local xml_test=$1

  # Check the lpmd debug log when LPM force on
  lpm_usr_entry=$(grep "Enter Low Power Mode ( usr enter)" $LPMD_PATH/logs/"$xml_test".log)
  [ -n "$lpm_usr_entry" ] || die "Did not decect msg: Enter Low Power Mode ( usr enter) when doing LPM Force on"

  # Check the lpmd debug log when LPM force off
  lpm_usr_exit=$(grep "Exit Low Power Mode (  usr exit)" $LPMD_PATH/logs/"$xml_test".log)
  [ -n "$lpm_usr_exit" ] || die "Did not decect msg: Exit Low Power Mode (  usr exit) when doing LPM Force off"

  # Check the lpmd debug log when LPM SUV_MODE Enter
  lpm_suv_entry=$(grep "Enter DBUS Survivability Mode" $LPMD_PATH/logs/"$xml_test".log)
  [ -n "$lpm_suv_entry" ] || die "Did not decect msg: Enter DBUS Survivability Mode when doing LPM SUV Enter"

  # Check the lpmd debug log when LPM SUV_MODE Exit
  lpm_suv_exit=$(grep "Exit DBUS Survivability Mode" $LPMD_PATH/logs/"$xml_test".log)
  [ -n "$lpm_suv_exit" ] || die "Did not decect msg: Exit DBUS Survivability Mode when doing LPM SUV Exit"

  # Check the lpmd debug log when LPM Auto
  lpm_auto=$(grep "Request 1 (  usr auto)" $LPMD_PATH/logs/"$xml_test".log)
  [ -n "$lpm_auto" ] || die "Did not decect msg: Request 1 (  usr auto) when doing LPM Auto"

  # Check the lpmd debug log when terminating
  lpm_terminal=$(grep "Terminating ..." $LPMD_PATH/logs/"$xml_test".log)
  [ -n "$lpm_terminal" ] || die "Did not decect msg: Terminating when doing terminate"

  test_print_trc "6 lpmd test commands response messages are received."
}

dmesg_check() {
  local dmesg_log

  dmesg_log=$(extract_case_dmesg)

  if echo "$dmesg_log" | grep -iE "fail|Call Trace|error|BUG"; then
    die "Kernel dmesg shows failure: $dmesg_log"
  else
    test_print_trc "Kernel dmesg shows Okay."
  fi
}

intel_lpmd_test() {
  case $TEST_SCENARIO in
  lpmd_default)
    lpmd_default_run default
    verify_lpmd_running_logs default
    ;;
  xml_lp_mode_cpus_fixed)
    change_cpus_fixed_xml "<lp_mode_cpus></lp_mode_cpus>" "0,1,2,3"
    re_make
    lpmd_default_run default_cpus_fixed
    restore_xml
    verify_cpus_fixed_config default_cpus_fixed "0,1,2,3"
    verify_lpmd_running_logs default_cpus_fixed
    ;;
  xml_mode_1)
    update_xml "<Mode>0</Mode>" 1
    re_make
    lpmd_default_run default_mode_1
    restore_xml
    verify_mode1_config default_mode_1
    verify_lpmd_running_logs default_mode_1
    ;;
  xml_mode_2)
    update_xml "<Mode>0</Mode>" 2
    re_make
    lpmd_default_run default_mode_2
    restore_xml
    verify_mode2_config default_mode_2
    verify_lpmd_running_logs default_mode_2
    ;;
  xml_power_slider_def_0)
    update_xml "<PerformanceDef>-1</PerformanceDef>" 0
    update_xml "<BalancedDef>-1</BalancedDef>" 0
    update_xml "<PowersaverDef>-1</PowersaverDef>" 0
    re_make
    lpmd_default_run default_power_0
    restore_xml
    verify_power_setting_0_config default_power_0
    verify_lpmd_running_logs default_power_0
    ;;
  xml_power_slider_def_1)
    update_xml "<PerformanceDef>-1</PerformanceDef>" 1
    update_xml "<BalancedDef>-1</BalancedDef>" 1
    update_xml "<PowersaverDef>-1</PowersaverDef>" 1
    re_make
    lpmd_default_run default_power_1
    restore_xml
    verify_power_setting_1_config default_power_1
    verify_lpmd_running_logs default_power_1
    ;;
  xml_hfi_lpm_enable)
    update_xml "<HfiLpmEnable>0</HfiLpmEnable>" 1
    re_make
    lpmd_default_run default_lpm_enable
    restore_xml
    verify_lpm_enable_config default_lpm_enable
    verify_lpmd_running_logs default_lpm_enable
    ;;
  xml_hfi_suv_enable)
    update_xml "<HfiSuvEnable>1</HfiSuvEnable>" 1
    re_make
    lpmd_default_run default_suv_enable
    restore_xml
    verify_suv_enable_config
    verify_lpmd_running_logs default_suv_enable
    ;;
  xml_util_entry_thres_0)
    update_xml "<util_entry_threshold>20</util_entry_threshold>" 0
    re_make
    lpmd_default_run default_entry_threshold
    restore_xml
    verify_util_entry_thres_config default_entry_threshold 0
    verify_lpmd_running_logs default_entry_threshold
    ;;
  xml_util_exit_thres_0)
    update_xml "<util_exit_threshold>95</util_exit_threshold>" 0
    re_make
    lpmd_default_run default_exit_threshold
    restore_xml
    verify_util_exit_thres_config default_exit_threshold 0
    verify_lpmd_running_logs default_exit_threshold
    ;;
  xml_util_entry_delay_500ms)
    update_xml "<EntryDelayMS>0</EntryDelayMS>" 500
    re_make
    lpmd_default_run default_entry_delay
    restore_xml
    verify_util_delay_config default_entry_delay
    verify_lpmd_running_logs default_entry_delay
    ;;
  xml_util_exit_delay_500ms)
    update_xml "<ExitDelayMS>0</ExitDelayMS>" 500
    re_make
    lpmd_default_run default_exit_delay
    restore_xml
    verify_util_delay_config default_exit_delay 500
    verify_lpmd_running_logs default_exit_delay
    ;;
  xml_util_entry_hyst_5000ms)
    update_xml "<EntryHystMS>0</EntryHystMS>" 5000
    re_make
    lpmd_default_run default_entry_hyst
    restore_xml
    verify_util_hyst
    verify_lpmd_running_logs default_entry_hyst
    ;;
  xml_util_exit_hyst_5000ms)
    update_xml "<ExitHystMS>0</ExitHystMS>" 5000
    re_make
    lpmd_default_run default_exit_hyst
    restore_xml
    verify_util_hyst
    verify_lpmd_running_logs default_exit_hyst
    ;;
  xml_ignore_itmt)
    update_xml "<IgnoreITMT>0</IgnoreITMT>" 1
    re_make
    lpmd_default_run default_ignore_itmt
    restore_xml
    verify_ignore_itmt_config default_ignore_itmt
    verify_lpmd_running_logs default_ignore_itmt
    ;;
  stress_full_mode0_default)
    update_xml "<HfiLpmEnable>0</HfiLpmEnable>" 1
    update_xml "<HfiSuvEnable>1</HfiSuvEnable>" 1
    re_make
    lpmd_default_run_stress stress_default_mode0
    restore_xml
    verify_lpm_enable_config stress_default_mode0
    verify_suv_enable_config
    verify_lpmd_running_logs stress_default_mode0
    ;;
  stress_full_mode0_systemd)
    update_xml "<HfiLpmEnable>0</HfiLpmEnable>" 1
    update_xml "<HfiSuvEnable>1</HfiSuvEnable>" 1
    re_make
    lpmd_systemd_run systemd
    restore_xml
    verify_lpm_enable_config systemd
    verify_suv_enable_config
    verify_lpmd_running_logs systemd
    ;;
  stress_full_mode0_daemonize)
    update_xml "<HfiLpmEnable>0</HfiLpmEnable>" 1
    update_xml "<HfiSuvEnable>1</HfiSuvEnable>" 1
    re_make
    lpmd_daemonized_run daemonize
    restore_xml
    verify_lpm_enable_config daemonize
    verify_suv_enable_config
    verify_lpmd_running_logs daemonize
    ;;
  stress_full_mode1_default)
    update_xml "<Mode>0</Mode>" 1
    update_xml "<HfiLpmEnable>0</HfiLpmEnable>" 1
    update_xml "<HfiSuvEnable>1</HfiSuvEnable>" 1
    re_make
    lpmd_default_run stress_default_mode1
    restore_xml
    verify_mode1_config stress_default_mode1
    verify_lpm_enable_config stress_default_mode1
    verify_suv_enable_config
    verify_lpmd_running_logs stress_default_mode1
    ;;
  stress_full_mode2_default)
    update_xml "<Mode>0</Mode>" 2
    update_xml "<HfiLpmEnable>0</HfiLpmEnable>" 1
    update_xml "<HfiSuvEnable>1</HfiSuvEnable>" 1
    re_make
    lpmd_default_run stress_default_mode2
    restore_xml
    verify_mode2_config stress_default_mode2
    verify_lpm_enable_config stress_default_mode2
    verify_suv_enable_config
    verify_lpmd_running_logs stress_default_mode2
    ;;
  default_non_lp_cpu_idle_iowait_check)
    verify_non_lp_stat_idle default_stat
    ;;
  fixed_non_lp_cpu_idle_iowait_check)
    change_cpus_fixed_xml "<lp_mode_cpus></lp_mode_cpus>" "0,2,3,4"
    re_make
    verify_non_lp_stat_idle default_cpus_fixed_stat
    restore_xml
    ;;
  negative_daemonized_kill_process)
    verify_daemonized_kill_process_change_power_0 daemoinze_kill_process
    ;;
  negative_systemd_kill_process)
    verify_systemd_kill_process_change_power_1 system_kill_process
    ;;
  esac
  dmesg_check
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

intel_lpmd_test
