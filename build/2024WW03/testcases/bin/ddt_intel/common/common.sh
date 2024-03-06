#!/bin/bash
###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2015 Intel Corporation - http://www.intel.com/
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
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Change the use of bc to awk (for floating point ops)
#      due to Busybox limitation.
#     -block_test() func was added to be able to set tests status as BLOCKED
#      instead of FAIL when some pre-requisite for tests were not met
#      e.g. SD card not present.
#   Zelin Deng <zelinx.deng@intel.com> (intel)
#     -Enhanced test log of do_cmd function
#     -Add new function check_koption to get the option of kernel config
#   Juan Carlos Alonso <juan.carlos.alonso@intel.com> (Intel)
#     -Added 'is_kmodule_builtin()' function. This function look in
#      '/lib/modules/$(uname -r)/modules.builtin' file. It returns '0' if
#      the driver is configured as built-in, '1' if it is not.
#   Yixin Zhang <yixin.zhang@intel.com> (Intel)
#     -Change to bash shell and unify coding style
#     -Add exec_teardown() to execute registered teardown function when test
#      exists in do_cmd and die
###############################################################################

# @history 2015-02-16: bc -> awk change.
# @history 2015-02-26: block_test() added.
# @history 2017-06-30: regex_scan_dir() added.
# @history 2017-07-06: exec_teardown() added
# @history 2017-07-11: is_kmodule_builtin() added.
# @history 2017-07-13: change to bash shell and unify coding style.
# @history 2017-08-03: rename check_koption() to get_kconfig()
#                      rename check_config_options() to test_kconfigs()
# @history 2017-12-21: add function: repeat_do_cmd()

source "st_log.sh"
source "site_info"

########### DEFINE CONSTANTS ##################################################

# TODO(yixin): add "readonly" for below constants after clean double source in
#              test cases

K=1024
KB=1000
M=$(( K * K ))
MB=$(( KB * KB ))
G=$(( K * K * K ))
GB=$(( KB * KB * KB ))
T=$(( K * K * K * K ))
TB=$(( KB * KB * KB * KB ))
MAX_UINT32_DEC_FORMAT=$((2*1024*1024*1024-1))
DEBUGFS_LOCATION=/sys/kernel/debug/
PSID="$0$$"
START_TIME=$(date "+%s")

########### DEFINE PLATFORM DATA ##############################################
# This is done by ltp-ddt's runltp script, but it is optionally done
# here for cases where we are running the scripts outside ltp-ddt
# If the PATH in the target filesystem doesn't have below path exported,
# please add those path in order to run standalone ltp scripts.
# export PATH="${PATH}:/opt/ltp/testcases/bin:/opt/ltp/testcases/bin/ddt"

resolve_platform_name() {
  case $1 in
    *) PLATFORM="$1" ;;
  esac
  echo "$PLATFORM"
}

if [[ -z "$SOC" ]]; then
  LTPPATH="${LTPROOT}"
  export PATH="${PATH}:${LTPPATH}/testcases/bin"$( find ${LTPPATH}/testcases/bin/ddt -type d -exec printf ":"{} \; )$( find ${LTPPATH}/testcases/bin/ddt_intel -type d -exec printf ":"{} \; )
  plat=$(uname -n)
  DRIVERS=""
  i=0

  while read -r file; do
    echo "$file" | grep -eq "^#.*" && continue

    mkdir -p "${PLATFORMDIR}/${file}"
    case $i in
      0) ARCH="$file"
         export ARCH ;;
      1) SOC="$file"
         export SOC ;;
      2) MACHINE="$file"
         export MACHINE ;;
      3) DRIVERS="$file" ;;
      *) DRIVERS="${DRIVERS},${file}" ;;
    esac
    ((i++))
  done < ${LTPPATH}/platforms/$(resolve_platform_name $plat)

  export DRIVERS
fi

########### FUNCTIONS #########################################################
# Default value for inverted_return is "false" but can
# be overridden by individual scripts.
inverted_return="false"

do_cmd() {
  CMD=$*

  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_trc "do_cmd() is called by $caller_info"
  test_print_trc "CMD=$CMD"

  eval "$CMD"
  RESULT=$?
  if [[ "$inverted_return" == "false" ]]; then
    if [[ $RESULT -ne 0 ]]; then
      test_print_err "$CMD failed. Return code is $RESULT"
      if [[ $RESULT -eq 32 || $RESULT -eq 2 ]]; then
        test_print_trc "Return code $RESULT is reserved, change to 1"
        RESULT=1
      fi
      exec_teardown
      exit $RESULT
    fi
  else
    if [[ $RESULT -eq 0 ]]; then
      test_print_err "$CMD passed, but expecting failed result."
      exec_teardown
      exit 1
    else
      test_print_trc "Failed result is expected.It should PASS."
    fi
    test_print_wrg "do_cmd() with inverted_return=\"true\" is DEPRECATED"
    test_print_wrg "Please use should_fail()"
  fi
}
#do_cmd "mount | grep mtdblock4 || echo notmounted"

should_fail() {
  # execute a command and check if it fails, exit 1 if it passes
  CMD=$*

  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_trc "should_fail() is called by $caller_info"
  test_print_trc "CMD=$CMD"

  eval "$CMD"
  if [[ $? -eq 0 ]]; then
    test_print_err "Command passes, but failed result is expected."
    exec_teardown
    exit 1
  else
    test_print_trc "Command fails as expected."
  fi
}
# should_fail "mount | grep mtdblock4 || echo notmounted"

repeat_do_cmd() {
  local LOOP
  local CMD
  local TEST_LOOP=1

  LOOP=$(echo "$@" | cut -d' ' -f1)
  CMD=$(echo "$@" | cut -d' ' -f2-)

  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_trc "repeat_do_cmd() is called by $caller_info"
  test_print_trc "CMD=$CMD"

  while [[ $TEST_LOOP -le $LOOP ]]; do
    test_print_trc "------ LOOP $TEST_LOOP ------"
    eval "$CMD"
    RESULT=$?
    if [[ "$inverted_return" == "false" ]]; then
      if [[ $RESULT -ne 0 ]]; then
        test_print_err "$CMD failed. Return code is $RESULT"
        exec_teardown
        exit $RESULT
      fi
    else
      if [[ $RESULT -eq 0 ]]; then
        test_print_err "$CMD passed, but expecting failed result."
        exec_teardown
        exit 1
      else
        test_print_trc "Failed result is expected.It should PASS."
      fi
    fi
    TEST_LOOP=$((TEST_LOOP + 1))
  done
}

# Check the given list of parameters and verify that they are set.
check_mandatory_inputs() {
  for x in "$@" ; do
    eval t="$"$x
    if [[ -z "$t" ]]; then
      test_print_trc "Mandatory input \"$x\" not specified"
      exit 1
    fi
  done
}

die() {
  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_err "FATAL: die() is called by $caller_info"
  test_print_err "FATAL: $*"
  exec_teardown
  exit 1
}

skip_test() {
  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_wrg "skip_test() is called by $caller_info"
  test_print_wrg "SKIPPING TEST: $*"
  exec_teardown
  exit 0
}

block_test() {
  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_err "block_test() is called by $caller_info"
  test_print_err "Result ====BLOCK==== : $*"
  exec_teardown
  exit 2
}

na_test() {
  caller_info="${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}:${FUNCNAME[1]}()"
  test_print_wrg "na_test() is called by $caller_info"
  test_print_wrg "NA TEST: $*"
  exec_teardown
  exit 32
}

# Get value for key from a string or a file
# Input:
#   $1 opertion mode, s -> from string, f -> from file
#   $2 key
#   $3 delimiter
#   $4 key-value pairs string or file with key-value pairs
get_value_for_key() {
  local mode=$1
  local key=""
  local delimiter=""
  local key_value_pairs=""
  local file=""
  local rtnk=""
  local rtnv=""
  shift

  if [[ "$mode" == s ]]; then
    if [[ $# -ne 3 ]]; then
      die "Wrong number of arguments. \
           Usage: get_value_for_key s <key> <delimiter> <key-value pairs>"
    fi
  elif [[ "$mode" == f ]]; then
    if [[ $# -ne 3 ]]; then
      die "Wrong number of arguments. \
           Usage: get_value_for_key_from_file f <key> <delimiter> <file>"
    fi
  else
    die "First argument must be valid operation mode!"
  fi

  key=$1
  delimiter=$2
  if [[ "$mode" == s ]]; then
    key_value_pairs=$3

    for pair in $key_value_pairs; do
      k=$(echo "$pair" | cut -d"$delimiter" -f1)
      v=$(echo "$pair" | cut -d"$delimiter" -f2)
      if [[ "$k" == "$key" ]]; then
        rtnk="$k"
        rtnv="$v"
        break
      fi
    done
    # return 1 if key not found
    [[ -n "$rtnk" ]] || return 1
  else
    file=$3

    # return 1 if key not found
    grep -q "^\s*${key}\s*${delimiter}\s*" "$file"  || return 1
    rtnv="$(grep "^\s*${key}\s*${delimiter}\s*" "$file" \
            | cut -d "$delimiter" -f2 | sed 's/^ *//g')"
  fi

  echo "$rtnv"
}

# Compare two files based on md5sum
# Input:
#   $1 file1
#   $2 file2
# Return:
#   true if equal; false otherwise
compare_md5sum() {
  local file1=$1
  local file2=$2
  local file1_md5
  local file2_md5
  file1_md5=$(md5sum "$file1" | cut -d' ' -f1)
  if [[ $? -ne 0 ]]; then
    test_print_err "Error getting md5sum of $file1"
    exit 1
  fi
  test_print_trc "$file1: $file1_md5"
  file2_md5=$(md5sum "$file2" | cut -d' ' -f1)
  if [[ $? -ne 0 ]]; then
    test_print_err "Error getting md5sum of $file2"
    exit 1
  fi
  test_print_trc "$file2: $file2_md5"
  [[ "$file1_md5" == "$file2_md5" ]]
}

# report something with delta time
report() {
  local CUR_TIME
  local delta
  CUR_TIME=$(date "+%s")
  delta=$((CUR_TIME - START_TIME))

  echo "$PSID:$START_TIME->$CUR_TIME($delta):$test_iteration: $*"
  sync
}

_random() {
  local max_mult
  local mult
  local v
  if [[ $1 -gt 32767 ]]; then
    max_mult=$(($1 / 32767))
    mult=$((RANDOM % max_mult))
  else
    mult=0;
  fi
  v=$(awk "BEGIN {print ($RANDOM + ($RANDOM * $mult))}")
  echo "$v"
}

# random
# $1 - max_value
random() {
  local v
  local v1
  v=$(_random "$1")
  #v=$(dd if=/dev/urandom count=1 2> /dev/null | cksum | cut -c 0-10)
  v1=$(($1 + 1))
  echo $((v % v1))
}

# random not equal to 0
random_ne0() {
  local v
  v=$(_random "$1")
  #v=$(dd if=/dev/urandom count=1 2> /dev/null | cksum | cut -c 0-10)
  echo $((v % $1 + 1))
}

# check different kernel errors
check_kernel_errors() {
  local type=$1
  shift
  local opts=$1
  case $type in
    kmemleak)
      test_kconfigs "y" DEBUG_KMEMLEAK
      kmemleaks="/sys/kernel/debug/kmemleak"
      if [[ ! -e ${kmemleaks} ]]; then
        die "kmemleak sys entry doesn't exist; perhaps need to increase CONFIG_DEBUG_KMEMLEAK_EARLY_LOG_SIZE"
      fi

      if [[ "$opts" = "clear" ]]; then
        # clear the list of all current possible memory leaks before scan
        do_cmd "echo clear > ${kmemleaks}"
        return
      fi

      # trigger memory scan
      do_cmd "echo scan > ${kmemleaks}"
      # give kernel some time to scan
      do_cmd sleep 30
      kmemleak_detail=$(cat ${kmemleaks})
      if [[ -n "${kmemleak_detail}" ]]; then
        test_print_err \
          "There are memory leaks being detected. The details are displayed as below: ${kmemleak_detail}"
        return 1
      else
        test_print_trc "No memory leaks being detected."
      fi
      ;;

    spinlock)
      test_kconfigs "y" DEBUG_SPINLOCK

      if [[ "$opts" = "clear" ]]; then
        dmesg -c
        return
      fi

      # Check dmesg to catch the error
      spinlock_errors="BUG: spinlock"
      if dmesg | grep -i "${spinlock_errors}"; then
        test_print_err "There is spinlock errors showing in dmesg"
        return 1
      else
        test_print_trc "No spinlock related error found in dmesg"
      fi
      ;;

    *)
      die "check_kernel_errors: No logic for type $type yet."
      ;;
  esac
}

# Function to check if environment variable is set
# Input: $1 - environment variable to be checked
# returns true if set
# returns false if not set
check_env_var() {
  local env_var=$1
  [[ -n $env_var ]] \
    || die "check_env_var() : 1 and only 1 areguement is required."

  local output_str
  output_str=$(env | grep "$env_var")
  if [[ -n $output_str ]]; then
    test_print_trc "$env_var is defined in env:"
    test_print_trc "$output_str"
    return 0
  else
    test_print_trc "$env_var is not defined in env"
    return 1
  fi
}

# $1: Options to check.
# Output:
# y,m or n message, die if no config file readable
get_kconfig() {
  local koption="$1"
  local value=""

  if [[ -r "/boot/config-$(uname -r)" ]]; then
    value=$(grep -E "^$koption=" "/boot/config-$(uname -r)" | cut -d'=' -f2)
  elif [[ -r "/lib/modules/$(uname -r)/build/.config" ]]; then
    value=$(grep -E "^$koption=" "/lib/modules/$(uname -r)/build/.config" \
            | cut -d'=' -f2)
  elif [[ -r "/proc/config.gz" ]]; then
    value=$(zcat "/proc/config.gz" | grep -E "^$koption=" | cut -d'=' -f2)
  else
    die "No config file readable on this system"
  fi

  [[ -n "$value" ]] || value="n"

  echo $value
  return 0
}

# $1: check type, either 'y', 'm', or 'n'
# $2: Options to check, which possible to use OR like CONFIG1|CONFIG2
test_kconfigs() {
  local koption_values="$1"
  local koption_names="$2"

  if [[ ! "$koption_values" =~ [ymn] ]]; then
    test_print_err "Invalid koption value!"
    return 1
  fi

  # For each expression between '|' separators
  for koption in $(echo "$koption_names" | tr '|' ' '); do
    if [[ $(get_kconfig "$koption") != "$koption_values" ]]; then
      test_print_wrg "$koption does not match $koption_values!"
      return 1
    else
      test_print_trc "$koption matches with expect $koption_values"
    fi
  done
}

# Check if at least one kconfig in the list match the given value
# Input: $1: CONFIG_A|CONFIG_B...
#        $2: y, m or n
# Output: return 0 for true, 1 for false
test_any_kconfig_match() {
  local kconfig_names=$1
  local kconfig_value=$2
  local kconfig_name=""

  for kconfig_name in $(echo "$kconfig_names" | tr '|' ' '); do
    test_kconfigs "$kconfig_value" "$kconfig_name" && return 0
  done
  test_print_err "None of $kconfig_names matches value $kconfig_value"
  return 1
}

# To know if driver is configured as built-in, looking in 'modules.builtin' file
# Input:
#   $1: kernel module name
# Return:
#   0 if it is configured as built-in, 1 if it is not.
is_kmodule_builtin() {
  [[ $# -eq 1 ]] \
    || die "is_kmodule_builtin(): 1 and only 1 argument is required!"

  local kmodule=$1
  [[ -n $kmodule ]] || die "is_kmodule_builtin(): kmodule cannot be empty!"

  if [[ "$OS" = "android" ]]; then
    LIB_PATH="/vendor/lib"
  else
    LIB_PATH="/lib"
  fi

  if grep -q -w "$kmodule" "${LIB_PATH}/modules/$(uname -r)/modules.builtin"; then
    return 0
  else
    local kmod
    kmod=$(echo "$kmodule" | tr '_' '-')
    grep -q -w "$kmod" "${LIB_PATH}/modules/$(uname -r)/modules.builtin"
    return $?
  fi
}

# To get instance number from dev node
# Input:
#   $1: dev node like /dev/rtc0, /dev/mmcblk0, /dev/sda1, /dev/mtdblk12 etc
# Output:
#   instance number like '0', '1' etc
get_devnode_instance_num() {
  local devnode_entry=$1
  local inst_num
  inst_num=$(echo "$devnode_entry" | grep -oE "[[:digit:]]+$" ) || \
            die "Failed to get instance number for dev node entry $devnode_entry"
  echo "$inst_num"
}

# Get filesize
# $1:     filename
# return: file size in byte
get_filesize() {
  local inputfile=$1
  local fs
  fs=$(wc -c < "$inputfile")
  echo "$fs"
}

# hexdump one byte at offset $oset from $filename
#   $1: filename
#   $2: offset
hexdump_onebyte() {
  local filename=$1
  local offset=$2
  local byte
  byte=$(hexdump -n 1 -s "$offset" -C "$filename" | head -1 | awk -F " " '{print $2}')
  echo "$byte"
}

# replace one byte of input file
# Input
#   $1: input file
#   $2: offset - decimal number and starting from 0
#   $3: new_byte - need to be hex
replace_onebyte() {
  local inputfile=$1
  local offset=$2
  local new_byte=$3

  local fs
  fs=$(get_filesize "$inputfile")
  echo "$inputfile size is: $fs"
  local tempfile
  tempfile="$TMPDIR/tempfile_to_replace_$$"
  do_cmd "dd if=$inputfile of=$tempfile bs=1 count=$offset"
  test_print_trc "echo -ne \"\x$new_byte\" >> $tempfile"
  echo -ne "\x$new_byte" >> "$tempfile"
  do_cmd "dd if=$inputfile of=$tempfile bs=1 count=$((fs-offset-1)) \
             skip=$((offset+1)) seek=$((offset+1))"

  do_cmd "cp $tempfile $inputfile"
}

# wrapper for wget
Wget() {
  wget "$@" || wget --proxy off "$@" || http_proxy=$SITE_HTTP_PROXY wget "$@"
}

# Description: Output notice message and then sleep
# Input:  $1 - Notice message
#         $2 - Optional, sleep time in seconds, default value 1 second
# Output: NA
# Return: 0
# Usage:  notify_and_wait "Please make sure divice is idle" 20
notify_and_wait() {
  test_print_trc "$1"
  local sleep_time=$2
  : "${sleep_time:=1}"
  test_print_trc "Sleep $sleep_time seconds"
  sleep "$sleep_time"
}

is_intel_android() {
  grep -q 'androidboot.serialno' '/proc/cmdline' && return 0 || return 1
}

# Description: pick out fils or directories in a directory which
#              match specific regex
# Inputs: $1 -- directory to scan
#         $2 -- regex to match
# Outputs: a list of files and directories
regex_scan_dir() {
  local dir=$1
  # to exact match, regex pattern should
  # start with '^' and end with '$'
  local regex_pattern=$2
  local rt=""

  items=$(ls "$dir")
  for i in $items; do
    if [[ $i =~ $regex_pattern ]]; then
      rt="${rt} $i"
    fi
  done

  # remove leading space
  rt=${rt/ /}

  echo "$rt"
}

# Description: execute teardown handler registered in test case
#              or <driver>_common.sh
# Return:      return value of status before execute teardown
# Usage:       teardown_handler="my_teardown_func my_parameters"
#              do_cmd "my_test" || die     #exec_teardown is called if failed
#              exec_teardown               #call exec_teardown for passed case
teardown_handler=""

exec_teardown() {
  #Record the original return value before excute teardown
  local original_ret=$?

  # return if teardown handler is not registered
  [[ -n "$teardown_handler" ]] || return $original_ret

  test_print_trc "-------- Teardown starts --------"
  test_print_trc "Teardown handler: $teardown_handler"
  eval "$teardown_handler" || test_print_err "Teardown failed"
  test_print_trc "-------- Teardown ends ---------"

  return $original_ret
}

# This function caculate file size in bytes based on input parameters
# Input:
#       $1: block size of the file, with unit
#       $2: block count of the file(optional, default value is 1)
# Output:
#       file size in byte on success
#       empty string on failure
# Usage:
#       caculate_size_in_bytes 18M
#       caculate_size_in_bytes 18MB
#       caculate_size_in_bytes 18M 2
#       caculate_size_in_bytes 18MB 2
caculate_size_in_bytes() {
  local block_size=$1
  local block_count=${2:-1}
  local block_size_unit=""
  local block_size_num=""
  local file_size=""

  block_size_num=${block_size//[a-zA-Z]/}
  block_size_unit=${block_size//$block_size_num/}

  # Convert unit to bytes
  block_size=$(echo "$block_size_num * ${!block_size_unit}" | bc)
  file_size=$(echo "scale=0; ($block_size * $block_count)/1" | bc)

  echo "$file_size"
}

# Execute command after switching to an no-root user(temporarily created)
# Input:
#       $@ command to be executed
# Output:
#       output of the command, temp username will be export as LTP_TEMP_USER
# Usage:
#       user_do ls
#       user_do cat test.txt
#       user_do echo hello > temp.txt
user_do() {
  local cmd="$*"
  local username=""
  local rt_code=0

  if [[ -n "$LTP_TEMP_USER" ]] && id -u "$LTP_TEMP_USER" &> /dev/null; then
    username="$LTP_TEMP_USER"
  else
    if [[ -e /dev/urandom ]]; then
      username="ltp-$(tr -dc '[:lower:]' < /dev/urandom | fold -w 6 | head -n 1)"
    else
      username="tempuser"
    fi

    useradd --shell /bin/bash -m "$username"
    export LTP_TEMP_USER="$username"
    echo "$username" >> /home/tempusers
  fi

  su "$username" -c "export PATH=$(echo $PATH | tr ":" "\n" | sed '/^$/d' | xargs echo | tr " " ":"); cd /home/$username; $cmd"
  rt_code=$?

  return "$rt_code"
}

# Clean temp users created by user_do()
# Input:
#       N/A
# Output:
#       N/A
# Usage:
#       clean_temp_users
clean_temp_users() {
  # /home/tempusers was created in user_do function
  local temp_users_file='/home/tempusers'

  [[ -e "$temp_users_file" ]] || {
    test_print_trc "no temp user need to clean."
    return 0
  }

  mapfile -t tempuers < "$temp_users_file"

  [[ ${#tempuers[@]} -ne 0 ]] || {
    test_print_trc "no temp user need to clean"
    return 0
  }

  test_print_trc "------ CLEAN TEMP USERS ------"
  for user in "${tempuers[@]}"; do
    test_print_trc "--> $user"
    userdel "$user" &> /dev/null
    rm -rf "/home/${user:?}"
  done
  test_print_trc "------------ DONE-------------"

  rm "$temp_users_file"
  unset LTP_TEMP_USER
}
