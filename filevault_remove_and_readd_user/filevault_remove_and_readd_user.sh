#!/bin/bash
# tags: applescript, fdesetup

####################################################################################
# NOTES
####################################################################################
# Script to remove and re-add an account from encryption - this can be used to fix an 
# account that is not syncing its password.
####################################################################################
# 
# IMPORTANT! 
# a) This can not re-add the user that is currently logged in, therefore it should be run 
# when logged in with a separate account than that to be re-added
#
# b) This must be run from an account that is enabled for filevault
#
# c) This is a work in progress script with no guarantees of its success 
# please test it carefully on a test machine in your environment before using it
#
# d) ALWAYS ensure that you have access to a valid filevault enabled account before making 
# any modifications on any other filevault enabled accounts, to avoid locking 
# yourself out of the machine!
#
####################################################################################
# HISTORY
####################################################################################
# Amos Deane July 4 2018
# v1.1 - fixed buy not applying to correct user - July 5 2018
# v1.2 - added debut messages
# v1.3 - updated messages
# v1.4 - improved formatting
# v1.5 - updated
# v1.5.3 - consolidated previous sections into functions
# v1.5.4 - minor formatting changes

allUsers=( `ls /Users/` )
currentLoggedInUser=$USER

# array of filevault users - only username
filevaultUsers=(`sudo fdesetup list | cut -f1 -d ,`)


####################################################################################
# SCRIPT PROCESS ORDER #############################################################
####################################################################################
# 
# OFFER LIST OF USERS TO BE SELECTED					SECTION A
# 
# 
# USER IS SELECTED
# 
# 
# CHECK if currently logged in user is filevault enabled user
# 
# 	IF NOT	ABORT (or offer to add to file vault?)
# 
# 	IF YES	
# 	SCRIPT CAN RUN										SECTION B
# 
# 
# REMOVE SELECTED USER AND RE-ADD						SECTION C
####################################################################################

####################################################################################
# FUNCTIONS ########################################################################
####################################################################################	

function separationLine {
		echo "------------------------------------------------------------------"
}
 
####################################################################################
# DEBUG ############################################################################
####################################################################################

function debug1 {

separationLine
echo "DEBUGGING - CHECKING VARIABLES ARE PASSED CORRECTLY"
separationLine

echo "NO DEBUG MESSAGES SET"
}
####################################################################################	

# function debug2 {
# echo "ARRAY IS:${allUsers[@]}"
# }


####################################################################################
# formatTheArrayForApplescript #####################################################
####################################################################################
# The below section formats the array so that it can be read by applescript - adding escape characters etc

function formatTheArrayForApplescript {
# _ProjectTemplateFolder - This defines the list - in this case it is the contents of a folder (Users)
for file in ${_ProjectTemplateFolder}/Users/*
do
	# get filename only - not path
    arrayItem=${file##*/}
    
    # the variable has an offset value to match the first character - e.g. character 0, 1 character long
    if [ "${arrayItem:0:1}" = "_" ] ; then
        echo "------------------------------------------------------------------"
        echo "NOT Processing $arrayItem" 1>&2      # for now just a test
    else 
	# if array is not empty add a comma to the array
        if [[ ! -z ${ItemList} ]] ; then
            ItemList=${ItemList}","
        fi
        echo "------------------------------------------------------------------"
        echo "Processing arrayItem: $arrayItem" 1>&2
        # adding array item and inserting escape characters
        ItemList=${ItemList}"\""${arrayItem}"\""   # to create "item1","item2","item..n"
    fi
done
echo "------------------------------------------------------------------"
echo "ItemList :"${ItemList}
}



####################################################################################
# removeUserFilevault ##############################################################
####################################################################################	

function removeUserFilevault {

echo "Removing $chosenUser from filevault"
sudo fdesetup remove -user "$chosenUser"
}

####################################################################################
# readdUserFilevault ###############################################################
####################################################################################	

function readdUserFilevault	{
echo "Now re-adding $chosenUser to filevault"
adminName=$currentLoggedInUser

adminPass="$(/usr/bin/osascript -e 'Tell application "System Events" to display dialog "Enter password for:'"$adminName"' to enable filevault for user:'"$chosenUser"'  " default answer "" with title "Enter Password of a Filevault Admin User" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"

# Get the logged in user's password via a prompt
echo "Prompting ${userName} for their login password."
userPass="$(osascript -e 'Tell application "System Events" to display dialog "Please enter the password for:'"$chosenUser"' " default answer "" with title "Enter Password for user being re-enabled" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"
}



####################################################################################
# createPlistFile
####################################################################################

# create the plist file:

function createPlistFile {
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>'$adminName'</string>
<key>Password</key>
<string>'$adminPass'</string>
<key>AdditionalUsers</key>
<array>
    <dict>
        <key>Username</key>
        <string>'$userName'</string>
        <key>Password</key>
        <string>'$userPass'</string>
    </dict>
</array>
</dict>
</plist>' > /tmp/fvenable.plist
}



####################################################################################
# chooseUserApplescript ############################################################
####################################################################################

function chooseUserApplescript {
# This contains the applescript that sets the variable via a dropdown menu
chosenUser="$(/usr/bin/osascript -e 'tell application "System Events" to activate' -e 'tell application "System Events" to return (choose from list {'"$ItemList"'} with prompt "Choose a User to remove and re-add to Filevault:" with title "Available Users" OK button name "Select" cancel button name "Quit")')"

separationLine
echo "My chosen user from the menu is:$chosenUser"
}

####################################################################################
# SCRIPT PROGRESS
####################################################################################
	
####################################################################################
# SECTION A ########################################################################
####################################################################################	


echo "------------------------------------------------------------------"
echo "LISTING ENABLED FILEVAULT USERS"
echo "------------------------------------------------------------------"
sudo fdesetup list | cut -f1 -d ,

####################################################################################
# formatTheArrayForApplescript #####################################################
####################################################################################

formatTheArrayForApplescript

####################################################################################
# chooseUserApplescript ############################################################
####################################################################################

chooseUserApplescript 

####################################################################################
# SECTION B ########################################################################
####################################################################################	

####################################################################################
# checkIfCurrentUserIsInFVList B ########################################################################
####################################################################################	
# this section will cycle through the list of filevault users and check if they match the 
# currently logged in user - if there is a match the script then checks if this user is 
# the user designated for removal - which is not allowed and will terminate the script!
	
	for currentFilevaultUser in ${filevaultUsers[@]}
	do
	
		echo "------------------------------------------------------------------"
		echo "Current Filevault user is:$currentFilevaultUser - checking with:$currentLoggedInUser"
	
		if [ "$currentFilevaultUser" == "$currentLoggedInUser" ]
		then

				echo "------------------------------------------------------------------"
				printf "$currentLoggedInUser matches and is enabled for filevault\t @@@@@@@@@@@@@ \n"
				
					if [ "$chosenUser" == "$currentLoggedInUser" ]
					then
					echo "$chosenUser is currently logged in and can't be removed - this script must be run under another login! ********"
					exit 0
					else

####################################################################################
# SECTION C ########################################################################
####################################################################################	

####################################################################################
################### DO REMOVE TASK #################################################
####################################################################################

removeUserFilevault

####################################################################################
################### DO RE-ADD TASK #################################################
####################################################################################
	
readdUserFilevault

####################################################################################
# Get the chosenUser 's name - e.g. the user selected in the dropdown menu
userName=$chosenUser

if [ "${adminName}" == "" ]; then
echo "Admin Username undefined. Please pass the management account username in parameter 4.********"
debug1
exit 1
fi

if [ "${adminPass}" == "" ]; then
echo "Admin Password undefined. Please pass the management account password in parameter 5.********"
debug1
exit 2
fi

# This first user check sees if the logged in account is already authorized with FileVault 2
userCheck=`sudo fdesetup list | awk -v usrN="$userName" -F, 'index($0, usrN) {print $1}'`
if [ "${userCheck}" == "${userName}" ]; then
echo "This user is already added to the FileVault 2 list.********"
debug1
exit 3
fi

# Check to see if the encryption process is complete
encryptCheck=`sudo fdesetup status`
statusCheck=$(echo "${encryptCheck}" | grep "FileVault is On.")
expectedStatus="FileVault is On."
if [ "${statusCheck}" != "${expectedStatus}" ]; then
echo "The encryption process has not completed, unable to add user at this time. ********"
echo "${encryptCheck}"
debug1
exit 4
fi

echo "Adding user to FileVault 2 list."

####################################################################################
# create the plist file:
####################################################################################

createPlistFile

####################################################################################
# now re-enable FileVault for chosen user
####################################################################################

sudo fdesetup add -i < /tmp/fvenable.plist

# This second user check sees if the logged in account was successfully added to the FileVault 2 list
userCheck=`sudo fdesetup list | awk -v usrN="$userName" -F, 'index($0, usrN) {print $1}'`
if [ "${userCheck}" != "${userName}" ]; then
echo "Failed to add user to FileVault 2 list."
debug1
exit 5
fi

echo "${userName} has been added to the FileVault 2 list."
debug1
# clean up
if [[ -e /tmp/fvenable.plist ]]; then
    rm /tmp/fvenable.plist
fi

					exit 0
			
####################################################################################
####################################################################################

					fi
		
				else
				echo "------------------------------------------------------------------"
				echo "no match - $currentUser is not enabled for filevault"
		fi
	done	
		
done				
echo "------------------------------------------------------------------"

exit 0