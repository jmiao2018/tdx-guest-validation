
#!/bin/bash
echo "Starting dsa0"
echo dsa0 > /sys/bus/dsa/drivers/idxd/bind
echo "Start wq0.0"
echo wq0.0 > /sys/bus/dsa/drivers/user/bind
echo "Start wq0.1"
echo wq0.1 > /sys/bus/dsa/drivers/user/bind
