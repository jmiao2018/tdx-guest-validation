#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# It's for USB4 device read and write function tests
#

source "usb4_common.sh"

usage() {
  cat <<__EOF
  usage: ./${0##*/}  [-t SCENARIO][-h]
  -p  Protocol type like ssd 2.0 3.0 which connected with thunderbolt
  -d  Device tp like flash or uas
  -b  Block size such as 1MB 10MB
  -c  Block count such as 1 10 100
  -t  Times want to execute such as 1 10
  -m  mode for other test
  -h  show This
__EOF
}

main() {
  local test_file=""
  local iozone_bin=""

  # Prepare stage
  check_auto_connect
  check_test_env
  check_free_partition "$BLOCK_SIZE" "$BLOCK_COUNT"

  is_only_usb4_device_connected \
        || die "Not only USB4 device connected"

  # Block rw test in dp only mode
  check_security_mode
  if [ "$SECURITY" == "dponly" ]; then
    block_test "dponly mode, could not read write test"
  fi

  # Enable authorized, find device connected by thunderbolt
  enable_authorized
  sleep 5
  find_tbt_device "$BLOCK_SIZE" "$BLOCK_COUNT" "$PROTOCOL_TYPE" "$DEVICE_TP"
  [[ -n "$DEVICE_NODE" ]] || die "No $PROTOCOL_TYPE $DEVICE_TP node:$DEVICE_NODE"

  case $MODE in
    NA)
      # Generate test folder and test file
      [[ -e "$TEMP_DIR" ]] || block_test "fail to create temporary directory!"
      test_print_trc "TEMP_DIR: $TEMP_DIR"
      test_file=$(generate_test_file "$BLOCK_SIZE" "$BLOCK_COUNT" "$TEMP_DIR")

      mount_dev "$DEVICE_NODE" "$MOUNT_FOLDER"

      # Read write test in request times
      for ((i=1; i <= TIME; i++)); do
        test_print_trc "------------------------$i times read write test:"
        write_test_with_file "$RW_FILE" "$test_file" \
          "$BLOCK_SIZE" "$BLOCK_COUNT"
        read_test_with_file "$RW_FILE" "$test_file" \
          "$BLOCK_SIZE" "$BLOCK_COUNT"
      done
      rm -rf "$TEMP_DIR"
      ;;
    *)
      usage
      die "Invalid MODE:$MODE"
      ;;
  esac

  fail_dmesg_check
}

# Default size 1MB
: ${BLOCK_SIZE:="1MB"}
: ${BLOCK_COUNT:="1"}
: ${TIME:="2"}
: ${DEVICE_TP:="device"}
: ${MODE:="NA"}

while getopts :p:d:b:c:t:m:h arg
do
  case $arg in
    p)
      PROTOCOL_TYPE=$OPTARG
      ;;
    d)
      DEVICE_TP=$OPTARG
      ;;
    b)
      BLOCK_SIZE=$OPTARG
      ;;
    c)
      BLOCK_COUNT=$OPTARG
      ;;
    t)
      TIME=$OPTARG
      ;;
    m)
      MODE=$OPTARG
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

main
exec_teardown
