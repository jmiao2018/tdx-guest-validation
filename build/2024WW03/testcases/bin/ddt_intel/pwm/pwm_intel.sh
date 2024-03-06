#!/bin/bash

# please install LTP-DDT first
# modify default path

#device= /sys/class/pwm/pwmchip0

Set_up ()
{
  rmmod pwm-lpss
  modprobe pwm-lpss
  return $?
}

Verify_Driver()
{
	DRIVERS="$(ls /sys/class/pwm | grep pwm 2> /dev/null)"
	echo "$DRIVERS"
	if [[ -z "$DRIVERS" ]]; then
	  echo "Check PWM controllers are detected: FAILED"
          return 1
          else echo "Check PWM controllers are detected: PASSED"
          echo 0 > /sys/class/pwm/pwmchip0/export
	  return $?
	fi

}

Verify_Device()
{

	echo 0 > "$device/export"
	if [ $? -ne 0 ]; then
	  return $?
	fi
	list=$(find /sys/devices -name "pwm")
	echo "$list"

	if [[ -n "$list" ]]; then
	  echo "Check PWM controller in /sys/devices/XXX/pwm/pwmchipX/pwmX: PASSED"
 	  return 1
	  else echo "Check PWM controller in /sys/devices/XXX/pwm/pwmchipX/pwmX: FAILED"
	   return $?
	fi

}

Positive_polarity ()
{
        cd /sys/class/pwm/pwmchip0/pwm0
	if [ $? -ne 0 ]; then
	  return $?
	fi
        echo 0 > enable
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
        echo normal > polarity
        return $?
}

Negative_polarity ()
{
	cd /sys/class/pwm/pwmchip0/pwm0
	if [ $? -ne 0 ]; then
	  return $?
	fi
	echo 0 > enable
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
	echo inversed > polarity
	return $?
}

Duty_Cycle ()
{
        cd /sys/class/pwm/pwmchip0/pwm0
	if [ $? -ne 0 ]; then
	  return $?
	fi
        echo 0 > duty_cycle
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
        echo 1 > duty_cycle
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
        echo 5 > duty_cycle
        return $?
}

Set_period()
{
	cd /sys/class/pwm/pwmchip0/pwm0
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
	echo 10000 > period
	return $?
}

Stress_period_duty ()
{
        cd /sys/class/pwm/pwmchip0/pwm0
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
        for i in {10000 20000 30000 40000 50000 60000 70000 80000 90000 100000}; do
        echo $i > period
                for j in {0..5}; do
                 echo $j > duty_cycle
		 if [ $? -ne 0 ]; then
	           return $?
		 fi
                done
        done
        return $?
}

Suspend_to_ram()
{
	echo -n mem > /sys/power/state
	return $?
}

Suspend_to_ram_stress()
{
	for i in {1..10}; do rtcwake -m mem -s 3; sleep 2; done
	DRIVERS="$(lsmod | grep pwm 2> /dev/null)"
	echo "$DRIVERS"
	if [[ -n "$DRIVERS" ]]; then
	list=$(find /sys/devices -name "pwm")
	echo "$list"
	  if [[ -n "$list" ]]; then
 	    echo "TEST6:Check PWM driver is detected after suspend/resume: PASSED"
  	    else   echo "TEST6:Check PWM driver is detected after suspend/resume: FAILED (controller down)"
	    return 1
	  fi
  	else echo "TEST6:Check PWM driver is detected after suspend/resume: FAILED (driver not found)"
	return 1
	fi
	return $?
}

Clean_up ()
{
        cd /sys/class/pwm/pwmchip0
	if [[ $? -ne 0 ]]; then
	  return $?
	fi
        echo 0 > unexport
	if [[ $? -ne 0 ]]; then
	    return $?
	fi
        rmmod pwm-lpss
        return $?
}
