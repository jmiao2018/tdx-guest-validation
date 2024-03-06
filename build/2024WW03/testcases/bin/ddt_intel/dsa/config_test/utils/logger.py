#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import logging
import time


def init_logging(logname="Logger", level=logging.INFO):
    file_date = time.strftime('%m%d%H%M', time.localtime())
    logfile = '{}_{}.log'.format(logname, file_date)
    format_str = ('%(asctime)s %(module)s[line:%(lineno)d]'
                  '%(levelname)s %(message)s')
    time_str = '%m/%d/%Y %I:%M:%S %p'
    logging.basicConfig(level=level,
                        format=format_str,
                        datefmt=time_str,
                        filename=logfile,
                        filemode='a')


def add_console(logger, level=logging.INFO):
    console = logging.StreamHandler()
    console.setLevel(level)
    formatter = logging.Formatter('%(asctime)s %(module)s[line:%(lineno)d]'
                                  '%(levelname)s %(message)s')
    console.setFormatter(formatter)
    logger.addHandler(console)
