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
# Contributors:
#   Weihong Zhang <weihong.zhang@intel.com> (Intel)
#     -Initial draft.
###############################################################################
# @desc Search for device nodes under sysfs (/sys/kernel/).
# @returns None.
# @history 2021-08-02: First version.

source "common.sh"  # Import do_cmd(), die() and other functions
#source "../common/common.sh"  # Import do_cmd(), die() and other functions

############################# Global variables ################################
EDAC_BUS_DIR="/sys/bus/edac"
CUR_DIR=`pwd`
BIN_DIR=$CUR_DIR/ras_bin
TEST_PATH=./
TEST_NAME=""
TEST_FILE="./runtest.sh"

CASE_ID=0
PARA_STR=""
SUB_CMDS=""
SKIP_LIST=0

TEST_LOOP=1

############################# Functions #######################################
usage()
{
  cat <<-EOF >&2
 usage: ./${0##*/}  [-l TEST_LOOP] [-t TESTCASE_ID] -s [skip list]
  	-t TESTCASE_ID test case id, which case to be run
 		=========FUNCTION TEST======
 		1: APEI-INJ
 		2: EDAC
 		3: EINJ-EXT
 		4: EMCA-INJ
 		5: ERST-INJ
 		6: KVM
 		7: PFA
 		===========TESTS===========
 		11: BSP-CORE
 		12: BSP-NOS3S4
 		13: SRAR-DCU
 		14: SRAR-IFU
		15: STRESS-HWPOISON-HARD
		16: STRESS-HWPOISON-SOFT
 		==========HWPOISON=========
 		21: HWPOISION SOFT
 		22: HWPOISION HARD
 		23: HWPOISION HUGE
 		24: HWPOISION HUGE OVERCOMMIT
 		25: HWPOISION THO
 		============LMCE===========
 		31: LMCE
 		===========================
 		=========== END ===========
 		
 	-l the number of testing loop
 	-m lmcd sub commands
 	-h Help   print this usage
EOF
  exit 0
}

#install mce tools 
install_package() {
	tar -xf ./ddt_intel/ras/ras_test_suite.tar
	cp -rf ./ras_bin/etc/* /etc/
	cp -rf ./ras_bin/usr/* /usr/
	cp -rf ./ras_bin/sbin/* /sbin/
	mv ./ras_bin/mce-test ${BIN_DIR}
	#rm -rf ./ras_bin
}


ras_packages_check() {
	local installed=1
	if [ ! -e /usr/sbin/mce-inject ]; then
		return 1
	fi
	if [ ! -e /sbin/mcelog ]; then
		return 1
	fi
	if [ ! -e ${BIN_DIR} ]; then
		return 1
	fi
	return 0
}

prepare_test_setting() {
	local caseid=$1
	case $caseid in
		1)	#: 
			TEST_NAME="APEI-INJ"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/apei-inj/
			;;
		12)	# 
			TEST_NAME="BSP-NOS3S4"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/bsp/
			export MCE_TEST_SKIP="s3_s4"
			;;
		11)	# 
			TEST_NAME="BSP-CORE"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/bsp/
			unset MCE_TEST_SKIP
			;;
		13)	#:
			TEST_NAME="SRAR-DCU"
			TEST_FILE="runtest_dcu.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/core_recovery/
			;;
		14)	#:
			TEST_NAME="SRAR-IFU"
			TEST_FILE="runtest_ifu.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/core_recovery/
			;;
		15)	# 
			TEST_NAME="STRESS-HWPOISON-HARD"
			TEST_FILE="./run_hard.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/stress/hwpoison/
			;;
		16)	# 
			TEST_NAME="STRESS-HWPOISON-SOFT"
			TEST_FILE="./run_soft.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/stress/hwpoison/
			;;
		2)	#: edac
			TEST_NAME="EDAC"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/edac/
			;;
		3)	#
			TEST_NAME="EINJ-EXT"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/einj-ext/
			;;
		4)	#
			TEST_NAME="EMCA-INJ"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/emca-inj/
			;;
		5)	# 
			TEST_NAME="ERST-INJ"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/erst-inject/
			;;
		6)	# 
			TEST_NAME="KVM"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/kvm/
			;;
		7)	# 
			TEST_NAME="PFA"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/pfa/
			;;
		############### POISON ################
		21)	# 
			TEST_NAME="HWPOISON-SOFT"
			TEST_FILE="./run_soft.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/hwpoison/
			;;
		22)	# 
			TEST_NAME="HWPOISON-HARD"
			TEST_FILE="./run_hard.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/hwpoison/
			;;
		23)	# 
			TEST_NAME="HWPOISON-HUGE"
			TEST_FILE="./run_hugepage.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/hwpoison/
			;;
		24)	# 
			TEST_NAME="HWPOISON-HUGE-OVER"
			TEST_FILE="./run_hugepage_overcommit.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/hwpoison/
			;;
		25)	# 
			TEST_NAME="HWPOISON-THP"
			TEST_FILE="./run_thp.sh"
			TEST_PATH=${BIN_DIR}/./mce-test/cases/function/hwpoison/
			;;
		###############LMCE#################
		31)	#LMCE 
			TEST_NAME="LMCE"
			TEST_FILE="./lmce_test.sh"
			TEST_PATH=`dirname "${BASH_SOURCE[0]}"`
			PARA_STR=${SUB_CMDS}
			;;
		*)
			TEST_PATH=""
			usage
			exit 1
			;;
	esac
	test_print_trc "--->$TEST_NAME   $TEST_PATH   $TEST_FILE=============="

	return
}


############################### CLI Params ###################################
while getopts :l:t:k:m:h arg; do
  case $arg in
    l)  TEST_LOOP="$OPTARG"
		;;
    t)  CASE_ID="$OPTARG"
		;;
    h)  usage
		;;
    k)  SKIP_LIST="$OPTARG"
		;;
    m)  SUB_CMDS="$OPTARG"
		;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage
        exit 1
    ;;
  esac
done

########################### REUSABLE TEST LOGIC ###############################
# DO NOT HARDCODE any value. If you need to use a specific value for your setup
# use user-defined Params section above.

ras_packages_check

need_install=$?
if [ $need_install -eq 1 ]; then
	install_package
fi

prepare_test_setting $CASE_ID

test_print_trc "STARTING RAS Test..."

if [ ! -d $TEST_PATH ]; then
	test_print_err "Please make sure the path $TEST_PATH is exist!"
	exit 1
fi

test_print_trc "--->$TEST_NAME   ===>$TEST_PATH=============="
test_print_trc " @@@@@@@@@@@@@@@@@@@@qqqq@@@@@  START ${TEST_NAME} @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ "
test_print_trc "!!!!!!  $TEST_PATH  !!!!!"
### goto the test path
cd ${TEST_PATH}
#pushd ${TEST_PATH} > /dev/null
echo "sh ${TEST_FILE} ${PARA_STR}"
sh ${TEST_FILE} ${PARA_STR}
ret=$?
test_print_trc " @@@@@@@@@@@@@@@@@@@@@@@@@  END $TEST_NAME ! ret:$ret @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ "
#popd > /dev/null
exit $ret

