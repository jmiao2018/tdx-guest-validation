#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.

import json
import logging
import os
import sys
import traceback
from enum import Enum, unique

CURRENT_DIR = os.path.dirname(os.path.realpath(__file__))
PARENT_DIR = os.path.dirname(CURRENT_DIR)
sys.path.insert(0, PARENT_DIR)
from utils import DsaConfigErr, add_console

logger = logging.getLogger('sysfs_properity')
add_console(logger, level=logging.DEBUG)


@unique
class SysfsDirType(Enum):
    device = "device"
    engine = "engine"
    group = "group"
    wq = "wq"
    root = "root"


@unique
class SysfsNodeType(Enum):
    directory = "directory"
    attribute = "attribute"
    null = "null"


@unique
class AttrValueRangeType(Enum):
    all = "all"
    calculated = "calculated"
    enum = "enum"
    minx_max = "min_max"
    null = "null"


class SysfsProperity(object):
    """
    Root collection of configuration properities. Contains 'DirProperity'
    objects for devices/groups/wqs/engines.
    """
    def __init__(self, filepath):
        self.device_prop = None
        self.group_prop = None
        self.wq_prop = None
        self.engine_prop = None

        self.__load_json(filepath)

    def __load_json(self, filepath):
        if not os.path.isfile(filepath):
            raise DsaConfigErr("json file {} does not exist".format(filepath))

        with open(filepath) as f:
            config_json = json.load(f)

            device_raw = config_json["device"]
            self.device_prop = DirProperity(device_raw)
            group_raw = config_json["group"]
            self.group_prop = DirProperity(group_raw)
            wq_raw = config_json["wq"]
            self.wq_prop = DirProperity(wq_raw)
            engine_raw = config_json["engine"]
            self.engine_prop = DirProperity(engine_raw)

    def get_dir_properties(self, dir_type):
        """
        Get DirProperity object for a given directory type.
            :param dir_type: member of SysfsDirType
        """
        prep_map = {SysfsDirType.device: self.device_prop,
                    SysfsDirType.group: self.group_prop,
                    SysfsDirType.engine: self.engine_prop,
                    SysfsDirType.wq: self.wq_prop,
                    SysfsDirType.root: self}
        try:
            target_prop = prep_map[dir_type]
            return target_prop
        except KeyError:
            logger.error(traceback.format_exc())
            return DsaConfigErr("Key error: {} not in prep_map"
                                .format(dir_type))


class BaseProperity(object):
    def __init__(self, properties):
        self._properties = properties
        self._prop_type = SysfsNodeType.null

    def get_prop_type(self):
        return self._prop_type


class DirProperity(BaseProperity):
    def __init__(self, properties):
        super(DirProperity, self).__init__(properties)
        self._prop_type = SysfsNodeType.directory
        self._attrs = {name: AttrProperity(item) for name, item in
                       properties["attributes"].items()}
        self._dir_type = SysfsDirType(properties["dir_type"])

    def get_dir_type(self):
        return self._dir_type

    def get_attr_prop(self, attribute):
        """
        Get Attrproperity object for a given attribute in this directory.
            :param attribute: attribute name in string format
        """
        try:
            return self._attrs[attribute]
        except KeyError:
            logger.error("Attr {} not found in {}"
                         .format(attribute, self._dir_type))
            return None


class AttrProperity(BaseProperity):
    def __init__(self, properties):
        super(AttrProperity, self).__init__(properties)
        self._prop_type = SysfsNodeType.attribute

        try:
            value_range_type = properties["value_range_type"]
        except KeyError:
            self._value_range_type = AttrValueRangeType.null
        else:
            if not value_range_type:
                self._value_range_type = AttrValueRangeType.null
            else:
                self._value_range_type = AttrValueRangeType(value_range_type)

        if properties["type"] != "attribute":
            raise DsaConfigErr("Type for {} is not 'attribute' but {}"
                               .format(self._name, properties["type"]))

    def get_permission(self):
        """
        Check the target permissions, return in string ("644"/"444")
        """
        return self.get_prop_value("permission")

    def get_name(self):
        return self.get_prop_value("name")

    def get_prop_type(self):
        return self._prop_type

    def get_prop_value(self, key):
        if not self.has_prop(key):
            raise KeyError("Attr {} is not found in {}"
                           .format(key, self.get_name()))
        return self._properties[key]

    def has_prop(self, key):
        return key in self._properties

    def is_writable(self):
        """
        Return true if the attribute is writable at current stauts, which means
        it has a permission of 644 and is not disabled by the driver.
        """
        if int(self.get_permission(), 8) & 0o200:
            return True
        return False


if __name__ == "__main__":
    pass
