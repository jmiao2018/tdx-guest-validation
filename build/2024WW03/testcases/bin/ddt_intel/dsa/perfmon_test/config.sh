#!/bin/bash
modprobe idxd
modprobe vfio_pci
# DSA0 config

# set engine 0 to group 0
echo 0 > /sys/bus/dsa/devices/dsa0/engine0.0/group_id

# setup group 0
echo 1 > /sys/bus/dsa/devices/dsa0/wq0.0/block_on_fault
echo 0 > /sys/bus/dsa/devices/dsa0/wq0.0/group_id
echo shared > /sys/bus/dsa/devices/dsa0/wq0.0/mode
echo 10 > /sys/bus/dsa/devices/dsa0/wq0.0/priority
echo 16 > /sys/bus/dsa/devices/dsa0/wq0.0/size
echo "15" > /sys/bus/dsa/devices/dsa0/wq0.0/threshold
echo 0 > /sys/bus/dsa/devices/dsa0/engine0.0/group_id
echo 0 > /sys/bus/dsa/devices/dsa0/engine0.1/group_id
echo "user" > /sys/bus/dsa/devices/dsa0/wq0.0/type
echo "user" > /sys/bus/dsa/devices/dsa0/wq0.0/driver_name
echo "app1" > /sys/bus/dsa/devices/dsa0/wq0.0/name
echo "Engines for group 0"
cat /sys/bus/dsa/devices/dsa0/group0.0/engines
echo "Work queues for group 0"
cat /sys/bus/dsa/devices/dsa0/group0.0/work_queues

# setup group 1
echo 1 > /sys/bus/dsa/devices/dsa0/wq0.1/block_on_fault
echo 1 > /sys/bus/dsa/devices/dsa0/wq0.1/group_id
echo dedicated > /sys/bus/dsa/devices/dsa0/wq0.1/mode
echo 10 > /sys/bus/dsa/devices/dsa0/wq0.1/priority
echo 16 > /sys/bus/dsa/devices/dsa0/wq0.1/size
echo 1 > /sys/bus/dsa/devices/dsa0/engine0.2/group_id
echo 1 > /sys/bus/dsa/devices/dsa0/engine0.3/group_id
echo "user" > /sys/bus/dsa/devices/dsa0/wq0.1/type
echo "user" > /sys/bus/dsa/devices/dsa0/wq0.1/driver_name
echo "app2" > /sys/bus/dsa/devices/dsa0/wq0.1/name

echo "Engines for group 1"
cat /sys/bus/dsa/devices/dsa0/group0.1/engines
echo "Work queues for group 1"
cat /sys/bus/dsa/devices/dsa0/group0.1/work_queues

