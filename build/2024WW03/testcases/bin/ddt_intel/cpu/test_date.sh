#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
# Show date script for CET dump/restore process test

test_date() {
  local i=1;

  while [[ "$i" -le 600 ]]; do
    date
    ((i++))
    sleep 1
  done
}

test_date
