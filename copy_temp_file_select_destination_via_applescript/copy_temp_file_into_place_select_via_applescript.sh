#!/bin/bash

# Amos Deane 20 May 2019
# v1.1 
# v1.2 - fixed bug
# v1.3 - added extra options
########################################################################################
# NOTES:
########################################################################################
# This script is to copy a file or folder from one location to another. If the copy 
# completes successfully the script provides options for running additional tasks - for 
# example listing contents or removing the original files being copied

# For Use in Jamf Pro
sourceFile="$4"
filePathStart="$5"
filePathEnd="$6"
chooseDestinationOfFiles1="$6"	
chooseDestinationOfFiles2="$7"	
chooseDestinationOfFiles3="$8"	
chooseDestinationOfFiles4="$9"	


# For local testing
# sourceFile="./A/toad.txt"
# destinationOfFiles="./B/"
# 

# destinationOfFiles="/Applications/Adobe InDesign CC 2017/Plug-Ins/" 

sourceFile="/tmp/Blurb Book Creator" 
filePathStart=/Applications/
filePathEnd=/Plug-Ins/
chooseDestinationOfFiles1="Adobe InDesign CC 2017"
chooseDestinationOfFiles2="Adobe InDesign CC 2018"
chooseDestinationOfFiles3="Adobe InDesign CC 2019"
chooseDestinationOfFiles4="Adobe InDesign CC 2020"



##########################################################################################
# setVariableFromApplescriptList
##########################################################################################

function setVariableFromApplescriptList () {
myApplescriptSelection=$(/usr/bin/osascript << EOT
set variable_name to {"$1", "$2", "$3", "$4"}

choose from list variable_name --
EOT)
}

 
##########################################################################################




########################################################################################
# separationRule
########################################################################################

separationRule () {
# Line separator - print a horizontal separation rule 
	printf -v string_int_var "%*s" $(tput cols) && echo ${string_int_var// /${1--}}
}

########################################################################################
# smallSeparationRule
########################################################################################

function smallSeparationRule {
echo "----------------------------------------------------------------------------------"
}

########################################################################################
# checkForSuccess
########################################################################################
	

function checkForSuccess {
# This function confirms if the previous command completed successfully - INVERTED
# HIGHLIGHTS IF COMMAND SUCCEEDED

	if [ $? == 0 ]; then
	smallSeparationRule
	echo "Last command succeeded" 
	lastCommandSuccessful=yes
	else
	smallSeparationRule
	echo "LAST COMMAND PRODUCED AN ERROR *****************************************************" 
	fi
	}	

########################################################################################
# removeFileIfExists
########################################################################################

function removeFileIfExists () {
# Delete file if it found
# this function will only run if the requested file is found
# it has the verbose mode enabled but this may need to be disabled if it produces too much output
if [ -d "$1" ] || [ -e "$1" ]
then
smallSeparationRule
echo "FILE:$1 EXISTS - REMOVING"
# sudo rm -Rfv "$1" 
else
smallSeparationRule
echo "FILE:$1 - NOT FOUND - IGNORING"
fi
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

		if [ ! -z "$3" ]
		then
		
			if [ ! -z "$4" ]
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
	
########################################################################################
# listLocation
########################################################################################


function listLocation () {
# Simple function to list a specified location

smallSeparationRule
echo "LISTING LOCATION:$1"
smallSeparationRule
ls -la "$1"
}
	
########################################################################################
# shasumChecksumCompare2Files
########################################################################################


function shasumChecksumCompare2Files () {
# shasum -a ” followed by either 1 or 256,
checksum1=$(shasum -a 256 "$1" | awk '{print $1}' )
checksum2=$(shasum -a 256 "$2" | awk '{print $1}')

smallSeparationRule
echo "CHECKING shasum CHECKSUM ON 2 FILES"
smallSeparationRule
echo "FILE ONE:$checksum1"
smallSeparationRule
echo "FILE TWO:$checksum2"
smallSeparationRule
echo "COMPARING THE TWO FILES"


		if [ $checksum1 == $checksum2 ]
		then
		smallSeparationRule
		echo "THE TWO FILES MATCH **************************************************************"
		else
		smallSeparationRule
		echo "THE TWO FILES DO NOT MATCH @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
		fi


smallSeparationRule
echo "DEBUG - CHECK THE TWO FILES"
smallSeparationRule
echo "CHECKSUM 1 IS:$checksum1"
echo "CHECKSUM 2 IS:$checksum2"
smallSeparationRule
}	
		
########################################################################################
# copyFilesAdvanced
########################################################################################

function copyFilesAdvanced () {
smallSeparationRule
echo "COPYING FILES FROM:$1 *** TO:$2"

copyFileTrimmed=$(basename "$1")
sudo cp -Rfv "$1" "$2"
checkForSuccess
########################################################################################
# OPTIONS FOR IF THE COMMAND HAS SUCCEEDED
########################################################################################
# If the copy command has succeeded run a command to list the destination to view the files
runIfVariableIsNotBlank $lastCommandSuccessful "listLocation" "$2"
# If the copy command has succeeded run a command to delete the original files
runIfVariableIsNotBlank $lastCommandSuccessful "shasumChecksumCompare2Files" "$1" "${2}${copyFileTrimmed}"
# If the copy command has succeeded run a command to delete the original files
runIfVariableIsNotBlank $lastCommandSuccessful "removeFileIfExists" "$1"


}
	
	
########################################################################################
# SCRIPT PROGRESS
########################################################################################


##########################################################################################

setVariableFromApplescriptList "$chooseDestinationOfFiles1" "$chooseDestinationOfFiles2" "$chooseDestinationOfFiles3" "$chooseDestinationOfFiles4" 



separationLine
echo "My choice is set as:${FilePath}${myVariable}"
separationLine





echo "My choice is set as:${FilePath}${myVariable}"

copyFilesAdvanced "$sourceFile" "${filePathStart}$myApplescriptSelection${filePathEnd}"


# copyFilesAdvanced "/tmp/Blurb Book Creator" "/Applications/Adobe InDesign CC 2017/Plug-Ins/" 

# separationRule
########################################################################################
# open "/Applications/Adobe InDesign CC 2017/Plug-Ins/"
########################################################################################
open "${filePathStart}$myApplescriptSelection${filePathEnd}"