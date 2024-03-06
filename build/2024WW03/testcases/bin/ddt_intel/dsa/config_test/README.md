# dsa_config_test

Test tool to test DSA configuration with accel-config tool and sysfs.

## Dependencies

* IDXD kernel driver <https://github.com/intel-innersource/os.linux.intelnext.kernel.git>
* Accel-config tool <https://github.com/intel/idxd-config.git>
* dsa-scripts <https://github.com/intel-sandbox/dsa-scripts.git>

## Test documents

* DSA Test Spec <https://intel.sharepoint.com/sites/SSPCLKVAL/_layouts/15/Doc.aspx?OR=teams&action=edit&sourcedoc={4F7AAA33-A9DD-4093-8778-069A0F2B199F}>
* Linux Core Kernel IDXD Test Plan <https://intel.sharepoint.com/sites/SSPCLKVAL/_layouts/15/Doc.aspx?OR=teams&action=edit&sourcedoc={B20A60F5-626E-463A-A2B9-DCE6C49A393E}>

## Run test

### List all tests

```bash
dsa_config_test_runner.py -d <dsa/iax> -l
```

### Run all tests

```bash
dsa_config_test_runner.py -d <dsa/iax> -a
```

### Run all BAT tests

```bash
dsa_config_test_runner.py -d <dsa/iax> -b
```

### Run all functional tests

```bash
dsa_config_test_runner.py -d <dsa/iax> -f
```

### Run all negative tests

```bash
dsa_config_test_runner.py -d <dsa/iax> -n
```

### Run all stres tests

```bash
dsa_config_test_runner.py -d <dsa/iax> -s
```

### Run tests with given name

```bash
dsa_config_test_runner.py -d <dsa/iax> test1 test2 test3 ...
```

### Know issues
traffic_class_a permission is 644 but could not write```bash
fuzz test fail with high frequency when trying random write
```


## Contact

Tony Zhu <tony.zhu@intel.com>
