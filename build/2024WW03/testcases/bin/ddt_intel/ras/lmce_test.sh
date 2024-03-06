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

#test_print_err() {
#		echo $*
#		return;
#}
#
#test_print_trc() {
#		echo $*
#		return;
#}
#

############################# Global variables ################################
CUR_DIR=$(pwd)
echo "$CUR_DIR"

BIN_DIR=$CUR_DIR/../../ras_bin/
TEST_FILE="./lmce"
TEST_PATH=${BIN_DIR}/./ras-tools
echo "$TEST_PATH"
PARA_STR=""
############################# functions ##############################
# check mcelog is running
check_mcelog()
{
	local daemon=0
	local foreground=0

	pgrep -x mcelog >/dev/null 2>&1
	local ret=$?
	if [ $ret -ne 0 ]; then
		test_print_trc "mcelog didn't run"
		exit 1
	fi
	for i in $(pgrep -a -x mcelog)
	do
		if [ "$i" == "--daemon" ]; then
			daemon=1
		fi
		if [ "$i" == "--foreground" ]; then
			foreground=1
		fi
	done
	if [ "$daemon" -ne 1 -o "$foreground" -eq 1 ]; then
		test_print_trc "mcelog not run in daemon mode, re-run mcelog"
		kill -9 $(pgrep -x mcelog)
		/usr/sbin/mcelog --ignorenodev --daemon
	fi
}

#remove possible edac related modules, otherwise mcelog can not
#capture machine checking information
cleanup()
{
  EDAC_MODL_LIST=$(awk '{print $1}' /proc/modules | grep edac)
	if [ "x$EDAC_MODL_LIST" != "x" ]; then
		for i in $EDAC_MODL_LIST; do
			modprobe $$i > /dev/null 2>&1
		done
	fi
}


set_lmce_sub_cmds() {
		mode=$1
		case $mode in
		  1)
					test_print_trc "========= same address, same core INSTR/INSTR =========="
				  PARA_STR="-a -c 1 -t INSTR/INSTR"
					;;
			2)
					test_print_trc "========= same address, same socket INSTR/INSTR=========="
					PARA_STR="-a -c 2 -t INSTR/INSTR"
					;;
		  3)
				  test_print_trc "========= same address, differnt socket INSTR/INSTR =========="
				  PARA_STR="-a -t INSTR/INSTR"
					;;
		  4)
					test_print_trc "========= different addresses, same core, INSTR/INSTR =========="
					PARA_STR="-c 1 -t INSTR/INSTR"
					;;
		  5)
					test_print_trc "========= different addresses, same socket, INSTR/INSTR  =========="
					PARA_STR="-c 2 -t INSTR/INSTR"
					;;
		  6)
					test_print_trc "========= different addresses, different socket, INSTR/INSTR  =========="
					PARA_STR="-t INSTR/INSTR"
					;;
		  7)
					test_print_trc "========= same address, same core, INSTR/DATA =========="
					PARA_STR="-a -c 1 -t INSTR/DATA"
					;;
		  8)
					test_print_trc "========= same address, same socket, INSTR/DATA =========="
					PARA_STR="-a -c 2 -t INSTR/DATA"
					;;
		  9)
					test_print_trc "========= same address, different socket, INSTR/DATA  =========="
					PARA_STR="-a -t INSTR/DATA"
					;;
		  10)
					test_print_trc "========= different address, same core, INSTR/DATA   =========="
					PARA_STR="-c 1 -t INSTR/DATA"
					;;
		  11)
					test_print_trc "========= different address, same socket, INSTR/DATA  =========="
					PARA_STR="-c 2 -t INSTR/DATA"
					;;
		  12)
					test_print_trc "========= different address, different socket, INSTR/DATA  =========="
					PARA_STR="-t INSTR/DATA"
					;;
		  13)
					test_print_trc "========= same address, same core, DATA/DATA  =========="
					PARA_STR="-a -c 1 -t DATA/DATA"
					;;
		  14)
					test_print_trc "========= same address, same socket, DATA/DATA  =========="
					PARA_STR="-a -c 2 -t DATA/DATA"
					;;
		  15)
					test_print_trc "========= same address, different socket, DATA/DATA  =========="
					PARA_STR="-a -t DATA/DATA"
					;;
		  16)
					test_print_trc "========= different address, same core,DATA/DATA =========="
					PARA_STR="-c 1 -t DATA/DATA"
					;;
		  17)
					test_print_trc "========= different address, same socket,DATA/DATA =========="
					PARA_STR="-c 2 -t DATA/DAT"
					;;
		  18)
					test_print_trc "========= different address, different socket,DATA/DATA =========="
					PARA_STR="-t DATA/DATA"
					;;
		  *)
					test_print_err "Wrong sub command: ${mode} please check!"
					return 1
					;;
		esac

		return 0
}


########################################################################
[ $# -eq 0 ] && exit 1
# get test mode from parameter
mode="$1"

# check root
trap "cleanup" 0
if [ "$(id -u)" != "0" ]; then
	test_print_err "Must be run as root"
	exit 0
fi

cleanup

#check_mcelog
#: > /var/log/mcelog

set_lmce_sub_cmds "$mode"
ret=$?
if [ $ret -gt 0 ]; then
    exit 1
fi
### goto the test path
cd "${TEST_PATH}"
test_print_trc "${TEST_FILE} ${PARA_STR}"
${TEST_FILE} 
#${PARA_STR}
ret=$?

sleep 1
#check result
if [ $ret -eq 0 ]; then
	if grep -q SRAR /var/log/mcelog; then
		test_print_trc "SRAR happened"
	fi
	if grep -q LMCE /var/log/mcelog; then
		test_print_trc "LMCE happened"
		test_print_trc "PASS"
	else
		test_print_trc "LMCE didn't happen"
		test_print_trc "FAIL"
		ret=1
	fi
else
  ret=1
	test_print_trc "FAIL"
fi

exit $ret
