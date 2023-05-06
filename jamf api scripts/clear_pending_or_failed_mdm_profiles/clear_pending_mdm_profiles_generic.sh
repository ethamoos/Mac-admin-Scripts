#!/bin/bash

########################################################################################
# Original script from https://aporlebeke.wordpress.com/2019/01/04/auto-clearing-Pending-mdm-commands-for-macos-in-jamf-pro/
# GitHub gist: https://gist.github.com/apizz/48da271e15e8f0a9fc6eafd97625eacd#file-ea_clear_Pending_mdm_commands-sh
########################################################################################
# Adapted by Amos Deane - June 2022
# v1.1
# v1.2 - Sep 20 2022
# v1.3 - Jan 10 2023 
# v1.4 - generic version 4 May 2023

error=0
encryptedString="$4"

########################################################################################
# For local testing with encryption populate the variable below manually
########################################################################################
# encryptedString=""
########################################################################################


########################################################################################

function DecryptString() {
# Usage:    DecryptString "Encrypted String" "Salt" "Passphrase"
	if [[ $(sw_vers -buildVersion) > "21A" ]]; then
	echo "${1}" | /usr/bin/openssl enc -md md5 -aes256 -d -a -A -S "${2}" -k "${3}"
	else
	echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
	fi
}


########################################################################################
# ADD IN salt and passphrase for encrypted string - if used
########################################################################################

salt=
passphrase=

########################################################################################

jamfpro_user=""
jamfpro_password=$(DecryptString "$encryptedString" "$salt" "$passphrase")
jamfpro_server_address=$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf jss_url)


########################################################################################
# MANUAL PASSWORD OVERIDE - use this for testing only
########################################################################################
# jamfpro_password=""
########################################################################################

dateTime=$(date +%d-%m-%Y-%H-%M-%S)
localLog=/var/log/clearPendingMDMCommandsLog_$dateTime.txt

########################################################################################
# TO RUN ON CURRENT MACHINE
########################################################################################
machineUUID=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk '/IOPlatformUUID/ { gsub(/"/,"",$3); print $3; }')
########################################################################################
# UNCOMMENT FOR MANUAL OVERRIDE TESTING and set a UUID
########################################################################################

# machineUUID=

########################################################################################
# Set a local log file
########################################################################################

# localLog=./log/clearPendingMDMCommandsLog_$dateTime.txt

########################################################################################

########################################################################################
# Remove the trailing slash from the Jamf Pro URL if needed.
########################################################################################
jamfpro_server_address=${jamfpro_server_address%%/}
########################################################################################
# Functions
########################################################################################


ClearPendingMDMCommands () {
	/usr/bin/curl -sfu "${jamfpro_user}:${jamfpro_password}" "${jamfpro_server_address}/JSSResource/commandflush/computers/id/${computerID}/status/Pending" -X DELETE
}

GetJamfProComputerID () {
	local computerID=$(/usr/bin/curl -sfu "${jamfpro_user}:${jamfpro_password}" "${jamfpro_server_address}/JSSResource/computers/udid/${machineUUID}" -X GET -H "accept: application/xml" | /usr/bin/xmllint --xpath "/computer/general/id/text()" - 2>/dev/null)
	echo "$computerID"
}

GetPendingMDMCommands () {
	local xmlResult=$(/usr/bin/curl -sfu "${jamfpro_user}:${jamfpro_password}" "${jamfpro_server_address}/JSSResource/computerhistory/udid/${machineUUID}/subset/Commands" -X GET -H "accept: application/xml" | /usr/bin/xmllint --xpath "/computer_history/commands/pending[node()]" - 2>/dev/null)
	echo "$xmlResult"
}

########################################################################################
# Build a list of Pending MDM commands associated with a particular Mac.
########################################################################################

echo "Create log file"
touch $localLog

xmlResult=$(GetPendingMDMCommands)

# Clear Pending MDM commands if they exist

if [[ -n "$xmlResult" ]]; then

	computerID=$(GetJamfProComputerID)

	if [[ "$computerID" =~ ^[0-9]+$ ]]; then
	
	    echo "Removing Pending MDM commands.....UUID is:$machineUUID" | tee -a $localLog
	    ClearPendingMDMCommands

	  	if [[ $? -eq 0 ]]; then
	    	echo "Removed Pending MDM commands."
	  	else
	   		echo "ERROR! Problem occurred when removing Pending MDM commands!"
	   		error=1
	  	fi
	  
	else
	   echo "ERROR! Problem occurred when identifying Jamf Pro computer ID!"
	   error=1
	fi

else
	echo "No Pending MDM commands found."
fi

exit $error
