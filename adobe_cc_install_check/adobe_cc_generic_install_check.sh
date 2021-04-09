#!/bin/bash
# tags: Adobe
# 
# 2018 Amos Deane
# 
# NOTES:

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
# The calculation of the size of the fully installed suite is fairly basic and limited in 
# the scope of what is checked. In practise, I have found that it works reasonably well as 
# if an install fails it usually ommits most of the install files, so there is an obvious size difference. However it could potentially be unreliable and I am looking at creating a function/some functions to do more accurate install checks.

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


version=v1.15
dateTime=$(date "+%d-%m-%Y_%H-%M")

#########################################################################################
# Editable parameters
#########################################################################################

adobeVersion=2020
localLog=/usr/local/scripts/Adobe/CC_${adobeVersion}_INSTALL_CHECK_LOG.txt
estimatedSize=73000000
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
currentUser=$(ls -l /dev/console | awk '{print $3}')
		if [ $currentUser == root ]; then
		echo "NOONE IS LOGGED IN"
		else
		echo "A USER IS LOGGED IN - ABORTING"
		exit 0
		fi
		}
		
#########################################################################################
# adobeApplicationCheck
#########################################################################################

# The function will check for the existence of the specified app. If it is not found it will 
# trigger a jamf policy. The app and the policy event can be specified as arguments.

function adobeApplicationCheck {

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
# getAdobeAppVersion
#########################################################################################

function getAdobeAppVersion {
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
if [ ! -d $1 ]
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
if [ ! -d $1 ]
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

function adobeAdd {
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

########################################################################################
# SCRIPT PROGRESS
########################################################################################

checkFolderExists /usr/local/scripts/Adobe
		
checkFileExists /usr/local/scripts/Adobe/CC_{$adobeVersion}_INSTALL_CHECK_LOG.txt		
		
# checkForLogin

proceedIfFileExists /usr/local/scripts/Adobe/CC_{$adobeVersion}_INSTALLED.txt

########################################################################################
############ REINSTALL POLICIES ########################################################
########################################################################################

echo "-----------------------------------------------------------------------------"
echo "SCRIPT VERSION IS:$version"

########################################################################################
# To run the application check configure as follows:
########################################################################################
# adobeApplicationCheck "Name of application folder" jssCustomTrigger
# 
########################################################################################
############ CONFIGURE HERE ############################################################
########################################################################################

# NOTE:
# THE CUSTOM INSTALL TRIGGERS BELOW ARE EXAMPLES - YOU WILL NEED TO ADD YOUR OWN!

getAdobeAppVersion

adobeApplicationCheck "Adobe Acrobat DC" ccExampleTrigger{$adobeVersion}_acrobat
checkForSuccess

adobeApplicationCheck "Adobe After Effects $adobeVersion" ccExampleTrigger{$adobeVersion}_aftereffects
checkForSuccess

adobeApplicationCheck "Adobe Audition $adobeVersion" ccExampleTrigger{$adobeVersion}_audition
checkForSuccess

adobeApplicationCheck "Adobe Animate CC $adobeVersion" ccExampleTrigger{$adobeVersion}_animate
checkForSuccess

adobeApplicationCheck "Adobe Bridge $adobeVersion" ccExampleTrigger{$adobeVersion}_bridge
checkForSuccess

adobeApplicationCheck "Adobe Character Animator $adobeVersion" ccExampleTrigger{$adobeVersion}_characteranimator
checkForSuccess

adobeApplicationCheck "Adobe Dreamweaver $adobeVersion" ccExampleTrigger{$adobeVersion}_dreamweaver
checkForSuccess

adobeApplicationCheck "Adobe Dimension CC" ccExampleTrigger{$adobeVersion}_dimension
checkForSuccess

adobeApplicationCheck "Adobe Illustrator $adobeVersion" ccExampleTrigger{$adobeVersion}_illustrator
checkForSuccess

adobeApplicationCheck "Adobe InCopy $adobeVersion" ccExampleTrigger{$adobeVersion}_incopy
checkForSuccess

adobeApplicationCheck "Adobe InDesign $adobeVersion" ccExampleTrigger{$adobeVersion}_indesign
checkForSuccess

adobeApplicationCheck "Adobe Lightroom CC" ccExampleTrigger{$adobeVersion}_lightroom
checkForSuccess

adobeApplicationCheck "Adobe Lightroom Classic CC" ccExampleTrigger{$adobeVersion}_lightroomclassic
checkForSuccess

adobeApplicationCheck "Adobe Media Encoder CC $adobeVersion" ccExampleTrigger{$adobeVersion}_mediaencoder
checkForSuccess

adobeApplicationCheck "Adobe Prelude CC $adobeVersion" ccExampleTrigger{$adobeVersion}_prelude
checkForSuccess

adobeApplicationCheck "Adobe Photoshop CC $adobeVersion" ccExampleTrigger{$adobeVersion}_photoshop
checkForSuccess

adobeApplicationCheck "Adobe Premiere Pro CC $adobeVersion" ccExampleTrigger{$adobeVersion}_premiere
checkForSuccess

adobeApplicationCheck "Adobe Premiere Rush CC" ccExampleTrigger{$adobeVersion}_premiererush
checkForSuccess

adobeApplicationCheck "Adobe XD" ccExampleTrigger{$adobeVersion}_xd
checkForSuccess

########################################################################################
############ END CONFIGURE HERE ########################################################
########################################################################################


echo "-----------------------------------------------------------------------------"
echo "Adobe CC {$adobeVersion} CHECK RUN:$dateTime *******************************************" >> $localLog
echo "-----------------------------------------------------------------------------"

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

adobeAdd

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
sudo chmod -Rf 777 /usr/local/scripts/Adobe
sudo printf $total > $adobeTotalSize

printf "CONVERTING BYTES TO HUMAN READABLE FORMAT:\n"
echo "-----------------------------------------------------------------------------"
echo "THIS IS THE GB FORMAT FROM THE TEXT FILE"
echo "-----------------------------------------------------------------------------"
echo `cat $adobeTotalSize | awk '{print $1}'` / 1024^2 | bc -l
# note:	bc is a calculator
echo "-----------------------------------------------------------------------------"
########################################################################################

if [ $total -lt $estimatedSize ]
then
echo "THE ADOBE TOTAL SIZE IS:$total"
echo "-----------------------------------------------------------------------------"
echo "THIS IS TOO SMALL - SUSPECT THAT ADOBE CC {$adobeVersion} IS NOT CORRECTLY INSTALLED - LEAVE FLAG SO RE-RUNS"
else
echo "THE ADOBE TOTAL SIZE IS:$total"
echo "-----------------------------------------------------------------------------"
echo "THIS IS CORRECT - REMOVING STAGE 1 CC_{$adobeVersion}_INSTALLED FLAG"
echo "-----------------------------------------------------------------------------"
sudo rm /usr/local/scripts/Adobe/CC_{$adobeVersion}_INSTALLED.txt
echo "ADDING ADOBE CC {$adobeVersion} IS INSTALLED FLAG"
sudo touch /usr/local/scripts/Adobe/CC_{$adobeVersion}_CHECK_COMPLETE.txt
fi

######### END ##########################################################################

echo "-----------------------------------------------------------------------------"
echo "POLICY HAS COMPLETED"
echo "-----------------------------------------------------------------------------"
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

exit 0