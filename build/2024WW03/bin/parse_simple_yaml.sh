#!/bin/bash
################################################################################
##                                                                            ##
## Copyright (c) Intel Corp., 2015                                            ##
##                                                                            ##
## This program is free software;  you can redistribute it and#or modify      ##
## it under the terms of the GNU General Public License as published by       ##
## the Free Software Foundation; either version 2 of the License, or          ##
## (at your option) any later version.                                        ##
##                                                                            ##
## This program is distributed in the hope that it will be useful, but        ##
## WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY ##
## or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License   ##
## for more details.                                                          ##
##                                                                            ##
## You should have received a copy of the GNU General Public License          ##
## along with this program;  if not, write to the Free Software Foundation,   ##
## Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA           ##
##                                                                            ##
################################################################################
## File:         parse_simple_yaml.sh                                         ##
##                                                                            ##
## Description:  This script parses 'simple' yaml file and convert key:value  ##
##               pairs to shell variables.                                    ##
##                                                                            ##
## Author:       Wenzhong Sun <wenzhong.sun@intel.com>                        ##
##                                                                            ##
## History:      Aug 28 2015 - Created - Wenzhong Sun                         ##
##                                                                            ##
################################################################################

parse_yaml()
{
	local prefix=$2
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
	sed -ne "s|^\($s\):|\1|" \
		-e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
	awk -F$fs '{
		indent = length($1)/2;
		vname[indent] = $2;
		for (i in vname) {if (i > indent) {delete vname[i]}}
			if (length($3) > 0) {
				vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
				printf("%s%s%s=%s\n", "'$prefix'",vn, $2, $3);
			}
	}'
}

parse_yaml $@
