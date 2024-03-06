#!/usr/bin/env python3
# -*- coding: utf-8 -*-

###############################################################################
#                                                                             #
# Copyright (c) 2018, Intel Corporation.                                      #
#                                                                             #
# This program is free software; you can redistribute it and/or modify it     #
# under the terms and conditions of the GNU General Public License,           #
# version 2, as published by the Free Software Foundation.                    #
#                                                                             #
# This program is distributed in the hope it will be useful, but WITHOUT      #
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or       #
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for   #
# more details.                                                               #
###############################################################################
#
# File:         scenario_generator.sh
#
# Description:  LTP DDT Scenario File Generator
#
# Authors:      Jerry C. Wang - jerry.c.wang@intel.com
#
# History:      Jan 09 2018 - Created - Jerry C. Wang
#               - First release

import subprocess
import argparse
import sys
import os


class ScenarioGenerator(object):

    def __init__(self, output):
        cwd = os.path.dirname(os.path.abspath(__file__))
        self.ltp_path = cwd + '/../runtest/ddt_intel'
        self.scn_files = {}
        self.output = output

    def run_command(self, cmd):
        ''' Execute Linux shell command from python.

        Parameters
        ----------
        cmd : Linux shell command

        Returns
        -------
        ret : list
            List of string containing standard output
        '''

        p = subprocess.Popen(cmd,
                             stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE,
                             shell=True)
        out, err = p.communicate()
        if p.returncode == 0:
            return list(map(lambda x: x.decode('UTF-8'), out.splitlines()))
        else:
            return []

    def add_scenario_files(self, tc_list):
        ''' Scan across ltp-ddt scenario set and extract command if found

        Parameters
        ----------
        tc_list: list
            list containing test case IDs
        '''

        for tc in tc_list:
            cmd = 'grep -rwn {} -e {}'.format(self.ltp_path, tc)
            ret = self.run_command(cmd)
            if ret:
                p, l, c = ret[0].split(':', 2)
                f = os.path.basename(p)
                if f not in self.scn_files:
                    self.scn_files[f] = []
                    cmd = "egrep \"@\w+\" {}".format(p)
                    headers = self.run_command(cmd)
                    self.scn_files[f] += headers
                self.scn_files[f].append(c)

    def to_files(self):
        ''' Writing new scenario file to disk '''

        for scn in self.scn_files:
            scn_file = open(os.path.join(self.output, scn), 'w')
            scn_file.write('\n'.join(self.scn_files[scn]))
            scn_file.write('\n')
            scn_file.close()


def main():
    parser = argparse.ArgumentParser(description='Scenario File Generator.')
    parser.add_argument('filenames', metavar='FILES', type=str, nargs='+',
                        help='Files contain test case ID list')
    parser.add_argument('-o', '--output', type=str, default='',
                        help='Folder to store new scenario files')
    parser.add_argument('-f', '--folder', type=str, default='',
                        help='Folder contains test case ID list')
    args = parser.parse_args()

    scn = ScenarioGenerator(args.output)
    for f in args.filenames:
        try:
            with open(os.path.join(args.folder, f)) as fp:
                tc_list = fp.read().splitlines()
            scn.add_scenario_files(tc_list)
        except FileNotFoundError:
            parser.print_help()
            exit(2)

    scn.to_files()


if __name__ == "__main__":
    main()
