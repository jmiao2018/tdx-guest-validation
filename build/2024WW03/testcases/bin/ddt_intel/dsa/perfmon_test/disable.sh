#!/bin/bash
echo "Stop wq0.0"
echo wq0.0 > /sys/bus/dsa/drivers/dsa/unbind
echo "Stop wq0.1"
echo wq0.1 > /sys/bus/dsa/drivers/dsa/unbind

echo "Stopping dsa0"
echo dsa0 > /sys/bus/dsa/drivers/dsa/unbind
