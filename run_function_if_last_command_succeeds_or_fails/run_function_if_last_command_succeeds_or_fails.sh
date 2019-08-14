#!/bin/bash

# Amos Deane - 2019
# v1 - May 23 2019
# v1.2 - Aug 14 2019 
# Fixed bug because of absence of: checkForLastCommandSuccess
####################################################################################
# NOTES
####################################################################################
# This function confirms if the previous command completed successfully
# If it succeeds additional commands or functions specified as arguments can be run
	

trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG

########################################################################################
# smallSeparationRule
########################################################################################

function smallSeparationRule {
echo "----------------------------------------------------------------------------------"
}

########################################################################################	
# runIfLastCommandSucceeded
########################################################################################

function runIfLastCommandSucceeded {	

	if [ $? != 0 ]; then
	# IF PREVIOUS COMMAND ERRORED THEN PRINT THIS MESSAGE
	smallSeparationRule	
	echo "*************** PREVIOUS COMMAND FAILED ******************:$previous_command"
	else
	# ELSE PRINT THIS MESSAGE AND RUN COMMANDS
	smallSeparationRule	
	echo "PREVIOUS COMMAND COMPLETED:$previous_command -  RUNNING Function:$1"


		if [ ! -z "$2" ]
		then
		smallSeparationRule
		echo "FUNCTION ARGUMENT (parameter 2) IS SET AS:$2"
			if [ ! -z "$4" ]
			then
			smallSeparationRule
			echo "FUNCTION ARGUMENT (parameter 3) IS SET AS:$3"
			"$1"
			"$2" 
			"$3" 
# 			"$4"
			else
# 			smallSeparationRule
			"$1" 
			"$2"
			fi
		
		else
		smallSeparationRule
		echo "NO ADDITIONAL ARGUMENTS SET - RUNNING $2 WITHOUT ARGUMENTS"
		"$1"
		fi		
	
	fi
	
	}
	
	
########################################################################################	
# checkForLastCommandSuccess ###########################################################
########################################################################################	

trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG

function checkForLastCommandSuccess {	
	if [ $? != 0 ]; then
	# IF PREVIOUS COMMAND ERRORED THEN PRINT THIS MESSAGE
	echo "--------------------------------------------------------------------------------"
	echo "PREVIOUS COMMAND:$previous_command FAILED ********************************************************"
	else
	# ELSE PRINT THIS MESSAGE
	echo "--------------------------------------------------------------------------------"
	echo "$previous_command COMMAND COMPLETED"
	fi
	}
	
	
	
	
########################################################################################	
# testFunction
########################################################################################

function testFunction {
smallSeparationRule
echo "TESTING FUNCTION"
}

########################################################################################	
# testFunction2
########################################################################################

function testFunction2 {
smallSeparationRule
echo "OTHER TESTING FUNCTION"
}

########################################################################################	
# runIfVariableIsNotBlank
########################################################################################

	function runIfVariableIsNotBlank () {
# run command if variable is not set/is blank
# Additional option to set an argument for the additional command (if required)
	if [ ! -z "$1" ]
	then
	# IF THE ASSIGNED ARGUMENT VARIABLE IS NOT BLANK PRINT THN DO COMMAND
	smallSeparationRule
	echo "VARIABLE:$1 IS NOT BLANK - RUNNING COMMAND"

		if [ ! -z "$2" ]
		then
		
			if [ ! -z "$3" ]
			then
			smallSeparationRule
			echo "COMMAND ARGUMENT (parameter 4) IS SET AS:$4"
			"$2" "$3" "$4"
			else
			smallSeparationRule
			echo "COMMAND ARGUMENT (parameter 3) IS SET AS:$3"
			"$2" "$3"
			fi
		
		else
		smallSeparationRule
		echo "NO ARGUMENTS SET - RUNNING COMMAND WITHOUT ARGUMENTS"
		"$2"
		fi
	
	else	

	smallSeparationRule
	echo "VARIABLE HAS NOT BEEN SET - IGNORING"
	fi
}

	
####################################################################################
# SCRIPT PROGRESS
####################################################################################

####################################################################################
# TESTING EXAMPLES
####################################################################################

echo "Hello there"
checkForLastCommandSuccess

####################################################################################
# Example comamnd - if this succeeds the functions specified as arguments will be called
touch ./testing.txt
runIfLastCommandSucceeded testFunction testFunction2

smallSeparationRule

####################################################################################
# DEBUG - open script location to view file output
# open ./