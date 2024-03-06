#!/bin/bash
#
################################################################################
##                                                                            ##
## Copyright (c) Intel, 2014                                                  ##
##                                                                            ##
################################################################################
#
# File:
#	get_i2c_acpi_alias.sh
#
# Description:
#	Get i2c acpi alias according $MACHINE
#
#-----------------------------------------------------------------------
#please check the return value(1 or 0) to determine it's successful or failed but
#not check if the string is empty or not.

i2c_acpi_alias_list=""

case "${MACHINE}" in
	t100)
		i2c_acpi_alias_list="80860F41"
	;;
	rvp)
		i2c_acpi_alias_list="INT3432 INT3433"
	;;
	nuc5i5ryh|rvp-skly03|rvp-kbly|rvp-kblu|rvp-kblr|rvp-skls06|rvp-bxt)
		#no i2c_devices on nuc5i5ryh and rvp_skly03
		i2c_acpi_alias_list=""
	;;
	*)
		exit 1
	;;
esac

echo "$i2c_acpi_alias_list"
exit 0

