#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import argparse
import functools
import logging
import os
import random as rd
import sys
import time
import unittest

from dsa_config_test import AccfgUtils, DriverHandler, DsaConfigs, IaxConfigs
from utils import ShellCommand, add_console, init_logging

logger = logging.getLogger('dsa_config_test')
init_logging('dsa_config_test', level=logging.DEBUG)
add_console(logger, level=logging.DEBUG)

CURRENT_DIR = os.path.dirname(os.path.realpath(__file__))
DSA_USER_CONFIG_DIR = os.path.join(CURRENT_DIR, 'dsa_config_test/dsa_configs')
IAX_USER_CONFIG_DIR = os.path.join(CURRENT_DIR, 'dsa_config_test/iax_configs')


def log_func_name(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        logger.info('*' * 60)
        logger.info(func.__name__)
        return func(*args, **kwargs)
    return wrapper


class IdxdConfigTest(unittest.TestCase):
    @log_func_name
    def setUp(self):
        self._driver_handler = DriverHandler('idxd')
        self._driver_handler.set_debug_option('dyndbg=+p')
        self._driver_handler.reload_driver()
        self.assertTrue(self._driver_handler.is_driver_loaded())

        self._valid_config = os.path.join(self.get_config_dir(), "valid",
                                          "2g2q_user_1.conf")
        self.assertTrue(os.path.isfile(self._valid_config))
        self._invalid_config = os.path.join(self.get_config_dir(), "invalid",
                                            "2g2q_user_inv_traffic_class.conf")
        self.assertTrue(os.path.isfile(self._invalid_config))

    @log_func_name
    def tearDown(self):
        self._driver_handler.force_unload_driver()

    @log_func_name
    def test_bat_load_unload(self):
        self.assertTrue(self._driver_handler.load_driver())
        self.assertGreaterEqual(self._driver_handler.get_ref_count(), 0)
        self.assertTrue(self._driver_handler.unload_driver())

    @log_func_name
    def test_stress_load_unload(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self.test_bat_load_unload()

    @log_func_name
    def test_bat_check_sysfs_device_permission(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs)
        self.assertTrue(dsa_configs.check_permission())

    @log_func_name
    def test_bat_check_sysfs_driver_permission(self):
        sysfs_nodes = self.get_sysfs_nodes()
        for sysfs_node in sysfs_nodes:
            logger.debug("Checking {}".format(sysfs_node))
            perm = oct(os.stat(sysfs_node).st_mode & 0o777)[-3:]
            self.assertEqual(perm, '200')

    @log_func_name
    def test_bat_check_device_number(self):
        dsa_configs = self.new_idxd_config()
        dsa_configs.read_from_system()

        pci_id = self.get_pci_id()
        cmd = 'lspci | grep {} | wc -l'.format(pci_id)
        sh = ShellCommand(cmd)
        device_num = int(sh.get_std_out()[0])

        self.assertEqual(device_num * 2, dsa_configs.count_devices())
        self.assertEqual(device_num * 2 * dsa_configs.get_max_groupes_pre_device(),
                         dsa_configs.count_groups())
        self.assertEqual(device_num * 2 * dsa_configs.get_max_wqs_pre_device(),
                         dsa_configs.count_wqs())
        #self.assertEqual(device_num * 2 * dsa_configs.get_max_engines_pre_device(),
        #                dsa_configs.count_engines())

    @log_func_name
    def test_func_check_sysfs_group_pairing(self):
        sh = ShellCommand('sudo accel-config load-config -c {}'
                          .format(self._valid_config))
        self.assertTrue(sh.is_passed())

        dsa_configs = self.new_idxd_config()
        dsa_configs.read_from_system()

        self.assertTrue(dsa_configs.check_groups_pairing())

    @log_func_name
    def test_func_write_config_to_sysfs(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.write_to_sysfs())

    @log_func_name
    def test_neg_write_config_to_sysfs_inactive_field(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.test_no_writable_sysfs())

    @log_func_name
    def test_neg_write_config_to_sysfs_invaild_value(self):
        dsa_configs = self.idxd_config_from_invalid_file()
        self.assertFalse(dsa_configs.write_to_sysfs())

    @log_func_name
    def test_func_write_config_accfg_short(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.write_to_accfg(short_cmd=True))

    @log_func_name
    def test_neg_write_config_accfg_short_inactive_field(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.test_no_writable_accfg(short_cmd=True))

    @log_func_name
    def test_neg_write_config_accfg_short_invalid_value(self):
        dsa_configs = self.idxd_config_from_invalid_file()
        self.assertFalse(dsa_configs.write_to_accfg(short_cmd=True))

    @log_func_name
    def test_func_write_config_accfg_long(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.write_to_accfg(short_cmd=False))

    @log_func_name
    def test_neg_write_config_accfg_long_inactive_field(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.test_no_writable_accfg(short_cmd=False))

    @log_func_name
    def test_neg_write_config_accfg_long_invalid_value(self):
        dsa_configs = self.idxd_config_from_invalid_file()
        self.assertFalse(dsa_configs.write_to_accfg(short_cmd=False))

    @log_func_name
    def test_func_write_config_accfg_file(self):
        cmd = "sudo accel-config load-config -c {}".format(self._valid_config)
        sh = ShellCommand(cmd)
        self.assertTrue(sh.is_passed())

    @log_func_name
    def test_neg_write_config_accfg_file_invalid_value(self):
        cmd = "sudo accel-config load-config -c {}"\
              .format(self._invalid_config)
        sh = ShellCommand(cmd)
        self.assertTrue(sh.is_failed())

    @log_func_name
    def test_neg_write_config_accfg_short_no_driver(self):
        self.assertTrue(self._driver_handler.force_unload_driver())
        dsa_configs = self.idxd_config_from_file()
        self.assertFalse(
            dsa_configs.write_to_accfg(short_cmd=True, readback=False))

    @log_func_name
    def test_neg_write_config_accfg_long_no_driver(self):
        self.assertTrue(self._driver_handler.force_unload_driver())
        dsa_configs = self.idxd_config_from_file()
        self.assertFalse(
            dsa_configs.write_to_accfg(short_cmd=False, readback=False))

    @log_func_name
    def test_neg_write_config_accfg_file_no_driver(self):
        self.assertTrue(self._driver_handler.force_unload_driver())
        cmd = "sudo accel-config load-config -c {}".format(self._valid_config)
        sh = ShellCommand(cmd)
        self.assertFalse(sh.is_passed())

    @log_func_name
    def test_func_bind_unbind_sysfs(self):
        dsa_configs = self.idxd_config_from_file()

        self.assertTrue(dsa_configs.write_to_sysfs())
        self.assertFalse(dsa_configs.enable_wqs_by_sysfs())
        self.assertFalse(dsa_configs.disable_wqs_by_sysfs())
        self.assertFalse(dsa_configs.disable_devices_by_sysfs())

        self.assertTrue(dsa_configs.write_to_sysfs())
        self.assertTrue(dsa_configs.enable_devices_by_sysfs())
        self.assertTrue(dsa_configs.enable_wqs_by_sysfs())
        self.assertTrue(dsa_configs.disable_wqs_by_sysfs())
        self.assertTrue(dsa_configs.disable_devices_by_sysfs())

        self.assertTrue(dsa_configs.write_to_sysfs())
        self.assertTrue(dsa_configs.enable_devices_by_sysfs())
        self.assertTrue(dsa_configs.enable_wqs_by_sysfs())
        self.assertTrue(dsa_configs.disable_devices_by_sysfs())

        self.assertTrue(dsa_configs.write_to_sysfs())
        self.assertTrue(dsa_configs.enable_devices_by_sysfs())
        self.assertTrue(dsa_configs.disable_devices_by_sysfs())

    @log_func_name
    def test_func_bind_unbind_accfg(self):
        dsa_configs = self.idxd_config_from_file()

        self.assertTrue(dsa_configs.write_to_accfg())
        self.assertFalse(dsa_configs.enable_wqs_by_accfg())
        self.assertFalse(dsa_configs.disable_wqs_by_accfg())
        self.assertFalse(dsa_configs.disable_devices_by_accfg())

        self.assertTrue(dsa_configs.write_to_accfg())
        self.assertTrue(dsa_configs.enable_devices_by_accfg())
        self.assertTrue(dsa_configs.enable_wqs_by_accfg())
        self.assertTrue(dsa_configs.disable_wqs_by_accfg())
        self.assertTrue(dsa_configs.disable_devices_by_accfg())

        self.assertTrue(dsa_configs.write_to_accfg())
        self.assertTrue(dsa_configs.enable_devices_by_accfg())
        self.assertTrue(dsa_configs.enable_wqs_by_accfg())
        self.assertTrue(dsa_configs.disable_devices_by_accfg())

        self.assertTrue(dsa_configs.write_to_accfg())
        self.assertTrue(dsa_configs.enable_devices_by_accfg())
        self.assertTrue(dsa_configs.disable_devices_by_accfg())

    @log_func_name
    def test_stress_bind_unbind_sysfs(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self.test_func_bind_unbind_sysfs()

    @log_func_name
    def test_stress_bind_unbind_accfg(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self.test_func_bind_unbind_accfg()

    @log_func_name
    def test_func_compare_accfg_file(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.loaded_file_by_accfg())

        self.assertTrue(dsa_configs.enable_devices_by_accfg())
        self.assertTrue(dsa_configs.enable_wqs_by_accfg())

        saved_config = AccfgUtils().save_config()
        dsa_configs_saved = self.new_idxd_config()
        dsa_configs_saved.load_from_file(saved_config)

        dsa_configs_sysfs = self.new_idxd_config()
        dsa_configs_sysfs.read_from_system()

        try:
            self.assertTrue(dsa_configs_saved.is_part_of(dsa_configs_sysfs))
        except AssertionError as e:
            logger.debug("idxd_configs_saved: {}"
                         .format(dsa_configs_saved.to_json()))
            logger.debug("idxd_configs_sysfs: {}"
                         .format(dsa_configs_sysfs.to_json()))
            raise e

    @log_func_name
    def test_func_compare_accfg_cmd(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.write_to_accfg(short_cmd=False))

        self.assertTrue(dsa_configs.enable_devices_by_accfg())
        self.assertTrue(dsa_configs.enable_wqs_by_accfg())

        saved_config = AccfgUtils().save_config()
        dsa_configs_saved = self.new_idxd_config()
        dsa_configs_saved.load_from_file(saved_config)

        dsa_configs_sysfs = self.new_idxd_config()
        dsa_configs_sysfs.read_from_system()

        self.assertTrue(dsa_configs_saved.is_part_of(dsa_configs_sysfs))

    @log_func_name
    def test_func_compare_sysfs(self):
        dsa_configs = self.idxd_config_from_file()
        self.assertTrue(dsa_configs.write_to_sysfs())

        self.assertTrue(dsa_configs.enable_devices_by_sysfs())
        self.assertTrue(dsa_configs.enable_wqs_by_sysfs())

        saved_config = AccfgUtils().save_config()
        dsa_configs_saved = self.new_idxd_config()
        dsa_configs_saved.load_from_file(saved_config)

        dsa_configs_sysfs = self.new_idxd_config()
        dsa_configs_sysfs.read_from_system()

        self.assertTrue(dsa_configs_saved.is_part_of(dsa_configs_sysfs))

    @log_func_name
    def test_func_load_save_accfg(self):
        accfg_utils = AccfgUtils()
        original_config_path = self._valid_config
        logger.debug("original config path: {}".format(original_config_path))

        original_config = self.new_idxd_config()
        original_config.load_from_file(original_config_path)

        self.assertTrue(accfg_utils.load_config(original_config_path))
        self.assertTrue(original_config.enable_devices_by_accfg())
        self.assertTrue(original_config.enable_wqs_by_accfg())

        saved_config_path = accfg_utils.save_config()
        logger.debug("saved config path: {}".format(saved_config_path))
        self.assertTrue(os.path.isfile(saved_config_path))

        # remove ungrouped items by load the config again
        saved_config = self.new_idxd_config()
        saved_config.load_from_file(saved_config_path)

        self.assertTrue(original_config.is_part_of(saved_config))

    @log_func_name
    def test_stress_fuzzing_accfg(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self._driver_handler.reload_driver()

            dsa_configs = self.idxd_config_from_file()

            fuzz_fields = rd.randint(1, 3)
            for _ in range(fuzz_fields):
                dsa_configs.fuzz_valid()

            dsa_configs.write_to_accfg()
            enable_ret = dsa_configs.enable_devices_by_accfg()
            dsa_configs.enable_wqs_by_accfg()
            if enable_ret:
                self.assertGreaterEqual(self._driver_handler.get_ref_count(), 0)
            dsa_configs.disable_devices_by_accfg()
            self.assertEqual(self._driver_handler.get_ref_count(), 0)

            self.assertTrue(self._driver_handler.unload_driver())
            time.sleep(1)

    @log_func_name
    def test_stress_fuzzing_negative_accfg(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self._driver_handler.reload_driver()

            dsa_configs = self.idxd_config_from_file()

            fuzz_fields = rd.randint(1, 3)
            for _ in range(fuzz_fields):
                dsa_configs.fuzz_invalid()

            dsa_configs.write_to_accfg()
            enable_ret = dsa_configs.enable_devices_by_accfg()
            dsa_configs.enable_wqs_by_accfg()
            if enable_ret:
                self.assertGreaterEqual(self._driver_handler.get_ref_count(), 0)
            dsa_configs.disable_devices_by_accfg()
            self.assertEqual(self._driver_handler.get_ref_count(), 0)

            self.assertTrue(self._driver_handler.unload_driver())
            time.sleep(1)

    @log_func_name
    def test_stress_fuzzing_sysfs(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self._driver_handler.reload_driver()

            dsa_configs = self.idxd_config_from_file()

            fuzz_fields = rd.randint(1, 3)
            for _ in range(fuzz_fields):
                dsa_configs.fuzz_valid()

            self.assertTrue(dsa_configs.write_to_sysfs())
            enable_ret = dsa_configs.enable_devices_by_sysfs()
            dsa_configs.enable_wqs_by_sysfs()
            if enable_ret:
                self.assertGreaterEqual(self._driver_handler.get_ref_count(), 0)
            dsa_configs.disable_devices_by_sysfs()
            self.assertEqual(self._driver_handler.get_ref_count(), 0)

            self.assertTrue(self._driver_handler.unload_driver())
            time.sleep(1)

    @log_func_name
    def test_stress_fuzzing_negative_sysfs(self, iter=20):
        for i in range(iter):
            logger.info("Iteration {}".format(i))
            self._driver_handler.reload_driver()

            dsa_configs = self.idxd_config_from_file()

            fuzz_fields = rd.randint(1, 3)
            for _ in range(fuzz_fields):
                dsa_configs.fuzz_invalid()

            dsa_configs.write_to_sysfs()
            enable_ret = dsa_configs.enable_devices_by_sysfs()
            dsa_configs.enable_wqs_by_sysfs()
            if enable_ret:
                self.assertGreaterEqual(self._driver_handler.get_ref_count(), 0)
            dsa_configs.disable_devices_by_sysfs()
            self.assertEqual(self._driver_handler.get_ref_count(), 0)

            self.assertTrue(self._driver_handler.unload_driver())
            time.sleep(1)


class DsaConfigTest(IdxdConfigTest):
    def get_config_dir(self):
        return DSA_USER_CONFIG_DIR

    def get_pci_id(self):
        return '0b25'

    def get_sysfs_nodes(self):
        return ['/sys/bus/dsa/drivers/idxd/bind',
                '/sys/bus/dsa/drivers/idxd/unbind',
                '/sys/bus/dsa/drivers/user/bind',
                '/sys/bus/dsa/drivers/user/unbind',
                '/sys/bus/dsa/drivers/dmaengine/bind',
                '/sys/bus/dsa/drivers/dmaengine/unbind']

    def idxd_config_from_file(self):
        json_name = os.path.splitext(self._valid_config)[-1]
        idxd_configs = DsaConfigs(json_name.split(".")[0])
        idxd_configs.load_from_file(self._valid_config)
        return idxd_configs

    def idxd_config_from_invalid_file(self):
        json_name = os.path.splitext(self._invalid_config)[-1]
        idxd_configs = DsaConfigs(json_name.split(".")[0])
        idxd_configs.load_from_file(self._invalid_config)
        return idxd_configs

    def new_idxd_config(self):
        return DsaConfigs()


class IaxConfigTest(IdxdConfigTest):
    def get_config_dir(self):
        return IAX_USER_CONFIG_DIR

    def get_pci_id(self):
        return '0cfe'

    def get_sysfs_nodes(self):
        return ['/sys/bus/dsa/drivers/idxd/bind',
                '/sys/bus/dsa/drivers/idxd/unbind',
                '/sys/bus/dsa/drivers/user/bind',
                '/sys/bus/dsa/drivers/user/unbind',
                '/sys/bus/dsa/drivers/dmaengine/bind',
                '/sys/bus/dsa/drivers/dmaengine/unbind']

    def idxd_config_from_file(self):
        json_name = os.path.splitext(self._valid_config)[-1]
        idxd_configs = IaxConfigs(json_name.split(".")[0])
        idxd_configs.load_from_file(self._valid_config)
        return idxd_configs

    def idxd_config_from_invalid_file(self):
        json_name = os.path.splitext(self._invalid_config)[-1]
        idxd_configs = IaxConfigs(json_name.split(".")[0])
        idxd_configs.load_from_file(self._invalid_config)
        return idxd_configs

    def new_idxd_config(self):
        return IaxConfigs()


def run_test(device, test_names):
    runner = unittest.TextTestRunner()
    suite = unittest.TestSuite()

    for test_name in test_names:
        logger.info('Adding test test {} to suite'.format(test_name))
        try:
            if device == 'dsa':
                suite.addTest(DsaConfigTest(test_name))
            elif device == 'iax':
                suite.addTest(IaxConfigTest(test_name))
            else:
                logger.error('Invalid device type {}'.format(device))
                raise ValueError('Invalid device type')
        except ValueError:
            logger.error('Test {} not found'.format(test_name))
            sys.exit(1)

    logger.info('Running tests')
    result = runner.run(suite)
    if not result.wasSuccessful():
        sys.exit(1)
    sys.exit(0)


def discovery_test_names(device, run_type):
    test_names = []
    loader = unittest.TestLoader()
    if run_type == "all":
        loader.testMethodPrefix = "test"
    elif run_type == "bat":
        loader.testMethodPrefix = "test_bat"
    elif run_type == "func":
        loader.testMethodPrefix = "test_func"
    elif run_type == "neg":
        loader.testMethodPrefix = "test_neg"
    elif run_type == "stress":
        loader.testMethodPrefix = "test_stress"
    else:
        return

    if device == 'dsa':
        test_names = loader.getTestCaseNames(DsaConfigTest)
    elif device == 'iax':
        test_names = loader.getTestCaseNames(IaxConfigTest)
    else:
        logger.error("unknown device type {}".format(device))

    return test_names


def parse_args():
    test_names = []
    parser = argparse.ArgumentParser()
    parser.add_argument('test_name', nargs='*')
    parser.add_argument('-d', '--device', default="dsa",
                        help='dsa/iax')
    parser.add_argument('-a', '--all', action='store_true',
                        help='run all tests')
    parser.add_argument('-b', '--bat', action='store_true',
                        help='run bat tests')
    parser.add_argument('-f', '--func', action='store_true',
                        help='run function tests')
    parser.add_argument('-n', '--neg', action='store_true',
                        help='run negative tests')
    parser.add_argument('-s', '--stress', action='store_true',
                        help='run stress tests')
    parser.add_argument('-l', '--list', action='store_true',
                        help='list all tests')
    args = parser.parse_args()

    device = args.device.lower()

    if args.list:
        test_names = discovery_test_names(device, 'all')
        for test in test_names:
            print(test)
        exit(0)
    if args.all:
        test_names = discovery_test_names(device, 'all')
    if args.test_name:
        test_names = args.test_name
    if args.bat:
        test_names = test_names + discovery_test_names(device, 'bat')
    if args.func:
        test_names = test_names + discovery_test_names(device, 'func')
    if args.neg:
        test_names = test_names + discovery_test_names(device, 'neg')
    if args.stress:
        test_names = test_names + discovery_test_names(device, 'stress')

    return args.device.lower(), set(test_names)


def main():
    if os.geteuid() != 0:
        logger.warning("This program must be run as root.")
        exit(1)
    device, test_names = parse_args()
    logger.info('Device type: {}'.format(device))
    logger.info('Number of test cases : {}'.format(len(test_names)))
    run_test(device, test_names)


if __name__ == '__main__':
    main()
