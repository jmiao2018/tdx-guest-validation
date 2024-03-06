#!/usr/bin/env bash
###############################################################################
# Copyright (C) 2019 Intel - http://www.intel.com/
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
# @desc do test
#      files: under /sys/devices/system/cpu(or cpus)
#
# @returns None.
# @history
#    2021-05-11: First version -draft!!!!
#    2021-05-14: add usage and reload test!

source "ifs_func.sh" # Import do_cmd(), die() and other functions

############################# Functions #######################################
#  usage
reload_usage() {
  cat <<-EOF >&2
  Test Scan at field ;
    usage: ./${0##*/} -c case id [parameters list]
  Case id:
  0:test loading blob files;
    usage: ./${0##*/} -c 0 [-m model] [-h hash file] [-s scan files]
      -m  test mode; 0 normal files; 1: err file 2: empty file; 3: random file
      -s  scan file path; the path of scan file
      -e  expected result: 0 success; 1 error;
      -n: the index of intel_ifs_x; 0: scan; 1: Array; 2: SBFT;
    example:
      ./${0##*/} -m 0 -s ~/scan
EOF
  echo ""
}

#mode: 0: normal load; 1: err load; 2:empty file; 3:random
#create a error blob with same file header as original blob
saf_gen_error_blob() {
  [ $# -lt 2 ] && return
  local file=$1
  local err_blob=$2

  # get the size of file
  local size=$(stat -c "%s" ${file})
  local half=$(expr $size / 2)
  local left=$(expr $size - $half)
  local errSize=10
  left=$(expr $left - $errSize)
  # create error blob from exist blob
  echo "Generating blob file with CRC error!"
  dd of=./file1.bin if=$file bs=1 count=$half
  # error content
  dd of=./zero1.bin if=/dev/zero bs=1 count=$errSize
  local pos=$(expr $size - $left)
  dd of=./file2.bin if=$file skip=$pos bs=1 count=$left
  #create error blob file

  cat ./file1.bin ./zero1.bin ./file2.bin >${err_blob}
  #remove temp files
  rm ./file1.bin ./zero1.bin ./file2.bin -rf
  md5sum $file $err_blob
  echo "Created error blob ${err_blob} !"
  return
}

############################################################################
#para:  -m x -s x
#s: blob file
saf_reload_test() {
  test_print_trc " Reload test"
  echo "[reload_test]::: $*"
  [[ $? -eq 0 ]] && {
    local blob_path="/lib/firmware/intel/ifs/"
  }
  echo "BLOB: ${blob_path}"
  ls $blob_path -l
  local mode=0
  #defaul file
  local testFile=""
  # check options
  OPTIND=1
  while getopts :m:s:e:n: arg; do
    case $arg in
    m) mode="$OPTARG" ;;
    s) testFile="$OPTARG" ;;
    e) ;;
    n) ;;
    *)
      test_print_err "=========wrong parameter=========="
      reload_usage
      exit 1
      ;;
    esac
  done

  #get the format of filename
  saf_get_blob_name_fmt
  local blobFile=${blob_path}/${blob_name}


  if [ ! -f "${blobFile}" ]; then
    test_print_err "Please check the file(not exist): ${blobFile}"
    exit 1
  fi

  case $mode in
  0) #noraml test load blob useing ori blob
    testFile=$blobFile
    test_print_trc "mode:$mode ==> test with original blob file $testFile"
    ;;
  1) #gen a file with crc errors
    testFile="${blob_path}/error_blob"
    saf_gen_error_blob $blobFile ${testFile}
    [[ -f "$testFile" ]] || {
      test_print_err "mode:$mode ==> $testFile not exist!"
      exit 1
    }
    test_print_trc "mode:$mode ==> test with  blob error file $testFile"
    ;;
  2) #empty file
    testFile="./empty"
    dd if=/dev/zero of=$testFile bs=512 count=10
    test_print_trc "mode:$mode ==> test with empty file $testFile"
    ;;
  3) #a ramdom file
    testFile="./random.blob"
    dd if=/dev/urandom of=$testFile bs=1k count=10
    test_print_trc "mode:$mode ==> test with file generated random"
    ;;
  *)
    test_print_err "======= Wrong mode !======="
    reload_usage
    exit 1
    ;;
  esac

  test_print_trc "Using $testFile as test file!"
  #backup the org files
  cp $blobFile $blobFile-org
  #copy new file to replace org file
  if [ -f "$testFile" ]; then
    cp $testFile $blobFile
  fi
  #rm temp files
  case $mode in
  [1-3])
    rm $testFile
    ;;
  esac

  ls $blob_path -l

  local para="-r0 -D -E -W"
  test_print_trc $para
  ifs_reload_blob

  #saf_run_cli "$para"
  local ret=$?
  # get the result from return and check the status of hash_valid

  #restore the org files
  #echo "mv $blobFile-org  $blobFile"
  mv $blobFile-org $blobFile

  # the message used as a reload finish symbol
  test_print_trc "reload function finished!"
  return $ret
}

#####################################################################
# check the dmesg log with key words
check_reload_result() {
  local mode=-1
  local ret=0
  local excepted=0
  local keys=""
  OPTIND=1

  while getopts :m:s:e: arg; do
    case $arg in
    m) mode="$OPTARG" ;;
    e) excepted="$OPTARG" ;;
    *) ;;
    esac
  done
  # err 0: well, 1: load fail; 2: kernel error
  local err=0
  cat ${log_file}.dmesg
  # first check kernel trace error
  local ret=$(grep -c -e "Call Trace" "${log_file}.dmesg")
  if [ $ret -gt 0 ]; then
    return 1
  fi
  # check
  # check driver error!
  ret=$(grep "ifs:" ${log_file}.dmesg | grep -c "fail")
  #echo "Get ========== ret"
  if [ ${ret} -gt 0 ]; then
    test_print_err "Get ${ret} errors: ifs: xxxxx fail"
  fi

  keys1="bad ifs data checksum"
  keys2="invalid/unknown ifs update format"
  keys3="bad ifs data file size"
  test_print_trc "Check message: 1 [${keys1}] 2:[${keys2}] 3:[${keys3}]"

  ret=$(grep -c -e "${keys1}" -e "${keys2}" -e "${keys3}" ${log_file}.dmesg)
  if [ $ret -eq 0 ]; then
    test_print_err "Failed to get mode[${mode} message:[${keys1}] [${keys2}] [${keys3}] "
  else
    err=$(grep -e "${keys1}" -e "${keys2}" -e "${keys3}" ${log_file}.dmesg)
    test_print_err "Get [${ret} message:${err}"
  fi

  case $mode in
  0) #noraml test load blob useing ori blob
    if [ $ret -eq 0 ]; then
      ret=0
    else
      ret=1
    fi
    ;;
  1 | 2 | 3) #gen a file with crc errors
    if [ $ret -eq 0 ]; then
      ret=1
    else
      ret=0
    fi
    ;;
  *) ;;

  esac

  return $ret
}

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.

TEST_NAME="RELOAD"

##########################################a
echo "##########################################"
saf_show_title "STARTING SAF TEST: $TEST_NAME... "
echo "##########################################"

# check the root user
if [ "$UID" -ne 0 ]; then
  test_print_err "Please use root!"
  exit 0
fi
# get function type(intel_ifs_x)
ifs_set_mode $@
# check the SAF driver
if saf_probe_check; then
  test_print_trc "Get the driver!"
fi

#[[ "$?" == "0" ]] && {
#  test_print_trc "Get the driver"
#}

#gen log/dmesg prefix
log_file=/tmp/${0##*/}_IFS${IFS_MODE}_${TEST_NAME}_$(date +%y%m%d-%N)

ifs_interrupt_trace_init
saf_reload_test $* 2>&1 | tee ${log_file}.log

#extract kernel message
echo "$(extract_case_dmesg)" >>${log_file}.dmesg

# save event trace to log
ifs_catch_event_trace_info ${log_file}.trc

ls ${log_file}.* -l

#################################
## check the dmessage
#################################
reload=$(grep -c "reload function finished" "${log_file}.log")
if [ $reload -eq 0 ]; then
  cmd_ret=1
else
  check_reload_result $@
  cmd_ret=$?
fi

# restore blob and reload again
ifs_reload_blob

echo "**********************---------------------***************************"
saf_show_title "SAF Test Over: $TEST_NAME !!RETURN: $cmd_ret"
echo "**********************---------------------***************************"
echo ""

exit $cmd_ret
