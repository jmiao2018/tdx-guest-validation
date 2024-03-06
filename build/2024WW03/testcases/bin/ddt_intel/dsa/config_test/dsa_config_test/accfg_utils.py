#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import logging
import os
import random as rd
import string
import sys
import tempfile

CURRENT_DIR = os.path.dirname(os.path.realpath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
sys.path.insert(0, PARENT_DIR)
from utils import DsaConfigErr, ShellCommand, add_console

logger = logging.getLogger('accfg_utils')
add_console(logger, level=logging.INFO)

rd.seed()


class AccfgUtils(object):
    def random_tmp_file(self):
        _, temp_file_name = tempfile.mkstemp(prefix='accfg_config_',
                                             suffix='.conf')
        return temp_file_name

    def save_config(self, config_path=""):
        if not config_path:
            config_path = self.random_tmp_file()
        logger.info("Accfg saving config to {}".format(config_path))

        cmd = "accel-config save-config -s {}".format(config_path)
        sh = ShellCommand(cmd)
        if sh.is_failed():
            raise DsaConfigErr("Save config file failed!")
        return config_path

    def load_config(self, config_path):
        logger.debug("Accfg loading config from {}".format(config_path))

        if not os.path.isfile(config_path):
            raise DsaConfigErr("Config file {} does not exist"
                               .format(config_path))

        cmd = "accel-config load-config -v -c {}".format(config_path)
        sh = ShellCommand(cmd)
        if sh.is_failed():
            logger.error("Load config file {} failed!".format(config_path))
            return False
        return True


if __name__ == "__main__":
    pass
