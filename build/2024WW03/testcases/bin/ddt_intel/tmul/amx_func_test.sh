#!/bin/bash
###############################################################################
# Copyright (C) 2020, Intel - http://www.intel.com
#
# SPDX-License-Identifier: GPL-2.0-or-later
###############################################################################

############################ DESCRIPTION ######################################
# @desc     This script is based on amx binary to do basic test of
#           amx/tmul, spec: glc-amx-eas-2020-01-08-rev-72.pdf
###############################################################################

source "common.sh"
source "functions.sh"

test_print_trc "Run AMX test " \
amx || die "AMX basic test failed"

