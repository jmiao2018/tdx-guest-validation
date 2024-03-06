#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && dirname "$PWD" )"
SM_FILE="$DIR/submodules.txt"

echo "$SM_FILE"

git submodule foreach --quiet 'printf "%s:\n\t%s\n\n" $sm_path `git rev-parse HEAD`' > "$SM_FILE"
