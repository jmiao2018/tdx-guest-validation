#!/bin/bash
#
#   Copyright (c) Intel, 2012
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU Lesser General Public
#   License as published by the Free Software Foundation; either
#   version 2.1 of the License, or (at your option) any later version.
#   
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   Lesser General Public License for more details.
#   
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
#
# File:         test_framework.sh
#
# Description:  This framework will execute the steps written in auto-generated
#               tests from TGen.
#
# Author(s):    Julian Dumez <julianx.dumez@intel.com>
#
# Date:         10/23/2012
# Version:      v1.0
#

#=============================================================================#
#		CONSTANTS															  #
#=============================================================================#

# Carriage return character to use in generated result reports
CR=`echo -e "\n\r"`

# Final code result of test
PASS=0
FAIL=1
BLOCK=2

# Code result for steps
SUCCESS=0
ERROR=1

# Codes of types of test
UNIT_TEST=1
BAT=2
FUNCTIONAL_POSITIVE=3
FUNCTIONAL_NEGATIVE=4
STRESS=5
PERFORMANCE=6

# Codes of operators
NONE=1
EQUAL=2
NOT_EQUAL=3
GREATER_THAN=4
LESSER_THAN=5
GREATER_EQUAL=6
LESSER_EQUAL=7
SUBSET_OF=8
NOT_SUBSET_OF=9

# Values for operations
TRUE=0
FALSE=1

# Boolean to display debug messages
DEBUG=1

# Kind of buffer for return values of functions
RETURN_VALUE=

#=============================================================================#
#		GLOBAL VARIABLES													  #
#=============================================================================#

# The final result of the test
test_result=
# The result of preconditions execution
preconditions_result=
# The result of steps execution
steps_result=
# The result of postconditions execution
postconditions_result=

# The number of the last executed precondition
last_precondition=
# The number of the last executed stress step
last_stress_step=

# Number of preconditions
preconditions_count=${#precondition_cmd[@]}
# Number of steps in the test
steps_count=${#step_cmd[@]}
# Number of postconditions
postconditions_count=${#postcondition_cmd[@]}

#=============================================================================#
#		MAIN																  #
#=============================================================================#

#
# This is the entry point of the program.
#
# @return The result of the test (PASS=0, FAIL=1, BLOCK=2).
#
function main()
{
	if [ "$TIMEOUT" != "" ]
	then
		# Transform timeout string into seconds
		delay=`timeToSeconds $TIMEOUT`

		if [ $delay -gt 0 ]
		then
			test_result=$FAIL
			(sleep $delay; debug "Test final result is $test_result"; write_result; kill 0) & exec_test
		else
			exec_test
		fi
	else
		exec_test
	fi

	debug "Test final result is $test_result"
	write_result

	return $test_result
}

#=============================================================================#
#		FUNCTIONS															  #
#=============================================================================#

function exec_test()
{
	# Execute preconditions
	if [ $preconditions_count -gt 0 ]
	then
		exec_preconditions
		preconditions_result=$?
	else
		preconditions_result=$SUCCESS
	fi

	# Execute steps if all preconditions are successful
	if [ $preconditions_result == $SUCCESS ]
	then
		exec_steps
		steps_result=$?
	else
		steps_result=$ERROR
	fi

	# Execute postconditions
	if [ $postconditions_count -gt 0 ]
	then
		exec_postconditions
		postconditions_result=$?
	else
		postconditions_result=$SUCCESS
	fi

	# Set the result of the test
	if [ $preconditions_result != $SUCCESS ]
	then
		test_result=$BLOCK
	elif [ $steps_result != $SUCCESS ]
	then
		test_result=$FAIL
	else
		test_result=$PASS
	fi
}

#
# Execute the preconditions of the test.
#
# @return SUCCESS if all preconditions has been executed without errors, ERROR otherwise.
#
function exec_preconditions()
{
	local ret=
	local i=

	# Execute all preconditions of the test
	for (( i=0; i<$preconditions_count; i++ ))
	do
		# Set number of last executed precondition for postconditions
		last_precondition=$i

		debug "> Executing precondition #$i"
		debug " -> cmd: ${precondition_cmd[$i]}"
		debug " -> operator: ${precondition_operator[$i]}"
		debug " -> result: ${precondition_expected_result[$i]}"
		debug " -> status: ${precondition_status[$i]}"

		# Execute precondition's command
		exec_precondition "${precondition_cmd[$i]}" ${precondition_operator[$i]} "${precondition_expected_result[$i]}" ${precondition_status[$i]}
		ret=$?

		debug " => $ret"

		if [ $ret == $ERROR ]
		then
			return $ERROR
		fi
	done

	return $SUCCESS
}

#
# Execute a precondition.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the precondition match expected result and/or expected status, ERROR otherwise.
#
function exec_precondition()
{
	local cmd=$1
	local operator=$2
	local expected_result=$3
	local expected_status=$4

	local ret_operation=
	local ret_status=
	local result=
	local status=

	# Execute command
	result=`eval "${cmd}"`
	# Get command's status
	status=$?

	# Compare command's result and expected result
	check_result "$result" "$expected_result" $operator
	ret_operation=$?

	# Compare command's status and expected status
	check_status $status $expected_status
	ret_status=$?

	if [ $ret_operation == $TRUE ] && [ $ret_status == $TRUE ]
	then
		return $SUCCESS
	else
		return $ERROR
	fi
}

#
# Execute the postconditions of the test.
#
# @return SUCCESS if all postconditions has been executed without errors, ERROR otherwise.
#
function exec_postconditions()
{
	local ret=
	local i=

	# Execute all postconditions of the test
	for (( i=0; i<$postconditions_count; i++ ))
	do
		debug "> Executing postcondition #$i"
		debug " -> cmd: ${postcondition_cmd[$i]}"
		debug " -> operator: ${postcondition_operator[$i]}"
		debug " -> result: ${postcondition_expected_result[$i]}"
		debug " -> status: ${postcondition_status[$i]}"

		# Execute postcondition's command
		exec_postcondition "${postcondition_cmd[$i]}" ${postcondition_operator[$i]} "${postcondition_expected_result[$i]}" ${postcondition_status[$i]}
		ret=$?

		debug " => $ret"

		if [ $ret == $ERROR ]
		then
			return $ERROR
		fi
	done

	return $SUCCESS
}

#
# Execute a postcondition.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the postcondition match expected result and/or expected status, ERROR otherwise.
#
function exec_postcondition()
{
	local cmd=$1
	local operator=$2
	local expected_result=$3
	local expected_status=$4

	local ret_operation=
	local ret_status=
	local result=
	local status=

	# Execute command
	result=`eval "${cmd}"`
	# Get command's status
	status=$?

	# Compare command's result and expected result
	check_result "$result" "$expected_result" $operator
	ret_operation=$?

	# Compare command's status and expected status
	check_status $status $expected_status
	ret_status=$?

	if [ $ret_operation == $TRUE ] && [ $ret_status == $TRUE ]
	then
		return $SUCCESS
	else
		return $ERROR
	fi
}

#
# Execute the steps of the test switch its type (functional positive, stress, performance, BAT, ...).
#
# @return SUCCESS if all steps has been executed without errors, ERROR otherwise.
#
function exec_steps()
{
	local ret=
	local i=

	# Execute all steps of the test
	for (( i=0; i<$steps_count; i++ ))
	do
		debug "> Executing step #$i"

		case ${test_type[$i]} in
			$UNIT_TEST)
				debug " -> type: UNIT_TEST"
				debug " -> cmd: ${step_cmd[$i]}"
				debug " -> operator: ${step_operator1[$i]}"
				debug " -> result: ${step_expected_result1[$i]}"
				debug " -> status: ${step_status[$i]}"

				exec_unit_test "${step_cmd[$i]}" ${step_operator1[$i]} "${step_expected_result1[$i]}" ${step_status[$i]}
				ret=$?

				debug " => $ret"
				;;

			$BAT)
				debug " -> type: BAT"
				debug " -> cmd: ${step_cmd[$i]}"
				debug " -> operator: ${step_operator1[$i]}"
				debug " -> result: ${step_expected_result1[$i]}"
				debug " -> status: ${step_status[$i]}"

				exec_bat "${step_cmd[$i]}" ${step_operator1[$i]} "${step_expected_result1[$i]}" ${step_status[$i]}
				ret=$?

				debug " => $ret"
				;;

			$FUNCTIONAL_POSITIVE)
				debug " -> type: FUNCTIONAL_POSITIVE"
				debug " -> cmd: ${step_cmd[$i]}"
				debug " -> operator: ${step_operator1[$i]}"
				debug " -> result: ${step_expected_result1[$i]}"
				debug " -> status: ${step_status[$i]}"

				exec_functional_positive "${step_cmd[$i]}" ${step_operator1[$i]} "${step_expected_result1[$i]}" ${step_status[$i]}
				ret=$?

				debug " => $ret"
				;;

			$FUNCTIONAL_NEGATIVE)
				debug " -> type: FUNCTIONAL_NEGATIVE"
				debug " -> cmd: ${step_cmd[$i]}"
				debug " -> operator: ${step_operator1[$i]}"
				debug " -> result: ${step_expected_result1[$i]}"
				debug " -> status: ${step_status[$i]}"

				exec_functional_negative "${step_cmd[$i]}" ${step_operator1[$i]} "${step_expected_result1[$i]}" ${step_status[$i]}
				ret=$?

				debug " => $ret"
				;;

			$STRESS)
				debug " -> type: STRESS"
				debug " -> cmd: ${step_cmd[$i]}"
				debug " -> operator: ${step_operator1[$i]}"
				debug " -> result: ${step_expected_result1[$i]}"
				debug " -> status: ${step_status[$i]}"
				debug " -> iteration: ${step_iteration[$i]}"

				exec_stress "${step_cmd[$i]}" ${step_operator1[$i]} "${step_expected_result1[$i]}" ${step_status[$i]} ${step_iteration[$i]}
				ret=$?

				debug " => $ret"
				;;

			$PERFORMANCE)
				debug " -> type: PERFORMANCE"
				debug " -> cmd: ${step_cmd[$i]}"
				debug " -> operator1: ${step_operator1[$i]}"
				debug " -> operator2: ${step_operator2[$i]}"
				debug " -> result1: ${step_expected_result1[$i]}"
				debug " -> result2: ${step_expected_result2[$i]}"
				debug " -> status: ${step_status[$i]}"

				exec_performance "${step_cmd[$i]}" ${step_operator1[$i]} ${step_operator2[$i]} "${step_expected_result1[$i]}" "${step_expected_result2[$i]}" ${step_status[$i]} 
				ret=$?

				debug " => $ret"
				;;
		esac

		if [ $ret == $ERROR ] || [ ! $ret ]
		then
			return $ERROR
		fi
	done

	return $SUCCESS
}

#
# Execute the step of a unit test.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the step match expected result and/or expected status, ERROR otherwise.
#
function exec_unit_test()
{
	# TODO
	echo
}

#
# Execute the step of a BAT.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the step match expected result and/or expected status, ERROR otherwise.
#
function exec_bat()
{
	exec_functional "$1" $2 "$3" $4
}

#
# Execute the step of a functional positive.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the step match expected result and/or expected status, ERROR otherwise.
#
function exec_functional_positive()
{
	exec_functional "$1" $2 "$3" $4
}

#
# Execute the step of a functional negative.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the step match expected result and/or expected status, ERROR otherwise.
#
function exec_functional_negative()
{
	exec_functional "$1" $2 "$3" $4
}

#
# Execute the step of a function (same thing for positive and negative).
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the step match expected result and/or expected status, ERROR otherwise.
#
function exec_functional()
{
	local cmd=$1
	local operator=$2
	local expected_result=$3
	local expected_status=$4

	local ret_operation=
	local ret_status=
	local result=
	local status=

	# Execute command
	result=`eval "${cmd}"`
	# Get command's status
	status=$?

	# Compare command's result and expected result
	check_result "$result" "$expected_result" $operator
	ret_operation=$?

	# Compare command's status and expected status
	check_status $status $expected_status
	ret_status=$?

	if [ $ret_operation == $TRUE ] && [ $ret_status == $TRUE ]
	then
		return $SUCCESS
	else
		return $ERROR
	fi
}

#
# Execute the step of a stress.
#
# @param cmd The command to execute.
# @param operator The operator of the operation between command and expected result.
# @param expected_result The expected result of the command.
# @param expected_status The expected status code of the command.
# @param iteration The number of iteration of the step.
#
# @return SUCCESS if the step went fine and match expected result and/or expected status, ERROR otherwise.
#
function exec_stress()
{
	local cmd=$1
	local operator=$2
	local expected_result=$3
	local expected_status=$4
	local iteration=$5

	local ret_operation=
	local ret_status=
	local result=
	local status=
	local i=

	# Execute step the given number of iterations
	for (( i=0; i<$iteration; i++ ))
	do
		# Set number of last executed step
		last_stress_step=$i

		# Execute command
		result=`eval "${cmd}"`
		# Get command's status
		status=$?

		# Compare command's result and expected result
		check_result "$result" "$expected_result" $operator
		ret_operation=$?

		# Compare command's status and expected status
		check_status $status $expected_status
		ret_status=$?

		if [ $ret_operation == $FALSE ] || [ $ret_status == $FALSE ]
		then
			return $ERROR
		fi
	done

	return $SUCCESS
}

#
# Execute the step of a performance.
#
# @param cmd The command to execute.
# @param operator1 The operator of the operation between command and expected result1.
# @param operator2 The operator of the operation between command and expected result2.
# @param expected_result1 The minimum expected result of the command.
# @param expected_result2 The maximum expected result of the command.
# @param expected_status The expected status code of the command.
#
# @return SUCCESS if the step's result is included between first and second expected result and/or match expected_status, ERROR otherwise.
#
function exec_performance()
{
	local cmd=$1
	local operator1=$2
	local operator2=$3
	local expected_result1=$4
	local expected_result2=$5
	local expected_status=$6

	local ret_operation1=
	local ret_operation2=
	local ret_status=
	local result=
	local status=

	# Execute command
	result=`eval "${cmd}"`
	# Get command's status
	status=$?

	# Compare command's result and expected result 1
	check_result "$result" "$expected_result1" $operator1
	ret_operation1=$?
	# Compare command's result and expected result 2
	check_result "$result" "$expected_result2" $operator2
	ret_operation2=$?

	# Compare command's status and expected status
	check_status $status $expected_status
	ret_status=$?

	if [ $ret_operation1 == $TRUE ] && [ $ret_operation2 == $TRUE ] && [ $ret_status == $TRUE ]
	then
		return $SUCCESS
	else
		return $ERROR
	fi
}

#
# Compare a command's result and a given expected result.
#
# @param operand1 The left operand of the comparison operation (i.e. the command's result).
# @param operand2 The right operand of the comparison operation (i.e. the expected result).
# @param operator The operator of the comparison operation.
#
# @return TRUE if the comparison is correct, FALSE otherwise.
#
function check_result()
{
	# Remove ^M characters from operands
	operand1=`echo "$1" | tr -d "\015"`
	operand2=`echo "$2" | tr -d "\015"`
	operator=$3

	case $operator in
		$NONE)
			return $TRUE
			;;

		$EQUAL)
			if [ "$operand1" == "$operand2" ]
			then
				return $TRUE
			else
				return $FALSE
			fi
			;;

		$NOT_EQUAL)
			if [ "$operand1" != "$operand2" ]
			then
				return $TRUE
			else
				return $FALSE
			fi
			;;

		$GREATER_THAN)
			if [ "$operand1" -gt "$operand2" ]
			then
				return $TRUE
			else
				return $FALSE
			fi
			;;

		$LESSER_THAN)
			if [ "$operand1" -lt "$operand2" ]
			then
				return $TRUE
			else
				return $FALSE
			fi
			;;

		$GREATER_EQUAL)
			if [ "$operand1" -ge "$operand2" ]
			then
				return $TRUE
			else
				return $FALSE
			fi
			;;

		$LESSER_EQUAL)
			if [ "$operand1" -le "$operand2" ]
			then
				return $TRUE
			else
				return $FALSE
			fi
			;;

		$SUBSET_OF)
			# Transform expected result into array
			array=`echo "$operand2" | tr ',' '\n'`

			for subset in $array
			do
				subset=`echo $subset | sed 's/^"//' | sed 's/"$//'`

				check_result "$operand1" "$subset" $EQUAL
				ret_operation=$?

				if [ $ret_operation == $TRUE ]; then
					return $TRUE
					break
				fi
			done

			return $FALSE
			;;

		$NOT_SUBSET_OF)
			# Transform expected result into array
			array=`echo "$operand2" | tr ',' '\n'`

			for subset in $array
			do
				subset=`echo $subset | sed 's/^"//' | sed 's/"$//'`

				check_result "$operand1" "$subset" $EQUAL
				ret_operation=$?

				if [ $ret_operation == $TRUE ]; then
					return $FALSE
					break
				fi
			done

			return $TRUE
			;;

		*)
			return $FALSE
			;;
	esac
}

#
# Compare a command's status and a given expected status.
#
# @param status The command's status.
# @param expected_status The expected status.
#
# @return TRUE if status match expected status, FALSE otherwise.
#
function check_status()
{
	# Check if expected status is set and not null
	if [ $expected_status ]
	then
		if [ $status == $expected_status ]
		then
			return $TRUE
		else
			return $FALSE
		fi
	fi

	return $TRUE
}

#
# Set the keyword corresponding to the backuped numeric result.
#
# @return The result's keyword (0=PASS, 1=FAIL, 2=BLOCK).
#
function getTestResult()
{
	case $test_result in
		0)	RETURN_VALUE="PASS"
			;;
		1)	RETURN_VALUE="FAIL"
			;;
		2)	RETURN_VALUE="BLOCK"
			;;
	esac
}

#
# Write the result line of a test into the log file.
#
function write_result()
{
	getTestResult

	local result="$RETURN_VALUE"

	echo "\"$COMPONENT\",\"$NAME\",\"$result\",,\"$TYPE\",\"$cr\",,,,,," >> "$FILE_RESULT"
}

#
# Display a debug message.
#
# @param message The debug message to display.
#
function debug()
{
	if [ $DEBUG == 1 ]
	then
		echo "$1"
	fi
}

#=============================================================================#
#		MISC																  #
#=============================================================================#

#
# Convert a string in H:i:s format into a number of seconds.
#
# @param time The time in H:i:s format to convert.
#
# @return The total number of seconds.
#
function timeToSeconds()
{
	time=$1

	hours=`echo $time | awk -F ':' '{print $1}'`
	minutes=`echo $time | awk -F ':' '{print $2}'`
	seconds=`echo $time | awk -F ':' '{print $3}'`

	totalSeconds=$(($hours * 3600 + $minutes * 60 + $seconds))

	echo $totalSeconds
}

#=============================================================================#
#		ENTRY POINT															  #
#=============================================================================#

main "$@"
