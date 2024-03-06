#!/usr/bin/env python3


import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict
from urllib.request import urlopen


API_BASE = "http://clkv-api.intel.com/api"


# check whether current directory is DDT root
if not Path("{}/runtests.sh".format(os.getcwd())).exists():
    print("You need to change directory to DDT root to use this tool!")
    sys.exit(1)

scenarios_root = Path(os.getcwd()).joinpath("runtest")
specs_root = scenarios_root.joinpath("spec")


domains = ["IO", "LPSS_IO", "Memory", "Security", "CPU", "OSE", "Power", "Other"]
statuses = ["New", "Designed", "Reviewed", "Closed"]
initial_platforms = [
    "Granite Rapids",
    "Sapphire Rapids",
    "Emerald Rapids",
    "Meteor Lake",
    "Raptor Lake",
    "Clearwater Forest",
]
priorities = ["P1", "P2", "P3", "P4", "P5"]


class InitialPlatforms:
    def __init__(self):
        self._initial_platforms = []
        self._get()

    def _get(self):
        url = f"{API_BASE}/initial_platforms"
        with urlopen(url) as response:
            try:
                data = json.loads(response.read())
                self._initial_platforms = [ip["name"] for ip in data]
                self._initial_platforms.sort()
            except Exception as e:
                raise Exception(f"getting feature list failed - {e}")

    def __iter__(self):
        return iter(self._initial_platforms)


class Scenario:
    def __init__(self, path: Path):
        self._file: Path = path
        self.file: str = self._file.name
        self.name: str = ""
        self.description: str = ""
        self.requires: List[str] = []
        self.tests: Dict[str, str] = {}
        self._parse()

    def _parse(self):
        text = self._file.read_text()
        lines = text.split("\n")

        for line in lines:
            if line.startswith("# @name "):
                self.name = line.replace("# @name ", "")
            elif line.startswith("# @desc "):
                self.description = line.replace("# @desc ", "")
            elif line.startswith("# @requires "):
                self.requires = line.replace("# @requires ", "").strip().split(" && ")
            elif not line or line.startswith("#"):
                continue
            else:
                items = line.split(" ")
                self.tests[items[0]] = " ".join(items[1:])


class Spec:
    def __init__(self, path: Path):
        self._file: Path = path
        self.file: str = self._file.stem
        self.Name: str = ""
        self.Cmdline: str = ""
        self.InitialPlatform: str = ""
        self.Summary: str = ""
        self.Status: str = ""
        self.Steps: List[str] = []
        self.Flags: List[str] = []
        self.Priority: str = ""
        self.Scenario: str = ""
        self.Domain: str = ""
        self.Feature: str = ""
        self.Owner: str = ""
        self.TestType: str = ""
        self.ExecType: str = ""
        self.PowerOn: bool = False
        self.PreSi: bool = False
        self.ClientOnly: bool = False
        self.ServerOnly: bool = False
        self.KParams: List[str] = []
        self.Kconfigs: List[str] = []
        self.Packages: List = []
        self.BIOS: List = []
        self.Peripherals: List = []
        self.CreateDate: str = ""
        self.InfoLink: str = ""
        self.Tips: str = ""
        self._parse()

    def _parse(self):
        if not self._file.exists():
            return
        raw = json.loads(self._file.read_text())
        try:
            self.Name = raw["name"]
            self.Cmdline = raw["cmdline"]
            self.InitialPlatform = (
                raw["initial_platform"] if "initial_platform" in raw else ""
            )
            self.Summary = raw["summary"]
            self.Status = raw["status"]
            self.Steps = raw["steps"] if "steps" in raw else []
            self.Flags = raw["flags"] if "flags" in raw else []
            self.Priority = raw["priority"]
            self.Scenario = raw["scenario"]
            self.Domain = raw["domain"]
            self.Feature = raw["feature"]
            self.Owner = raw["owner"]
            self.TestType = raw["testType"]
            self.ExecType = raw["execType"]
            self.PowerOn = raw["poweron"]
            self.PreSi = raw["presilicon"]
            self.ClientOnly = raw["clientOnly"]
            self.ServerOnly = raw["serverOnly"]
            self.KParams = raw["kparams"]
            self.Kconfigs = raw["kconfigs"]
            self.Packages = raw["packages"]
            self.BIOS = raw["bios"]
            self.Peripherals = raw["peripherals"]
            self.CreateDate = raw["createDate"]
            self.InfoLink = raw["link"] if "link" in raw else ""
            self.Tips = raw["tips"] if "tips" in raw else ""
        except KeyError as e:
            print(f"{self._file.absolute()} - field missing: {e}")

    def __str__(self):
        spec_dict = {
            "name": self.Name,
            "cmdline": self.Cmdline,
            "initial_platform": self.InitialPlatform,
            "summary": self.Summary,
            "status": self.Status,
            "steps": self.Steps,
            "flags": self.Flags,
            "priority": self.Priority,
            "scenario": self.Scenario,
            "domain": self.Domain,
            "feature": self.Feature,
            "owner": self.Owner,
            "testType": self.TestType,
            "execType": self.ExecType,
            "poweron": self.PowerOn,
            "presilicon": self.PreSi,
            "clientOnly": self.ClientOnly,
            "serverOnly": self.ServerOnly,
            "kparams": self.KParams,
            "kconfigs": self.Kconfigs,
            "packages": self.Packages,
            "bios": self.BIOS,
            "peripherals": self.Peripherals,
            "createDate": self.CreateDate,
            "link": self.InfoLink,
            "tips": self.Tips,
        }
        return json.dumps(spec_dict, indent=4)

    def update_field(self, key: str, value):
        setattr(self, key, value)
        self._file.write_text(str(self))

    def _check_name(self):
        if self.file != self.Name:
            print(f"{self.file:50}: spec file name and test name does not match!")

    def _check_exectype(self):
        if self.ExecType == "Auto":
            if not self.Cmdline:
                print(f"{self.file:50}: auto test does not contain cmdline!")
            if not self.Scenario:
                print(f"{self.file:50}: auto test does not contain scenario!")
        elif self.ExecType in ["Semi", "Manual"]:
            if not self.Steps:
                print(f"{self.file:50}: non-auto test does not contain steps!")
            elif not self.Flags:
                print(f"{self.file:50}: non-auto test does not contain flags!")
        elif not self.ExecType:
            print(f"{self.file:50}: exec_type is missing")

    def _check_summary(self):
        if not self.Summary:
            print(f"{self.file:50}: summary is empty!")

    def _check_status(self):
        if self.Status not in statuses:
            print(f"{self.file:50}: invalid status {self.Status}")

    def _check_priority(self):
        if not self.Priority:
            print(f"{self.file:50}: priority is missing")
        elif self.Priority not in priorities:
            print(f"{self.file:50}: invalid priority {self.Priority}")

    def _check_domain(self):
        if not self.Domain:
            print(f"{self.file:50}: domain is missing")
        elif self.Domain not in domains:
            print(f"{self.file:50}: invalid domain {self.Domain}")

    def _check_feature(self, features: list):
        if not self.Feature:
            print(f"{self.file:50}: feature is missing")
        else:
            if self.Feature not in features:
                print(f"{self.file:50}: invalid feature {self.Feature}")

    def _check_initial_platform(self, initial_platforms):
        if self.InitialPlatform and self.InitialPlatform not in initial_platforms:
            print(f"{self.file:50}: invalid initial platform {self.InitialPlatform}")

    def _check_owner(self):
        if not self.Owner:
            print(f"{self.file:50}: owner is missing")

    def _check_testtype(self):
        if not self.TestType:
            print(f"{self.file:50}: test_type is missing")
        elif self.TestType not in ["BAT", "FUNC", "PERF", "STRESS"]:
            print(f"{self.file:50}: invalid test_type {self.TestType}")

    def _check_platform_only(self):
        if self.ClientOnly and self.ServerOnly:
            print(f"{self.file:50}: serverOnly and clientOnly cannot both be true!")

    def check(self, features: list, initial_platforms: InitialPlatforms):
        self._check_name()
        self._check_initial_platform(initial_platforms)
        self._check_exectype()
        self._check_summary()
        self._check_status()
        self._check_priority()
        self._check_domain()
        self._check_feature(features)
        self._check_owner()
        self._check_testtype()
        self._check_platform_only()


def edit_spec_files(scenarios: dict, specs: dict, scenario_file: str):
    try:
        from flask import Flask, render_template, jsonify, request
    except ImportError:
        print("flask not found, run 'pip3 install Flask'")
        sys.exit(1)

    os.chdir("tools")

    app = Flask("Spec File Editor")
    template = "templates/spec-editor.html"

    if not Path(template).exists():
        print("spec-editor.html not found!")
        sys.exit(1)

    def update_specs(names: list, key: str, value):
        for name in names:
            try:
                specs[name].update_field(key, value)
            except KeyError:
                pass

    @app.after_request
    def patch_header(req):
        req.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        req.headers["Expires"] = "0"
        return req

    @app.route("/", methods=["GET"])
    def index():
        return render_template("spec-editor.html")

    @app.route("/spec/<name>", methods=["GET"])
    def spec(name: str):
        try:
            return str(specs[name])
        except KeyError:
            return f"{name} not found"

    @app.route("/specs", methods=["GET"])
    def spec_list():
        try:
            return jsonify(list(scenarios[scenario_file].tests.keys()))
        except KeyError:
            return f"scenario file {scenario_file} not found!"

    @app.route("/edit_simple", methods=["PUT"])
    def edit_simple():
        tests = request.form["testCases"].split(",")
        key = request.form["key"]
        value = request.form["value"]

        if value == "true":
            value = True
            update_specs(tests, key, value)
            return ""
        elif value == "false":
            value = False
            update_specs(tests, key, value)
            return ""

        if key == "KParams":
            if not value:
                update_specs(tests, key, [])
            else:
                update_specs(tests, key, value.strip(",").split(","))
            return ""

        update_specs(tests, key, value)
        return ""

    app.run(host="0.0.0.0", port=9000)


def get_feature_list():
    url = f"{API_BASE}/features"
    with urlopen(url) as response:
        try:
            data = json.loads(response.read())
            return [f["kernel_name"] for f in data if f["kernel_name"]]
        except Exception as e:
            raise Exception(f"getting feature list failed - {e}")


def scan_ddt() -> tuple:
    scenarios = {}
    specs = {}

    for item in scenarios_root.iterdir():
        if (
            not item.name.endswith("_tests")
            or item.name.startswith("alsa_")
            or item.name.startswith("eth_")
        ):
            continue
        s = Scenario(item)
        scenarios[s.file] = s

    for item in specs_root.iterdir():
        if not item.name.endswith(".json"):
            continue
        s = Spec(item)
        specs[s.file] = s

    return (scenarios, specs)


def check_specs(
    scenarios: dict,
    specs: dict,
    features: list,
    initial_platforms: InitialPlatforms,
    scenario_file: str = "",
):
    if not scenario_file:
        for scenario in scenarios.values():
            for name in scenario.tests:
                try:
                    specs[name].check(features, initial_platforms)
                except KeyError:
                    print(f"{name}: spec file not found!")
    else:
        try:
            for name in scenarios[scenario_file].tests:
                try:
                    specs[name].check(features, initial_platforms)
                except KeyError:
                    print(f"{name}: spec file not found!")
        except KeyError:
            print(f"scenario {scenario_file} not found!")


def domain_candidates(specs, test_name: str) -> set:
    prefix = test_name.split("_")[0]
    candidates = set()
    for name, spec in specs.items():
        if name.startswith(prefix):
            candidates.add(spec.Domain)
    return candidates


def feature_candidates(specs, test_name: str) -> set:
    prefix = test_name.split("_")[0]
    candidates = set()
    for name, spec in specs.items():
        if name.startswith(prefix):
            candidates.add(spec.Feature)
    return candidates


def owner_candidates(specs, test_name: str) -> set:
    prefix = test_name.split("_")[0]
    candidates = set()
    for name, spec in specs.items():
        if name.startswith(prefix):
            candidates.add(spec.Owner)
    return candidates


def candidate_test_type(test_name: str) -> str:
    if test_name.find("_BAT_") != -1:
        return "BAT"
    elif test_name.find("_FUNC_") != -1:
        return "FUNC"
    elif test_name.find("_PERF_") != -1:
        return "PERF"
    elif test_name.find("_STRESS_") != -1:
        return "STRESS"
    else:
        return "BAT|FUNC|PERF|STRESS"


def created_date():
    now = datetime.now()
    return f"{now:%Y-%m-%dT%H:%M:%S.000-0800}"


def generate_spec_file(scenario: Scenario, specs, test_name: str):
    spec_file = Path(f"runtest/spec/{test_name}.json")
    spec = Spec(spec_file)
    spec.Name = spec.file
    spec.Cmdline = scenario.tests[test_name]
    spec.InitialPlatform = "|".join(initial_platforms)
    spec.Summary = ""
    spec.Status = "New|Designed|Reviewed|Closed"
    spec.Steps = []
    spec.Flags = []
    spec.Priority = "|".join(priorities)
    spec.Scenario = scenario.file
    spec.Domain = "|".join(list(domain_candidates(specs, test_name)))
    spec.Feature = "|".join(list(feature_candidates(specs, test_name)))
    spec.Owner = "|".join(list(owner_candidates(specs, test_name)))
    spec.TestType = candidate_test_type(test_name)
    spec.ExecType = "Auto"
    spec.PowerOn = False
    spec.PreSi = False
    spec.ClientOnly = False
    spec.ServerOnly = False
    spec.CreateDate = spec.CreateDate if spec.CreateDate else created_date()
    spec.InfoLink = ""
    spec.Tips = ""
    spec_file.write_text(str(spec))
    print(f"{spec_file.name} generated")


def generate_spec_files(scenarios, specs, scenario_file: str):
    try:
        scenario = scenarios[scenario_file]
        for name in scenario.tests:
            try:
                # spec file already checked in, do nothing.
                specs[name]
            except KeyError:
                generate_spec_file(scenario, specs, name)
    except KeyError:
        print(f"scenario {scenario_file} not found!")
        sys.exit(1)


def usage():
    return """
    1. Check correctness of test spec files for all tests
    ./tools/spec.py -c

    2. Check correctness of spec files for the tests defined in specified scenario file
    ./tools/spec.py -c -s pwm_func_tests

    3. Generate spec files for the tests defined in specified scenario file
    ./tools/spec.py -g -s pwm_func_tests

    4. Edit spec file of tests defined in specified scenario file
    ./tools/spec.py - e -s pwm_func_tests"""


def main():
    parser = argparse.ArgumentParser(
        description="A tool for managing test spec files.", usage=usage()
    )
    parser.add_argument(
        "-c",
        dest="check",
        action="store_true",
        default=False,
        help="Check test spec file(s)",
    )
    parser.add_argument(
        "-g",
        dest="generate",
        action="store_true",
        default=False,
        help="generate test spec file(s)",
    )
    parser.add_argument(
        "-e",
        dest="edit",
        action="store_true",
        default=False,
        help="edit test spec file(s)",
    )
    parser.add_argument(
        "-s",
        dest="scenario",
        type=str,
        default="",
        help="select test cases from scenario file",
    )
    args = parser.parse_args()

    if args.generate:
        if not args.scenario:
            print(
                "Scenario file is not specified! Example: ./tools/spec.py -g -s pwm_bat_tests"
            )
            sys.exit(1)
        scenarios, specs = scan_ddt()
        generate_spec_files(scenarios, specs, args.scenario)
    elif args.edit:
        if not args.scenario:
            print(
                "Scenario file is not specified! Example: ./tools/spec.py -e -s pwm_bat_tests"
            )
            sys.exit(1)

        scenarios, specs = scan_ddt()
        edit_spec_files(scenarios, specs, args.scenario)
    elif args.check:
        scenarios, specs = scan_ddt()
        features = get_feature_list()
        initial_platforms = InitialPlatforms()

        if not args.scenario:
            check_specs(scenarios, specs, features, initial_platforms)
        else:
            check_specs(
                scenarios,
                specs,
                features,
                initial_platforms,
                scenario_file=args.scenario,
            )
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
