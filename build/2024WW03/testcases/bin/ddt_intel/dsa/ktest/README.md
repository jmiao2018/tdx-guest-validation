# idxd_ktest

## Description

This tool is used to test IDXD driver kernel API with DMATEST kernel module.

## Usage

```bash
usage: ./idxd_ktest.sh [-c channels ] [-d device_type] [-i iterations ]
                       [ -m mode] [ -t threads ] [-h Help]
  -c channels :     Number of channels
  -d device_type :  "dsa"(default) / "iax"
  -i iterations :   Number of iterations
  -m mode :         "shared"/"dedicated", used when channels is equal to 1
  -t threads:       Threads per channel
  -h :              Print this
```

## Eaxample

```bash
idxd_ktest.sh -c 1 -t 1 -i 100 -m shared
idxd_ktest.sh -c 1 -t 1 -i 100 -m dedicated
idxd_ktest.sh -c 2 -t 4 -i 1000
idxd_ktest.sh -c 4 -t 2 -i 1000
idxd_ktest.sh -d dsa -c 8 -t 1 -i 1000
idxd_ktest.sh -d dsa -c 32 -t 2 -i 1000
idxd_ktest.sh -d dsa -c 64 -t 1 -i 100000
idxd_ktest.sh -d iax -c 4 -t 16 -i 100000
idxd_ktest.sh -d iax -c 8 -t 8 -i 100000
idxd_ktest.sh -d iax -c 1 -t 64 -i 100000
idxd_ktest.sh -d iax -c 64 -t 64 -i 100000
```

## Contact

Yixin Zhang <yixin.zhang@intel.com>

