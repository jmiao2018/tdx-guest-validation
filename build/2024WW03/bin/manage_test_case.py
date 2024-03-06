#!/usr/bin/env python3
#
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2020, Intel Corporation.


import os
import re
import sys
import csv
import json
import base64
from time import sleep
from pathlib import Path
from threading import Thread
from argparse import ArgumentParser
from getpass import getpass, getuser
from datetime import datetime, timedelta

import requests


URL = 'http://lckqa-cluster-master.sh.intel.com:31130/tests'


CREATED_DATE_FIELD = 'customfield_20824'


PRIORITY = {
    '2': 'P1',
    '3': 'P2',
    '4': 'P3',
    '5': 'P4',
    '6': 'P5'
}


def encode_password(username: str, password: str):
    combined_string = username + password
    encoded_bytes = combined_string.encode('utf-8')
    encrypted_bytes = base64.b64encode(encoded_bytes)
    encrypted_string = encrypted_bytes.decode('utf-8')

    return encrypted_string


class Base:
    def __init__(self, data: dict):
        self.raw = data

    def __getattr__(self, name):
        try:
            return self[name]
        except Exception as e:
            if name == '__getnewargs__':
                raise KeyError(name)

            if hasattr(self, 'raw') and name in self.raw:
                return self.raw[name]

            msg = '{} has no attribute {} ({})'.format(
                self.__class__.__name__, name, e
            )
            raise AttributeError(msg)


class MultiThreadTask:
    def __init__(self):
        self._t_count = 0
        self._t_done = 0
        self._lock = False
        self.data = {}

    @property
    def is_done(self):
        if self._t_count == 0:
            # There's no task
            return True
        elif self._t_done < self._t_count:
            return False
        else:
            return True


class TestCase(Base):

    def __init__(self, data: dict):
        super(TestCase, self).__init__(data)


class TestScenario(Base):
    def __init__(self, path: Path, data: dict):
        super(TestScenario, self).__init__(data)
        self._path = path

    @property
    def test_type(self):
        if 'BAT' in self.tag:
            return 'BAT'
        elif 'FUNC' in self.tag:
            return 'FUNC'
        elif 'PERF' in self.tag:
            return 'PERF'
        elif 'STRESS' in self.tag:
            return 'STRESS'
        else:
            return 'UNKNOWN'

    @classmethod
    def from_file(cls, path: Path):
        if not path.is_file():
            msg = 'scenario file not found: {}'.format(path.absolute())
            raise Exception(msg)

        scenario = path.name
        data = {'name': scenario, 'test_cases': []}
        content = path.read_text()
        lines = [i for i in content.split('\n') if i]

        for line in lines:
            if line.startswith('# @requires'):
                flags = [i for i in re.split(r'[&&, \s]', line)[2:] if i]
                data['flags'] = flags
            elif line.startswith('#'):
                continue
            else:
                try:
                    tag, cmdline = re.split(r'[\s\t]', line, 1)
                    test_case_data = {'tag': tag,
                                      'cmdline': cmdline,
                                      'scenario': scenario}
                    test_case = TestCase(test_case_data)
                    data['test_cases'].append(test_case)
                except Exception as e:
                    raise Exception(str(e))

        return cls(path, data)


class DdtTestScenarios(MultiThreadTask):

    PATH = 'runtest/ddt_intel/upstream'

    def __init__(self, root: Path):
        super(DdtTestScenarios, self).__init__()
        self._root = root.joinpath(self.PATH)

    def _parse(self, scenario: Path):
        self._t_count += 1

        try:
            data = TestScenario.from_file(scenario)
            data.raw['framework'] = 'LTP-DDT'
        except Exception as e:
            print(e)
            self._t_done += 1
            return

        while self._lock:
            sleep(0.1)

        self._lock = True
        try:
            self.data[scenario.name] = data
        finally:
            self._lock = False
            self._t_done += 1

    def scan(self):
        scenarios = [i for i in self._root.iterdir()
                     if not i.name.startswith('alsa')
                     and not i.name.startswith('eth')
                     and i.name.endswith('tests')]
        for scenario in scenarios:
            Thread(target=self._parse, args=(scenario,)).start()
        sleep(0.5)


class Platform(Base):
    def __init__(self, data: dict):
        super(Platform, self).__init__(data)

    @classmethod
    def from_file(cls, path: Path):
        if not path.is_file():
            msg = 'Platform file {} not found'.format(path.absolute())
            raise Exception(msg)

        content = path.read_text()
        lines = [i for i in content.split('\n') if i and not i.startswith('#')]

        try:
            arch, soc, machine, _os, *flags = lines
        except Exception:
            msg = 'Parse platform file {} failed'.format(path.absolute())
            print(msg)
            raise Exception(msg)
        data = {'arch': arch,
                'soc': soc,
                'machine': machine,
                'os': _os,
                'flags': flags}

        return cls(data)


class Skip(Base):
    def __init__(self, data: dict):
        super(Skip, self).__init__(data)

    @classmethod
    def from_file(cls, path: Path):
        if not path.is_file():
            return cls([])

        content = path.read_text()
        lines = [i for i in content.split('\n') if i and not i.startswith('#')]

        return cls(lines)


class Platforms(MultiThreadTask):

    PLATFORM_PATH = 'platforms/generic'
    SKIP_PATH = 'skips/generic'

    def __init__(self, root: Path):
        super(Platforms, self).__init__()
        self._root = root

    def _parse(self, platform: Path, skip: Path):
        self._t_count += 1

        try:
            data = Platform.from_file(platform)
            data.raw['skips'] = Skip.from_file(skip).raw
        except Exception as e:
            print(str(e))
            self._t_done += 1
            return

        while self._lock:
            sleep(0.1)

        self._lock = True
        try:
            self.data[platform.name] = data
        finally:
            self._t_done += 1
            self._lock = False

    def scan(self):
        platform_root = self._root.joinpath(self.PLATFORM_PATH)
        platforms = [i for i in platform_root.iterdir()
                     if i.name != 'Makefile']

        for platform in platforms:
            skip = self._root.joinpath(self.SKIP_PATH).joinpath(platform.name)
            Thread(target=self._parse, args=(platform, skip,)).start()

        sleep(0.5)


class JiraUtils:

    TEST_TYPES = {'BAT', 'FUNC', 'PERF', 'STRESS'}
    EXEC_TYPES = {'Auto', 'Semi', 'Manual'}

    @staticmethod
    def parse_summary(description: str):
        contents = description.split('\t\n')
        summary_line = [i for i in contents if i.startswith('Summary:')]

        if summary_line:
            return summary_line[0][8:].strip()

        return ''

    @staticmethod
    def parse_peripherals(description: str):
        contents = description.split('\t\n')
        peri_line = [i for i in contents if i.startswith('Peripherals:')]

        if peri_line:
            return peri_line[0][12:].strip()

        return ''

    @staticmethod
    def parse_kernel_params(description: str):
        contents = description.split('\t\n')
        kp_line = [i for i in contents if i.startswith('Kernel Parameters:')]

        if kp_line:
            return kp_line[0][18:].strip()

        return ''

    @staticmethod
    def parse_powerone(labels: list):
        return 'Y' if 'PowerOn' in labels else 'N'

    @staticmethod
    def parse_presi(labels: list):
        return 'Y' if 'PreSi' in labels else 'N'

    @staticmethod
    def parse_bios(labels: list):
        return 'Y' if 'BIOS' in labels else 'N'

    @staticmethod
    def parse_client_only(labels: list):
        return 'Y' if 'ClientOnly' in labels else 'N'

    @staticmethod
    def parse_server_only(labels: list):
        return 'Y' if 'ServerOnly' in labels else 'N'

    @staticmethod
    def parse_test_type(labels: list):
        try:
            _type = list(JiraUtils.TEST_TYPES & set(labels))
            return _type[0] if _type else 'TBD'
        except Exception:
            return 'TBD'

    @staticmethod
    def parse_exec_type(labels: list):
        try:
            _type = list(JiraUtils.EXEC_TYPES & set(labels))
            return _type[0] if _type else 'TBD'
        except Exception:
            return 'TBD'

    @staticmethod
    def parse_created_date(raw: str):
        m = re.match(r'(\d{4}-\d{2}-\d{2})', raw)

        if m is not None:
            date = m.group()
            date = datetime.strptime(date, '%Y-%m-%d') + timedelta(days=1)
            date = date.strftime('%Y-%m-%d')
        else:
            date = datetime.now().strftime('%Y-%m-%d')

        return date


class TestCaseFilter:
    def __init__(self, test_cases: dict, criteria: str):
        self._test_cases = test_cases
        self.criteria = [criterion for criterion in criteria.split(';')]
        self.output = {}

    def do(self):
        for tag, item in self._test_cases.items():
            matched = True

            for criterion in self.criteria:
                key, value = [i.strip() for i in criterion.split('=')]
                try:
                    if str(getattr(item, key)) != str(value):
                        matched = False
                except Exception:
                    matched = False

            if matched:
                self.output[tag] = item


class Analyser(MultiThreadTask):
    def __init__(self, local, jira, platforms):
        super(Analyser, self).__init__()
        self._local = local
        self._jira = jira
        self._platforms = platforms

    def _analyse(self, test_case: TestCase, test_scenario: TestScenario):
        self._t_count += 1

        tag = test_case.tag
        test_case.raw['framework'] = test_scenario.framework

        try:
            jira_data = self._jira[tag]
            test_case.raw['id'] = int(jira_data['id'])
            test_case.raw['created_date'] = JiraUtils.parse_created_date(
                jira_data[CREATED_DATE_FIELD]
            )
            test_case.raw['component'] = jira_data['components'][0]['name']
            test_case.raw['priority'] = \
                PRIORITY[str(jira_data['priority']['id'])]
            test_case.raw['owner'] = jira_data['reporter']['name']
            test_case.raw['assignee'] = jira_data['assignee']['name']

            labels = jira_data['labels']
            test_case.raw['test_type'] = JiraUtils.parse_test_type(labels)
            test_case.raw['exec_type'] = JiraUtils.parse_exec_type(labels)
            test_case.raw['presilicon'] = JiraUtils.parse_presi(labels)
            test_case.raw['poweron'] = JiraUtils.parse_powerone(labels)
            test_case.raw['bios'] = JiraUtils.parse_bios(labels)
            test_case.raw['client_only'] = JiraUtils.parse_client_only(labels)
            test_case.raw['server_only'] = JiraUtils.parse_server_only(labels)

            description = jira_data['description']
            test_case.raw['summary'] = JiraUtils.parse_summary(description)
            test_case.raw['peripherals'] = \
                JiraUtils.parse_peripherals(description)
            test_case.raw['kernel_params'] = \
                JiraUtils.parse_kernel_params(description)
            test_case.raw['new'] = 'N'
        except KeyError:
            test_case.raw['id'] = -1
            test_case.raw['created_date'] = datetime.now().strftime('%Y-%m-%d')
            test_case.raw['component'] = 'TBD'
            test_case.raw['priority'] = 'TBD'
            test_case.raw['owner'] = 'TBD'
            test_case.raw['assignee'] = 'TBD'
            test_case.raw['test_type'] = 'TBD'
            test_case.raw['exec_type'] = 'TBD'
            test_case.raw['presilicon'] = 'N'
            test_case.raw['poweron'] = 'N'
            test_case.raw['bios'] = 'N'
            test_case.raw['client_only'] = 'N'
            test_case.raw['server_only'] = 'N'
            test_case.raw['peripherals'] = ''
            test_case.raw['summary'] = ''
            test_case.raw['kernel_params'] = ''
            test_case.raw['new'] = 'Y'

        platforms = []

        for name, platform in self._platforms.items():
            if not set(test_scenario.flags) - set(platform.flags) \
                    and tag not in platform.skips:
                platforms.append(name)

        test_case.raw['platforms'] = platforms
        self.data[tag] = test_case
        self._t_done += 1

    def analyse(self):
        for test_scenario in self._local.values():
            for test_case in test_scenario.test_cases:
                Thread(target=self._analyse,
                       args=(test_case, test_scenario,)).start()
        sleep(0.5)

    def export_csv(self, criteria=None):
        time_suffix = datetime.today().strftime('%Y%m%d%H%M%S')
        csv_name = 'testcases_{}.csv'.format(time_suffix)

        if criteria is None or not criteria:
            data = self.data
        else:
            tc_filter = TestCaseFilter(self.data, criteria)
            tc_filter.do()
            data = tc_filter.output

        rows = []

        for tag, i in data.items():
            row = [i.id, tag, i.scenario, i.cmdline, i.summary, i.priority,
                   ';'.join(i.platforms), i.component, i.owner, i.assignee,
                   i.test_type, i.exec_type, i.framework, i.bios,
                   i.poweron, i.presilicon, i.peripherals,
                   i.kernel_params, i.client_only, i.server_only,
                   i.created_date]
            rows.append(row)

        test_case_csv = TestCaseCsv(rows)
        test_case_csv.export_csv_file(csv_name)


class TestCaseCsv:

    HEADER = ['Id', 'Tag', 'Scenario', 'Cmdline', 'Summary', 'Priority',
              'Platforms', 'Component', 'Owner', 'Assignee', 'TestType',
              'ExecType', 'Framework', 'BIOS', 'PowerOn', 'PreSilicon',
              'Peripherals', 'KernelParams', 'ClientOnly', 'ServerOnly',
              'CreatedDate']
    KEY_INDEX = {'id': 0, 'tag': 1, 'scenario': 2, 'cmdline': 3, 'summary': 4,
                 'priority': 5, 'platforms': 6, 'component': 7, 'owner': 8,
                 'assignee': 9, 'test_type': 10, 'exec_type': 11,
                 'framework': 12, 'bios': 13, 'poweron': 14, 'presilicon': 15,
                 'peripherals': 16, 'kernel_params': 17, 'client_only': 18,
                 'server_only': 19, 'created_date': 20}

    def __init__(self, data: list):
        self._data = data

    def export_csv_file(self, dest: str):
        try:
            f = open(dest, 'w')
            writer = csv.writer(f)
            writer.writerow(self.HEADER)
            writer.writerows(self._data)
            print('Check {}'.format(dest))
        except Exception as e:
            print(str(e))
        finally:
            f.close()

    @classmethod
    def import_csv_file(cls, source: str):
        if not os.path.isfile(source):
            raise Exception('file {} not found'.format(source))

        data = []

        with open(source, 'r') as f:
            reader = csv.reader(f)

            for row in reader:
                if row[0] == 'Id':
                    continue
                data.append(row)

            test_case_csv = cls(data)

        return test_case_csv

    def format(self):
        data = {'create': [], 'update': {}}

        for row in self._data:
            test_case = {}

            for key, index in self.KEY_INDEX.items():
                if key == 'created_date':
                    test_case[CREATED_DATE_FIELD] = row[index]
                else:
                    test_case[key] = row[index]

            tc_id = test_case['id']
            if int(test_case['id']) == -1:
                data['create'].append(test_case)
            else:
                data['update'][tc_id] = test_case

        return data


def retrieve_jira_data():
    payload = {'username': os.environ['JIRA_USER'],
               'password': os.environ['JIRA_PASSWD']}

    res = requests.get(URL, params=payload)
    if res.status_code != 200:
        raise Exception(res.text)

    return {i['summary']: i for i in res.json()}


def retrieve_local_data(root: Path):
    ddt_test_scenarios = DdtTestScenarios(root)
    ddt_test_scenarios.scan()

    while not ddt_test_scenarios.is_done:
        sleep(0.5)

    return ddt_test_scenarios.data


def retrieve_platforms_data(root: Path):
    platforms = Platforms(root)
    platforms.scan()

    while not platforms.is_done:
        sleep(0.5)

    return platforms.data


def generate_csv_file(root: Path, criteria: str):
    jira_data = retrieve_jira_data()
    local_data = retrieve_local_data(root)
    platforms_data = retrieve_platforms_data(root)
    analyser = Analyser(local_data, jira_data, platforms_data)
    analyser.analyse()
    while not analyser.is_done:
        sleep(0.5)
    analyser.export_csv(criteria)


def upload_test_cases(csv_file: str):
    test_case_csv = TestCaseCsv.import_csv_file(csv_file)
    test_cases = test_case_csv.format()

    print('\nStart updatng exsiting test cases...')
    payload = {'username': os.environ['JIRA_USER'],
               'password': os.environ['JIRA_PASSWD'],
               'data': json.dumps(test_cases['update'])}
    res = requests.put(URL, data=payload)
    if res.status_code != 200:
        print('Something is wrong while updating test cases data')
        print(res.text)
    else:
        data = res.json()
        print('Update below {} test cases succeeded:\n{}'.format(
            len(data), '\n'.join(data)
        ))

    print('\nstart creating new test cases...')
    payload = {'username': os.environ['JIRA_USER'],
               'password': os.environ['JIRA_PASSWD'],
               'data': json.dumps(test_cases['create'])}
    res = requests.post(URL, data=payload)
    if res.status_code != 200:
        print('Something is wrong while creating new test cases')
        print(res.text)
    else:
        data = res.json()
        print('Create below {} test cases succeeded:\n{}'.format(
            len(data), '\n'.join(data)
        ))


def main():
    parser = ArgumentParser()
    parser.add_argument('-r', '--root', dest='root_path',
                        help='LTP-DDT for IA root path')
    parser.add_argument('-c', '--criteria', dest='criteria',
                        help='criteria to filter test cases')
    parser.add_argument('-i', '--input', dest='input', default=None,
                        help='input csv file')
    args = parser.parse_args()

    username = input('Jira Username: ')
    os.environ['JIRA_USER'] = username

    password = getpass(prompt='Jira Password: ')
    os.environ['JIRA_PASSWD'] = encode_password(username, password)

    if args.input is not None:
        upload_test_cases(args.input)
    else:
        if not args.root_path:
            print('LTP-DDT for IA root path is required.')
            sys.exit(1)

        generate_csv_file(Path(args.root_path).absolute(), args.criteria)


if __name__ == '__main__':
    main()
