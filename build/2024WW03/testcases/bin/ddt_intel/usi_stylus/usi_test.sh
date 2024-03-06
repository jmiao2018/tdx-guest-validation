#!/bin/sh

run_test()
{
  if [ ! -x hid_usi_server ] || [ ! -x hid_usi_client ] ; then
    echo "hid_usi_* binaries not found in current directory."
    exit 1
  fi

  MODE=$1
  ARGS=$2
  EXPECTED=$3
  BG=$4

  # Expected return value for test binary
  if [ "$EXPECTED" = "" ] ; then
    EXPECTED=0
  fi

  # Test binary setup. 'prof' is the log file to use for clang test coverage.
  if [ "$1" = "server" ] ; then
    prog=./hid_usi_server
  else
    prog=./hid_usi_client
  fi

  echo "----------------------"
  echo "Running $MODE test"
  if [ "$BG" != "" ] ; then
    "$prog" "$ARGS" 2>&1 &
  else
    "$prog" "$ARG" 2>&1
  fi

  RET=$?

  # Capture started process id for background mode
  if [ "$BG" != "" ] ; then
    if [ "$MODE" = "server" ] ; then
      server_pid=$!
    else
      client_pid=$!
    fi
  fi

  # Verify result
  if [ "$EXPECTED" != "$RET" ] ; then
    echo "ERROR: $MODE test returned $RET, expected $EXPECTED!"
    exit 1
  fi
}
"$@"

