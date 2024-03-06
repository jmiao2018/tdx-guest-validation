#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import logging
import os
import re
import sys
import time

CURRENT_DIR = os.path.dirname(os.path.realpath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
sys.path.insert(0, PARENT_DIR)
from utils import DsaConfigErr, ShellCommand, add_console

logger = logging.getLogger('driver_handler')
add_console(logger, level=logging.DEBUG)


class DriverHandler(object):
    def __init__(self, driver_name, total_dev_number=8):
        self._driver_name = driver_name
        self._debug_option = ""
        self._total_dev_number = total_dev_number

    def set_debug_option(self, option):
        self._debug_option = option

    def load_driver(self):
        cmd = "sudo modprobe {} {}".format(self._driver_name,
                                           self._debug_option)
        sh = ShellCommand(cmd)
        # force sleep to let driver ready
        time.sleep(1)
        return sh.is_passed()

    def unload_driver(self):
        cmd = "lsmod | grep -q iaa_crypto && rmmod iaa_crypto"
        sh = ShellCommand(cmd)
        cmd = "lsmod | grep -q iax_crypto && rmmod iax_crypto"
        sh = ShellCommand(cmd)
        cmd = "lsmod | grep -q idxd_vdev && rmmod idxd_vdev"
        sh = ShellCommand(cmd)
        cmd = "lsmod | grep -q idxd_mdev && rmmod idxd_mdev"
        sh = ShellCommand(cmd)
        cmd = "lsmod | grep -q idxd_uacce && rmmod idxd_uacce"
        sh = ShellCommand(cmd)
        cmd = "lsmod | grep -q {} && rmmod {}".format(self._driver_name,
                                                      self._driver_name)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def force_unload_driver(self):
        if not self.is_driver_loaded():
            return True
        if self.get_ref_count() > 0:
            self.disable_devices()
        ret = self.unload_driver()
        return ret

    def reload_driver(self):
        self.force_unload_driver()
        self.load_driver()

    def is_driver_loaded(self):
        cmd = "sudo lsmod | grep '^{} '".format(self._driver_name)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def get_ref_count(self):
        cmd = "sudo lsmod | grep '^{} '".format(self._driver_name)
        sh = ShellCommand(cmd)
        ret_line = sh.get_std_out()[0]
        if not ret_line:
            raise DsaConfigErr("Driver {} is not loaded"
                               .format(self._driver_name))
        pattern = '({})[ ]+([0-9]+)[ ]+([0-9]+)'.format(self._driver_name)
        m = re.search(pattern, ret_line)
        if m:
            return int(m.group(3))
        else:
            logger.debug("ret_line: {}".format(ret_line))
            raise DsaConfigErr("Driver {} is in unknown status"
                               .format(self._driver_name))

    def disable_devices(self, device_list=[]):
        if not device_list:
            device_list = range(0, self._total_dev_number)

        ret = True
        for dev_type in ('dsa', 'iax'):
            for index in device_list:
                if not self.is_device_enabled(dev_type, index):
                    continue

                cmd = "sudo accel-config disable-device {}{}" \
                      .format(dev_type, index)
                sh = ShellCommand(cmd)
                if sh.is_failed():
                    logger.error("Disable device failed: {}{}"
                                 .format(dev_type, index))
                    ret = False
        return ret

    def is_device_enabled(self, device_type, index):
        sysfs_path = "/sys/bus/{}/devices/{}{}/state" \
                     .format(device_type, device_type, index)
        if not os.path.exists(sysfs_path):
            return False

        sh = ShellCommand("cat {}".format(sysfs_path))
        if sh.is_failed():
            logger.error("Get status failed: dsa{}".format(index))
            return False
        if sh.get_std_out()[0] == "enabled":
            return True
        if sh.get_std_out()[0] == "disabled":
            return False
        raise DsaConfigErr("Device {}{} status unknown: {}"
                           .format(device_type, index, sh.get_std_out()))


if __name__ == "__main__":
    pass
