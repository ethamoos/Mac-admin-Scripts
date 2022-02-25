#!/bin/bash

# Script to trigger a jamf policy if no user is currently logged in. 
# If a user is logged in the script will error, meaning logs with an error can be flushed
# Amos Deane 2020
# v1

# RUN WITHIN JAMF
runPolicy="$4"
# LOCAL TESTING
# runPolicy="testselfservice"

###########################################################################################
# runIfNooneIsLoggedIn
###########################################################################################

function runIfNooneIsLoggedIn {
# Run Policy if noone is logged in
currentUser=$(ls -l /dev/console | awk '{print $3}')
if [ $currentUser == root ]; then
echo "NOONE IS LOGGED IN - RUNNING POLICY:$1"
"$1"
exit 0
else
echo "A USER IS LOGGED IN - ABORTING WITH EXIT 1"
exit 1
fi
}


###########################################################################################
# runPolicy
###########################################################################################

function runPolicy {
echo "Running Jamf Policy with trigger:$runPolicy"
sudo /usr/local/jamf/bin/jamf policy -event "$runPolicy"
}


###########################################################################################
# SCRIPT PROGRESS
###########################################################################################

runIfNooneIsLoggedIn "runPolicy"
