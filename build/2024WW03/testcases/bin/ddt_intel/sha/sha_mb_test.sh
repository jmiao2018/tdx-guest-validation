#!/bin/bash
#
# Copyright 2017 Intel Corporation
#
# This file is part of LTP-DDT for IA to validate SHA component
#
# This program file is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 1, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Author:
#             Pengfei Xu <pengfei.xu@intel.com>
#
# History:
#             July 4 2017 - (Pengfei Xu)Creation
# - Check SHA1/256/512 config and install mulit buffer mod if need
# - Test SHA1/256/512 mulit buffer and without multi buffer
# - Add SHA checksum stress test

source "sha_common.sh"

# For original configuration
SHA1_M=0
SHA256_M=0
SHA512_M=0
test_kconfigs "m" "CONFIG_CRYPTO_SHA1_MB"
if [ $? -eq 0 ]; then
  SHA1_M=1
fi
test_kconfigs "m" "CONFIG_CRYPTO_SHA256_MB"
if [ $? -eq 0 ]; then
  SHA256_M=1
fi
test_kconfigs "m" "CONFIG_CRYPTO_SHA512_MB"
if [ $? -eq 0 ]; then
  SHA512_M=1
fi

usage()
{
  cat <<-EOF >&2
  usage: ./${0##*/} [-t SHA_TYPE] [-n SHA_NAME] [-a ACTION] [-s STRESS] [-h help]
  -t  SHA_TYPE, such as sha1_mb sha256_mb sha_512mb
  -n  SHA_NAME, such as CONFIG_CRYPTO_SHA1_MB
  -a  ACTION, such as install test or recovery
  -s  STRESS checksum test, such as 100000 times
  -h  show this
EOF
}

teardown_handler="sha_teardown"
function sha_teardown()
{
  test_print_trc "Set original CPU mode"
  echo "$CPU0_GOVERNOR_ORIGINAL" > "$CPU_PATH"/scaling_governor
  if [ "$SHA1_M" == 1 ]; then
    test_print_trc "modprobe -r sha1_mb"
    modprobe -r sha1_mb
  fi
  if [ "$SHA256_M" == 1 ]; then
    test_print_trc "modprobe -r sha256_mb"
    modprobe -r sha256_mb
  fi
  if [ "$SHA512_M" == 1 ]; then
    test_print_trc "modprobe -r sha512_mb"
    modprobe -r sha512_mb
  fi
}

sha_main()
{
  if [ "$ACTION" == "install" ]; then
    check_type_install "$SHA_TYPE" "$SHA_NAME"
  elif [ "$ACTION" == "test" ]; then
    SHA_CONFIG=$(get_kconfig "$SHA_NAME")
    if [ "$SHA_CONFIG" == "m" ]; then
      test_print_trc "$SHA_NAME is m, modprobe $SHA_TYPE"
      load_unload_module.sh -l -d "$SHA_TYPE" || \
        die "load module $SHA_TYPE failed"
    elif [ "$SHA_CONFIG" == "y" ]; then
      test_print_trc "$SHA_NAME set y, could test multi buffer directly."
    else
      block_test "$SHA_NAME does not set to y or m, block multi buffer test."
    fi
    sleep 1
    test_sha_mb "$SHA_TYPE" || die "$SHA_TYPE test failed!"
  elif [ "$ACTION" == "speed" ]; then
    test_sha_speed || die "Test sha256 and 512 speed failed!"
  elif [ "$ACTION" == "recovery" ]; then
    SHA_CONFIG=$(get_kconfig "$SHA_NAME")
    test_print_trc "$SHA_NAME set: $SHA_CONFIG"
    if [ "$SHA_CONFIG" == "m" ]; then
      test_print_trc "$SHA_NAME is m, rmmod $SHA_TYPE."
      load_unload_module.sh -u -d "$SHA_TYPE" || \
        die "unload module $SHA_TYPE failed"
    elif [ "$SHA_CONFIG" == "y" ]; then
      skip_test "$SHA_NAME set y, could not rmmod."
    else
      block_test "$SHA_NAME does not set to y or m, block multi buffer test."
    fi
  fi

  # TC: SHA_S_STRESS_SHA_CHECKSUM like sha256 and sha512 checksum 100000 times
  if [ "$STRESS_CHECKSUM" -eq 1 ]; then
    set_performance_cpu
    SHA_CONFIG=$(get_kconfig "$SHA_NAME")

    # Tested the sha checksums, to support SHA_MB set y, m or not set
    if [ "$SHA_TYPE" == "sha256_mb" ]; then
      SHA_SUM="sha256sum"
    elif [ "$SHA_TYPE" == "sha512_mb" ]; then
      SHA_SUM="sha512sum"
    else
      block_test "SHA_TYPE: $SHA_TYPE is not correct type."
    fi
    sha_checksum_test "$SHA_SUM" "$CHECKSUM_NUMBER"

    # If SHA_MB set to m as expect, will install sha_mb to test and check result
    if [ "$SHA_CONFIG" == "m" ]; then
      test_print_trc "Will install $SHA_TYPE to test checksum."
      load_unload_module.sh -l -d "$SHA_TYPE"
      sleep 1
      sha_checksum_test "$SHA_SUM" "$CHECKSUM_NUMBER"
    fi
  fi
}

: "${STRESS_CHECKSUM:=0}"
: "${CHECKSUM_NUMBER:=0}"

while getopts :t:n:a:s:h: arg
do
  case $arg in
      t)
          SHA_TYPE=$OPTARG
          ;;
      n)
          SHA_NAME=$OPTARG
          ;;
      a)
          ACTION=$OPTARG
          ;;
      s)
          STRESS_CHECKSUM=1
          CHECKSUM_NUMBER=$OPTARG
          ;;
      h)
          usage && exit 0
          ;;
      \?)
          usage
          die "Invalid Option -$OPTARG"
          ;;
      :)
          usage
          die "Option -$OPTARG requires an argument."
          ;;
  esac
done

sha_main
exec_teardown
