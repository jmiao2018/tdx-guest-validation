#!/bin/bash

export EC_DIR="/sys/bus/acpi/drivers/ec"
export LID_BUTTON="/proc/acpi/button/lid/LID0/state"

S_CAPS_DIR=`ls -l /sys/class/leds/ | grep caps | grep serio | awk -F"->" '{print $1}' | awk '{print $9}'`
P_CAPS_DIR=`ls -l /sys/class/leds/ | grep caps | grep pci | awk -F"->" '{print $1}' | awk '{print $9}'`
S_NUM_DIR=`ls -l /sys/class/leds/ | grep num | grep serio | awk -F"->" '{print $1}' | awk '{print $9}'`
P_NUM_DIR=`ls -l /sys/class/leds/ | grep num | grep pci | awk -F"->" '{print $1}' | awk '{print $9}'`
S_SCROLL_DIR=`ls -l /sys/class/leds/ | grep scroll | grep serio | awk -F"->" '{print $1}' | awk '{print $9}'`
P_SCROLL_DIR=`ls -l /sys/class/leds/ | grep scroll | grep pci | awk -F"->" '{print $1}' | awk '{print $9}'`

export SER_CAPS_LOCK_DIR="/sys/class/leds/${S_CAPS_DIR}"
export PCI_CAPS_LOCK_DIR="/sys/class/leds/${P_CAPS_DIR}"
export SER_NUM_LOCK_DIR="/sys/class/leds/${S_NUM_DIR}"
export PCI_NUM_LOCK_DIR="/sys/class/leds/${P_NUM_DIR}"
export SER_SCROLL_LOCK_DIR="/sys/class/leds/${S_SCROLL_DIR}"
export PCI_SCROLL_LOCK_DIR="/sys/class/leds/${P_SCROLL_DIR}"
