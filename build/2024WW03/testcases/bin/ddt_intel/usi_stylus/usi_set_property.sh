#!/bin/sh
source "usi_test.sh"

echo "Please hold a pen on screen."

input_param=$1
expected_ret=$2
set_value=$(echo $input_param | cut -d " " -f 2)
set_property=$(echo $input_param | cut -d " " -f 1)
# Run server in debug mode to cover debug prints
run_test "server" "0" 0 1

sleep 1
run_test "client" "$input_param" $expected_ret

if ["$expected_ret" == 0] ; then
   # Read back set values
   col=$(./hid_usi_client $set_property | grep ":" | cut -d ":" -f 2 | cut -c 2-)
   if [ "$col" != "$set_value" ] ; then
      echo "Bad values [$col], expected [$set_value]"
      echo "Stopping server $server_pid..."
      kill -INT $server_pid
      exit 1
   fi
fi

echo "Stopping server $server_pid..."
kill -INT "$server_pid"


