#!/bin/bash
#Copyright (C) 2015 Intel - http://www.intel.com
#Author:
#   Zelin Deng(zelinx.deng@intel.com)
#
#ChangeLog:
#   Jan 30th, 2015 - (Zelin) Created
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

source "../lib/lib-common.sh"
#Function: Verified if driver dose exsit
#Input: PATH of driver
#Output: 0 successfully 1 failed
function Verified_driver()
{
    local ret=""
    local drv_path=""
    local drv_name=""
    #verified the parameter's number
    if [ $# -ne 1 ];then
        PnL 2 It should be 1 parameter
        return 1
    fi

    #got the driver's path
    drv_path=$1
    #separeted by "/", get the last field
    drv_name=$(echo "${drv_path}" | awk -F/ '{print $NF}')
    ret=$(run_cmd 1 "test -d ${drv_path} && echo -n GOTYOU" )
    if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
        PnL 2 "${drv_name}" is registered
        return 0
    else
        PnL 2 "${drv_name}" is NOT registered
        return 1
    fi
}

#Function: Verified if device has been binded exsit
#Input: PATH of sysfs
#Output: 0 successfully 1 failed
function Verfied_sysfs()
{
    local ret=""
    local sysfs_path=""
    local dev_name=""
    #verified the parameter's number
    if [ $# -ne 1 ];then
        PnL 2 It should be 1 parameter
        return 1
    fi

    #got the driver's path
    sysfs_path=$1
    #separeted by "/", get the last field
    dev_name=$(echo "${sysfs_path}" | awk -F/ '{print $NF}')
    ret=$(run_cmd 1 "test -L ${sysfs_path} && echo -n GOTYOU" )
    if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
        PnL 2 "${dev_name}" is EXIST under "{sysfs_path}"
        return 0
    else
        PnL 2 "${dev_name}" is NOT EXIST under "${sysfs_path}"
        return 1
    fi
}

#Function: Verified if device is under driver's dir
#Input: $1 driver path $2 device name
#Output: 0 successfully 1 failed
function Verified_device
{
    local ret=""
    local drv_bind_path=""
    local dev_name=""
    if [ $# -ne 2 ];then
        PnL 2 It should be 2 parameters
        return 1
    fi

    #check if the device's symbolic link is under the driver path
    drv_bind_path=$1
    dev_name=$2
    ret=$(run_cmd 1 "test -L ${drv_bind_path}/${dev_name} && echo -n GOTYOU")

    if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
        PnL 2 "${dev_name}" is EXIST under "${drv_bind_path}"
        return 0
    else
        PnL 2 "${dev_name}" is NOT EXIST under "${drv_bind_path}"
        return 1
    fi

}
#Function: bind devices to their driver
#Input: $1 driver path $2 device name
#Output: 0 successfully 1 failed
function Bind_device()
{
    local ret=""
    local drv_bind_path=""
    local dev_name=""
    local drv_name=""
    local last_ts=""
    if [ $# -ne 2 ];then
        PnL 2 It should be 2 parameters
        return 1
    fi
    last_ts=$(run_cmd 1 "dmesg | tail -n 1 | \
            sed -e 's/\[/\n/g' -e 's/\]/\n/g' | sed -n '2p'")
    #got the parameter
    drv_bind_path=$1
    dev_name=$2
    drv_name=$(echo ${drv_bind_path} | awk -F/ '{print $NF}')
    Verified_device "${drv_bind_path}" "${dev_name}"
    if [ "$?" -eq "0" ]; then
        #has been exit unbind first
        run_cmd 1 "echo -n ${dev_name} > ${drv_bind_path}/unbind"
    fi
    run_cmd 1 "echo -n ${dev_name} > ${drv_bind_path}/bind"
    if [ $? -eq 0 ]; then
        PnL 0 "${dev_name}" is SUCCESSFULLY bound to  "${drv_name}"
        return 0
    else
        check_dmesg_error "${dev_name}" "${last_ts}"
        PnL 1 "${dev_name}" is FAILED bound to  "${drv_name}"
        RET=1
        return 1
    fi
}

#Function: bind devices to their driver
#Input: $1 driver path $2 device name
#Output: 0 successfully 1 failed
function Unbind_device()
{
    local ret=""
    local drv_bind_path=""
    local dev_name=""
    local drv_name=""
    if [ $# -ne 2 ];then
        PnL 2 It should be 2 parameters
        return 1
    fi

    #got the parameter
    drv_bind_path=$1
    dev_name=$2
    drv_name=$(echo ${drv_bind_path} | awk -F/ '{print $NF}')
    Verified_device "${drv_bind_path}" "${dev_name}"
    if [ "$?" -ne "0" ]; then
        #has been exit unbind first
        run_cmd 1 "echo -n ${dev_name} > ${drv_bind_path}/bind"
    fi
    run_cmd 1 "echo -n ${dev_name} > ${drv_bind_path}/unbind"
    if [ $? -eq 0 ]; then
        PnL 0 "${dev_name}" is SUCCESSFULLY unbound to  "${drv_name}"
        return 0
    else
        PnL 1 "${dev_name}" is FAILED unbound to  "${drv_name}"
        RET=1
        return 1
    fi
}

#Function: Verified if module dose exsit
#Input: module name
#Output: 0 successfully 1 failed
function Verified_mod()
{
    local ret=""
    local mod_name=""
    if [ $# -ne 1 ];then
        PnL 2 It should be 1 parameters
        return 1
    fi
    mod_name=$1
    ret=$(run_cmd 1 "lsmod | grep -q "${mod_name}" && echo GOTYOU")
    if [ -n "${ret}" -a "${ret}" = "GOTYOU" ];then
        PnL 2 "${mod_name}" is loaded
        return 0
    else
        PnL 2 "${mod_name}" is NOT loaded
        return 1
    fi
}

#Function: Load module
#Input: module name
#Output: 0 successfully 1 failed
function Load_mod()
{
    local ret=""
    local mod_name=""
    if [ $# -ne 1 ];then
        PnL 2 It should be 1 parameters
        return 1
    fi
    mod_name=$1
    mod_name="/system/lib/modules/${mod_name}.ko"
    run_cmd 1 "modprobe ${mod_name}"
    if [ $? -eq 0 ];then
        PnL 2 "${mod_name}" is loaded SUCCESSFULLY
        return 0
    else
        PnL 2 "${mod_name}" is loaded FAILED
        return 1
    fi
}

#Function: Remove module
#Input: module name
#Output: 0 successfully 1 failed
function Remove_mod()
{
    local ret=""
    local mod_name=""
    if [ $# -ne 1 ];then
        PnL 2 It should be 1 parameters
        return 1
    fi
    mod_name=$1
    #mod_name="/system/lib/modules/${mod_name.ko}"
    run_cmd 1 "rmmod ${mod_name}"
    if [ $? -eq 0 ];then
        PnL 2 "${mod_name}" is removed SUCCESSFULLY
        return 0
    else
        PnL 2 "${mod_name}" is removed FAILED
        return 1
    fi
}
