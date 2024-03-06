#!/bin/bash

# CHECK TEST ENVIRONMENT
check_rtc_test_env()
{
	which date &> /dev/null
	[ $? -eq 0 ] || die "date is not in current environment"
	which hwclock &> /dev/null
	[ $? -eq 0 ] || die "hwclock is not in current environment"
}

# EXPORT PATHS USED FOR TESTS
export PROC_RTC="/proc/driver/rtc"
export SYS_RTC="/sys/class/rtc/rtc0"
export ALARM="/sys/class/rtc/rtc0/wakealarm"

# ARRAY/HASH
declare -a ATTRIBUTE=('date' 'dev' 'name' 'max_user_freq' 'since_epoch' 'time' 'uevent' 'wakealarm' 'hctosys')
