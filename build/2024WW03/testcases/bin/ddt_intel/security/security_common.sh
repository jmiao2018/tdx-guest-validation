#!/usr/bin/env bash
##
## Copyright (c) 2017, Intel Corporation.
##
## This program is free software; you can redistribute it and/or modify it
## under the terms and conditions of the GNU General Public License,
## version 2, as published by the Free Software Foundation.
##
## This program is distributed in the hope it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
## more details.
##

source common.sh

INTEL_SGX_INIT_PATTERNS="sgx|INT0E0C|sgx_init.*returned 0 after.*usecs"
SEACCEPTTEST_CHECKING_PATTERNS="Test exits with error code: 0|Success ecall: [0-9]+"
MSR_FILE_NAME="intel_sgx_signing_key-4.12.msr"
ENCLAVE_WORKAROUNDED_PLATFORM="whl-u-rvp|icl-u-rvp"
