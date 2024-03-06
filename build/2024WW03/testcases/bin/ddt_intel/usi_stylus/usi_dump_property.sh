#!/bin/sh
source "usi_test.sh"

echo "Please hold a pen on screen."

input_param=$1

run_test "server" "0" 0 1
sleep 1
run_test "client" "$input_param" 0

echo "Stopping server $server_pid..."
kill -INT "$server_pid"


