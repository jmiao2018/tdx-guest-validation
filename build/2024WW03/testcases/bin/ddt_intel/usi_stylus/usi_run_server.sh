#!/bin/sh
source "usi_test.sh"

input_param=$1
# Run server in debug mode to cover debug prints
run_test "server" "$input_param" 0 1

sleep 1
run_test "client" "--dump" 0

echo "Stopping server $server_pid..."
kill -INT "$server_pid"


