#!/bin/bash

###############################################################################
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

# @Author   Sun, Wenzhong <wenzhong.sun@intel.com>

#   Juan Carlos Alonso <juan.carlos.alonso@intel.com>
#     - Added 'getopts' statement to replace 'shift' logic to parse
#       parameters.
#     - Improve the way to get Watchdog Device Node.

############################ DESCRIPTION ######################################

# @desc Script to run wdt test
# @returns
# @history 2015-09-01: Upstream kernel do not have /sbin/watchdogd daemon. So add codes
#                      to distingush upstream and android.
# @history 2018-01-31: Add 'getopts' statement.
#                      Improve the way to get Watchdog Device Node.

###############################################################################

############################# FUNCTIONS #######################################

usage()
{
  cat<<_EOF
  Usage:./${0##*/} [-d DEV_NODE] [-i IOCTL] [-a IOCTL_ARG] [-l LOOP]
  Option:
    -d: device node under /dev
    -i: ioctl command to operate WDT
    -a: some ioctl command may need argument
    -l: loops need to be tested
    -h: look for usage
_EOF
}

################################ DO THE WORK ##################################

source "common.sh"
source "wdt_common.sh"

while getopts :d:i:a:l:rh arg; do
  case "${arg}" in
    d)  DEV_NODE="${OPTARG}" ;;
    i)  IOCTL="${OPTARG}" ;;
    a)  IOCTL_ARG="${OPTARG}" ;;
    l)  LOOP="${OPTARG}" ;;
    r)  RNDM="1" ;;
    h)  usage ;;
    :)  test_print_err "$0: Must supply an argument to -$OPTARG."
        die
        ;;
    \?) test_print_err "Invalid Option -$OPTARG ignored."
        usage
        ;;
  esac
done

# Default parameters
: ${IOCTL_ARG:='20'}
: ${RNDM:='0'}
: ${LOOP:='1'}

# Load kernel module
kconfig=$(get_kconfig "${WDAT_KCONFIG}") || exit 2
if [[ "${kconfig}" = 'm' ]]; then
  modprobe "${DRV_MOD_NAME}"
  lsmod | grep "${DRV_MOD_NAME}"
  if [[ $? -ne 0 ]]; then
    test_print_trc "${DRV_MOD_NAME} module is not loaded"
    exit 2
  fi
fi

# Get Device Node
if [[ -z "${DEV_NODE}" ]]; then
  WDT_NODE=$(ls /dev | grep "watchdog" | tr '\n' '\t' | awk -F'\t' '{print $1}') \
    || die "Watchdog device cannot be found!"
  DEV_NODE="/dev/${WDT_NODE}"
fi
test_print_trc "WDT DEVICE NODE:${DEV_NODE}"

# Check if Watchdog service is running on DUT.
if [[ "${OS}" == "android" ]]; then
  DUT_PID=$(ps -o pid,comm,args | grep -v grep | grep "watchdogd" | grep "sbin" |awk -F' ' '{print $1}')
else
  DUT_PID=$(ps | grep -v grep | grep "watchdog" | awk -F' ' '{print $2}')
fi

# KILL THE RUNNING SERVICES, CASE ONLY ONE PROCESS CAN OPEN WATCHDOG
[[ -n "${DUT_PID}" ]] && {
  test_print_trc "===/sbin/watchdogd is running, pid=${DUT_PID}, now kill it!==="
  kill -9 "${DUT_PID}"
  if [[ $? -eq 0 ]]; then
    test_print_trc "===/sbin/watchdogd is killed, now start ${IOCTL} test...==="
  fi
}

# Case statement
case "${IOCTL}" in
  getsupport)    wdt_tests -device "${DEV_NODE}" -ioctl getsupport ;;
  settimeout)    for (( x=0; x<LOOP; x++ )); do
                   if [[ "${RNDM}" -eq 1 ]]; then
                     IOCTL_ARG=$(( RANDOM % 100 ))
                     test_print_trc "RANDOM TIME:$IOCTL_ARG"
                   fi
                   do_cmd watchdog_test -t "${IOCTL_ARG}"
                 done
                 ;;
  gettimeout)    do_cmd watchdog_test -g ;;
  getstatus)     wdt_tests -device "${DEV_NODE}" -ioctl getstatus ;;
  getbootstatus) wdt_tests -device "${DEV_NODE}" -ioctl getbootstatus ;;
  keepalive)     wdt_tests -device "${DEV_NODE}" -ioctl keepalive -loop "${LOOP}" ;;
  write)         wdt_tests -device "${DEV_NODE}" -ioctl -write -loop "${LOOP}" ;;
esac

test_print_trc "Disable Watchdog to avoid system reboot"
do_cmd "watchdog_test -d"

# AFTER TEST, WATCHDOG SERVICE SHOULD BE RESTARTED IN CASE OF DEVICE REBOOT
if [[ -n "${DUT_PID}" ]]; then
  test_print_trc "===Ioctl ${IOCTL} Finished,restart /sbin/watchdogd==="
  setsid /sbin/watchdogd &
  if [[ $? -eq 0 ]]; then
    test_print_trc "===/sbin/watchdogd restart successfully!==="
  fi
fi
