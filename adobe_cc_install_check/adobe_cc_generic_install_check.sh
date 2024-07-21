#!/bin/bash
# 
# tags: Adobe
# 
# 2018 Amos Deane
# 
# NOTES:
# 
# This is a script to make sure that all the components of Adobe CC have installed correctly.
#  
# This will do the following:
# 
# Checks components: (e.g. that files are physically there?
# Checks size of the overall install - if it finds applications missing it will trigger a re-install via jamf pro
# Checks for crash logs, to ascertain if they are crashing on launch -  if so, triggers a re-install for that module.
# (Note: this needs to be configured and individual install policies need to be present in Jamf) 
# The script works via the presence of flags, so it can be configured to keep trying at a 
# set interval until it detects all components from Adobe CC present on the device, at which 
# point the flag will be removed and the script will cease to trigger.
#
#########################################################################################
# Current method of usage via Jamf Pro
#########################################################################################
# 
# 1 Install Adobe CC - at the end of the install deposit a flag to indicate that Adobe CC (version) has been installed
# 2 Create extension attribute in jamf pro to check for presence of flag
# 3 Create a smart group based on the EA for machines that have the flag present
# 4 Create policy to run the install checker - this should be scoped to the smart group
# This can be run more or less regularly as required - an example is doing a check every day or every week
#
# If the script runs correctly the flag will be removed
# The policy should then update inventory so that any changes are recorded in jamf pro
# The machine will drop out of the smart group and the script will no longer run
#
#########################################################################################
# Known issues:
#########################################################################################
# 
# The calculation of the size of the fully installed suite is fairly basic and limited in 
# the scope of what is checked. In practise, I have found that it works reasonably well as 
# if an install fails it usually ommits most of the install files, so there is an obvious size difference. However it could potentially be unreliable and I am looking at creating a function/some functions to do more accurate install checks.
# 
# v1.1 - Feb 8 2018
# v1.2 - Feb 26 2018
# v1.3 - correct line 105
# v1.4 - Apr 25 2018
# v1.5 - May 2 2018 - corrected error if no log found and clarified progress of script
# v1.6 - May 9 2018 - corrected bug with install flag
# v1.7 - "" corrected formatting
# v1.8 - "" added additional comments
# v1.9 - added more history etc
# v1.10 - updated for CC 2020
# v1.10.2 - 23 Jul 2020
# v1.11 - beta
# v1.12 - added check for login 
# v1.13 - made generic
# v1.14 - tidied up
# v1.15 - 8 Apr 2021 - re-organised so all configuration is in obvious areas
# v1.16 - 8 Apr 2021 - added jamf parameters
# v1.17 - 20 Aug 2021 - added toggle option for check for login 
# V1.18 - 24 Aug 2021 - added kill option 
# V1.19 - minor tweak
# v1.20 - 2 Sep 2021 - added line to fix receipts issue
# v1.21 - 16 Feb 2022 - updated to fix logging
# v1.22 - 1 Sep 2022
# v1.23 - 7 Sep 2022 - fixed issue with Substance Painter
#########################################################################################

version=v1.23

dateTime=$(date "+%d-%m-%Y_%H-%M")

#########################################################################################
# Editable parameters
#########################################################################################
# Comfigure via Jamf
#########################################################################################

adbeVersion="$4"
localLog="$5"
estimatedSize="$6"
runIfLoggedIn="$7"

#########################################################################################
# Comfigure locally
#########################################################################################

# adbeVersion=2021
# localLog=/usr/local/scripts/Adobe/CC_${adbeVersion}_INSTALL_CHECK_LOG.txt
# estimatedSize=73000000
# runIfLoggedIn="No"

#########################################################################################
# Note: THIS IS AN APPROXIMATE FIGURE FOR THE TOTAL SIZE OF THE ADOBE INSTALL - Adjust as prefered
#########################################################################################



#########################################################################################
### FUNCTIONS ###########################################################################
#########################################################################################

#########################################################################################
# checkForLogin
#########################################################################################

# This is an option to ensure that an install check doesn't take place whilst a user is logged in
# DISABLE THIS FUNCTION IF TESTING WHILST LOGGED IN

function checkForLogin {
if [ ! -z $runIfLoggedIn ]; then
echo "checkForLogin is enabled"
currentUser=$(ls -l /dev/console | awk '{print $3}')
		if [ $currentUser == root ]; then
		echo "NOONE IS LOGGED IN"
		else
		echo "A USER IS LOGGED IN - ABORTING"
		exit 1
		fi
else
echo "checkForLogin is not enabled"

fi		
		}
		
#########################################################################################
# adbeApplicationCheck
#########################################################################################

# The function will check for the existence of the specified app. If it is not found it will 
# trigger a jamf policy. The app and the policy event can be specified as arguments.

function adbeApplicationCheck {

# multiplejamf
		if [ ! -e "/Applications/$1" ]; then
		echo "-----------------------------------------------------------------------------"
		echo "$1 IS MISSING - INSTALLING!"
		sudo jamf policy -event "$2"
		else
		echo "-----------------------------------------------------------------------------"
		echo "$1 HAS BEEN INSTALLED ON THIS MACHINE - SKIPPING"
		fi
		
		}

#########################################################################################
# checkForSuccess
#########################################################################################

function checkForSuccess {
	if [ $? != 0 ]; then
	# IF PREVIOUS COMMAND ERRORED THEN PRINT THIS MESSAGE
	echo "-----------------------------------------------------------------------------"
	echo "PREVIOUS COMMAND FAILED *****************************************************"
	else
	# ELSE PRINT THIS MESSAGE
	echo "-----------------------------------------------------------------------------"
	echo "COMMAND COMPLETED"
	fi
	}

#########################################################################################
# getAdbeAppVersion
#########################################################################################

function getAdbeAppVersion {
appManagerVersion=$( /usr/libexec/plistbuddy -c Print:CFBundleShortVersionString: /Applications/Utilities/Adobe\ Application\ Manager/core/Adobe\ Application\ Manager.app/Contents/Info.plist )

echo "-----------------------------------------------------------------------------"
echo "********** ADOBE APPLICATION MANAGER VERSION IS:$appManagerVersion ***********************"

}

#########################################################################################
# multiplejamf
#########################################################################################


function multiplejamf {
	# Based on function by Richard Purves
	# Error trapping function to prevent multiple jamf binary processes running simultaneously
	# Check to see if jamf binary is running, and wait for it to finish.
	# Trying to avoid multiple triggers running at once at the expense of time taken.
	# The maximum should be two existing jamf processes running at all times.

	TEST=$( pgrep -x jamf | wc -l )

	while [ $TEST -gt 2 ]
	do
		echo "Waiting for existing jamf processes to finish ..."
echo "-----------------------------------------------------------------------------"
		echo "Some policies can take significant time to install."
		/bin/sleep 3
		TEST=$( pgrep -x jamf | wc -l )
	done
}

#########################################################################################
# CHECK FOLDER EXISTS
#########################################################################################

function checkFolderExists () {
if [ ! -d $1 ]
then
echo "-----------------------------------------------------------------------------"
echo "$1 DOES NOT EXIST - MAKING"
sudo mkdir -p $1
else
echo "-----------------------------------------------------------------------------"
echo "$1 ALREADY EXISTS - PROCEEDING"
fi
}

#########################################################################################
# CHECK FILE EXISTS
#########################################################################################

function checkFileExists () {
if [ ! -e $1 ]
then
echo "-----------------------------------------------------------------------------"
echo "$1 DOES NOT EXIST - MAKING"
sudo touch $1
else
echo "-----------------------------------------------------------------------------"
echo "$1 ALREADY EXISTS - PROCEEDING"
fi
}

#########################################################################################
# PROCEED IF FILE EXISTS
#########################################################################################

function proceedIfFileExists () {
if [ -e $1 ]
then
echo "-----------------------------------------------------------------------------"
echo "$1 EXISTS - PROCEEDING WITH SCRIPT"
else
echo "-----------------------------------------------------------------------------"
echo "$1 DOES NOT EXIST - ABORTING"
echo "-----------------------------------------------------------------------------"
exit 0
fi
}

#########################################################################################
# ADD ADOBE COMPONENTS
#########################################################################################

function countItems {
# Add all the adobe apps together to get a total size of the install 
# NOTE: this excludes resource files, so is approximate.

IFS=$'\n'
AdobeApps=(`ls /Applications/ | grep Adobe`)

		total=0
		for item in "${AdobeApps[@]}" ; do
		echo "-----------------------------------------------------------------------------"
		echo "CURRENT ITEM IS:$item"
		filesize=$(du -s /Applications/"$item" | awk '{print $1}')
		echo "-----------------------------------------------------------------------------"
		printf "$item \nSIZE IS: $filesize\n"
		let total+=$filesize
		## This adds the current variable to the total variable
		done
		echo "-----------------------------------------------------------------------------"
		printf "ADOBE TOTAL INSTALL SIZE IS: \n$total bytes\n"
		## This then outputs the totalled variable of all the Adobe components
}



################################################################################
# checkProcessRunsAndKill
################################################################################

function checkProcessRunsAndKill () {
	
	# Check if process is running and kill if not
	# v1.4 - added failsafe to bypass in case process argument is ommitted
	
	echo "--------------------------------------------------------------------------"
	echo "Checking for processes"
	if [ ! -z "$1" ]
	then
		
		if [ ! -z "$2" ]
		then
			echo "--------------------------------------------------------------------------"
			echo "Custom process parameters have been specified:$2"	
			
			runningProcesses=(`ps -ax | grep -i "$2" | grep -iv 'jamf' | grep -v 'grep' | grep -v '/usr/local/scripts/Adobe/CC_${adbeVersion}_INSTALL_CHECK_LOG.txt	' | awk '{print $1}'`)
			runningProcessesName=(`ps -ax | grep -i "$2" | grep -iv 'jamf' | grep -v 'grep'`)	
			
		else
			echo "--------------------------------------------------------------------------"
			echo "Process parameters have been specified:$1"
			
			runningProcesses=(`ps -ax | grep -i "$1" | grep -iv 'jamf' | grep -v 'grep' | awk '{print $1}'`)
			runningProcessesName=(`ps -ax | grep -i "$1" | grep -iv 'jamf' | grep -v 'grep'`)
			
			if [ ! -z "$runningProcesses" ]
			then
				echo "--------------------------------------------------------------------------"
				echo "CHECKING FOR PROCESS:$1"
				echo "--------------------------------------------------------------------------"
				echo "PROCESS FOUND - ID VALUE IS/ARE:"
				echo "--------------------------------------------------------------------------"
				echo "${runningProcesses[@]}"
				echo "--------------------------------------------------------------------------"
				echo "PROCESS FOUND - NAMES ARE:"        
				echo "--------------------------------------------------------------------------"
				echo "${runningProcessesName[@]}"
				echo "--------------------------------------------------------------------------"
				echo "KILLING PROCESSES"
				for processID in "${runningProcesses[@]}"
				do
					echo "--------------------------------------------------------------------------"
					echo "KILLING PROCESS: $processID"
					sudo kill -9 $processID
				done
			else
				echo "--------------------------------------------------------------------------"
				echo "PROCESS:$1 NOT FOUND"
				#			DEBUG
				#			echo "ALL VARIABLE VALUES ARE:${runningProcesses[@]}"
			fi
		fi	
	else
		
		echo "--------------------------------------------------------------------------"
		echo "No process parameters have been specified - ignoring"
	fi
	
}

################################################################################
# compareTotals
################################################################################

function compareTotals () {
	total=$1
	estimatedSize=$2
	adbeVersion=$3
	
	if [ $total -lt $estimatedSize ]
	then
		echo "THE ADOBE TOTAL SIZE IS:$total"
		echo "-----------------------------------------------------------------------------"
		echo "THIS IS TOO SMALL - SUSPECT THAT ADOBE CC ${adbeVersion} IS NOT CORRECTLY INSTALLED - LEAVE FLAG SO RE-RUNS"
	else
		echo "THE ADOBE TOTAL SIZE IS:$total"
		echo "-----------------------------------------------------------------------------"
		echo "THIS IS CORRECT - REMOVING STAGE 1 CC_${adbeVersion}_INSTALLED FLAG"
		echo "-----------------------------------------------------------------------------"
		sudo rm /usr/local/scripts/Adobe/CC_${adbeVersion}_INSTALLED.txt
		echo "ADDING ADOBE CC ${adbeVersion} IS INSTALLED FLAG"
		# echo "-----------------------------------------------------------------------------"
		sudo touch /usr/local/scripts/Adobe/CC_${adbeVersion}_CHECK_COMPLETE.txt
	fi
}


########################################################################################
# SCRIPT PROGRESS
########################################################################################

########################################################################################
# Fix issues with previous install version
########################################################################################
echo "Fixing issue with old receipts"
rm -Rf /private/var/db/receipts/com.adobe.Enterprise*

checkFolderExists /usr/local/scripts/Adobe
		
checkFileExists /usr/local/scripts/Adobe/CC_${adbeVersion}_INSTALL_CHECK_LOG.txt		

sudo chmod -Rf 777 /usr/local/scripts/Adobe

checkForLogin

proceedIfFileExists /usr/local/scripts/Adobe/CC_${adbeVersion}_INSTALLED.txt

########################################################################################
############ REINSTALL POLICIES ########################################################
########################################################################################

echo "-----------------------------------------------------------------------------"
echo "SCRIPT VERSION IS:$version"
echo "Script is running at:$dateTime"

########################################################################################
# To run the application check configure as follows:
########################################################################################
# adbeApplicationCheck "Name of application folder" jssCustomTrigger
# 
########################################################################################
############ CONFIGURE HERE ############################################################
########################################################################################


########################################################################################
# NOTE:
########################################################################################
# THE CUSTOM INSTALL TRIGGERS BELOW ARE EXAMPLES - YOU WILL NEED TO ADD YOUR OWN!


getAdbeAppVersion | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Acrobat DC" cc${adbeVersion}_acrobat | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe After Effects $adbeVersion" cc${adbeVersion}_aftereffects | tee -a "$localLog"
checkForSuccess


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Audition $adbeVersion" cc${adbeVersion}_audition | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Animate CC $adbeVersion" cc${adbeVersion}_animate | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Bridge $adbeVersion" cc${adbeVersion}_bridge | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Character Animator $adbeVersion" cc${adbeVersion}_characteranimator | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Dreamweaver $adbeVersion" cc${adbeVersion}_dreamweaver | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Dimension CC" cc${adbeVersion}_dimension | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Illustrator $adbeVersion" cc${adbeVersion}_illustrator | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe InCopy $adbeVersion" cc${adbeVersion}_incopy | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe InDesign $adbeVersion" cc${adbeVersion}_indesign | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Lightroom CC" cc${adbeVersion}_lightroom | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Lightroom Classic CC" cc${adbeVersion}_lightroomclassic | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Media Encoder CC $adbeVersion" cc${adbeVersion}_mediaencoder | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Prelude CC $adbeVersion" cc${adbeVersion}_prelude | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Photoshop CC $adbeVersion" cc${adbeVersion}_photoshop | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Premiere Pro CC $adbeVersion" cc${adbeVersion}_premiere | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Premiere Rush CC" cc${adbeVersion}_premiererush | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"

checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe Substance 3D Painter" cc${adbeVersion}_substance | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"


checkProcessRunsAndKill 'Adobe' 
adbeApplicationCheck "Adobe XD" cc${adbeVersion}_xd | tee -a "$localLog"
checkForSuccess | tee -a "$localLog"

echo "Get the latest version of the Adobe Desktop App" | tee -a "$localLog"
sudo jamf policy -event adobeccapp | tee -a "$localLog"

########################################################################################
############ END CONFIGURE HERE ########################################################
########################################################################################



########################################################################################
## SECTION TO CHECK SIZE OF CURRENT INSTALL
########################################################################################

echo "*****************************************************************************"
echo "*****************************************************************************"
echo "-----------------------------------------------------------------------------"

########################################################################################
## GET SIZE SECTION ####################################################################
########################################################################################

# Run adobeAdd function - to calculate total size of adobe install

countItems

echo "-----------------------------------------------------------------------------"

########################################################################################
### DEBUG SECTION ######################################################################
########################################################################################
# Enable this function to output additional trace messages checking variables
# 
# function deBug {
# IFS=$'\n'
# AdobeSimpleTotal=(`ls -la /Applications/ | grep Adobe | awk '{print $5}'`)
# AdobeAppName=(`ls -la /Applications/ | grep Adobe | awk '{print $10}'`)
# echo "LIST AND GREP ADOBE APPS ARE:"
# echo "-----------------------------------------------------------------------------"
# echo "${AdobeAppName[@]}"
# echo "-----------------------------------------------------------------------------"
# echo "ADOBE SIMPLE TOTAL IS: ${AdobeSimpleTotal[@]}"
# echo "-----------------------------------------------------------------------------"
# echo "ADOBE APP SIZE ARRAY IS: ${AdobeApps[@]}"
# echo "-----------------------------------------------------------------------------"
# unset IFS
# }
# deBug ################################################################################


########################################################################################
## CHECK SIZE ##########################################################################
########################################################################################
# write size to temp file

adobeTotalSize=/usr/local/scripts/Adobe/adobeTotalSize.txt

sudo printf $total > $adobeTotalSize

printf "CONVERTING BYTES TO HUMAN READABLE FORMAT:\n"
echo "-----------------------------------------------------------------------------"
echo "THIS IS THE GB FORMAT FROM THE TEXT FILE"
echo "-----------------------------------------------------------------------------"
echo `cat $adobeTotalSize | awk '{print $1}'` / 1024^2 | bc -l

# note:	bc is a calculator

echo "-----------------------------------------------------------------------------"

########################################################################################

compareTotals $total $estimatedSize ${adbeVersion}

######### END ##########################################################################

echo "-----------------------------------------------------------------------------"
echo "POLICY HAS COMPLETED"

########################################################################################
### CLEANUP ############################################################################
########################################################################################
# REMOVE adobeTotalSize.txt TEMP FILE
########################################################################################

rm $adobeTotalSize

########################################################################################
echo "-----------------------------------------------------------------------------"
echo "REMOVING ANY CACHED PACKAGES THAT REMAIN FROM INITIAL INSTALL"
########################################################################################

rm -Rf /Library/Application\ Support/JAMF/Waiting\ Room/Adobe*

checkForSuccess

echo "-----------------------------------------------------------------------------"
echo "Adobe CC ${adbeVersion} Check Completed:$dateTime *******************************************" >> $localLog
echo "-----------------------------------------------------------------------------"

exit 0