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
# File: collect_system_information.py
#
# Description:  This script is used to collect system information.
#
# Authors:      Yahui Cheng - yahuix.cheng@intel.com
# History:      Sept 25 2019 - Created -  Yahui Cheng


import os
import sys
import json
import subprocess as sp
from hashlib import md5
from collections import OrderedDict


class Sysinfo(object):

    def __init__(self):
        self._property_cache = {}

    def _update_property_cache(self, key, value):
        try:
            self._property_cache[key] = value
        except Exception:
            print('unknown system information - {}'.format(key))

    @property
    def hash(self):
        od = OrderedDict(sorted(self._property_cache.items()))
        kv_list = [':'.join([key, value]) for key, value in od.items()]
        info = '\n'.join(kv_list)
        hash_obj = md5()
        hash_obj.update(info.encode('utf-8'))
        return hash_obj.hexdigest()

    @property
    def cpu_model_id(self):
        try:
            cmd = 'grep -E "model\s+:" -m1 /proc/cpuinfo | awk \'{print $3}\''
            rtv = sp.getoutput(cmd)
        except Exception:
            print("Fail to get cpu model id.")
            rtv = None

        if rtv is not None:
            self._update_property_cache('cpu_model_id', rtv)

        return rtv

    @property
    def logic_cpu(self):
        try:
            cmd = 'cat /proc/cpuinfo | grep processor | wc -l'
            rtv = sp.getoutput(cmd)
        except Exception:
            print("Fail to get logic cpu.")
            rtv = None

        if rtv is not None:
            self._update_property_cache('logic_cpu', rtv)

        return rtv

    @property
    def memory(self):
        try:
            cmd = 'dmidecode -t memory | grep -E \'Type:|Size:\' | \
                grep -Ev "Error Correction Type|No Module Installed|Unknow"'
            cmd_value = sp.getoutput(cmd).replace("\t", "").split("\n")
            for i in cmd_value:
                if i.startswith('Type'):
                    mem_type = i.split(":")[1].strip()
                    break
                elif i.startswith('Size'):
                    mem_size_info = i.split(":")[1].strip().split(" ")
                    mem_size = mem_size_info[0]
                    mem_size_unit = mem_size_info[1]
                    if 'MB' not in i:
                        mem_size = int(mem_size)
                        mem_size += mem_size
                    mem_size = str(mem_size)
            mem = ''.join([mem_type, '(', mem_size, mem_size_unit, ')'])
        except Exception:
            print("Fail to get memory value.")
            mem = None

        if mem is not None:
            self._update_property_cache('memory', mem)

        return mem

    @property
    def swap_size(self):
        try:
            cmd = 'free -h | tail -n2 | awk \'{print $2}\' | xargs'
            _swap_size = sp.getoutput(cmd).split()[1]
        except Exception:
            print("Fail to get swap size.")
            _swap_size = None

        if _swap_size is not None:
            self._update_property_cache('swap_size', _swap_size)

        return _swap_size

    @property
    def kernel_version(self):
        try:
            _kernel_version = sp.getoutput("uname -r")
        except Exception:
            print("Fail to get kernel version.")
            _kernel_version = None

        if _kernel_version is not None:
            self._update_property_cache('kernel_version', _kernel_version)

        return _kernel_version

    @property
    def bios(self):
        try:
            cmd = 'dmidecode -t bios\
                | grep Version | awk -F\": \" \'{print $2}\''
            _bios = sp.getoutput(cmd)
        except Exception:
            print("Fail to get bios version")
            _bios = None

        if _bios is not None:
            self._update_property_cache('bios', _bios)

        return _bios

    @property
    def kernel_cmdline(self):
        try:
            k_cmdline = sp.getoutput('cat /proc/cmdline')
        except Exception:
            print("Fail to get kernel cmdline.")
            k_cmdline = None

        if k_cmdline is not None:
            kcmdline_items = k_cmdline.split(" ")

            filtered_items = [
                item
                for item in kcmdline_items
                if not item.startswith("job")
                and not item.startswith("RESULT_ROOT")
            ]
            k_cmdline = " ".join(filtered_items)

            self._update_property_cache('kernel_cmdline', k_cmdline)

        return k_cmdline

    @property
    def OS(self):
        if sp.getstatusoutput('ls /etc/os-release')[0] == 0:
            os_raw = sp.getoutput('cat /etc/os-release')
        elif sp.getstatusoutput('ls /usr/lib/os-release')[0] == 0:
            os_raw = sp.getoutput('cat /usr/lib/os-release')
        else:
            print('Fail to get OS information.')
            os_raw = None

        if os_raw is None:
            _os = None
        else:
            try:
                for line in os_raw.split("\n"):
                    if 'PRETTY_NAME' in line:
                        _name = line.split('=')[1].replace('\"', '')
                    elif 'VERSION_ID' in line:
                        _version = line.split('=')[1].replace('\"', '')
                    else:
                        continue
                _os = '{}({})'.format(_name, _version)
            except Exception:
                print("Fail to get OS information")
                _os = None

        if _os is not None:
            self._update_property_cache('OS', _os)

        return _os

    @property
    def graphics(self):
        try:
            cmd = 'lspci | grep -i vga | awk -F \': \' \'{print $2}\''
            gra_version = sp.getoutput(cmd)
        except Exception:
            print("Fail to get graphics version")
            gra_version = None

        if gra_version is not None:
            self._update_property_cache('graphics', gra_version)

        return gra_version

    @property
    def motherboard(self):
        try:
            cmd = 'dmidecode | grep -A4 \'Base Board Information\''
            rtv = sp.getoutput(cmd).replace("\t", "").split("\n")
            mb_raw = [i for i in rtv if 'Product Name' in i]
            mb = ''.\
                join([mb_raw[0].split(':')[1].strip(), '(', self.bios, ')'])
        except Exception:
            print("Fail to get motherboard information.")
            mb = None

        if mb is not None:
            self._update_property_cache('motherboard', mb)

        return mb

    @property
    def compiler(self):
        try:
            gcc_exist = sp.getstatusoutput('which gcc')[0]
            if gcc_exist == 0:
                cmd = 'gcc -v 2>&1 | grep \'gcc version\''
                gcc_version = sp.getoutput(cmd).split('(')[0].strip()
            else:
                print('gcc does not exist.')
                gcc_version = None
        except Exception:
            print('Fail to get gcc information.')
            gcc_version = None

        if gcc_version is not None:
            self._update_property_cache('compiler', gcc_version)

        return gcc_version

    @property
    def cpu_version(self):
        try:
            cpu_version = sp.getoutput('dmidecode -s processor-version')
            cpu_version = cpu_version.split()
            cpu_version = " ".join(cpu_version)
        except Exception:
            print("cpu version does not exist.")
            cpu_version = None

        core_num = self.logic_cpu

        cmd = 'grep \'processor\' /proc/cpuinfo | sort -u | wc -l'
        try:
            thread_num = sp.getoutput(cmd)
        except Exception:
            print('thread num does not exist.')
            thread_num = None
        if cpu_version is None or core_num is None or thread_num is None:
            info = None
        else:
            info = ''.join(
                [cpu_version, '(', core_num,
                 ' Cores/', thread_num, ' Threads)']
            )

        if info is not None:
            self._update_property_cache('cpu_version', info)

        return info

    @property
    def disk_raw(self):
        try:
            cmd = 'lsblk | grep -E \' /$\' | awk \'{print $1}\''
            raw = sp.getoutput(cmd)
        except Exception:
            print("Fail to get disk information.")
            raw = None
        return raw

    @property
    def disk_type(self):
        disk_raw = self.disk_raw

        if disk_raw is None:
            _type = None
        else:
            dt_raw = disk_raw[2:]
            if dt_raw.startswith('sd'):
                _type = 'SATA'
            elif dt_raw.startswith('nvme'):
                _type = 'NVME'
            else:
                _type = None
                return None

        return _type

    @property
    def disk_size(self):
        disk_raw = self.disk_raw
        disk_type = self.disk_type

        if disk_type == 'SATA':
            rt = disk_raw[2:5]
        elif disk_type == 'NVME':
            rt = disk_raw[2:9]
        else:
            rt = None

        if rt is None:
            size = None
        else:
            try:
                cmd = 'lsblk | grep \'{} \''.format(rt)
                size = sp.getoutput(cmd).split()[3]
            except Exception:
                print("Fail to get disk size.")
                size = None
        return size

    @property
    def disk(self):
        try:
            _disk = ''.join([self.disk_type, '(', self.disk_size, ')'])
        except Exception:
            print("Fail to get disk information.")
            _disk = None

        if _disk is not None:
            self._update_property_cache('disk', _disk)

        return _disk

    @property
    def pch(self):
        try:
            raw = sp.getoutput('lspci | grep \'xHCI\'')
            _pch = raw.split(':')[2].split('USB')[0].strip()
        except Exception:
            print("Fail to get pch version.")
            _pch = None

        if _pch is not None:
            self._update_property_cache('pch', _pch)

        return _pch

    @property
    def perf_version(self):
        try:
            rtv = sp.getstatusoutput('perf -v')
            if rtv[0] != 0:
                perf_ver = None
                print("Fail to get perf version")
            else:
                perf_ver = rtv[1]
        except Exception:
            print("Fail to get perf version")
            perf_ver = None

        if perf_ver is not None:
            self._update_property_cache('perf_version', perf_ver)

        return perf_ver

    @property
    def microcode(self):
        try:
            cmd = 'grep microcode /proc/cpuinfo | head -n 1 | awk \'{print $3}\''
            output = sp.getoutput(cmd)
            self._update_property_cache('microcode', output)
            return output
        except Exception:
           return ''

    def json(self):
        sysinfos = {}
        info_list = [
            'cpu_model_id', 'logic_cpu', 'memory', 'swap_size',
            'kernel_version', 'bios', 'kernel_cmdline', 'OS',
            'graphics', 'motherboard', 'compiler', 'cpu_version',
            'disk', 'pch', 'perf_version', 'microcode'
        ]
        for item in info_list:
            if getattr(self, item) is not None:
                sysinfos[item] = getattr(self, item)
        data = {
            'data': sysinfos, "hash": self.hash
        }
        return data


def main():
    sysinfo = Sysinfo()

    try:
        dest_dir = sys.argv[1]
    except Exception:
        dest_dir = None

    if dest_dir is None:
        output = 'sysinfo.json'
    else:
        output = os.path.join(dest_dir, 'sysinfo.json')
    with open(output, 'w') as f:
        json.dump(sysinfo.json(), f, indent=4)


if __name__ == "__main__":
    main()
