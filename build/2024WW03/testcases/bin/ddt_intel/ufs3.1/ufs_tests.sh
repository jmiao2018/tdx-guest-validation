#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Author: Pengfei, Xu <pengfei.xu@intel.com>
# It's for UFS3.1(Universal Flash Storage) tests
#

source "ufs_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-s Scenario][-h]
  -s  Scenario like "ufs_basic"
  -h  show This
__EOF
}

main() {
  local ufs_version="0x031"
  local size="1M"
  local cnt="50"
  local inline_result=""
  local none_result=""

  case $SCENARIO in
    ufs_basic_pci)
      ufs_pci_check
      ;;
    ufs_version)
      ufs_version_check "$ufs_version"
      ;;
    ufs_node)
      ufs_node_check
      [[ -n "$UFS_NODE" ]] || die "No UFS node found:$UFS_NODE"
      ;;
    ufs_transfer_file)
      ufs_node_check
      ufs_mount "/dev/${UFS_NODE}" "$UFS_FOLDER"
      ufs_transfer_file "$UFS_FOLDER" "$size" "$cnt"
      ;;
    inline_encrypt)
      ufs_node_check
      [[ -n "$UFS_NODE" ]] || die "No UFS node found:$UFS_NODE"
      # ext4 format UFS node to avoid fake failure when encryption
      do_cmd "mkfs.ext4 -F /dev/${UFS_NODE}"
      # enable encryption in UFS node
      do_cmd "tune2fs -O encrypt /dev/${UFS_NODE}"
      ufs_mount "/dev/${UFS_NODE}" "$UFS_FOLDER" "$INLINE"
      fio_encrypt_test
      inline_result=$FIO_NUM
      ufs_mount "/dev/${UFS_NODE}" "$UFS_FOLDER"
      fio_encrypt_test "$NONE"
      none_result=$FIO_NUM
      [[ "$inline_result" -gt "$none_result" ]] || \
        test_print_wrg "inline is $inline_result not greater than $none_result!"
      test_print_trc "WR inline_encrypt:$inline_result MB/S, none:$none_result"
      ;;
    ufs_mod)
      load_unload_mod "$UFS_PCI_MOD"
      basic_dmesg_check
      ufs_node_check
      [[ -n "$UFS_NODE" ]] || die "No UFS node found:$UFS_NODE"
      ;;
    *)
      usage && exit 1
      ;;
  esac
}

while getopts :s:h arg; do
  case $arg in
    s)
      SCENARIO=$OPTARG
      ;;
    h)
      usage
      exit 0
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

main
