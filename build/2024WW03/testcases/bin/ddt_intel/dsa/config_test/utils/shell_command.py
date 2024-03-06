#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import subprocess
import logging

from .logger import add_console

logger = logging.getLogger('shell_command')
add_console(logger, level=logging.WARNING)


class ShellCommand(object):

    def __init__(self, command, input_str=""):
        self.ret_code = -1
        self.__exec_shell_cmd(command, input_str)

    def __exec_shell_cmd(self, command, input_str):
        '''
        Execute the shell command in a subprocess

        Parameters:
        -----------
        command: str
            Shell command to be executed
        input_str: str (Optional, Default: "")
            Input string used to execute command
        '''
        if not command:
            logger.error("Command cannot be empty!")
            return

        p = subprocess.Popen(command,
                             stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE,
                             shell=True)
        (self.out, self.err) = p.communicate(input=input_str.encode('utf-8'))
        self.ret_code = p.returncode

        logger.debug("Run shell command - \"%s\" - Return Code: %s",
                     command, self.ret_code)

        if self.is_failed():
            logger.warning('Fail to execute shell command: {}'.format(command))
            logger.warning("Std out:\n" + self.out.decode('UTF-8'))
            logger.warning("Std err:\n" + self.err.decode('UTF-8'))

    def get_std_out(self):
        '''
        Get the standard output from Shell Command

        Returns:
        --------
        ret: [str]
            List of the standard output string splitted by new line character
            [""] if the standard output is empty
        '''
        std_out = list(map(lambda x: x.decode('UTF-8'), self.out.splitlines()))
        if not std_out:
            std_out.append("")
        return std_out

    def get_std_err(self):
        '''
        Get the standard error from Shell Command

        Returns:
        --------
        ret: [str]
            List of standard error string splitted by new line character
            [""] if the standard output is empty
        '''
        std_err = list(map(lambda x: x.decode('UTF-8'), self.err.splitlines()))
        if not std_err:
            std_err.append("")
        return std_err

    def get_ret_code(self):
        '''
        Get the return code from the shell command run.

        Returns:
        --------
        ret: int
            0 if success and non-zero otherwise.
        '''
        return self.ret_code

    def is_passed(self):
        '''
        Check if the shell command has passed

        Returns:
        --------
        ret: bool
            true if success and false otherwise.
        '''
        return self.ret_code == 0

    def is_failed(self):
        '''
        Check if the shell command has failed

        Returns:
        --------
        ret: bool
            true if failed and false otherwise.
        '''
        return self.ret_code != 0
