#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2019, Intel Corporation
#
# Author:
#             Tony Zhu <tony.zhu@intel.com>
#
# History:
#             Dec. 03, 2019 - (Tony Zhu)Creation

source common.sh

usage() {
  cat << _EOF
    gpio_libtool.sh -c <case id> -h
      c: case id
      h: show this
_EOF
}

libgpiod_suite_prepare() {

  GPIO_LIBTOOL_PATH="$(pwd)/ddt_intel/gpio/libgpiod"
  export PATH="${GPIO_LIBTOOL_PATH}/tools/.libs:${GPIO_LIBTOOL_PATH}/tests/.libs:$PATH"

  [[ -e ${GPIO_LIBTOOL_PATH}/tools/.libs/gpioinfo ]] && return 0
  cd ddt_intel/gpio/ && tar -xvf libgpiod.tar
  cp -a "${GPIO_LIBTOOL_PATH}/lib/.libs/libgpiod.so.2.2.2" /usr/lib64/
  ln -s /usr/lib64/libgpiod.so.2.2.2 /usr/lib64/libgpiod.so.2
  cp -a "${GPIO_LIBTOOL_PATH}/tests/mockup/.libs/libgpiomockup.so.0.0.1" /usr/lib64/
  ln -s /usr/lib64/libgpiomockup.so.0.0.1 /usr/lib64/libgpiomockup.so.0

  return 0
}

while getopts c:h opt; do
  case $opt in
    h) usage && exit ;;
    c) cid=$OPTARG ;;
    \?) die "Invalide option: -$OPTARG" ;;
    :) die "Option -$OPTARG requires an argument." ;;
  esac
done

libgpiod_suite_prepare

case $cid in
  gpiodetect)
    do_cmd "gpiodetect"
    ;;
  gpioinfo)
    do_cmd "gpioinfo"
    ;;
  gpiod-test)
    do_cmd "gpiod-test"
    ;;
  *)
    die "Invalid case id: $cid!"
    ;;
esac
