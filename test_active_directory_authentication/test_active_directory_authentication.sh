#!/bin/bash
# tags:read, ldapsearch
#
# Amos Deane 2017

##########################################################################################
#
# This script runs a standard test to test authentication to a specified number of domain controllers
#
# This script is designed to by run within the management system Jamf Pro - but It can be
# run manually by dropping it on an open terminal window on a machine with the jamf binary
# installed and then press enter You will be prompted to provide your user information,
# which will be used to run the test
##########################################################################################
# SCRIPT LIMITATIONS
##########################################################################################


##########################################################################################
# HISTORY
##########################################################################################
# v1.2 - improved text output
# v1.3 - added extra options
# v1.4 - added timestamp
# v1.5 - minor formatting changes - Dec 1 2017
# v1.6 - added applescript dialog boxes and jamf notifications - Dec 1 2017
# v1.6.1 - adjusted text formating for warning message - Jan 16 2018
# v1.7 - bugs fixes - date and remove text from log not relevant - Jan 19 2017
# v1.8 - updated let counter=0 and completed cycles
# v1.9 - updated for alternative DCs - june 26 2018
# v1.10 - updated to make universal for all systems


##########################################################################################
# VARIABLES ##############################################################################
##########################################################################################

dateTime=$(date "+%d-%m-%Y_%H_%M")
currentTime=$(date "+%H:%M")
logFile=/Users/$USER/Desktop/Active_Directory_Authentication_Test_${dateTime}.txt
jamfMessage="/Library/Application Support/JAMF/bin/Management Action.app/Contents/MacOS/Management Action"
currentUser=$USER

##########################################################################################
# CUSTOM SETTINGS ########################################################################
##########################################################################################
# THESE SETTINGS NEED TO BE CONFIGURED - EXAMPLE SETTINGS ARE GIVEN BELOW - SEE DESCRIPTION
##########################################################################################

##########################################################################################
# PATH TO USER - this is the OU path to the currently logged in user
##########################################################################################
# this assumes this OU structure but can be adjusted to your own environment
##########################################################################################
# SERVER LIST - this is the list of domain controlers to test
##########################################################################################

pathToOU="CN=$currentUser,OU=USERS,OU=MyOU,OU=MyOtherOU,DC=myDomain,DC=com"

		serverlist=(
			'myDomainController_01.myDomain.com'
			'myDomainController_02.myDomain.com'
			'myDomainController_03.myDomain.com'
			'myDomainController_04.myDomain.com'
		   )

##########################################################################################
## END OF CONFIGURED SETTINGS ############################################################
##########################################################################################



##########################################################################################
# FUNCTIONS ##############################################################################
##########################################################################################

##########################################################################################
# jamfNotification
##########################################################################################

# This produces the jamf notifications messages
function jamfNotification () {
/Library/Application\ Support/JAMF/bin/Management\ Action.app/Contents/MacOS/Management\ Action -title "$1" -subtitle "$2" -message "$3"
}


##########################################################################################
# CHECK FOR SUCCESS
##########################################################################################
# This function confirms if the previous command completed successfully

function checkForSuccess {
	if [ $? != 0 ]; then
	#IF PREVIOUS COMMAND ERRORED THEN PRINT THIS MESSAGE
	echo "AUTHENTICATION FAILED @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@" | tee -a $logFile
	jamfNotification "AUTHENTICATION FAILED @@@@@@@@@@@@@@@@@@@@@@@@" "Authentication Test:" "Running - count cycle is:$counter"
	sleep 2
	else
	#ELSE PRINT THIS MESSAGE
	echo "AUTHENTICATION COMPLETED SUCCESSFULLY" | tee -a $logFile
	jamfNotification "AUTHENTICATION COMPLETED SUCCESSFULLY" "Authentication Test:" "Running - Completed cycles:$counter"
	sleep 2
	fi
	}



##########################################################################################
# CUSTOM USER - FOR TESTING PURPTOSES
##########################################################################################
# THIS LETS YOU HARDCODE THE USER DETAILS YOU WISH TO USE
##########################################################################################
# TO ENABLE CUSTOM USER OPTION COMMENT OUT THE INTERACTIVE MODE SECTION AND UNCOMMENT
# THE CUSTOM USER MODE SECTION BELOW

##########################################################################################
# CUSTOM USER MODE (DO NOT UNCOMMENT THIS LINE!)
##########################################################################################

# CurrentUser=myUser
# Password=""
# NUMBER OF TIMES TO RUN
# totalCount=5
# pause between each test
# sleepValue=2


##########################################################################################
# SCRIPT PROGRESS
##########################################################################################



echo "************************************************************************************" > $logFile
echo "RUNNING TEST ON: $dateTime"  > $logFile
# CUSTOM USER MODE SECTION ENDS (DO NOT UNCOMMENT THIS LINE!)

##########################################################################################
# INTERACTIVE MODE STARTS HERE ###########################################################
##########################################################################################

echo "************************************************************************************"  | tee -a $logFile
echo "PLEASE ENTER YOUR USERNAME" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile
# read CurrentUser
CurrentUser="$(/usr/bin/osascript -e 'Tell application "System Events" to display dialog "Enter Username" default answer "" with title "Username" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"
echo "USERNAME IS:$CurrentUser" | tee -a $logFile

echo "************************************************************************************" | tee -a $logFile
echo "PLEASE ENTER YOUR PASSWORD" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile

# Prompt the user for their details and read them in
# read -s Password
Password="$(/usr/bin/osascript -e 'Tell application "System Events" to display dialog "Enter Password" default answer "" with title "Password" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"
echo "PASSWORD IS: *************" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile
echo "PLEASE ENTER HOW MANY TIMES YOU WANT THE TEST TO RUN - DEFAULT IS 4 TIMES" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile
# read totalCount
totalCount="$(/usr/bin/osascript -e 'Tell application "System Events" to display dialog "How many times should the test run? (default is 5 times)" default answer "5" with title "How many times" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"
echo "TEST WILL RUN $totalCount TIMES" | tee -a $logFile
# SET DEFAULT VALUE IF NO VALUE ENTERED
totalCount=${totalCount:-"4"}
echo "************************************************************************************" | tee -a $logFile
echo "PLEASE ENTER HOW LONG YOU WANT BETWEEN TESTS - DEFAULT IS 2 SECONDS" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile
# read sleepValue - the delay between tests
sleepValue="$(/usr/bin/osascript -e 'Tell application "System Events" to display dialog "How much delay between tests? (default is 2 seconds)" default answer "5" with title "Set Delay" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"

# SET DEFAULT VALUE IF NO VALUE ENTERED
sleepValue=${sleepValue:-"2"}
clear

##########################################################################################
# INTERACTIVE MODE SECTION ENDS HERE #####################################################
##########################################################################################

echo "************************************************************************************" | tee -a $logFile
echo "TESTING ACTIVE DIRECTORY AUTHENTICATION FOR USER:$CurrentUser" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile
# echo "------------------------------------------------------------------------------------"
jamfNotification "TESTING ACTIVE DIRECTORY AUTHENTICATION" "FOR USER:$CurrentUser"
sleep 2

let counter=0
		while [ $counter -lt $totalCount ]
		do
		echo "Counter Value IS:$counter"
		# echo "------------------------------------------------------------------------------------"
		echo "************************************************************************************" | tee -a $logFile
		echo "Test Will Run:$totalCount Times" | tee -a $logFile
		echo "************************************************************************************" | tee -a $logFile
		echo "Sleep Value IS:$sleepValue Seconds" | tee -a $logFile
		echo "************************************************************************************" | tee -a $logFile


		# echo "------------------------------------------------------------------------------------"
		echo "TESTING AUTHENTICATION - RUNNING - TIME IS:$currentTime" | tee -a $logFile
# 		echo "------------------------------------------------------------------------------------" | tee -a $logFile

				for currentServer in ${serverlist[@]}
				do
				echo "------------------------------------------------------------------------------------" | tee -a $logFile
				echo "TESTING AUTHENTICATION $currentServer - TIME IS:$currentTime" | tee -a $logFile
				echo "------------------------------------------------------------------------------------" | tee -a $logFile
				echo "SERVER IS:$currentServer"
				echo "------------------------------------------------------------------------------------" | tee -a $logFile
				ldapsearch -h "$currentServer" -p 389 -x -D "$pathToOU" -w "$Password" -b "$pathToOU" "distinguishedName" &> /dev/null
				checkForSuccess
				jamfNotification "TESTING FOR SERVER:$currentServer:" "TIME IS:$currentTime"
				sleep $sleepValue
				done


		echo "************************************************************************************" | tee -a $logFile
		echo "COMPLETED CYCLE $counter *****************************************************************" | tee -a $logFile

		jamfNotification "COMPLETED TEST CYCLE: $counter" "Authentication Test:" "Running"

		echo "************************************************************************************" | tee -a $logFile

		let counter=$counter+1
		sleep 1

		done

echo "SCRIPT COMPLETED" | tee -a $logFile
echo "************************************************************************************" | tee -a $logFile

echo "************************************************************************************"
/usr/bin/osascript -e 'Tell application "System Events" to display dialog "A test report file is now on your desktop"'

echo "************************************************************************************"

exit 0
