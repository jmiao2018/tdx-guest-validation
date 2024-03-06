#!/bin/bash

###############################################################################
# Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
# Copyright (C) 2015 Intel - http://www.intel.com/
#
# This program is free software; you can redistribute it and/or
# modify it under the temms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
###############################################################################
# Contributors:
#   Ruben Diaz <ruben.a.diaz.jimenez@intel.com> (Intel)
#     -Added logic to create folders required to perform common test ops
#      (mount,read,write).
#     -Changed shebang and some cmd's to force the use busybox cmd set.
#     -Modified mount point and R/W ops folder due to permission restriction in
#      Android rootfs, change to /data.
#     -Modified untar() decompression tool logic.
#     -Added get_tarball() wget error handling.
#     -Added logic to work with both tarball from source and obtain tarball
#      from DUT.
#     -Added logic for FS format check before test.
#     -Added logic to block test if there's not enough space in dev_node to
#      perform the test.
#     -Removed tarball file removal.
#     -Added -T and -s option to build fixed size tarball gzip / bzip.
###############################################################################

# @desc Perform extract tar ball into both blk device and another location and
#       then compair the contents to check if blk write went ok.
# @params [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-m MNT_POINT]
#         [-l TEST_LOOP] [-t TARBALL_SRC] ] [-T TARBALL_TYPE] [-s TARBALL_SIZE]
# @returns
# @history 2015-02-12: Copied from ddt -> ddt_intel
# @history 2015-02-17: Ported to work with Android on IA.
# @history 2015-04-08: Added check before mount_point removal.
# @history 2015-04-17: Added logic for FS format check before test.
# @history 2015-04-26: Added logic to check if there's enough space in dev_node.
# @history 2015-04-26: Avoid original tarball file removal from DUT.

source "blk_device_common.sh"

############################# Functions #######################################
usage() {
cat <<-EOF >&2
usage: ./${0##*/} [-n DEV_NODE] [-d DEVICE_TYPE] [-f FS_TYPE] [-m MNT_POINT]
                  [-l TEST_LOOP] [-t TARBALL_SRC] ] [-T TARBALL_TYPE]
                  [-s TARBALL_SIZE]
  -n DEV_NODE    optional param; device node like /dev/mtdblock2; /dev/sda1
  -f FS_TYPE     filesystem type like jffs2, ext2, etc
  -m MNT_POINT   mount point
  -d DEVICE_TYPE device type like 'nand', 'mmc', 'usb' etc
  -l TEST_LOOP   test loop for r/w. default is 1.
  -t TARBALL_SRC tarball location
  -h Help        print this usage
EOF
exit 0
}

# wget tarball from source
get_tarball() {

  if [[ $# -ne 2 ]]; then
    die "Usage: $0 <tarball-wget-src-path> <tarball-dest-path>"
  fi

  TARBALL_PATH=$2
  TARBALL_SRC=$1
  TARBALL_BASENAME=$(basename "${TARBALL_SRC}")
  test_print_trc "Getting a rootfs tarball"
  if [[ -f "${BLK_TEST_DIR}/${TARBALL_BASENAME}" ]]; then
    do_cmd rm "${BLK_TEST_DIR}/${TARBALL_BASENAME}" > /dev/null 2>"$1"
  fi
  do_cmd cd "${BLK_TEST_DIR}"
  do_cmd wget "${TARBALL_SRC}" \
    || block_test "Error: wget could not obtain tarball ${TARBALL_SRC}"
  do_cmd mv "${TARBALL_BASENAME}" "${TARBALL_PATH}"
}

# Extract tarball to destination folder
untar() {

  if [[ $# -ne 2 ]]; then
    die "Usage: $0 <tarball-path> <destination-folder>"
  fi

  TARBALL=$1
  DEST=$2

  if [[ ! -f "${TARBALL}" || ! -d "${DEST}" ]]; then
    die "${TARBALL} or ${DEST} doesn't exist!"
  fi

  # find out type
  TYPE=$(echo "${TARBALL}" | tail -c 3)
  TARBALL_BASENAME=$(basename "${TAR_BALL}")
  do_cmd cp "${TARBALL}" "${DEST}"
  do_cmd cd "${DEST}"

  case "${TYPE}" in
    gz)    do_cmd tar -xzf "${TARBALL_BASENAME}" ;;
    bz|z2) do_cmd tar -xjf "${TARBALL_BASENAME}" ;;
    *)     die "Unrecognized tarball type" ;;
  esac

  do_cmd cd "${BLK_TEST_DIR}"
}


############################### CLI Params ###################################
main() {
while getopts :d:f:m:n:l:t:T:s:h arg; do
case "${arg}" in
  n)  DEV_NODE="$OPTARG" ;;
  d)  DEVICE_TYPE="$OPTARG" ;;
  f)  FS_TYPE="$OPTARG" ;;
  m)  MNT_POINT="$OPTARG" ;;
  l)  TEST_LOOP="$OPTARG" ;;
  t)  TARBALL_SRC="$OPTARG" ;;
  T)  TARBALL_TYPE="$OPTARG" ;;
  s)  TARBALL_BASE_SIZE="$OPTARG" ;;
  h)  usage ;;
  :)  test_print_err "$0: Must supply an argument to -$OPTARG."
      die
      ;;
  \?) test_print_err "Invalid Option -$OPTARG ignored."
      die
      ;;
esac
done

############################ DEFAULT Params #######################
if [[ -z "${DEV_NODE}" ]]; then
  DEV_NODE=$(get_blk_device_node.sh -d "${DEVICE_TYPE}") \
    || block_test "Error getting device node for ${DEVICE_TYPE}: ${DEV_NODE}"
  test_print_trc "DEV_NODE returned from get_blk_device_node is: ${DEV_NODE}"
fi

: "${MNT_POINT:=$TEST_MNT_DIR/partition_$DEVICE_TYPE_$$}"
: ${TEST_LOOP:='1'}

SRC_FILE="${TEST_DIR}/tarball_base_file"
LOCATION1="${BLK_TEST_DIR}"

test_print_trc "DEV_NODE: ${DEV_NODE}"
test_print_trc "MNT_POINT:${MNT_POINT}"
test_print_trc "FS_TYPE:  ${FS_TYPE}"

############# Do the work ###########################################
do_cmd mkdir -p "${LOCATION1}"

# Get tarball to perform test
if [[ -z "${TARBALL_SRC}" ]]; then
  # Tarball not provided, create or find one in system
  if [[ -n "${TARBALL_TYPE}" ]]; then
    [[ -z "${TARBALL_BASE_SIZE}" ]] && block_test "No size provided to build tarball"
    test_print_trc "Building custom tarball with ${TARBALL_BASE_SIZE} fixed size"
    # Create base file for tarball with given size
    "${DD}" if="/dev/urandom" of="${SRC_FILE}" bs="${TARBALL_BASE_SIZE}" count=1
    du -h "${SRC_FILE}"
    TAR_BALL="${TEST_DIR}/test_tarball"
    # Create tarball from src file
    case "${TARBALL_TYPE}" in
      gz) TAR_BALL+=".gz"
          do_cmd tar -czf "${TAR_BALL}" "${SRC_FILE}"
          ;;
      bz) TAR_BALL+=".bz2"
          do_cmd tar -cjf "${TAR_BALL}" "${SRC_FILE}"
          ;;
      *)  die "Unrecognized tarball type ${TARBALL_TYPE}" ;;
    esac
  else
    test_print_trc "No tarball src provided, Searching tarball in system..."
    TAR_BALL=$(find /data -name "*gz" -o -name "*bz2" | tail -1)
    if [[ -z "${TAR_BALL}" ]]; then
      block_test "Error: no tarrball to perform the test..."
    fi
  fi
# Before wget this file, one may need set http_proxy in target
else
  do_cmd get_tarball "${TARBALL_SRC}" "${LOCATION1}"
fi


# Check if there's enough space in dev_node
TARBALL_SIZE=$(du -h "${TAR_BALL}" |  awk '{print $1}')
TARBALL_SIZE=$(calc_space_needed_for_test "${TARBALL_SIZE}")
is_dev_node_big_enough "${DEV_NODE}" "${TARBALL_SIZE}"
RET="$?"
[[ "${RET}" -eq 0 ]] \
  || block_test "There's not enough space in ${DEV_NODE}, ${TARBALL_SIZE} MB are required"

trap "cleanup" 0
do_cmd untar "${TAR_BALL}" "${LOCATION1}"

# Check if format is needed
if [[ -n "${FS_TYPE}" ]]; then
  FORMAT_NEEDED=$(is_format_needed "${DEV_NODE}" "${FS_TYPE}")
fi

x=0
while [[ "${x}" -lt "${TEST_LOOP}" ]]; do

  test_print_trc "============= Doing extract tarball test loop ${x} ..."
  do_cmd date

  if [[ -n "${FS_TYPE}" && "${FORMAT_NEEDED}" = "yes" ]]; then
    do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -f "${FS_TYPE}" -m "${MNT_POINT}"
  else
    do_cmd blk_device_prepare_format.sh -d "${DEVICE_TYPE}" -n "${DEV_NODE}" -m "${MNT_POINT}"
  fi

  # Untar tarball to blk device
  if [[ -z "${MNT_POINT}" ]]; then
    die "MNT_POINT can not be empty!"
  fi
  do_cmd mkdir -p "${MNT_POINT}"
  if [[ -n "${MNT_POINT}" && -d "${MNT_POINT}" ]]; then
    do_cmd "rm -r -f ${MNT_POINT}/*" > /dev/null 2> /dev/null
  fi
  do_cmd untar "${TAR_BALL}" "${MNT_POINT}"
  do_cmd diff -r "${LOCATION1}" "${MNT_POINT}"
  x=$((x+1))
  do_cmd date
  if [[ -d "${MNT_POINT}" ]]; then
    do_cmd "rm -r -f ${MNT_POINT}/*" > /dev/null 2> /dev/null
  fi
  do_cmd blk_device_unprepare.sh -n "${DEV_NODE}" -d "${DEVICE_TYPE}" -m "${MNT_POINT}"
  # Set FS_TYPE to nothing so the device will not be formatted for the 2nd and following times
  FS_TYPE=""
done
}

# Clean up
cleanup() {
  do_cmd "blk_device_umount.sh -m ${MNT_POINT}"
  if [[ -n "${LOCATION1}" ]]; then
    do_cmd "rm -r -f ${LOCATION1}/*"  > /dev/null 2>/dev/null
  fi
}

main "$@"
