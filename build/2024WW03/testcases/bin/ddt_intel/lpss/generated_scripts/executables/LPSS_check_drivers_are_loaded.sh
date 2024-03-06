#!/bin/bash
#
# - linux
#
#   Copyright (c) Intel, 2015
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2.1 of the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
#
# File:         LPSS_check_drivers_are_loaded.sh
#
# Description:  Check if LPSS drivers are loaded.
#               As of 2015-07-17 the list of LPSS drivers to check is as follows:
#               - pci_drivers=("i2c-designware-pci" "sdhci-pci" "pxa2xx_spi_pci" "serial" "dw_dmac_pci")
#               - non_pci_drivers=("lp_gpio" "byt_gpio" "cherryview-pinctrl" "i2c_designware" "sdhci-acpi" "pxa2xx-spi" "dw-apb-uart" "dw_dmac")
#
# Author(s):    Helia Correia <helia.correia@intel.com>
#
# Date:         2015-07-17
#
#


# Final code result of test is PASS=0 / FAIL=1 / BLOCK=2
result=2


Usage()
{
    cat <<-EOF

    Usage: ./`basename $0` [DRIVER] [PCI_DRIVER]

    [DRIVER]            Mandatory paramter:
                        - the name of the driver to check

    [PCI_DRIVER]        Optional parameter:
                        - whether or not the driver is plugged to PCI bus

    Examples:
    ./`basename $0` lp_gpio
    ./`basename $0` sdhci-pci pci_driver

EOF
}


Check_pci_driver_is_loaded()
{
    result=`ls /sys/bus/pci/drivers/ | grep -x ${driver}` # force PATTERN to match only whole lines i.e. exact match of driver name
    [[ ${result} ]] && return 0 || return 1 # if $result is not empty then test is 0 or PASS else test is 1 or FAIL
}


Check_non_pci_driver_is_loaded()
{
    result=`ls /sys/bus/platform/drivers/ | grep -x ${driver}` # force PATTERN to match only whole lines i.e. exact match of driver name
    [[ ${result} ]] && return 0 || return 1
}


if [ ${#} -eq 0 ] || [ ${#} -gt 2 ]; then
    Usage
else
    driver=$1
    if [ ${#} -eq 2 ]; then
        if [ ${2} != "pci_driver" ]; then
            echo "Wrong optional parameter, expected value is \"pci_driver\"."
        else
            Check_pci_driver_is_loaded
            result=$?
        fi
    else
        Check_non_pci_driver_is_loaded
        result=$?
    fi
fi


exit $result
