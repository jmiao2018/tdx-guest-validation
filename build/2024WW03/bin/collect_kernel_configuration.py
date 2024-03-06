#!/usr/bin/env python3
#
# Copyright (c) 2019, Intel Corporation.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
#
#
# File: collect_kernel_configuration.py
#
# Description:  This script is used to collect kernel configuration
#
# Authors:      Yahui Cheng - yahuix.cheng@intel.com

import os
import sys
import json
import subprocess as sp
from hashlib import md5


class Kconfig:

    @property
    def collect_kconfig(self):
        try:
            cmd = 'grep -E \"^ID=\" /usr/lib/os-release \
                    | awk -F\"=\" \'{print $2}\''
            release = sp.getoutput(cmd)
        except Exception:
            print("Kernel version does not exist.")
            return release

        if release == 'clear-linux-os':
            try:
                cmd = 'cat /lib/kernel/config-$(uname -r)'
                _kconfig = sp.getoutput(cmd)
            except Exception:
                print("Fail to get kernel configuration in Clear Linux.")
                _kconfig = None
        elif release in ['ubuntu', '"centos"']:
            try:
                cmd = 'cat /boot/config-$(uname -r)'
                _kconfig = sp.getoutput(cmd)
            except Exception:
                print("Fail to get Kernel configuration in Ubuntu.")
                _kconfig = None
        elif release == 'debian':
            try:
                cmd = 'gunzip -c /proc/config.gz'
                _kconfig = sp.getoutput(cmd)
            except Exception:
                print("Fail to get kernel configuration in debian.")
                _kconfig = None
        else:
            print('Target OS not recognized: {}'.format(release))
            _kconfig = None

        kconfig_list = _kconfig.split("\n")
        kernel_config = []
        try:
            for line in kconfig_list:
                if line != "" and not line.startswith("#"):
                    kernel_config.append(line)
                    kernel_config = sorted(kernel_config)
        except Exception:
            print("Fail to traverse list.")
            kernel_config = None

        return kernel_config

    @property
    def hash(self):
        hash_obj = md5()
        info = "\n".join(self.collect_kconfig)
        hash_obj.update(info.encode('utf-8'))
        hash_code = hash_obj.hexdigest()
        return hash_code

    def json(self):
        data = {
            "data": self.collect_kconfig,
            "hash": self.hash
        }
        return data


def main():
    kernel_c = Kconfig()
    try:
        dest_dir = sys.argv[1]
    except Exception:
        dest_dir = None

    if dest_dir is None:
        output = 'kconfig.json'
    else:
        output = os.path.join(dest_dir, 'kconfig.json')
    with open(output, 'w') as f:
        json.dump(kernel_c.json(), f, indent=4)


if __name__ == "__main__":
    main()
