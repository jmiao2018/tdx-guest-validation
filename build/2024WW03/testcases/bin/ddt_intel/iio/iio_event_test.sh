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

# This script is to test IIO event driver.

source "common.sh"
source "iio-common.sh"

############################# Functions #######################################
usage()
{
cat <<-EOF >&2
        usage: ./${0##*/} [-c CASE_ID] [-d IIO_DEVICE] [-l TEST_LOOP] [-C CHANNEL_INDEX]
        -c CASE_ID      test case ID.
        -d IIO_DEVICE   IIO device name;
                        it is optional; if not provided, 'get_iio_devname.sh'
                        will be called to query all available IIO devices.
        -l TEST_LOOP    test loop for r/w. default is 1.
        -C CHN_INDEX    channel index for enable event. default is all.
                        value can be any combinations of [x|y|z] or all
        -h Help         print this usage
EOF
exit 0
}

############################### CLI Params ###################################
while getopts  :c:C:d:l:h arg
do case $arg in
        c)
            TEST_ID="$OPTARG";;
        d)
            IIO_DEVICE="$OPTARG";;
        l)
            TEST_LOOP="$OPTARG";;
        C)
            CHANNEL_INDEX="$OPTARG";;
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
: ${TST_LOG:='.iio_event_test.log'}
[[ -n $IIO_DEVICE ]] || \
IIO_DEVICE=$(get_iio_devname.sh "Event") || \
           die "error getting IIO device name for IIO event test"

############# Do the work ###########################################
test_print_trc "Running IIO event test [$TEST_ID] for $TEST_LOOP times"


enable_event()
{
  local evt_name=$1

  test_print_trc " *IIO* [$iio_dev]: enable event by $evt_name"
  do_cmd "echo 1 > $EVENT_SYS_IF/$evt_name"
  get_val=$(cat "$EVENT_SYS_IF/$evt_name")
  if [ $get_val -ne 1 ];then
    test_print_err "enable event by $evt_name"
  else
    test_print_result PASS "enable event by $evt_name"
  fi
}

disable_event()
{
  local evt_name=$1

  test_print_trc " *IIO* [$iio_dev]: disable event by $evt_name"
  do_cmd "echo 0 > $EVENT_SYS_IF/$evt_name"
  get_val=$(cat "$EVENT_SYS_IF/$evt_name")
  if [ $get_val -ne 0 ];then
    test_print_err "disable event by $evt_name"
  else
    test_print_result PASS "disable event by $evt_name"
  fi
}

test_enable_disable_events()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  for iio_dev in $IIO_DEVICE
  do
    IIO_DEV_ID=$(get_iio_devid $iio_dev) || \
              die "error getting ID for IIO device: $iio_dev"
    EVENT_ENA_IF=$(get_iio_event.sh $iio_dev) || \
         die "error getting event enable interfaces for IIO device: $iio_dev"
    EVENT_SYS_IF="$IIO_SYS_DIR/iio:device$IIO_DEV_ID/events"

    test_print_trc " *IIO* ena/dis-able event test on IIO device name: $iio_dev"
    for event_name in $EVENT_ENA_IF
    do
      old_val=$(cat "$EVENT_SYS_IF/$event_name")
      if [ $old_val -eq 0 ];then
        enable_event $event_name
      else
        disable_event $event_name
      fi
      # restore to default event state
      echo $old_val > "$EVENT_SYS_IF/$event_name"
    done
  done

  IFS=$OIFS
}

test_separate_event()
{
  evt_idx=$1
  evt_num=$2

  event_name=$(echo "$EVENT_ENA_IF" | awk -F"|" '{print $'$evt_idx'}')
  test_print_trc " *IIO* test enable separate event: $event_name"
  enable_event $event_name

  # Check other events' state
  local idx=1
  while [ $idx -le $evt_num ]
  do
    if [ $idx -eq $evt_idx ];then
      idx=$(($idx+1))
      continue
    fi

    chk_event_name=$(echo "$EVENT_ENA_IF" | awk -F"|" '{print $'$idx'}')
    get_val=$(cat "$EVENT_SYS_IF/$chk_event_name")
    if [ $get_val -eq 1 ];then
      test_print_err "read $chk_event_name is 1, should be 0"
      exit 1
    fi
  done

  test_print_result PASS "enable separate event: $event_name"
}

test_enable_separate_event()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  for iio_dev in $IIO_DEVICE
  do
    IIO_DEV_ID=$(get_iio_devid $iio_dev) || \
         die "error getting ID for IIO device: $iio_dev"
    EVENT_ENA_IF=$(get_iio_event.sh $iio_dev) || \
         die "error getting event enable interfaces for IIO device: $iio_dev"
    EVENT_SYS_IF="$IIO_SYS_DIR/iio:device$IIO_DEV_ID/events"

    num_event=$(echo "$EVENT_ENA_IF" | awk -F"|" '{print NF}')
    if [ $num_event -eq 1 ];then
      test_print_trc " *IIO* only shared event is registered, \
          test is skipped for IIO device: $iio_dev"
      continue
    fi
    test_print_trc " *IIO* test separate event enable/disable on \
        IIO device name: $iio_dev"
    idx=1
    # disable all channels' events
    while [ $idx -le $num_event ]
    do
      event_name=$(echo "$EVENT_ENA_IF" | awk -F"|" '{print $'$idx'}')
      disable_event $event_name
      idx=$(($idx+1))
    done

    idx=1
    while [ $idx -le $num_event ]
    do
      test_separate_event $idx $num_event
      idx=$(($idx+1))
    done
  done

  IFS=$OIFS
}

enable_channel_events()
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
  EVENT_ENA_IF=$(get_iio_event.sh $dev_name) || \
     die "error getting event enable interfaces for IIO device: $dev_name"
  EVENT_SYS_IF="$IIO_SYS_DIR/iio:device$IIO_DEV_ID/events"
  num_event=$(echo "$EVENT_ENA_IF" | awk -F"|" '{print NF}')

  for chn_name in $EVENT_ENA_IF
  do
    for chn_idx in $CHANNEL_INDEX
    do
      case $chn_idx in
        x|X)
           pattern="in_.*_x_.*_en" ;;
        y|Y)
           pattern="in_.*_y_.*_en" ;;
        z|Z)
           pattern="in_.*_z_.*_en" ;;
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

  [ $enable_all -eq 0 ] || enable_name_list=$EVENT_ENA_IF

  # for shared event spec, skip the test for separated event test
  if [ $num_event -eq 1 -a $enable_all -eq 0 ];then
    test_print_trc " *IIO* *$dev_name* ONLY shared event spec is registered"
    test_print_result PASS " *IIO* *$dev_name* SKIP separated event test"
    return 2
  fi

  [ -n "$enable_name_list" ] || die "no event for channels: $CHANNEL_INDEX"

  # disable all channels' events
  idx=1
  while [ $idx -le $num_event ]
  do
    event_name=$(echo "$EVENT_ENA_IF" | awk -F"|" '{print $'$idx'}')
    disable_event $event_name
    idx=$(($idx+1))
  done

  for name in $enable_name_list
  do
    enable_event $name
  done

  IFS=$OIFS
  return 0
}

check_event_log()
{
  if [ -f $TST_LOG ];then
    cat $TST_LOG | grep -q "^Event:"
    if [ $? -eq 0 ];then
      test_print_result PASS "Event is captured successfully"
      cat $TST_LOG | grep "^Event:"
    else
      cat $TST_LOG | grep -q "^nothing available"
      if [ $? -eq 0 ];then
        test_print_result PASS "Event is not triggered"
      else
        test_print_err "not valid event log"
        exit 1
      fi
    fi
  else
    die "error event log: $TST_LOG"
  fi
}

test_poll_event()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  for iio_dev in $IIO_DEVICE
  do
    test_print_trc " *IIO* test poll events of IIO device: $iio_dev"
    enable_channel_events $iio_dev
    # test is skipped on this iio device
    [ $? -eq 2 ] && continue
    do_cmd "timeout -t 10 iio_event_test -d $iio_dev > $TST_LOG"
    check_event_log
  done
  IFS=$OIFS
}

test_read_event()
{
  # Backup current IFS separator and set a new one
  OIFS=$IFS

  IFS='|'
  for iio_dev in $IIO_DEVICE
  do
    test_print_trc " *IIO* test read events of IIO device: $iio_dev"
    enable_channel_events $iio_dev
    # test is skipped on this iio device
    [ $? -eq 2 ] && continue
    do_cmd "iio_event_test -d $iio_dev -e > $TST_LOG"
    check_event_log
  done
  IFS=$OIFS
}

x=1
while [ $x -le $TEST_LOOP ]
do
  test_print_start "IIO event test [$TEST_ID] loop: $x"

  case $TEST_ID in
    1) test_enable_disable_events;;
    2) test_enable_separate_event;;
    3) test_poll_event;;
    4) test_read_event;;
    *) test_print_err "error test id: $TEST_ID"
  esac

  test_print_end "IIO event test [$TEST_ID] loop: $x"
  x=$((x+1))
done
