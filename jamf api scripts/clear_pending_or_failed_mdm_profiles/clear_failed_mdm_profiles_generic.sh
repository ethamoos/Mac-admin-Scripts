#!/bin/bash

########################################################################################
# Original script from https://aporlebeke.wordpress.com/2019/01/04/auto-clearing-failed-mdm-commands-for-macos-in-jamf-pro/
# GitHub gist: https://gist.github.com/apizz/48da271e15e8f0a9fc6eafd97625eacd#file-ea_clear_failed_mdm_commands-sh
########################################################################################

########################################################################################
# Adapted by Amos Deane - June 2022
# v1.1
# v1.2 - Sep 20 2022
# v1.3 - Jan 10 2023 
# v1.4 - generic version 4 May 2023

encryptedString="$4"
error=0

########################################################################################
# For local testing with encryption populate the variable below manually
########################################################################################
# encryptedString=""
########################################################################################

########################################################################################
# DEBUG
# echo "encryptedString is:$encryptedString"
########################################################################################
# ADD IN salt and passphrase for encrypted string - if used
########################################################################################

salt=
passphrase=

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
# CONFIGURE VARIABLES
########################################################################################

jamfpro_server_address=$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf jss_url)
# jamfpro_server_address=""
jamfpro_user=""
jamfpro_password=$(DecryptString "$encryptedString" "$salt" "$passphrase")


########################################################################################
# MANUAL PASSWORD OVERIDE - use this for testing only
########################################################################################
# jamfpro_password=""
########################################################################################


########################################################################################
# DEBUG - pass in string
########################################################################################
# decryptedString=
# echo "-----------------------------------------------------------"
# echo "DEBUGGING COMMANDS:"
# echo "curl -sfku ${jamfpro_user}:${jamfpro_password} $jamfpro_server_address"
########################################################################################

dateTime=$(date +%d-%m-%Y-%H-%M-%S)
localLog=/var/log/clearFailedMDMCommandsLog_$dateTime.txt

########################################################################################
# RUN ON CURRENT MACHINE
machineUUID=$(/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/awk '/IOPlatformUUID/ { gsub(/"/,"",$3); print $3; }')
########################################################################################
# UNCOMMENT FOR MANUAL OVERRIDE
########################################################################################
# machineUUID=
########################################################################################

# Remove the trailing slash from the Jamf Pro URL if needed.
jamfpro_server_address=${jamfpro_server_address%%/}

ClearFailedMDMCommands () {
	/usr/bin/curl -sfu "${jamfpro_user}:${jamfpro_password}" "${jamfpro_server_address}/JSSResource/commandflush/computers/id/${computerID}/status/Failed" -X DELETE
}

GetJamfProComputerID () {
	local computerID=$(/usr/bin/curl -sfu "${jamfpro_user}:${jamfpro_password}" "${jamfpro_server_address}/JSSResource/computers/udid/${machineUUID}" -X GET -H "accept: application/xml" | /usr/bin/xmllint --xpath "/computer/general/id/text()" - 2>/dev/null)
	echo "$computerID"
}

GetFailedMDMCommands () {
	local xmlResult=$(/usr/bin/curl -sfu "${jamfpro_user}:${jamfpro_password}" "${jamfpro_server_address}/JSSResource/computerhistory/udid/${machineUUID}/subset/Commands" -X GET -H "accept: application/xml" | /usr/bin/xmllint --xpath "/computer_history/commands/failed[node()]" - 2>/dev/null)
	echo "$xmlResult"
}

########################################################################################
# Build a list of failed MDM commands associated with a particular Mac.
########################################################################################

echo "Create log file"
touch $localLog

xmlResult=$(GetFailedMDMCommands)

# Clear failed MDM commands if they exist

if [[ -n "$xmlResult" ]]; then

	computerID=$(GetJamfProComputerID)

	if [[ "$computerID" =~ ^[0-9]+$ ]]; then
	
	    echo "Removing failed MDM commands.....UUID is:$machineUUID" | tee -a $localLog
	    ClearFailedMDMCommands

	  	if [[ $? -eq 0 ]]; then
	    	echo "Removed failed MDM commands."
	  	else
	   		echo "ERROR! Problem occurred when removing failed MDM commands!"
	   		error=1
	  	fi
	  
	else
	   echo "ERROR! Problem occurred when identifying Jamf Pro computer ID!"
	   error=1
	fi

else
	echo "No failed MDM commands found."
fi

exit $error