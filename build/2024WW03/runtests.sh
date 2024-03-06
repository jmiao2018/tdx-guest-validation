#!/usr/bin/env bash
###############################################################################
##                                                                            #
## Copyright (c) Intel Corp., 2017                                            #
##                                                                            #
## This program is free software;  you can redistribute it and#or modify      #
## it under the terms of the GNU General Public License as published by       #
## the Free Software Foundation; either version 2 of the License, or          #
## (at your option) any later version.                                        #
##                                                                            #
## This program is distributed in the hope that it will be useful, but        #
## WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY #
## or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License   #
## for more details.                                                          #
##                                                                            #
## You should have received a copy of the GNU General Public License          #
## along with this program;  if not, write to the Free Software Foundation,   #
## Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA           #
##                                                                            #
###############################################################################
## File:         runtests.sh                                                  #
##                                                                            #
## Description:  This script wrappers runltp to support running different     #
##               test scenarios and generate csv-formatted results            #
##                                                                            #
## Author:       Wenzhong Sun <wenzhong.sun@intel.com>                        #
##                                                                            #
## History:      Aug 24 2015 - Created - Wenzhong Sun                         #
##               Sep 28 2015 - Modified - Wenzhong Sun                        #
##               - Refactor run_scenario function                             #
##               - Add "-S SKIPFILE" parameter                                #
##               Jul 27 2016 - Modified - Wenzhong Sun                        #
##               - Concatenate DEFAULT parameters with platform-specific ones #
##               Sep 9 2016 - Modified - Wenzhong Sun                         #
##               - Change parameter file option to '-X' to align with runltp  #
##                 after rebase                                               #
##               Mar 3 2017 - Modified - Wenzhong Sun                         #
##               - Add user check to make sure root is running LTP-DDT        #
##               Apr 1 2017 - Modified - Ning Han                             #
##               - Introduce prerequisites checking mechanism                 #
##               June 8 2017 - Modified - Wenzhong Sun                        #
##               - Add '-D' option to dump dmesg logs before & after test     #
##                                                                            #
###############################################################################

export LTPROOT=${PWD}
export PATH="${PATH}:${LTPROOT}/testcases/bin:${LTPROOT}/bin:${LTPROOT}/testcases/bin/openposix_testsuite/bin:${LTPROOT}/testcase/bin/ftdi:"$( find ${LTPROOT}/testcases/bin/ddt_intel -type d | tr "\n" ":" | sed "s/^/:/" )
export RUNTEST_PARA="$*"
RUNLTP="${LTPROOT}/runltp"
LOG2CSV="${LTPROOT}/bin/log2csv.sh"
SCAN_RESULTS="${LTPROOT}/bin/scan_results.py"
TELEMETRY_DIR="/var/log/telemetry/records"

# Initialize Global Variables
CMDFILES=""
CMDFILE_LIST=""
GROUPFILES=""
PLATFORM=""
PARAMFILE=""
LOGDIR=""
LOGFILE=""
EXT_PARAMS=""
CSV_RESULT=0
DETACHED_RUN=1
# DEBUG Pirnt Option
DEBUG="off"
# DMESG Log Dump Option
DMESG="off"
TELEMETRY="off"
VERBOSE="off"
CASES=""


usage() {
  cat <<-EOF >&2
  usage: ${0##*/} [[ -p PLATFORM ]] [[ -f CMDFILES(,...) ]] [[ -g GROUPFILES(,...) ]
        -R -h -a -c [[ -A APPEND_ARGS ]] -d -D [[ -P PARAMFILES ]] [[ -o LOGDIR ]

    -p PLATFORM    Platform to run tests on. Used to filter device driver tests (ddt)
    -f CMDFILES    Execute user defined list of testcases in test scenario files separated by ','
                   CMDFILES should be defined in $LTPROOT/runtest/
    -g GROUPFILES  Execute user defined list of testcases in a group of test scenario files separated by with ','
                   GROUPFILES should be defined in $LTPROOT/scenario_groups/
    -P PARAMFILE   Parameter file to override default test case parameters
                   PARAMFILE should be defined in $LTPROOT/params/
    -S SKIPFILE    Skip tests specified in SKIPFILE
                   SKIPFILE should be defined in $LTPROOT/skips/
    -o LOGDIR      Output directory for test results and logs
    -a             Run All the test scenarios together with a merged test result file
    -c             Generate CSV-formatted results
    -C TCS         Execute test cases specified in command line, separate test cases with comma
    -t             Generate TAP-formatted results
    -T             Collect telemetry records
    -A APPEND_ARGS Appended arguments for runltp
    -d             Debug print
    -D             Dmesg log will be dumped before and after test
    -V             Verbose output on screen
    -h             Help. Prints all available options

    example: ${0##*/} -p bdw-u-rvp -f ddt_intel/emmc-func-tests,syscall
             ${0##*/} -p bdw-u-rvp -g default-alsa -P bdw-u -c -R -o /opt/result
EOF
}

# Error print
err() {
  exit_code=$1
  shift

  echo "[$(date "+%Y-%m-%d %H:%M:%S")] *ERROR* - $*" >&2
  exit "$exit_code"
}

# INFO print
info() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] *INFO* - $*"
}

# Warning print
warn() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] *WARN* - $*" >&2
}

# Debug print
dbg() {
  [[ "$DEBUG" == "on" ]] && echo "[$(date "+%Y-%m-%d %H:%M:%S")] *DEBUG* - $*"
}

dump_dmesg() {
  # Make sure all the kernel logs will be dumped
  echo 8 > /proc/sys/kernel/printk

  dmesg -s 2097152 > "$LOGDIR/${1}"
}

dump_telemetry_list() {
  telemetry_list="$LOGDIR/$1"

  if [[ -d "$TELEMETRY_DIR" ]]; then
    find "$TELEMETRY_DIR" > "$telemetry_list"
  else
    echo > "$telemetry_list"
  fi
}

parse_telemetry() {
  old_list="$LOGDIR/$1"
  new_list="$LOGDIR/$2"
  telemetry_file="$LOGDIR/${CASES}.telemetry"

  delta=$(diff "$new_list" "$old_list" | grep "\>")
  if [[ -n "$delta" ]]; then
    echo -n > "$telemetry_file"
    for record_file in $delta; do
      [[ -e "$record_file" ]] || continue
      record=$(basename "$record_file")
      echo "<telemetry_start>" >> "$telemetry_file"
      telem_journal -V -r "$record" &>> "$telemetry_file"
      echo '<telemetry_delimeter>' >> "$telemetry_file"
      grep -Ev "^$" "$record_file" &>> "$telemetry_file"
      echo "<telemetry_stop>" >> "$telemetry_file"
    done
  fi

  rm "$old_list"
  rm "$new_list"
}

add_cmdfile_list() {
  local cmdfile=$1

  # Tail to CMDFILE_LIST
  if [[ -z "$CMDFILE_LIST" ]]; then
    CMDFILE_LIST="$cmdfile"
  else
    CMDFILE_LIST="$CMDFILE_LIST,$cmdfile"
  fi
}

setup_case_mode() {
  export TEMP_SCENARIO_DIR="$LTPROOT/runtest/temp"
  rm -rf "$TEMP_SCENARIO_DIR"
  mkdir -p "$TEMP_SCENARIO_DIR"
}

parse_case_tags() {
  [[ -n "$CASES" ]] || return

  setup_case_mode || err 1 "setup single case mode failed."

  local cases
  local scenario
  local temp_scenario
  local temp_scenarios

  cases=$(tr "," " " <<< $CASES)

  for case in $cases; do
    scenario=$(grep -rE "^$case\s+" runtest/ 2> /dev/null \
                                    | awk -F: '{print $1}')

    if echo "$scenario" | grep -qE "\s"; then
      err 1 "At least 2 scenarios contains this case."
    fi

    temp_scenario="${TEMP_SCENARIO_DIR}/${case}"

    if ! grep -q "$temp_scenario" <<< "$temp_scenarios"; then
      temp_sces="${temp_scenarios},${temp_scenario}"
      touch "$temp_scenario"
      grep -E "^# @" "$scenario" > "$temp_scenario"
      echo >> "$temp_scenario"
    fi

    grep -E "^$case\s+" "$scenario" >> "$temp_scenario"

    CMDFILE_LIST="${CMDFILE_LIST},temp/${case}"
    info "Add $case to $temp_scenario"
  done
}

parse_cmdfiles() {
  dbg "parse_cmdfiles: CMDFILES is $CMDFILES"
  if [[ -n "$CMDFILES" ]]; then
    for cmdfile in $(echo "$CMDFILES" | tr ',' ' '); do
      # Skip non-existent test scenario files
      if [[ -f $LTPROOT/runtest/$cmdfile ]]; then
        dbg "parse_cmdfiles: Add $cmdfile to CMDFILE_LIST"
        add_cmdfile_list "$cmdfile"
      else
        warn "$LTPROOT/runtest/$cmdfile is not existent"
      fi
    done
  fi
}

parse_groupfiles() {
  dbg "parse_groupfiles: GROUPFILES is $GROUPFILES"
  if [[ -n "$GROUPFILES" ]]; then
    for groupfile in $(echo "$GROUPFILES" | tr ',' ' '); do
      # Skip non-existent test scenario group files
      [[ -f $LTPROOT/scenario_groups/$groupfile ]] || continue
      while read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" && "${line:0:1}" != "#" ]]; then
          # Skip non-existent test scenario files
          if [[ -f $LTPROOT/runtest/$line ]]; then
            dbg "parse_groupfiles: Add $line to CMDFILE_LIST"
            add_cmdfile_list "$line"
          else
            warn "$LTPROOT/runtest/$line is not existent"
          fi
        fi
      done < "$LTPROOT/scenario_groups/$groupfile"
    done
  fi
}

check_platform_file() {
  dbg "check_platform_file: PLATFORM file is $PLATFORM"
  if [[ -n "$PLATFORM" ]]; then
    if [[ -f $LTPROOT/platforms/$PLATFORM ]]; then
      EXT_PARAMS="$EXT_PARAMS -P $PLATFORM "
      info "Test Platform: $PLATFORM"
    else
      err 1 "$LTPROOT/platforms/$PLATFORM is not existent"
    fi
  fi
}

check_parameter_file() {
  dbg "check_parameter_file: Parameter file is $PARAMFILE"
  if [[ -n "$PARAMFILE" ]]; then
    if [[ -f $LTPROOT/params/$PARAMFILE ]]; then
      if [[ -s "$LTPROOT/params/DEFAULT" ]]; then
        # Concatenate common parameters with platform specific ones
        cat "$LTPROOT/params/DEFAULT" "$LTPROOT/params/$PARAMFILE" > \
          "$LTPROOT/params/${PARAMFILE}.united"
        EXT_PARAMS="$EXT_PARAMS -X $LTPROOT/params/${PARAMFILE}.united "
      else
        EXT_PARAMS="$EXT_PARAMS -X $LTPROOT/params/$PARAMFILE "
      fi
      info "Test Parameter file: $PARAMFILE"
    else
      warn "$LTPROOT/params/$PARAMFILE is not existent"
    fi
  else
    if [[ -s $LTPROOT/params/DEFAULT ]]; then
      EXT_PARAMS="$EXT_PARAMS -X $LTPROOT/params/DEFAULT"
    else
      warn "default kernel parameters missing, some test cases may fail!"
    fi
  fi
}

check_skip_file() {
  dbg "check_skip_file: Skip file is $SKIPFILE"
  if [[ -n "$SKIPFILE" ]]; then
    if [[ -f $LTPROOT/skips/$SKIPFILE ]]; then
      EXT_PARAMS="$EXT_PARAMS -S $LTPROOT/skips/$SKIPFILE "
      info "Test Skip file: $SKIPFILE"
    else
      warn "$LTPROOT/skips/$SKIPFILE is not existent"
    fi
  fi
}

setup() {
  # Default LOGDIR
  [[ -n "$LOGDIR" ]] || LOGDIR="$LTPROOT/results"
  # Create LOGDIR is not existent
  [[ -d "$LOGDIR" ]] || mkdir -p "$LOGDIR"
  [[ $? -eq 0 ]] || err 1 "$LOGDIR can NOT be created"

  if [[ "$LOGDIR" == /* ]]; then
    export LOG_PATH="$LOGDIR"
  else
    export LOG_PATH="$LTPROOT/$LOGDIR"
  fi

  # clean LOGDIR
  rm -rf "$LOGDIR/*"

  # Default LOGFILE
  LOGFILE="$LOGDIR/LTPDDT_TEST_ON_$(date "+%Y%m%d-%H%M%S").log"

  dbg "setup: LOGDIR is $LOGDIR"
}

print_prerequisites() {
  local require_class=$1
  local requires=$2
  local spaces4="    "

  info "Required $require_class:"

  for require in $requires; do
    info "$spaces4$require"
  done
}

check_kconfig_options() {
  local kernel_configs=$1
  local kconfigs=""
  local result=0

  if [[ -e "/boot/config-$(uname -r)" ]]; then
    kconfigs=$(cat "/boot/config-$(uname -r)")
  elif [[ -e "/lib/kernel/config-$(uname -r)" ]]; then
    kconfigs=$(cat "/lib/kernel/config-$(uname -r)")
  elif [[ -e "/proc/config.gz" ]]; then
    kconfigs=$(gzip -cd /proc/config.gz)
  fi

  if [[ -z "$kconfigs" ]]; then
    warn "Fail to get kernel configurations!"
    return 0
  fi

  for kernel_config in $kernel_configs; do
    [[ -n "${kernel_config#*=}" ]] \
      || warn "$kernel_config is not a correct kernel configuration format!"
    if [[ "${kernel_config#*=}" == "my" ]] \
      || [[ "${kernel_config#*=}" == "ym" ]]; then
      if [[ ! "$kconfigs" =~ ${kernel_config%=*}=m ]] \
          && [[ ! "$kconfigs" =~ ${kernel_config%=*}=y ]]; then
        warn "Checking kconfig options: $kernel_config ...... failed!"
        ((result++))
      fi
    else
      if [[ ! "$kconfigs" =~ $kernel_config ]]; then
        warn "Checking kconfig options: $kernel_config ...... failed!"
        ((result++))
      fi
    fi
  done

  return $result
}

check_utilities() {
  local utilities=$1
  local result=0

  for utility in $utilities; do
    which "$utility" &> /dev/null || {
      warn "Checking utilities: $utility ...... failed!"
      ((result++))
    }
  done

  return $result
}

check_kernel_cmdline() {
  local cmdlines=$1
  local local_cmdlines=""
  local result=0

  local_cmdlines=$(cat /proc/cmdline)
  if [[ -z "$local_cmdlines" ]]; then
    warn "No output from /proc/cmdline!"
    return 0
  fi

  for cmdline in $cmdlines; do
    if [[ ! "$local_cmdlines" =~ $cmdline ]]; then
      warn "Checking kernel cmdlines: $cmdline ...... failed!"
      ((result++))
    fi
  done

  return $result
}

check_export_libpath() {
  local pathes=$1

  for path in $pathes; do
    abs_path="$LTPROOT/$path"
    [[ -d "$abs_path" ]] || {
      warn "$abs_path does not exist!"
      return 1
    }

    [[ ! $LD_LIBRARY_PATH = *"$abs_path"* ]] || continue
    LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${abs_path}"
  done

  # Remove potential existent of leading ':'
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH#:*}"
}

check_prerequisites() {
  local scenario_file=$1
  local kernel_options=""
  local utilities=""
  local cmdlines=""
  local exit_code=0

  info "Checking prerequisites for running $scenario_file"
  kernel_options=$(grep "@koption_requires" "$LTPROOT/runtest/$scenario_file" \
                  | sed 's/# @koption_requires//g' \
                  | xargs)
  if [[ -n "$kernel_options" ]]; then
    [[ "$DEBUG" == "on" ]] \
      && print_prerequisites "Kconfig options" "$kernel_options"
    check_kconfig_options "$kernel_options"
    exit_code=$((exit_code + $?))
  fi

  utilities=$(grep "@utility_requires" "$LTPROOT/runtest/$scenario_file" \
              | sed 's/# @utility_requires//g' \
              | xargs)
  if [[ -n "$utilities" ]]; then
    [[ "$DEBUG" == "on" ]] && print_prerequisites "Utilities" "$utilities"
    check_utilities "$utilities"
    exit_code=$((exit_code + $?))
  fi

  cmdlines=$(grep "@cmdline_requires" "$LTPROOT/runtest/$scenario_file" \
            | sed 's/# @cmdline_requires//g' \
            | xargs)
  if [[ -n "$cmdlines" ]]; then
    [[ "$DEBUG" == "on" ]] && print_prerequisites "Kernel cmdlines" "$cmdlines"
    check_kernel_cmdline "$cmdlines"
    exit_code=$((exit_code + $?))
  fi

  lib_pathes=$(grep "@libpath_requires" "$LTPROOT/runtest/$scenario_file" \
               | sed 's/# @libpath_requires//g' \
               | xargs)
  if [[ -n "$lib_pathes" ]]; then
    [[ "$DEBUG" == "on" ]] && print_prerequisites "LIB PATHs" "$lib_pathes"
    check_export_libpath "$lib_pathes"
    exit_code=$((exit_code + $?))
  fi

  return $exit_code
}

run_scenario() {
  local test_scenario=$1
  for scenario in $(echo "$test_scenario" | tr ',' ' '); do
    check_prerequisites "$scenario"
    if [[ $? -ne 0 ]]; then
      warn "Checking prerequisites for running $scenario failed. Abort!"
      return 1
    fi
  done

  info "Start Running Test Scenario: $test_scenario ..."
  info "Test log file: $LOGFILE"

  dbg "RUNCMD: $RUNLTP -f $test_scenario $EXT_PARAMS &> $LOGFILE"
  if [[ "$LOGDIR" = "STDOUT"  ]]; then
    # No quotation for $EXT_PARAMS as it's expected to be splited.
    # shellcheck disable=SC2086
    $RUNLTP -f "$test_scenario" $EXT_PARAMS
  elif [[ "$VERBOSE" == "on" ]]; then
    # shellcheck disable=SC2086
    $RUNLTP -f "$test_scenario" $EXT_PARAMS |& tee "$LOGFILE"
  else
    # shellcheck disable=SC2086
    $RUNLTP -f "$test_scenario" $EXT_PARAMS &> "$LOGFILE"
  fi
}

run_detached_scenario() {
  dbg "run_detached_scenario"
  for scenario in $(echo "$CMDFILE_LIST" | tr ',' ' '); do
    # Format LOGFILE name: [LTP|DDT]_$scenario.log
    if [[ "${scenario%%/*}" = "ddt_intel" ]]; then
      LOGFILE="$LOGDIR/DDT_${scenario##*/}.log"
    elif [[ "${scenario%%/*}" = "temp" ]]; then
      LOGFILE="$LOGDIR/${scenario##*/}.log"
    else
      LOGFILE="$LOGDIR/LTP_${scenario##*/}.log"
    fi
    run_scenario "$scenario"
  done
}

run_all_scenario() {
  dbg "run_all_scenario"
  run_scenario "$CMDFILE_LIST"
}

###############################################################################

while getopts aA:ctC:dDf:g:ho:p:P:S:TV arg; do
  case $arg in
    a) DETACHED_RUN=0;;
    A) APPEND_ARGS+=$OPTARG;;
    c) CSV_RESULT=1;;
    t) TAP_RESULT=1;;
    C) CASES=$OPTARG
       [[ ${CASES:0:1} = ',' ]] && CASES=${CASES#*,}
       [[ ${CASES:0,-1} = ',' ]] && CASES=${CASES%,*}
       ;;
    d) DEBUG="on";;
    D) DMESG="on";;
    f) CMDFILES=$OPTARG;;
    g) GROUPFILES=$OPTARG;;
    o) LOGDIR=$OPTARG;;
    p) PLATFORM=$OPTARG;;
    P) PARAMFILE=$OPTARG;;
    S) SKIPFILE=$OPTARG;;
    T) TELEMETRY="on";;
    V) VERBOSE="on";;
    h) usage
       exit 0
       ;;
    :) usage
       err 1 "Option -$OPTARG requires an argument."
       ;;
    \?) usage
        err 1 "Invalid Option -$OPTARG"
        ;;
  esac
done
EXT_PARAMS="$EXT_PARAMS $APPEND_ARGS"

if command -v command >/dev/null 2>&1; then
  has_cmd() {
    command -v "$1" >/dev/null
  }
else
  has_cmd() {
    type "$1" >/dev/null 2>&1
  }
fi

user_check() {
  local user=

  if has_cmd whoami; then
    user=$(whoami)
  elif has_cmd id; then
    user=$(id -nu)
  else
    user="${USER}"
  fi

  [[ "${user}" == 'root' ]] \
    || err 1 "Current user [${user}] is not root. Test must be run as root!"
}

if [[ -n "$ANDROID_OS" ]]; then
  user_id=$(id -u)
  [[ "$user_id" -eq 0 ]] || err 1 "Current user is not root. Abort the test!"
else
  user_check
fi

# Parse CASETAGS
parse_case_tags
# Parse CMDFILES
parse_cmdfiles
# Parse GROUPFILES
parse_groupfiles
# At least one test scenario file is required
if [[ -n "$CMDFILE_LIST" ]]; then
  info "Test Scenarios: $CMDFILE_LIST"
else
  err 1 "NO Test Scenario is defined"
fi
# Check PLATFORM File
check_platform_file
# Check Parameter File
check_parameter_file
# Check Skip File
check_skip_file
# Set-up
setup
# Dump dmesg log before actual testing
if [[ "$DMESG" == "on" ]]; then
  dmesg_0=dmesg_0_$(date "+%Y%m%d_%H%M%S").log
  dump_dmesg $dmesg_0
fi

# Dump telemetry record ids before testing
if [[ "$TELEMETRY" == "on" ]] && [[ -n "$CASES" ]] && [[ ! "$CASES" =~ , ]]; then
  telemetry_0="telemetry_0_$(date +%Y%m%d_%H%M%S).telemetry"
  dump_telemetry_list "$telemetry_0"
fi

# Run test scenario
if [[ "$DETACHED_RUN" -eq 1 ]]; then
  run_detached_scenario
else
  run_all_scenario
fi

# Dump dmesg log after testing
if [[ "$DMESG" == "on" ]]; then
  dmesg_1=dmesg_1_$(date "+%Y%m%d_%H%M%S").log
  dump_dmesg "$dmesg_1"
fi

# Dump telemetry records ids after testing
if [[ "$TELEMETRY" == "on" ]] && [[ -n "$CASES" ]] && [[ ! "$CASES" =~ , ]]; then
  sync
  telemetry_1="telemetry_1_$(date +%Y%m%d_%H%M%S).telemetry"
  dump_telemetry_list "$telemetry_1"
fi

if [[ "$DMESG" == "on" ]] && [[ -n "$GROUPFILES" ]]; then
  last_line=$(tail -n 1 "$LOGDIR/$dmesg_0")
  occur_line=$(grep -F "$last_line" "$LOGDIR/$dmesg_1" -Rsn | awk -F ":" '{print $1}')
  line_count_file2=$(wc -l < "$LOGDIR/$dmesg_1")
  let left_lines=$line_count_file2-$occur_line
  dmesg_groupfiles=$LOGDIR/${GROUPFILES#*ddt_intel/}.dmesg
  tail -n $left_lines "$LOGDIR/$dmesg_1" > "$dmesg_groupfiles"

  scenario_list=$(grep -v "#" < "scenario_groups/$GROUPFILES" | xargs)

  summary=()
  tmp=0
  for scenario in $scenario_list; do
    for i in $(grep -v "^#" < "./runtest/$scenario" | awk '{print $1}' | xargs); do
      nr=$(grep "LTP: starting $i " "$dmesg_groupfiles" -Rwsn | awk -F ":" '{print $1}')
      summary[tmp++]="$i,$nr"
    done
  done
  summary[tmp]="DUMMY,$(($(wc -l < "$dmesg_groupfiles")+1))"

  for ((i = 0; i < $((${#summary[@]}-1)); i++)); do
    name=${summary[i]%,*}
    cs=${summary[i]#*,}
    nx=${summary[i+1]#*,}
    head -n $((nx-1)) "$dmesg_groupfiles" | tail -n $((nx-cs)) > "$LOGDIR/$name.dmesg"
  done

  rm -rf $LOGDIR/$dmesg_0 $LOGDIR/$dmesg_1 $dmesg_groupfiles
fi

if [[ "$DMESG" == "on" ]] && [[ -n "$CMDFILES" ]]; then
  last_line=$(tail -n 1 "$LOGDIR/$dmesg_0")
  occur_line=$(grep -F "$last_line" "$LOGDIR/$dmesg_1" -Rsn | awk -F ":" '{print $1}')
  line_count_file2=$(wc -l < "$LOGDIR/$dmesg_1")
  let left_lines=$line_count_file2-$occur_line
  dmesg_cmdfiles=$LOGDIR/${CMDFILES#*ddt_intel/}.dmesg
  tail -n $left_lines "$LOGDIR/$dmesg_1" > "$dmesg_cmdfiles"

  summary=()
  tmp=0
  for i in $(grep -v "^#" < "./runtest/$CMDFILES"  | awk '{print $1}' | xargs); do
    nr=$(grep "LTP: starting $i " "$dmesg_cmdfiles" -Rwsn | awk -F ":" '{print $1}')
    summary[tmp++]="$i,$nr"
  done
  summary[tmp]="DUMMY,$(($(wc -l < "$dmesg_cmdfiles")+1))"

  for ((i = 0; i < $((${#summary[@]}-1)); i++)); do
    name=${summary[i]%,*}
    cs=${summary[i]#*,}
    nx=${summary[i+1]#*,}
    head -n $((nx-1)) "$dmesg_cmdfiles" | tail -n $((nx-cs)) > "$LOGDIR/$name.dmesg"
  done

  rm -rf "${LOGDIR:?}/$dmesg_0" "${LOGDIR:?}/$dmesg_1" "${dmesg_cmdfiles:?}"
fi

if [[ "$DMESG" == "on" ]] && [[ -n "$CASES" ]] && [[ $CASES != *,* ]]; then
  last_line=$(tail -n 1 $LOGDIR/$dmesg_0)
  occur_line=$(fgrep "$last_line" $LOGDIR/$dmesg_1 -Rsn | awk -F ":" '{print $1}')
  line_count_file2=$(cat $LOGDIR/$dmesg_1 | wc -l)
  let left_lines=$line_count_file2-$occur_line
  tail -n $left_lines $LOGDIR/$dmesg_1 > $LOGDIR/$CASES.dmesg
  rm -rf $LOGDIR/$dmesg_0 $LOGDIR/$dmesg_1
fi

# Parse telemetry content
if [[ "$TELEMETRY" == "on" ]] && [[ -n "$CASES" ]] && [[ ! "$CASES" =~ , ]]; then
  parse_telemetry "$telemetry_0" "$telemetry_1"
fi

# Generate CSV-formatted results which can be accepted by Test Report Center
if [[ "$CSV_RESULT" -eq 1 ]]; then
  [[ -x "$LOG2CSV" ]] || err 1 "$LOG2CSV is not existent or not executable"
  info "Generating CSV-formatted results ..."
  eval "$LOG2CSV $LOGDIR"
fi

if [[ "$TAP_RESULT" -eq 1 ]]; then
  [[ -x "$SCAN_RESULTS" ]] || err 1 "$SCAN_RESULTS doesn't exit or executable"
  which python3 &> /dev/null || err 1 "python3 not installed"
  eval "$SCAN_RESULTS -d $LOGDIR --tap"
fi
