#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import json
import logging
import os
import random as rd
import re
import string
import sys

CURRENT_DIR = os.path.dirname(os.path.realpath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
sys.path.insert(0, PARENT_DIR)
from dsa_config_test.accfg_utils import AccfgUtils
from dsa_config_test.sysfs_properity import (SysfsDirType, SysfsNodeType,
                                             SysfsProperity)
from utils import DsaConfigErr, ShellCommand, add_console

logger = logging.getLogger('dsa_configs')
add_console(logger, level=logging.DEBUG)

rd.seed()

IDXD_SYSFY_PROP = os.path.join(CURRENT_DIR, 'sysfs_properity.json')
DSA_SYSFS_DEV_ROOT = '/sys/bus/dsa/devices/'
DSA_SYSFS_DRV_ROOT = '/sys/bus/dsa/drivers/idxd'
IAX_SYSFS_DEV_ROOT = '/sys/bus/dsa/devices/'
IAX_SYSFS_DRV_ROOT = '/sys/bus/dsa/drivers/idxd'
IDXD_SYSFS_DRV_USER_ROOT = '/sys/bus/dsa/drivers/user'


class ConfigNode(object):
    def __init__(self, dev_id, parent=None):
        self._dev_id = dev_id
        self._node_type = SysfsNodeType.null
        self._config_prop = None
        self._sysfs_path = ""
        self._parent = parent

    def is_root(self):
        """
        Return True if it's the root dir (/sys/bus/dsa/devices).
        """
        return False

    def get_dev_id(self):
        return self._dev_id

    def get_property(self):
        return self._config_prop

    def get_sysfs_path(self):
        return self._sysfs_path

    def get_parent(self):
        return self._parent

    def get_root(self):
        node = self
        while not node.is_root():
            node = node.get_parent()
        return node

    def set_property(self, prop):
        self._config_prop = prop

    def set_sysfs_path(self, parent_path):
        self._sysfs_path = os.path.join(parent_path, self._dev_id)

    def set_parent(self, parent):
        self._parent = parent


class ConfigDir(ConfigNode):
    def __init__(self, dev_id, parent=None):
        super(ConfigDir, self).__init__(dev_id, parent)

        self._attrs = dict()
        self._devices = dict()
        self._groups = dict()
        self._wqs = dict()
        self._engines = dict()

        self._node_type = SysfsNodeType.directory

    def read_from_system(self):
        """
        Return status from sysfs and create child nodes recurly.
        """
        logger.debug("Reading from sysfs: {}".format(self._sysfs_path))
        for attr_name in os.listdir(self._sysfs_path):
            full_path = os.path.join(self._sysfs_path, attr_name)
            if attr_name == "cdev_minor":
                continue
            if attr_name == "enqcmds_retries":
                continue
            if attr_name == "dma_chans":
                continue
            if attr_name == "max_tokens":
                continue
            if attr_name == "token_limit":
                continue
            if attr_name == "tokens_allowed":
                continue
            if attr_name == "tokens_reserved":
                continue
            if attr_name == "use_token_limit":
                continue
            if attr_name == "vdev_create":
                continue
            if attr_name == "vdev_remove":
                continue
            if os.path.isdir(full_path):
                continue
            if os.path.islink(full_path):
                continue
            logger.debug("Reading attribute: {}".format(full_path))
            sh = ShellCommand("cat {}".format(full_path))
            if sh.is_failed():
                raise DsaConfigErr("Read attribute failed from {}"
                                   .format(full_path))
            value = sh.get_std_out()[0]

            attr = ConfigAttrFactory.get_config_attr(attr_name, value, self)
            self._attrs[attr_name] = attr

    def to_json(self):
        """
        Translate self to a JSON object
        """
        content = dict()
        content['dev'] = self._dev_id

        content.update(
            {name: attr.get_value() for name, attr in self._attrs.items()}
        )

        return content

    def write_to_sysfs(self):
        """
        Write all the writable attributes to the sysfs.
        Return True is all passed.
        """
        ret = True
        for attr in self.iter_attributes():
            ret &= attr.write_to_sysfs()
        return ret

    def write_to_accfg(self, short_cmd=True, readback=True):
        """
        Write all the writable attributes to the accel-config tool.
        Return True is all passed.
        """
        ret = True
        for attr in self.iter_attributes():
            ret &= attr.write_to_accfg(short_cmd, readback)
        return ret

    def test_no_writable_accfg(self, short_cmd=True):
        """
        Test all non-writable attributes cannot be written with accel-cofig
        tool. Return True if all writes are rejected.
        """
        ret = True
        for attr in self.iter_attributes():
            ret &= attr.test_no_writable_accfg(short_cmd)
        return ret

    def test_no_writable_sysfs(self):
        """
        Test all non-writable attributes cannot be written to sysfs.
        Return True if all writes are rejected.
        """
        ret = True
        for attr in self.iter_attributes():
            ret &= attr.test_no_writable_sysfs()
        return ret

    def set_property(self, prop):
        """
        Set preperty for self and all sub-nodes recurly.
        """
        super(ConfigDir, self).set_property(prop)
        for attr_id, attr_item in self._attrs.items():
            attr_item.set_property(self._config_prop.get_attr_prop(attr_id))

    def set_parent(self, parent):
        """
        Set the correct parent pointer for self and all sub-nodes recurly.
        """
        self._parent = parent
        for device in self._devices.values():
            device.set_parent(self)
        for group in self._groups.values():
            group.set_parent(self)
        for wq in self._wqs.values():
            wq.set_parent(self)
        for engine in self._engines.values():
            engine.set_parent(self)

    def get_device_type(self):
        """
        Return the device type: 'dsa'/'iax'
        """
        root = self.get_root()
        return root.get_device_type()

    def get_device_id(self):
        """
        Return the corresponding device name (dsaN/iaxN) for this node.
        This is around to justify it is dsa/iax by %2.
        """
        device_idx = int(self.get_device_idx())
        if (device_idx % 2) == 0:
            device_type = "dsa"
        else:
            device_type= "iax"

        return "{}{}".format(device_type, device_idx)

    def get_device_node(self):
        """
        Return the corresponding device node object (dsaN) for this node.
        """
        root = self.get_root()
        device_id = self.get_device_id()
        return root._devices[device_id]

    def get_device_idx(self):
        """
        Return the index of the corresponding device for this node.
        wq3.4 -> 3
        """
        pattern = r'(group|wq|engine)([0-9]+)(\.)([0-9]+)'
        m = re.search(pattern, self._dev_id)
        if m:
            return m.group(2)
        else:
            raise DsaConfigErr("Invalid dev_id: {}".format(self._dev_id))

    def get_group_dev_id(self):
        """
        Get the group name for this node if it's in a group.
        Return "" if it's not groupped.
        """
        try:
            group_id = self._attrs["group_id"].get_value()
        except KeyError:
            logger.warning("There is no group_id in {}".format(self._dev_id))
            return ""
        # return "" for ungrouped items
        if int(group_id) < 0:
            logger.debug("Ungroupped item {} with group_id {}"
                         .format(self._dev_id, group_id))
            return ""
        device_num = self.get_device_idx()
        return "group{}.{}".format(device_num, group_id)

    def get_group_node(self):
        """
        Get the group object for this node if it's in a group.
        Return None if it's not groupped.
        """
        root = self.get_root()
        group_dev_id = self.get_group_dev_id()
        if not group_dev_id:
            return None
        return root.get_sub_dir_node(group_dev_id)

    def get_dev_index(self):
        """
        Get the index of the node in the collection of objects under same
        parent device node (dsaN).
        groupx.y -> y
        wqx.y -> y
        """
        pattern = r'(group|wq|engine)([0-9]+)(\.)([0-9]+)'
        m = re.search(pattern, self._dev_id)
        if m:
            return m.group(4)
        else:
            raise DsaConfigErr("Invalid dev_id: {}".format(self._dev_id))

    def get_dir_type(self):
        return self._sysfs_dir_type

    def get_attr_value(self, attr_name):
        return self._attrs[attr_name].get_value()

    def get_attr_prop(self, name):
        """
        Get properity item for a given attribute
            :param name: name for the attribute
        """
        prop = self._config_prop
        if not prop:
            return None
        return prop.get_attr_prop(name)

    def _get_accfg_config_prefix(self):
        """
        Get the common prefix part of the "accel-config config-xxx" command.
        """
        pre_prefix = "sudo accel-config"
        post_prefix = "config-{} {}/{}".format(self._sysfs_dir_type.value,
                                               self.get_device_id(),
                                               self._dev_id)
        return "{} {}".format(pre_prefix, post_prefix)

    def random_choice_writable_attr(self):
        """
        Choose a writable attribute randomly from all the sub-attributes.
        """
        writable_attrs = [attr for attr in self.iter_attributes()
                          if attr.is_writable()]
        if not writable_attrs:
            raise DsaConfigErr("No writable attribute!")
        item = rd.choice(writable_attrs)
        return item

    def enable_device_by_sysfs(self):
        """
        Enable node by writing to sysfs. Applied for only device node type.
        """
        if self._sysfs_dir_type not in [SysfsDirType.device, SysfsDirType.wq]:
            raise DsaConfigErr("Sysfs item type {} cannot be binded!"
                               .format(self._sysfs_dir_type))

        sysfs_node = os.path.join(self.get_root().sysfs_drv_root, 'bind')
        cmd = "sudo echo '{}' > {}".format(self._dev_id, sysfs_node)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def enable_wq_by_sysfs(self):
        """
        Enable node by writing to sysfs. Applied for only wq node
        type.
        """
        if self._sysfs_dir_type not in [SysfsDirType.device, SysfsDirType.wq]:
            raise DsaConfigErr("Sysfs item type {} cannot be binded!"
                               .format(self._sysfs_dir_type))

        sysfs_node = os.path.join(self.get_root().sysfs_drv_user_root, 'bind')
        cmd = "sudo echo '{}' > {}".format(self._dev_id, sysfs_node)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def disable_device_by_sysfs(self):
        """
        Disable node by writing to sysfs. Applied for only device and wq node
        type.
        """
        if self._sysfs_dir_type not in [SysfsDirType.device, SysfsDirType.wq]:
            raise DsaConfigErr("Sysfs item type {} cannot be unbinded!"
                               .format(self._sysfs_dir_type))

        sysfs_node = os.path.join(self.get_root().sysfs_drv_root, 'unbind')
        cmd = "sudo echo '{}' > {}".format(self._dev_id, sysfs_node)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def disable_wq_by_sysfs(self):
        """
        Disable node by writing to sysfs. Applied for only device and wq node
        type.
        """
        if self._sysfs_dir_type not in [SysfsDirType.device, SysfsDirType.wq]:
            raise DsaConfigErr("Sysfs item type {} cannot be unbinded!"
                               .format(self._sysfs_dir_type))

        sysfs_node = os.path.join(self.get_root().sysfs_drv_user_root, 'unbind')
        cmd = "sudo echo '{}' > {}".format(self._dev_id, sysfs_node)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def iter_attributes(self,):
        """
        Iterate all the attributes from top to bottom.
        """
        for attr in self._attrs.values():
            yield attr

        sub_dicts = (self._devices, self._groups, self._wqs, self._engines)
        for sub_dict in sub_dicts:
            for sub_dir in sub_dict.values():
                for attr in sub_dir.iter_attributes():
                    yield attr

    def iter_all_dirs(self, dir_type=None):
        """
        Iterate over all levels of sub-directories
            :param dir_type: Iterate only given type of sub-directory.
                             None for all.
        """
        for sub_dir in self.iter_child_dirs():
            if not dir_type:
                # disable filter
                yield sub_dir
            elif sub_dir._sysfs_dir_type == dir_type:
                # enable filter
                yield sub_dir

            # next levle sub_dir
            for d in sub_dir.iter_all_dirs(dir_type):
                yield d

    def iter_child_dirs(self):
        """
        iterate over 1st level sub-directories
        """
        sub_dicts = (self._devices, self._wqs, self._groups, self._engines)
        for sub_dict in sub_dicts:
            for sub_dir in sub_dict.values():
                yield sub_dir

    @staticmethod
    def get_dir_type_from_name(name):
        mapping = {'dsa': SysfsDirType.device,
                   'iax': SysfsDirType.device,
                   'group': SysfsDirType.group,
                   'engine': SysfsDirType.engine,
                   'wq': SysfsDirType.wq}

        pattern_device = r'^(dsa|iax)([0-9]+)$'
        m = re.search(pattern_device, name)
        if m:
            return mapping[m.group(1)]

        pattern_sub = r'^(group|wq|engine)([0-9]+)(\.)([0-9]+)$'
        m = re.search(pattern_sub, name)
        if m:
            return mapping[m.group(1)]

        logger.warning('{} is not a valid sysfs dir'.format(name))
        return None

    @staticmethod
    def new_config_dir_instance(name, dir_type=None, parent=None):
        """
        Create a new instance of ConfigDir.
        """
        if not dir_type:
            dir_type = ConfigDir.get_dir_type_from_name(name)
        if not dir_type:
            raise DsaConfigErr("Dir type unknown for request with name {}"
                               .format(name))
        if dir_type == SysfsDirType.device:
            return DeviceConfig(name, parent)
        elif dir_type == SysfsDirType.engine:
            return EngineConfig(name, parent)
        elif dir_type == SysfsDirType.group:
            return GroupConfig(name, parent)
        elif dir_type == SysfsDirType.wq:
            return WqConfig(name, parent)
        else:
            raise DsaConfigErr("Invalid dir type {}".format(dir_type))

    def set_sysfs_path(self, parent_path):
        """
        Set sysfs path to self and all children recurly.
        """
        super(ConfigDir, self).set_sysfs_path(parent_path)
        self.set_sysfs_path_to_child()

    def set_sysfs_path_to_child(self):
        for item in self._attrs.values():
            item.set_sysfs_path(self._sysfs_path)
        for item in self._devices.values():
            item.set_sysfs_path(self._sysfs_path)
        for item in self._wqs.values():
            item.set_sysfs_path(self._sysfs_path)
        for item in self._groups.values():
            item.set_sysfs_path(self._sysfs_path)
        for item in self._engines.values():
            item.set_sysfs_path(self._sysfs_path)

    def check_permission(self):
        """
        Check all attribute permission is aligned between preperity file and
        the sysfs filesystem.
        """
        targets = (self._attrs,
                   self._devices,
                   self._groups,
                   self._wqs,
                   self._engines)
        for target in targets:
            for item in target.values():
                if not item.check_permission():
                    return False
        return True

    def add_sub_dir(self, sub):
        """
        Add object 'sub' as children of self.
        """
        sub_name = sub.get_dev_id()
        sub_type = sub.get_dir_type()

        if sub_type == SysfsDirType.device:
            self._devices[sub_name] = sub
        elif sub_type == SysfsDirType.group:
            self._groups[sub_name] = sub
        elif sub_type == SysfsDirType.engine:
            self._engines[sub_name] = sub
        elif sub_type == SysfsDirType.wq:
            self._wqs[sub_name] = sub
        else:
            raise DsaConfigErr("Invalid directory type {} for {}"
                               .format(sub_type, sub_name))

    def fuzz_valid(self):
        """
        Random choose a attribute and fuzz its value to a valid value.
        """
        attr = self.random_choice_writable_attr()
        attr.set_valid_value()

    def fuzz_invalid(self):
        """
        Random choose a attribute and fuzz its value to a invalid value.
        """
        attr = self.random_choice_writable_attr()
        attr.set_invalid_value()

    def __eq__(self, other):
        if self._sysfs_path != other._sysfs_path:
            return False
        if self._attrs != other._attrs:
            return False
        if self._devices != other._devices:
            return False
        if self._groups != other._groups:
            return False
        if self._wqs != other._wqs:
            return False
        if self._engines != other._engines:
            return False
        return True


class DeviceConfig(ConfigDir):
    def __init__(self, dev_id, parent=None):
        super(DeviceConfig, self).__init__(dev_id, parent)
        self._set_prop_from_parent()
        self._sysfs_dir_type = SysfsDirType.device

    def parse_json(self, config):
        """
        Fill content of self and create children recurly with the given json
        object 'config'.
        """
        for key, val in config.items():
            if key == 'dev':
                if self._dev_id != val:
                    logger.warning("self._dev_id {} != confing['dev'] {}"
                                   .format(self._dev_id, val))
                self._dev_id = val
            elif key == 'groups':
                for sub_config in val:
                    group_item = GroupConfig(sub_config['dev'], self)
                    group_item.parse_json(sub_config)
                    self._groups[group_item._dev_id] = group_item
            elif key.startswith('ungrouped_'):
                logger.debug("Ignore ungrouped items: {}".format(key))
                continue
            else:
                attr_item = ConfigAttrFactory.get_config_attr(key, val, self)
                self._attrs[key] = attr_item

    def to_json(self):
        """
        Translate self to a JSON object
        """
        content = dict()
        content['dev'] = self._dev_id

        content.update(
            {name: attr.get_value() for name, attr in self._attrs.items()}
        )

        groups = [g.to_json() for g in self._groups.values()]
        content['groups'] = groups

        return content

    def get_device_id(self):
        return self._dev_id

    def _get_accfg_config_prefix(self):
        pre_prefix = "sudo accel-config"
        post_prefix = "config-{} {}".format(self._sysfs_dir_type.value,
                                            self._dev_id)
        return "{} {}".format(pre_prefix, post_prefix)

    def _set_prop_from_parent(self):
        if not self._parent:
            logger.warning("No parent found for {}".format(self._dev_id))
            return

        root = self.get_root()
        root_prop = root.get_property()
        prop = root_prop.get_dir_properties(SysfsDirType.device)
        self.set_property(prop)

    def enable_by_accfg(self):
        """
        Enable node by accel-config command.
        """
        cmd = "sudo accel-config enable-device {}".format(self._dev_id)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def disable_by_accfg(self):
        """
        Disable node by accel-config command.
        """
        cmd = "sudo accel-config disable-device {}".format(self._dev_id)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def get_reserved_read_buffers(self):
        root = self.get_root()
        groups = [g for g in root.iter_all_dirs(SysfsDirType.group)
                  if g.get_device_id() == self._dev_id]
        reserved_read_buffers = [int(g.get_attr_value("read_buffers_reserved"))
                           for g in groups]
        return sum(reserved_read_buffers)

    def get_available_read_buffers(self):
        try:
            max_read_buffers = int(self.get_attr_value("max_read_buffers"))
        except KeyError:
            # TODO: read from sysfs
            max_read_buffers = 96
        available_read_buffers = max_read_buffers - self.get_reserved_read_buffers()
        return available_read_buffers

    def get_used_wq_size(self):
        root = self.get_root()
        wqs = [q for q in root.iter_all_dirs(SysfsDirType.wq)
               if q.get_device_id() == self._dev_id]
        wq_sizes = [int(q.get_attr_value("size")) for q in wqs]
        return sum(wq_sizes)

    def get_available_wq_size(self):
        try:
            max_size = self.get_attr_value("max_work_queues_size")
        except KeyError:
            max_size = 128
        return max_size - self.get_used_wq_size()


class GroupConfig(ConfigDir):
    def __init__(self, dev_id, parent=None):
        super(GroupConfig, self).__init__(dev_id, parent)
        self._set_prop_from_parent()
        self._sysfs_dir_type = SysfsDirType.group

    def parse_json(self, config):
        """
        Fill content of self and create children recurly with the given json
        object 'config'.
        """
        for key, val in config.items():
            if key == 'dev':
                if self._dev_id != val:
                    logger.warning("self._dev_id {} != confing['dev'] {}"
                                   .format(self._dev_id, val))
                self._dev_id = val
            elif key == 'grouped_workqueues':
                for sub_config in val:
                    wq_item = WqConfig(sub_config['dev'], self)
                    wq_item.parse_json(sub_config)
                    self._wqs[wq_item._dev_id] = wq_item
            elif key == 'grouped_engines':
                for sub_config in val:
                    engine_item = EngineConfig(sub_config['dev'], self)
                    engine_item.parse_json(sub_config)
                    self._engines[engine_item._dev_id] = engine_item
            else:
                attr_item = ConfigAttrFactory.get_config_attr(key, val, self)
                self._attrs[key] = attr_item

    def to_json(self):
        """
        Translate self to a JSON object
        """
        content = dict()
        content['dev'] = self._dev_id

        content.update(
            {name: attr.get_value() for name, attr in self._attrs.items()}
        )

        wqs = [wq.to_json() for wq in self._wqs.values()]
        if wqs:
            content['grouped_workqueues'] = wqs

        engines = [engine.to_json() for engine in self._engines.values()]
        if engines:
            content['grouped_engines'] = engines

        return content

    def get_group_node(self):
        return self

    def _set_prop_from_parent(self):
        if not self._parent:
            logger.warning("No parent found for {}".format(self._dev_id))
            return

        root = self.get_root()
        root_prop = root.get_property()
        prop = root_prop.get_dir_properties(SysfsDirType.group)
        self.set_property(prop)

    def check_groups_pairing(self):
        wq_attr_value = self.get_attr_value("work_queues")
        logger.debug("{}.work_queues: {}".format(self._dev_id, wq_attr_value))
        for wq in self._wqs.keys():
            if wq not in wq_attr_value:
                logger.error("Wq {} not in {}.work_queues"
                             .format(wq, self._dev_id))
                return False

        engine_attr_value = self.get_attr_value("engines")
        logger.debug("{}.engines: {}".format(self._dev_id, engine_attr_value))
        for engine in self._engines.keys():
            if engine not in engine_attr_value:
                logger.error("Engine {} not in {}.engines"
                             .format(wq, self._dev_id))
                return False

        return True

    def get_reserved_read_buffers_range(self):
        device = self.get_device_node()
        available_read_buffers = device.get_available_read_buffers()
        self_reserved = self.get_attr_value("read_buffers_reserved")
        min = 0
        max_1 = int(self.get_attr_value("read_buffers_allowed"))
        max_2 = self_reserved + available_read_buffers
        max = max_1 if max_1 < max_2 else max_2
        return (min, max)

    def get_read_buffers_allowed_range(self):
        """
        Calculate the valid range for group.read_buffers_allowed
        """
        # TODO: add unittest
        device = self.get_device_node()
        root = self.get_root()
        grouped_engines = [e for e in root.iter_all_dirs(SysfsDirType.engine)
                           if e.get_group_dev_id() == self._dev_id]
        min_1 = 4*len(grouped_engines)
        min_2 = int(self.get_attr_value("read_buffers_reserved"))
        min = min_1 if min_1 > min_2 else min_2

        self_reserved = int(self.get_attr_value("read_buffers_reserved"))
        max = self_reserved + device.get_available_read_buffers()

        return (min, max)


class WqConfig(ConfigDir):
    def __init__(self, dev_id, parent=None):
        super(WqConfig, self).__init__(dev_id, parent)
        self._set_prop_from_parent()
        self._sysfs_dir_type = SysfsDirType.wq

    def parse_json(self, config):
        """
        Fill content of self and create children recurly with the given json
        object 'config'.
        """
        for key, val in config.items():
            if key == 'dev':
                if self._dev_id != val:
                    logger.warning("self._dev_id {} != confing['dev'] {}"
                                   .format(self._dev_id, val))
                self._dev_id = val
            else:
                attr_item = ConfigAttrFactory.get_config_attr(key, val, self)
                self._attrs[key] = attr_item

    def _set_prop_from_parent(self):
        if not self._parent:
            logger.warning("No parent found for {}".format(self._dev_id))
            return

        root = self.get_root()
        root_prop = root.get_property()
        prop = root_prop.get_dir_properties(SysfsDirType.wq)
        self.set_property(prop)

    def enable_by_accfg(self):
        cmd = "sudo accel-config enable-wq {}/{}".format(self.get_device_id(),
                                                         self._dev_id)
        sh = ShellCommand(cmd)
        return sh.is_passed()

    def disable_by_accfg(self):
        cmd = "sudo accel-config disable-wq  {}/{}" \
              .format(self.get_device_id(), self._dev_id)
        sh = ShellCommand(cmd)
        return sh.is_passed()


class EngineConfig(ConfigDir):
    def __init__(self, dev_id, parent=None):
        super(EngineConfig, self).__init__(dev_id, parent)
        self._set_prop_from_parent()
        self._sysfs_dir_type = SysfsDirType.engine

    def parse_json(self, config):
        """
        Fill content of self and create children recurly with the given json
        object 'config'.
        """
        for key, val in config.items():
            if key == 'dev':
                if self._dev_id != val:
                    logger.warning("self._dev_id {} != confing['dev'] {}"
                                   .format(self._dev_id, val))
                self._dev_id = val
            else:
                attr_item = ConfigAttrFactory.get_config_attr(key, val, self)
                self._attrs[key] = attr_item

    def _set_prop_from_parent(self):
        if not self._parent:
            logger.warning("No parent found for {}".format(self._dev_id))
            return

        root = self.get_root()
        root_prop = root.get_property()
        prop = root_prop.get_dir_properties(SysfsDirType.engine)
        self.set_property(prop)


class IdxdConfigs(ConfigDir):
    def __init__(self, dev_id=""):
        super(IdxdConfigs, self).__init__(dev_id)
        self._sysfs_dir_type = SysfsDirType.root

        self._config_prop = SysfsProperity(IDXD_SYSFY_PROP)

    def is_root(self):
        return True

    def read_from_system(self):
        logger.debug("Reading from sysfs")
        self.set_sysfs_path_to_self()
        self._is_flatten = True

        for dir_name in os.listdir(self._sysfs_path):
            dir_type = ConfigDir.get_dir_type_from_name(dir_name)
            if not dir_type:
                logger.debug("Ignore unknown directory {}".format(dir_name))
                continue
            dir_node = ConfigDir.new_config_dir_instance(dir_name, dir_type,
                                                         self)
            self.add_sub_dir(dir_node)
            self.set_sysfs_path_to_child()
            dir_node.read_from_system()

        self.set_sysfs_path_to_child()

    def load_from_file(self, filename):
        if not os.path.isfile(filename):
            raise DsaConfigErr("json file {} does not exist".format(filename))

        with open(filename) as f:
            config_json = json.load(f)
            self.parse_json(config_json)

    def parse_json(self, config):
        """
        Fill content of self and create children recurly with the given json
        object 'config'.
        """
        for idxd_device in config:
            dev_id = idxd_device["dev"]
            item = DeviceConfig(dev_id, self)
            item.parse_json(idxd_device)
            self._devices[dev_id] = item
        self.flatten_dirs()
        self.set_sysfs_path()

    def loaded_file_by_accfg(self):
        """
        Load config and wirte to system by "accel-config load-config" command
        """
        tmp_file = self.save_to_file()
        ret = AccfgUtils().load_config(tmp_file)
        return ret

    def save_to_file(self, file_path=""):
        """
        Save current configuration to file.
            :param file_path: file path. Create a random file under "/tmp"
                              if empty
        """
        if not file_path:
            file_path = AccfgUtils().random_tmp_file()
        logger.debug("Save config to file {}".format(file_path))

        json_content = self.to_json()
        json_obj = json.dumps(json_content, indent=4)
        with open(file_path, "w") as f:
            f.write(json_obj)
        return file_path

    def to_json(self):
        """
        Translate self to a JSON object.
        """
        is_flatten = self._is_flatten
        self.dirs_to_tree()

        content = [d.to_json() for d in self._devices.values()]

        if is_flatten:
            self.flatten_dirs()
        return content

    def flatten_dirs(self):
        """
        Transfer self to the flattern mode, which means groups/wqs/engines will
        be the direct children of root.
        """
        for device in self._devices.values():
            self._groups.update(device._groups)
            device._groups = dict()
        for group in self._groups.values():
            self._wqs.update(group._wqs)
            group._wqs = dict()
            self._engines.update(group._engines)
            group._engines = dict()
        self._is_flatten = True
        self.set_parent(None)

    def set_sysfs_path(self):
        self.set_sysfs_path_to_self()
        self.set_sysfs_path_to_child()

    def get_sub_dir_node(self, dev_id):
        """
        Get a sub-directory node with given name from all the children recurly.
        """
        dir_type = ConfigDir.get_dir_type_from_name(dev_id)
        is_flatten = self._is_flatten
        self.flatten_dirs()
        try:
            if dir_type == SysfsDirType.device:
                return self._device[dev_id]
            elif dir_type == SysfsDirType.group:
                return self._group[dev_id]
            elif dir_type == SysfsDirType.wq:
                return self._wq[dev_id]
            elif dir_type == SysfsDirType.engine:
                return self._engine[dev_id]
        except KeyError:
            raise DsaConfigErr("Dir {} not found".format(dev_id))
        finally:
            if not is_flatten:
                self.dirs_to_tree()

    def get_max_groupes_pre_device(self):
        dev_type = self.get_device_type()
        if dev_type == "iax":
            device0 = self.get_device_type() + '1'
        else:
            device0 = self.get_device_type() + '0'
        return self._devices[device0].get_attr_value('max_groups')

    def get_max_wqs_pre_device(self):
        dev_type = self.get_device_type()
        if dev_type == "iax":
            device0 = self.get_device_type() + '1'
        else:
            device0 = self.get_device_type() + '0'
        return self._devices[device0].get_attr_value('max_work_queues')

    def get_max_engines_pre_device(self):
        dev_type = self.get_device_type()
        if dev_type == "iax":
            device0 = self.get_device_type() + '1'
        else:
            device0 = self.get_device_type() + '0'
        return self._devices[device0].get_attr_value('max_engines')

    def count_devices(self):
        return len(self._devices)

    def count_groups(self):
        is_flatten = self._is_flatten
        self.flatten_dirs()
        count = len(self._groups)
        if not is_flatten:
            self.dirs_to_tree()
        return count

    def count_wqs(self):
        is_flatten = self._is_flatten
        self.flatten_dirs()
        count = len(self._wqs)
        if not is_flatten:
            self.dirs_to_tree()
        return count

    def count_engines(self):
        is_flatten = self._is_flatten
        self.flatten_dirs()
        count = len(self._engines)
        if not is_flatten:
            self.dirs_to_tree()
        return count

    def dirs_to_tree(self):
        """
        Transfer self to the tree mode, which means groups will be children of
        device and wqs/engines will be children of groups.
        """
        engines_to_tree = []
        for engine_name, engine in self._engines.items():
            group_name = engine.get_group_dev_id()
            if not group_name:
                logger.debug("No group for engine {}".format(engine_name))
                continue
            elif group_name not in self._groups:
                raise DsaConfigErr("Group {} for engine {} not in group list"
                                   .format(group_name, engine_name))
            else:
                self._groups[group_name].add_sub_dir(engine)
                engines_to_tree.append(engine_name)
        for engine_name in engines_to_tree:
            self._engines.pop(engine_name)

        wqs_to_tree = []
        for wq_name, wq in self._wqs.items():
            group_name = wq.get_group_dev_id()
            if not group_name:
                logger.debug("No group for wq {}".format(wq_name))
                continue
            elif group_name not in self._groups:
                raise DsaConfigErr("Group {} for wq {} not in group list"
                                   .format(group_name, wq_name))
            else:
                self._groups[group_name].add_sub_dir(wq)
                wqs_to_tree.append(wq_name)
        for wq_name in wqs_to_tree:
            self._wqs.pop(wq_name)

        for group_name, group in self._groups.items():
            device_name = group.get_device_id()
            if device_name not in self._devices:
                raise DsaConfigErr("Device {} for group {} not in dev list"
                                   .format(device_name, group_name))
            else:
                self._devices[device_name].add_sub_dir(group)
        self._groups = dict()

        self._is_flatten = False
        self.set_parent(None)

    def enable_devices_by_accfg(self):
        """
        Enable all devices by accel-config command.
        """
        ret = True
        for device in self._devices.values():
            ret &= device.enable_by_accfg()
        return ret

    def enable_devices_by_sysfs(self):
        """
        Enable all devices by write to sysfs.
        """
        ret = True
        for device in self._devices.values():
            ret &= device.enable_device_by_sysfs()
        return ret

    def enable_wqs_by_accfg(self):
        """
        Enable all wqs by accel-config command.
        """
        ret = True
        for wq in self._wqs.values():
            ret &= wq.enable_by_accfg()
        return ret

    def enable_wqs_by_sysfs(self):
        """
        Enable all wqs by write to sysfs.
        """
        ret = True
        for wq in self._wqs.values():
            ret &= wq.enable_wq_by_sysfs()
        return ret

    def disable_devices_by_accfg(self):
        """
        Disable all devices by accel-config command.
        """
        ret = True
        for device in self._devices.values():
            ret &= device.disable_by_accfg()
        return ret

    def disable_devices_by_sysfs(self):
        """
        Disable all devices by write to sysfs.
        """
        ret = True
        for device in self._devices.values():
            ret &= device.disable_device_by_sysfs()
        return ret

    def disable_wqs_by_accfg(self):
        """
        Disable all wqs by accel-config command.
        """
        ret = True
        for wq in self._wqs.values():
            ret &= wq.disable_by_accfg()
        return ret

    def disable_wqs_by_sysfs(self):
        """
        Disable all wqs by write to sysfs.
        """
        ret = True
        for wq in self._wqs.values():
            ret &= wq.disable_wq_by_sysfs()
        return ret

    def check_groups_pairing(self):
        """
        Check group_id for wqs/engines are paired to wq/engine attribute for
        the corresponding group.
        """
        is_flatten = self._is_flatten
        self.dirs_to_tree()

        ret = True
        for group in self._groups.values():
            ret &= group.check_groups_pairing()

        if is_flatten:
            self.flatten_dirs()

        return ret

    def is_part_of(self, other):
        """
        Return True if the configuartions in 'self' is also contained in
        'other' with same value, while 'other' may contain extar configuartions
        than 'self'
        """
        if other._node_type != self._node_type:
            return False
        if other._sysfs_dir_type != self._sysfs_dir_type:
            return False

        other_attrs = {attr.get_sysfs_path(): attr for attr
                       in other.iter_attributes()}
        for attr in self.iter_attributes():
            attr_path = attr.get_sysfs_path()
            if attr_path not in other_attrs:
                return False
            if other_attrs[attr_path] != attr:
                return False
        return True


class DsaConfigs(IdxdConfigs):
    def __init__(self, dev_id=""):
        super(DsaConfigs, self).__init__(dev_id)
        self.sysfs_drv_root = DSA_SYSFS_DRV_ROOT
        self.sysfs_drv_user_root = IDXD_SYSFS_DRV_USER_ROOT

    def set_sysfs_path_to_self(self):
        self._sysfs_path = DSA_SYSFS_DEV_ROOT

    def get_device_type(self):
        return 'dsa'


class IaxConfigs(IdxdConfigs):
    def __init__(self, dev_id=""):
        super(IaxConfigs, self).__init__(dev_id)
        self.sysfs_drv_root = IAX_SYSFS_DRV_ROOT
        self.sysfs_drv_user_root = IDXD_SYSFS_DRV_USER_ROOT

    def set_sysfs_path_to_self(self):
        self._sysfs_path = IAX_SYSFS_DEV_ROOT

    def get_device_type(self):
        return 'iax'


class ConfigAttr(ConfigNode):
    def __init__(self, dev_id, value, parent=None):
        super(ConfigAttr, self).__init__(dev_id, parent)
        if parent:
            self._config_prop = parent.get_attr_prop(dev_id)

        try:
            if self._config_prop.get_prop_value('value_type') == 'int':
                value = int(value)
        except (AttributeError, KeyError):
            pass
        self._value = value

        self._node_type = SysfsNodeType.attribute

    def get_value(self):
        return self._value

    def get_valid_value(self):
        raise DsaConfigErr("Should be implemented by subclasses. "
                           "Attribute: {}".format(self._sysfs_path))

    def get_invalid_value(self):
        raise DsaConfigErr("Should be implemented by subclasses. "
                           "Attribute: {}".format(self._sysfs_path))

    def set_value(self, value):
        self._value = value

    def set_valid_value(self):
        """
        Set self with a valid value. self.get_valid_value() should be
        implemented by subclasses.
        """
        self._value = self.get_valid_value()

    def set_invalid_value(self):
        """
        Set self with a invalid value. self.get_invalid_value() should be
        implemented by subclasses.
        """
        self._value = self.get_invalid_value()

    def read_back(self):
        """
        Read back value from sysfs. Used when after wirte value to system.
        """
        cmd = "cat {}".format(self._sysfs_path)
        sh = ShellCommand(cmd)
        if sh.is_failed():
            logger.error("Readback failed: {}".format(self._sysfs_path))
            return False
        return True

    def read_perm(self, path=""):
        if not path:
            path = self._sysfs_path
        return oct(os.stat(path).st_mode & 0o777)[-3:]

    def check_permission(self):
        actual_perm = self.read_perm()
        expected_perm = self._config_prop.get_permission()
        if actual_perm != expected_perm:
            logger.error(
                "Check permission failed for {}, expected: {}, actual: {}"
                .format(self._sysfs_path, expected_perm, actual_perm))
            return False
        logger.debug("Check permission passed for {}".format(self._sysfs_path))
        return True

    def is_writable(self):
        return self._config_prop.is_writable()

    def write_to_sysfs(self, readback=True):
        if not self.is_writable():
            return True

        # LCK-11424 On SPR due to silicon bug, we have to restrict write to
        # traffic class unless using the module parameter to override
        if self._dev_id == "traffic_class_a" and self._value == 1:
            return True
        if self._dev_id == "traffic_class_b" and self._value == 1:
            return True

        value = str(self._value).replace("'", r'\'')
        cmd = "sudo echo '{}' > {}".format(value, self._sysfs_path)
        sh = ShellCommand(cmd)
        if sh.is_failed():
            logger.error("Wirte attribute to sysfs failed: {} -> {}"
                         .format(self._value, self._sysfs_path))
        ret = sh.is_passed()
        if readback:
            ret &= self.read_back()
        return ret

    def write_to_accfg(self, short_cmd, readback=True):
        if not self.is_writable():
            return True

        # LCK-11424 On SPR due to silicon bug, we have to restrict write to
        # traffic class unless using the module parameter to override
        if self._dev_id == "traffic_class_a" and self._value == 1:
            return True
        if self._dev_id == "traffic_class_b" and self._value == 1:
            return True

        cmd = self._get_accfg_write_cmd(short_cmd)
        sh = ShellCommand(cmd)
        if sh.is_failed():
            logger.error("Wirte attribute to accfg failed: {} -> {}"
                         .format(self._value, self._sysfs_path))
        ret = sh.is_passed()
        if readback:
            ret &= self.read_back()
        return ret

    def test_no_writable_accfg(self, short_cmd):
        if self.is_writable():
            return True

        cmd = self._get_accfg_write_cmd(short_cmd)
        sh = ShellCommand(cmd)
        if sh.is_passed():
            logger.error("Wirte attribute to accfg passed while failure is "
                         "expected: {} -> {}"
                         .format(self._value, self._sysfs_path))
            return False
        return True

    def test_no_writable_sysfs(self):
        if self.is_writable():
            return True

        cmd = "sudo echo '{}' > {}".format(self._value, self._sysfs_path)
        sh = ShellCommand(cmd)
        if sh.is_passed():
            logger.error("Wirte attribute to sysfs passed while failure is "
                         "expected: {} -> {}"
                         .format(self._value, self._sysfs_path))
            return False
        return True

    def _get_accfg_write_cmd(self, short_cmd):
        prefix = self._parent._get_accfg_config_prefix()
        if short_cmd:
            argument = self._config_prop.get_prop_value("config_option_short")
        else:
            argument = self._config_prop.get_prop_value("config_option_long")

        value = str(self._value).replace("'", r'\'')
        sub_cmd = "{} '{}'".format(argument, value)
        cmd = "{} {}".format(prefix, sub_cmd)
        return cmd

    def __eq__(self, other):
        if self._sysfs_path != other._sysfs_path:
            return False
        if self._dev_id != other._dev_id:
            return False
        if self._value != other._value:
            return False
        return True

    @staticmethod
    def _get_random_num():
        return rd.randint(-1024, 1024)

    @staticmethod
    def _get_random_string():
        range_1 = string.ascii_letters + string.digits + string.punctuation \
                  + ' '
        range_2 = string.ascii_letters + string.digits
        range_3 = string.ascii_letters
        range_4 = string.digits
        char_range = rd.choice([range_1, range_2, range_3, range_4])
        length = rd.randint(1, 255)

        ret = ''.join(rd.choice(char_range) for _ in range(length))
        return ret

    @staticmethod
    def _get_random_bool():
        return rd.randint(0, 1)


class ConfigAttrRangeEnum(ConfigAttr):
    def get_valid_value(self):
        valid_list = self._config_prop.get_prop_value('value_range')
        return rd.choice(valid_list)

    def get_invalid_value(self):
        while True:
            if ConfigAttr._get_random_bool():
                ret = ConfigAttr._get_random_string()
            else:
                ret = ConfigAttr._get_random_num()
            if not self.in_range(ret):
                return ret

    def in_range(self, value):
        return value in self._config_prop.get_prop_value('value_range')


class ConfigAttrRangeMinMax(ConfigAttr):
    def get_valid_value(self):
        min, max = self.get_range()
        return rd.randint(min, max)

    def get_invalid_value(self):
        while True:
            if ConfigAttr._get_random_bool():
                ret = ConfigAttr._get_random_string()
            else:
                ret = ConfigAttr._get_random_num()
            if not self.in_range(ret):
                return ret

    def in_range(self, value):
        if not isinstance(value, int):
            return False
        min, max = self.get_range()
        return value >= min and value <= max

    def get_range(self):
        min = int(self._config_prop.get_prop_value('value_range')[0])
        max = int(self._config_prop.get_prop_value('value_range')[1])
        return (min, max)


class ConfigAttrRangeCaluclated(ConfigAttr):
    def get_valid_value(self):
        raise DsaConfigErr("Should be implemented by subclasses. "
                           "Attribute: {}".format(self._sysfs_path))

    def get_invalid_value(self):
        raise DsaConfigErr("Should be implemented by subclasses. "
                           "Attribute: {}".format(self._sysfs_path))


class ConfigAttrAllString(ConfigAttr):
    def get_valid_value(self):
        return ConfigAttr._get_random_string()

    def get_invalid_value(self):
        # TODO: add typical invalid value
        return ""


class ConfigAttrGrpReadBuffersReserved(ConfigAttrRangeMinMax):
    def get_range(self):
        group = self._parent
        return group.get_reserved_read_buffers_range()


class ConfigAttrGrpUseReadBufferLimit(ConfigAttrRangeEnum):
    def is_writable(self):
        group = self._parent
        device = group.get_device_node()
        read_buffer_limit = device.get_attr_value("read_buffer_limit")
        try:
            read_buffer_limit = int(read_buffer_limit)
        except ValueError:
            logger.warning("read_buffer_limit {} is not int".format(read_buffer_limit))
            return False
        return read_buffer_limit > 0


class ConfigAttrGrpReadBuffersAllowed(ConfigAttrRangeMinMax):
    def get_range(self):
        group = self._parent
        return group.get_read_buffers_allowed_range()


class ConfigAttrWqThreshold(ConfigAttrRangeMinMax):
    def is_writable(self):
        wq_node = self._parent
        wq_type = wq_node.get_attr_value("mode")
        return wq_type == "shared"

    def get_range(self):
        """
        [0, wq_size]
        """
        min = 0

        wq = self._parent
        wq_size = int(wq.get_attr_value("size"))
        return (min, wq_size)


class ConfigAttrWqSize(ConfigAttrRangeMinMax):
    def get_range(self):
        """
        Sum(wq.size) <= device.max_workqueue_size
        """
        min = 0

        wq = self._parent
        device = wq.get_device_node()
        available_size = device.get_available_wq_size()
        max = available_size + int(self._value)

        return (min, max)


class ConfigAttrGroupId(ConfigAttrRangeMinMax):
    """
    Group_id for both wq and engine
    """
    def get_range(self):
        # TODO: move logic to DeviceConfig
        engine = self._parent
        device_id = engine.get_device_id()
        root = self.get_root()
        grps_share_dev = [g for g in root.iter_all_dirs(SysfsDirType.group)
                          if g.get_device_id() == device_id]
        grps_index_list = [int(g.get_dev_index()) for g in grps_share_dev]
        if not grps_index_list:
            raise DsaConfigErr("grps_index_list should not be empty for "
                               "devices {}".format(device_id))
        min = sorted(grps_index_list)[0]
        max = sorted(grps_index_list)[-1]
        return (min, max)


class ConfigAttrUevent(ConfigAttr):
    def is_writable(self):
        return False


class ConfigAttrFactory(object):
    @staticmethod
    def get_config_attr(dev_id, value, parent=None):

        if not parent:
            logger.warning("No parent for attr {}".format(dev_id))
            return ConfigAttr(dev_id, value, parent)

        if dev_id == "read_buffers_reserved":
            return ConfigAttrGrpReadBuffersReserved(dev_id, value, parent)
        if dev_id == "use_read_buffer_limit":
            return ConfigAttrGrpUseReadBufferLimit(dev_id, value, parent)
        if dev_id == "read_buffers_allowed":
            return ConfigAttrGrpReadBuffersAllowed(dev_id, value, parent)
        if dev_id == "threshold":
            return ConfigAttrWqThreshold(dev_id, value, parent)
        if dev_id == "uevent":
            return ConfigAttrUevent(dev_id, value, parent)
        if dev_id == "group_id":
            return ConfigAttrGroupId(dev_id, value, parent)
        if dev_id == "size":
            return ConfigAttrWqSize(dev_id, value, parent)

        attr_prop = parent.get_attr_prop(dev_id)
        if not attr_prop:
            logger.warning("No config properity for attr {}".format(dev_id))
            logger.warning("Parent: {}".format(parent.get_dev_id()))
            return ConfigAttr(dev_id, value, parent)

        if not attr_prop.has_prop("value_range_type"):
            return ConfigAttr(dev_id, value, parent)
        if attr_prop.get_prop_value("value_range_type") == "enum":
            return ConfigAttrRangeEnum(dev_id, value, parent)
        if attr_prop.get_prop_value("value_range_type") == "min_max":
            return ConfigAttrRangeMinMax(dev_id, value, parent)
        if attr_prop.get_prop_value("value_range_type") == "calculated":
            return ConfigAttrRangeCaluclated(dev_id, value, parent)
        if attr_prop.get_prop_value("value_range_type") == "all":
            return ConfigAttrAllString(dev_id, value, parent)

        return ConfigAttr(dev_id, value, parent)


if __name__ == "__main__":
    pass
