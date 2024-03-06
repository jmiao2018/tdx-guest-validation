#! /bin/sh
#
# Copyright (c) Intel Corporation, 2015
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation version 2.
#
# This program is distributed "as is" WITHOUT ANY WARRANTY of any
# kind, whether express or implied; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# This script is to test IIO buffer driver.

source "common.sh"
source "iio-common.sh"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
        usage: ./${0##*/} [-c CASE_ID] [-d IIO_DEVICE] [-l TEST_LOOP] [-C CHANNEL_INDEX] [-t TRIGGER_DEV]
        -c CASE_ID      test case ID.
        -d IIO_DEVICE   IIO device name; it is optional; if not provided, will use 'get_iio_devname.sh' to query all available IIO devices.
        -l TEST_LOOP    test loop for r/w. default is 1.
        -C CHN_INDEX    channel index for trigger buffer test. default is all.
                        value can be any combinations of [x|y|z|t] or all
        -t TRIG_DEV     trigger device used for triggered buffer test.
                        default is all available trigger devices.
                        value: any-data|any-motion , or trigger devie name
        -h Help         print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts  :c:C:d:l:t:h arg
do case $arg in
        c)
            TEST_ID="$OPTARG";;
        d)
            IIO_DEVICE="$OPTARG";;
        l)
            TEST_LOOP="$OPTARG";;
        C)
            CHANNEL_INDEX="$OPTARG";;
        t)
            TRIG_DEVICE="$OPTARG";;
        h)  usage;;
        :)  test_print_trc "$0: Must supply an argument to -$OPTARG." >&2
            exit 1
            ;;

        \?) test_print_trc "Invalid Option -$OPTARG ignored." >&2
            usage
            exit 1
            ;;
esac
done

############################ DEFAULT Params #######################
: ${TEST_ID:='1'}
: ${TEST_LOOP:='1'}
: ${CHANNEL_INDEX:='all'}
: ${TST_LOG:='.iio_buffer_test.log'}
[[ -n $IIO_DEVICE ]] || \
IIO_DEVICE=$(get_iio_devname.sh "Buffer") || \
				die "error getting IIO device name for IIO buffer test"

############# Do the work ###########################################
test_print_trc "Running IIO buffer test [$TEST_ID] for $TEST_LOOP times"

test_set_buffer()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  for iio_dev in $IIO_DEVICE
  do
    IIO_DEV_ID=$(get_iio_devid $iio_dev) || \
				die "error getting ID for IIO device: $iio_dev"
    SETGET_BUF_IF="$IIO_SYS_DIR/iio:device$IIO_DEV_ID/buffer/length"

    test_print_trc " *IIO*  test on IIO device name: $iio_dev id: $IIO_DEV_ID"
    old_val=$(cat "$SETGET_BUF_IF")
    for set_val in $BUF_LEN
    do
      test_print_trc " *IIO*  [$iio_dev]: set buffer length to $set_val"
      do_cmd "echo $set_val > $SETGET_BUF_IF"
      get_val=$(cat "$SETGET_BUF_IF")
      if [ "$inverted_return" == "false" ];then
        if [ $get_val -ne $set_val ];then
          test_print_err "set buffer length to $set_val"
        else
          test_print_result PASS "set buffer length to $set_val"
        fi
      else
        if [ $get_val -eq $set_val ];then
          test_print_err "set invalid buffer length to $set_val"
        else
          test_print_result PASS "set invalid buffer length to $set_val"
        fi
      fi
    done
    # restore to default buffer length
    echo $old_val > "$SETGET_BUF_IF"
  done

  IFS=$OIFS
}

test_set_valid_buffer()
{
  BUF_LEN=$(get_valid_buf_len.sh) || \
                die "error getting valid buffer length"

  test_print_trc " *IIO*  test set valid buffer length"
  test_set_buffer
}

test_set_invalid_buffer()
{
  BUF_LEN=$(get_invalid_buf_len.sh) || \
                die "error getting invalid buffer length"

  inverted_return="true"
  test_print_trc " *IIO*  test set invalid buffer length"
  test_set_buffer
  inverted_return="false"
}

active_buffer()
{
  local iiodev_id=$1
  ENA_BUF_IF="$IIO_SYS_DIR/iio:device$iiodev_id/buffer/enable"

  do_cmd "echo 1 > $ENA_BUF_IF"
  get_val=$(cat "$ENA_BUF_IF")
  if [ $get_val -eq 1 ];then
    test_print_result PASS "active trigger buffer successfully"
  else
    test_print_err "FAIL to active trigger buffer"
    exit 1
  fi
}

deactive_buffer()
{
  local iiodev_id=$1
  ENA_BUF_IF="$IIO_SYS_DIR/iio:device$iiodev_id/buffer/enable"

  do_cmd "echo 0 > $ENA_BUF_IF"
  get_val=$(cat "$ENA_BUF_IF")
  if [ $get_val -eq 0 ];then
    test_print_result PASS "deactive trigger buffer successfully"
  else
    test_print_err "FAIL to deactive trigger buffer"
    exit 1
  fi
}

_set_trigger()
{
  local iiodev_id=$1
  local trigger_dev=$2
  SET_TRI_IF="$IIO_SYS_DIR/iio:device$iiodev_id/trigger/current_trigger"

  do_cmd "echo $trigger_dev > $SET_TRI_IF"
  get_tri=$(cat "$SET_TRI_IF")
  if [ -n "$get_tri" -a "$get_tri" = "$trigger_dev" ];then
    test_print_result PASS "set trigger device: $trigger_dev"
  else
    test_print_err "set trigger device: $trigger_dev"
    exit 1
  fi
}

set_trigger()
{
  local iiodev_id=$1
  local trigger_dev=$2
  ENA_BUF_IF="$IIO_SYS_DIR/iio:device$iiodev_id/buffer/enable"
  SET_TRI_IF="$IIO_SYS_DIR/iio:device$iiodev_id/trigger/current_trigger"

  # Check if buffer is already activated
  ret=$(cat $ENA_BUF_IF)
  if [ $ret -eq 0 ];then
    # Set trigger device
    _set_trigger $iiodev_id $trigger_dev
  else
    test_print_trc " *IIO*  Buffer is already activated"
    deactive_buffer $iiodev_id
    _set_trigger $iiodev_id $trigger_dev
  fi
}

remove_trigger()
{
  local iiodev_id=$1
  SET_TRI_IF="$IIO_SYS_DIR/iio:device$iiodev_id/trigger/current_trigger"

  do_cmd "echo NULL > $SET_TRI_IF"
  get_tri=$(cat "$SET_TRI_IF")
  if [ -z "$get_tri" ];then
    test_print_result PASS "remove trigger device"
  else
    test_print_err "FAIL to remove trigger device"
    exit 1
  fi
}

test_neg_set_buffer()
{
  test_print_trc " *IIO*  negative test set buffer length when buffer is activated"

  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  for iio_dev in $IIO_DEVICE
  do
    IIO_DEV_ID=$(get_iio_devid $iio_dev) || \
				die "error getting ID for IIO device: $iio_dev"
    IIO_TRI_DEV=$(get_iio_trigger.sh $iio_dev | awk -F"|" '{print $1}')
    SETGET_BUF_IF="$IIO_SYS_DIR/iio:device$IIO_DEV_ID/buffer/length"

    test_print_trc " *IIO*  test on IIO device name: $iio_dev id: $IIO_DEV_ID"
    old_val=$(cat "$SETGET_BUF_IF")

    set_trigger $IIO_DEV_ID $IIO_TRI_DEV
    # Set an valid buffer length beforehand
    do_cmd "echo 32 > $SETGET_BUF_IF"
    active_buffer $IIO_DEV_ID
    should_fail "echo 128 > $SETGET_BUF_IF"
    deactive_buffer $IIO_DEV_ID
    remove_trigger $IIO_DEV_ID
    test_print_result PASS "set buffer length when buffer is activated"

    # restore to default buffer length
    echo $old_val > "$SETGET_BUF_IF"
  done
  IFS=$OIFS
}

enable_scan_channel()
{
  local iiodev_id=$1
  local chan_name=$2
  SCAN_ELEMENT_IF="$IIO_SYS_DIR/iio:device$iiodev_id/scan_elements"

  test_print_trc " *IIO* enable scan_channel by $chan_name"
  do_cmd "echo 1 > $SCAN_ELEMENT_IF/$chan_name"
  get_val=$(cat "$SCAN_ELEMENT_IF/$chan_name")
  if [ $get_val -ne 1 ];then
    test_print_err "enable scan_channel by $chan_name"
  else
    test_print_result PASS "enable scan_channel by $chan_name"
  fi
}

disable_scan_channel()
{
  local iiodev_id=$1
  local chan_name=$2
  SCAN_ELEMENT_IF="$IIO_SYS_DIR/iio:device$iiodev_id/scan_elements"

  test_print_trc " *IIO* disable scan_channel by $chan_name"
  do_cmd "echo 0 > $SCAN_ELEMENT_IF/$chan_name"
  get_val=$(cat "$SCAN_ELEMENT_IF/$chan_name")
  if [ $get_val -ne 0 ];then
    test_print_err "disable scan_channel by $chan_name"
  else
    test_print_result PASS "disable scan_channel by $chan_name"
  fi
}

enable_scan_channels()
{
  local dev_name=$1
  local first=1
  local enable_all=0
  local enable_name_list=

  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'

  IIO_DEV_ID=$(get_iio_devid $dev_name) || \
              die "error getting ID for IIO device: $dev_name"
  scan_channels=$(get_iio_channel.sh $dev_name) || \
     die "error get scan channel interface for IIO device: $dev_name"
  num_channels=$(echo "$scan_channels" | awk -F"|" '{print NF}')

  for chn_name in $scan_channels
  do
    for chn_idx in $CHANNEL_INDEX
    do
      case $chn_idx in
        x|X)
           pattern="in_.*_x_en" ;;
        y|Y)
           pattern="in_.*_y_en" ;;
        z|Z)
           pattern="in_.*_z_en" ;;
        t|T)
           pattern="in_timestamp_en" ;;
        all)
           enable_all=1 && break 2 ;;
          *) die "error channel index: $chn_idx" ;;
      esac
      echo "$chn_name" | grep -q "$pattern"
      if [ $? -eq 0 ];then
        if [ $first -eq 1 ];then
          first=0
          enable_name_list=$chn_name
        else
          enable_name_list="$enable_name_list|$chn_name"
        fi
      fi
    done
  done

  [ $enable_all -eq 0 ] || enable_name_list=$scan_channels

  [ -n "$enable_name_list" ] || \
           die "FAIL to get scan channels thr $CHANNEL_INDEX"

  # disable all channels' events
  idx=1
  while [ $idx -le $num_channels ]
  do
    scan_chan=$(echo "$scan_channels" | awk -F"|" '{print $'$idx'}')
    disable_scan_channel $IIO_DEV_ID $scan_chan
    idx=$(($idx+1))
  done

  for name in $enable_name_list
  do
    enable_scan_channel $IIO_DEV_ID $name
  done

  IFS=$OIFS
}

check_buffer_log()
{
  local pattern=
  for chn_idx in $CHANNEL_INDEX
  do
    case $chn_idx in
        x|X)
           pattern="in_.*_x" ;;
        y|Y)
           pattern="in_.*_y" ;;
        z|Z)
           pattern="in_.*_z" ;;
        t|T)
           pattern="in_timestamp" ;;
        all)
           pattern="in_.*";;
      esac
  done

  if [ -f $TST_LOG ];then
    cat $TST_LOG | grep -q "$pattern"
    if [ $? -eq 0 ];then
      test_print_result PASS "triggered buffer data captured successfully"
      cat $TST_LOG
    else
      test_print_err "NO triggered buffer data"
      exit 1
    fi
  else
    die "error event log: $TST_LOG"
  fi
}

gen_test_channels()
{
  local dev_name=$1
  scan_channels=$(get_iio_channel.sh $dev_name) || \
     die "error get scan channel interface for IIO device: $dev_name"

  first=1
  for chn_idx in $CHANNEL_INDEX
  do
    case $chn_idx in
        x|X)
           pattern="in_.*_x_en" ;;
        y|Y)
           pattern="in_.*_y_en" ;;
        z|Z)
           pattern="in_.*_z_en" ;;
        t|T)
           pattern="in_timestamp_en" ;;
        all)
           TEST_CHANNELS=$(echo "$scan_channels" | sed -e 's/|/;/g')
           return;;
          *) die "error channel index: $chn_idx" ;;
     esac
     chn_name=$(lsiio -d $dev_name -c | grep "$pattern" | cut -d":" -f2)
     if [ -n "chn_name" ];then
       chn_name=$(echo $chn_name | sed -e 's/^[ ,\t]*//g' -e 's/[ ,\t]*$//g')
       if [ $first -eq 1 ];then
         first=0
         TEST_CHANNELS=$chn_name
       else
         TEST_CHANNELS="$TEST_CHANNELS;$chn_name"
       fi
     fi
  done
}

test_trigger_buffer()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  [ -n "$TRIG_DEVICE" ] || need_query_tridev=1
  for iio_dev in $IIO_DEVICE
  do
    test_print_trc " *IIO* test triggered buffer on IIO device: $iio_dev"
    test_print_trc " *IIO* test scan channel: $CHANNEL_INDEX"
    test_print_trc " *IIO* test trigger device: $TRIG_DEVICE"

    # reset buffer state
    iiodev_id=$(get_iio_devid $iio_dev) || \
				die "error getting ID for IIO device: $iio_dev"
    deactive_buffer $iiodev_id

    if [ "$need_query_tridev" -eq 1 ];then
      TRIG_DEVICE=$(get_iio_trigger.sh "$iio_dev") || \
				die "error get trigger device for $iio_dev"
    fi

    case $TRIG_DEVICE in
      "any-data")
        trig_devices=$(lsiio -d "$iio_dev" -t | grep "$iio_dev-dev*" | \
             cut -d" " -f2)
      ;;
      "any-motion")
        trig_devices=$(lsiio -d "$iio_dev" -t | \
             grep "$iio_dev-any-motion-dev*" | cut -d" " -f2)
      ;;
      *) # do nothing, for user-specified trigger name
        trig_devices=$TRIG_DEVICE
      ;;
    esac

    for trigger_dev in $trig_devices
    do
      #enable_scan_channels $iio_dev
      gen_test_channels $iio_dev
      test_print_trc " *IIO* start test with trigger: $trigger_dev"
      do_cmd "iio_buffer_test -d $iio_dev -t $trigger_dev \
         -c \"$TEST_CHANNELS\" -e > $TST_LOG"
      check_buffer_log
    done
  done
  IFS=$OIFS
}

test_trigger_buffer_with_poll()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  [ -n "$TRIG_DEVICE" ] || need_query_tridev=1
  for iio_dev in $IIO_DEVICE
  do
    test_print_trc " *IIO* test triggered buffer (poll event) on IIO device: $iio_dev"
    test_print_trc " *IIO* test scan channel: $CHANNEL_INDEX"
    test_print_trc " *IIO* test trigger device: $TRIG_DEVICE"

    # reset buffer state
    iiodev_id=$(get_iio_devid $iio_dev) || \
				die "error getting ID for IIO device: $iio_dev"
    deactive_buffer $iiodev_id

    if [ "$need_query_tridev" -eq 1 ];then
      TRIG_DEVICE=$(get_iio_trigger.sh "$iio_dev") || \
				die "error get trigger device for $iio_dev"
    fi

    case $TRIG_DEVICE in
      "any-data")
        trig_devices=$(lsiio -d "$iio_dev" -t | grep "$iio_dev-dev*" | \
             cut -d" " -f2)
      ;;
      "any-motion")
        trig_devices=$(lsiio -d "$iio_dev" -t | \
             grep "$iio_dev-any-motion-dev*" | cut -d" " -f2)
      ;;
      *) # do nothing, for user-specified trigger name
        trig_devices=$TRIG_DEVICE
      ;;
    esac

    for trigger_dev in $trig_devices
    do
      #enable_scan_channels $iio_dev
      gen_test_channels $iio_dev
      test_print_trc " *IIO* start test with trigger: $trigger_dev"
      do_cmd "timeout -t 10 iio_buffer_test -d $iio_dev -t $trigger_dev \
        -c \"$TEST_CHANNELS\" > $TST_LOG"
      check_buffer_log
    done
  done
  IFS=$OIFS
}

x=1
while [ $x -le $TEST_LOOP ]
do
  test_print_start "IIO buffer test [$TEST_ID] loop: $x"

  case $TEST_ID in
    1) test_set_valid_buffer;;
    2) test_set_invalid_buffer;;
    3) test_neg_set_buffer;;
    4) test_trigger_buffer;;
    5) test_trigger_buffer_with_poll;;
    *) test_print_err "error test id: $TEST_ID"
  esac

  test_print_end "IIO buffer test [$TEST_ID] loop: $x"
  x=$((x+1))
done

