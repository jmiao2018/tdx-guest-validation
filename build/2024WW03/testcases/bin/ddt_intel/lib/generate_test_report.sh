#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2014                                                  ##
##                                                                            ##
## Author:                                                                    ##
##  Wenzhong Sun <wenzhong.sun@intel.com>                                     ##
##                                                                            ##
## History:                                                                   ##
##  Aug 25, 2014 - (Wenzhong Sun) Created                                     ##
##                                                                            ##
################################################################################
#
# File:
#	generate_test_report.sh
#
# Description:
#	Generate csv-formated test report for TRC
#
# csv format:
#	Feature,Case Name,Test Point,Notes,PASS,FAIL,N/A
#	Example: Kernel,BAT/ALS,Test driver module load/unload,,1,,
#-----------------------------------------------------------------------
#shopt -s expand_aliases
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Global variables
DUT_NAME=$1
CASE_NAME=$2
TEST_RESULT=$3
TEST_POINT=$4
TEST_NOTE=$5
TR_DIR=$6
NEW_TRC=$7
TR_HEADER="Feature,Case id,Check points,Notes,Pass,Fail,N/A"

#-----------------------------------------------------------------------
# At least, 4 parameters are needed
if [ $# -lt 3 ];then
	echo "Error: Invalid Argument. Syntax: $0 <DUT name> \
<case name> <test result> <test point> <test notes> <TR dir>"
	exit -1
fi

case "${TEST_RESULT}" in
0)# result = pass
REPORT="Kernel,${CASE_NAME},${TEST_POINT},${TEST_NOTE},1,,"
;;
1)# result = fail
REPORT="Kernel,${CASE_NAME},${TEST_POINT},${TEST_NOTE},,1,"
;;
*)# result = N/A
REPORT="Kernel,${CASE_NAME},${TEST_POINT},${TEST_NOTE},,,1"
esac

# ROOTDIR should be exported by main test process
[ -n "${ROOTDIR}" ] || ROOTDIR="../../../"
[ -n "${TR_DIR}" ] || TR_DIR=${ROOTDIR}
SW_VER=$(../lib/get_sw_ver.sh)
SERIAL_ID=$(../lib/get_serial_no.sh)
TR_FILE="${TR_DIR}/TRC/${DUT_NAME}/TRC-${SERIAL_ID}-${DUT_NAME}-${SW_VER}.csv"
if [ ! -f "${TR_FILE}" ];then
	mkdir -p "${TR_DIR}/TRC/${DUT_NAME}" > /dev/null 2>&1
	echo "${TR_HEADER}" > "${TR_FILE}"
fi
if [ "${NEW_TRC}" -eq 1 ];then
	rm -r "${TR_FILE}" > /dev/null 2>&1
	echo "${TR_HEADER}" > "${TR_FILE}"
fi
echo "${REPORT}" >> "${TR_FILE}"
exit 0
