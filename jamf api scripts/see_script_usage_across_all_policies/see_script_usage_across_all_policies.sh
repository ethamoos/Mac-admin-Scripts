#!/bin/sh

#########################################################################################
# NOTES
#########################################################################################
# Amos Deane 2019
# This is combined version of multiple scripts created in 2017
# The purpose of the overall script is to be able to check the usage of packages across all policies on the JSS
# and to determine which are used the most/least
# The method for doing this requires multiple stages for parsing the data.
# Below is a summary:
# The script downloads a list of all policy ids
# It then parses list of these and downloads their xml files from the JSS
# The xml files are then parsed for their name and packages 
# A final list is then output in a text file
#########################################################################################
# Updated Jul 2022 - v.1 - updated xpath
# v1.2 - improved formatting
# v1.3 - improved efficiency
# v1.4 - added package detail
# v1.5 - added search
# v1.6 - tidied up
# v1.7 - search working
# v1.8 - tidied up
# v1.9 - new version for scripts - Feb 13 2023
# v1.9.1 - tidied up

#########################################################################################
# Variables
#########################################################################################
# These are examples and need to be configured
#########################################################################################
# Adjust address url and port to that of your jss
#########################################################################################
debugMode=YES
dateTime=$(date "+%d-%m-%Y-%H-%M")
IFS=$'\n'

########################################################################################
# Via JSS - specify here which parameter is being used
########################################################################################

# encryptedString="$4"
# jssUser="$5"

########################################################################################
########################################################################################
# To use the decrypted string as the variable $decryptedString set the salt and passphrase below
########################################################################################
# salt=
# passphrase=




#########################################################################################
# Testing Configuration - for local testing prior to usage in the JSS
#########################################################################################
#########################################################################################
# Using temp files to hold credentials for the jss. 
# These should be stored in a secure location!
#########################################################################################
# Example - needs to be configured
#########################################################################################

#########################################################################################
# If using hard coded values - these need to be configured
#########################################################################################
# jssURL=https://myJss.myDomain.co.uk:8443/
# jssUser=myExampleApiUser
# jssPass=myExamplePW



########################################################################################

function DecryptString() {
# Usage:    DecryptString "Encrypted String" "Salt" "Passphrase"
	if [[ $(sw_vers -buildVersion) > "21A" ]]; then
	echo "${1}" | /usr/bin/openssl enc -md md5 -aes256 -d -a -A -S "${2}" -k "${3}"
	else
	echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
	fi
}

decryptedString=$(DecryptString "$encryptedString" "$salt" "$passphrase")

jssPass="$decryptedString"


#########################################################################################
# Using temp files - INSECURE
#########################################################################################
# Example - needs to be configured
#########################################################################################
if [ -z "$jssPass" ]
then
echo "--------------------------------------------------------------------------" 
echo "Values not set - using local testing override for authentication"

#########################################################################################
# TESTING OVERIDE
#########################################################################################

#########################################################################################
jssURL=$(cat /Volumes/SECURE/Configs/myserv.txt)
jssUser=$(cat /Volumes/SECURE/Configs/myuser.txt)
jssPass=$(cat /Volumes/SECURE/Configs/myuserinfo.txt)

fi

#########################################################################################
currentUser=$USER
#########################################################################################
# Objects
#########################################################################################
# This is set to search for policies 
objectRequested=policies
#########################################################################################
# EXAMPLE OBJECTS
#########################################################################################
# objectRequested=departments
# objectRequested=computers
#########################################################################################
# Configured locations
#########################################################################################
# By default this creates these files in the folder where the script is being run - this can
# be re-configured if desired

#########################################################################################
# TEST CONFIGURATION
#########################################################################################
cacheFolder=./CACHE

#########################################################################################
# JSS CONFIGURATION
#########################################################################################
# cacheFolder=/Users/Shared/CACHE
# allDataXmlFilesFold="$cacheFolder/ALL_DATA_XML"
# outputFilesProcessed="$cacheFolder/PROCESSED"
# outputFolder="$cacheFolder/OUTPUT_FILES"

# xmlFilesFolder="$cacheFolder/XML_FILES"
# xmlFilesFolder="$cacheFolder/XML_FILES/PROCESSED"

xmlFilesMainFolder=$cacheFolder/XML_FILES_MAIN
xmlFilesFolder=$xmlFilesMainFolder/XML_FILES
xmlFilesProcessedFolder=$xmlFilesMainFolder/XML_FILES_PROCESSED

# xmlFilesFolder=$cacheFolder/XML_FILES
outputFolder=$cacheFolder/OUTPUT_FILES
outputFilesProcessed=$outputFolder/PROCESSED


# CONTAINED WITHIN
requestedObjectsFolder="$cacheFolder/REQUESTED_OBJECTS"
allDataXmlFilesFold=$requestedObjectsFolder/ALL_DATA_XML
# requestedObjectsFolder="$cacheFolder/REQUESTED_OBJECTS"
requestedObjectsProcessed=$requestedObjectsFolder/REQUESTED_OBJECTS_PROCESSED


finalFolder="$cacheFolder/FINAL"
# finalFolder="$cacheFolder/FINAL"
# finalFolder="$cacheFolder/FINAL"

allPoliciesTextFile="$finalFolder"/all_policies.txt
allPoliciesSummaryFile="$cacheFolder/FINAL"/allPoliciesSummary.txt
# allItemUsageSummaryFile="$cacheFolder/FINAL"/all_item_usage_summary.txt

allScriptsFile="$finalFolder"/all_scripts.txt
allScriptsAssignedFile="$finalFolder"/all_scripts_assigned.txt
confirmedAssignedScriptsFile="$finalFolder"/all_scripts_assigned_confirmed.txt
final_summary_file="$cacheFolder/FINAL"/final_summary_file.txt
policiesWithoutScriptsFile="$cacheFolder/FINAL"/policies_without_scripts.txt
unassignedScriptsFile="$finalFolder"/unassignedScripts.txt

#########################################################################################
# ACCESS DETAILS/SECURITY ETC
#########################################################################################
# To avoid including config information in the script key details are accessed from text files
# which are created on the host machine running the script - or on any location
# It is recommended that these are NOT permanently stored but are created and then removed 
# via script with some form of secure hashing

#########################################################################################
# The script is mainly in Bash but also incorporates a section in Python

#########################################################################################
# FUNCTIONS - descriptions if not self-explanatory
#########################################################################################

#########################################################################################
# checkFolderExists
#########################################################################################

function checkFolderExists () {
if [ ! -d $1 ]
then
separationLine 
echo "$1 Folder DOES NOT EXIST - MAKING"
mkdir -p $1
else
separationLine 
echo "$1 ALREADY EXISTS - PROCEEDING"
fi
}

#########################################################################################
# checkFileExists
#########################################################################################

function checkFileExists () {
# Function to check if a file exists
if [ ! -e "$1" ]
then
separationLine
echo "$1 File DOES NOT EXIST - MAKING"
touch "$1"
else
separationLine
echo "$1 ALREADY EXISTS - PROCEEDING"
fi
}

#########################################################################################
# checkFordebugMode
#########################################################################################

function checkFordebugMode () {
if [ ! -z $debugMode ]
then
separationLine
highlightSeparationLine
echo "DEBUG MODE IS ENABLED - NOT SECURE"
separationLine
echo "jssURL is set as:$jssURL"
echo "jssUser is set as:$jssUser"
echo "jssPass is set as:$jssPass"
separationLine
else
separationLine
echo "Running Normally"

fi

}


###########################################################################################
# checkForMatchInLists
###########################################################################################


function checkForMatchInLists () {
# checkForMatchInLists $allScripts $allScriptsAssignedFile $unassignedScriptsFile $confirmedAssignedScriptsFile
firstArg=$1
secondArg=$2
listOne=(`cat "$firstArg"`)
listTwo=(`cat "$secondArg"`)
missingList="$3"
foundList="$4"

separationLine 


highlightSeparationLine2
echo "Running function:checkForMatchInLists"
echo "Check for:$missingList"
echo "Check for:$foundList"

touch "$missingList"
touch "$foundList"


if [ ! -z $debugMode ]
then
separationLine
highlightSeparationLine
echo "DEBUG MODE IS ENABLED - NOT SECURE"
separationLine
echo "Confirming:listOne = $firstArg"
echo "Confirming:listTwo = $secondArg"
separationLine
echo "Confirming:missingList = $missingList"
separationLine
echo "Confirming:listOne = $listOne"
separationLine
echo "Confirming:listTwo = $listTwo"
separationLine
echo "Confirming:foundList = $foundList"

fi

	separationLine 
	echo "Check for items in $firstArg but not $secondArg"

for eachItem in "${listOne[@]}"; do
	
	echo "Checking item:$eachItem from:$listOne"
	separationLine 
	echo "Reset Match to false to allow to check for match for the next item"
	Match="False"
	
	for eachItem2 in "${listTwo[@]}"; do
	
		if [ "$Match" = "False" ]
		then
		    # If the elements don't match, loop through until we find a match or get to the end of the array
	    	if [ "$eachItem" != "$eachItem2" ]
	    	then
		    	
		    		separationLine 
					echo "$eachItem doesn't match: $eachItem2"
					echo "Continue"
					echo ""
		    else
	    		
	    			separationLine 
					echo "$eachItem matches $eachItem2 - write to found list and reset"
					echo "$eachItem" >> "$foundList"
	    		# Once we find a match, set the match variable to True. This will stop looking for additional matches.
	    		Match="True"
	    	fi
	    fi
	done
		
		# If we don't find a match as it iterates through each item write it to the missing list
		if [ "$Match" = "True" ]
		then
			separationLine 
			echo "A match occured for $eachItem"

		else
separationLine 
			echo "#############################################################"
			echo "No match found - write $eachItem to missing list:$missingList"
			echo "$eachItem" >> "$missingList"
		fi
done

}


#########################################################################################
# downloadAllChosenObject
#########################################################################################

function downloadAllChosenObject () {
# This script will download an XML file containing all the requested objects from the JSS - script 1
objectRequested=$1
requestedObjectsFolder="$2"
objectRequestedFolder="$requestedObjectsFolder/$objectRequested"
checkFolderExists "$objectRequestedFolder"

highlightSeparationLine2
echo "Running function:downloadAllChosenObject"

separationLine 
echo "Downloading XML file containing for requested object:$objectRequested from the JSS"
curl -k -u $jssUser:$jssPass "$jssURL"/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml

#########################################################################################
# DEBUG
#########################################################################################
#########################################################################################
# DEBUG
#########################################################################################

	if [ ! -z $debugMode ]
	then
	highlightSeparationLine
	echo "DEBUG MODE ENABLED - request is:"
	echo "DEBUG ****************************************************************************"
	echo "/usr/bin/curl --request Get --user ${jssUser}:${jssPass} ${jssURL}/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml"
	fi

#########################################################################################
}


#########################################################################################
# extractSearchCriteria
#########################################################################################

#########################################################################################
# This script will interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria, getting all the names and IDs. 
# In this case, this is policy record names and ids
#########################################################################################

function extractSearchCriteria () {
objectRequested=$1
#########################################################################################
# RUNNING IN PYTHON
#########################################################################################

python3 - << EOF

from __future__ import print_function

import xml.etree.ElementTree as ET
tree = ET.parse('$xmlFilesFolder/${objectRequested}.xml')
root = tree.getroot()

#########################################################################################
# parse this xml file
#########################################################################################
# TEXT OUTPUT FILE -
outputFile = '$allPoliciesTextFile'

# w means write 
log = open( outputFile , "w")

policyID = root.findall('policies/policy/id')

allPolicies = root.findall('policies/policy')

policyName = root.find('policy/name').text

policyinfo = root.findall('policy')

for data in policyinfo:
	ids =  data.find('./id').text
	policyNames = data.find('./name').text
	print ('ID:' + ids + '\tPolicy:' + policyNames , file = log)

EOF
}

#########################################################################################
# This script will interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria, getting all the names and IDs. 
# In this case, this is policy script names and ids
#########################################################################################

function extractSearchCriteria2 () {
objectRequested=$1
#########################################################################################
# RUNNING IN PYTHON
#########################################################################################

python3 - << EOF

from __future__ import print_function

import xml.etree.ElementTree as ET

tree = ET.parse('$requestedObjectsProcessed/${objectRequested}.xml')

root = tree.getroot()

# print("Printing" + "$xmlFilesFolder/${objectRequested}.xml")

#########################################################################################
# parse this xml file
#########################################################################################
# TEXT OUTPUT FILE - '$cacheFolder/FINAL/all_scripts.txt'
#########################################################################################

outputFile = '$allScriptsFile'

#########################################################################################
# w means write 
#########################################################################################
log = open( outputFile , "w")

allscripts = root.findall('script')

for data in allscripts:
	
	id =  data.find('./id').text
	scriptName = data.find('./name').text
	
	print ('Running for ID:' + id + '\tName:' + scriptName)
	print ('ID:' + id + '\tScript:' + scriptName , file = log)

	
EOF
}


function extractSearchCriteriaGeneric () {
objectRequested=$1
objectRequestedSingleLocal=$2
local xmlFilesFolder=$3
outputFileLocal=$4

#########################################################################################
# RUNNING IN PYTHON
#########################################################################################
# Arguments are:
# objectRequested
# path to: xmlFilesFolder
# Output file for objects found


highlightSeparationLine2
echo "Running function:extractSearchCriteriaGeneric"

	if [ ! -z $debugMode ]
	then
	highlightSeparationLine
	echo "DEBUG MODE"
	echo "objectRequested is set as:$objectRequested"
	echo "objectRequestedSingleLocal is set as:$objectRequestedSingleLocal"
	echo "xmlFilesFolder is set as:$xmlFilesFolder"
	echo "outputFileLocal is set as:$outputFileLocal"
	fi

python3 - << EOF

from __future__ import print_function

import xml.etree.ElementTree as ET

tree = ET.parse('$xmlFilesFolder/$objectRequested.xml')

root = tree.getroot()

outputFile = '$outputFileLocal'

objectRequestedSingle = '$objectRequestedSingleLocal'

#########################################################################################
# DEBUG
#########################################################################################


#########################################################################################
# parse this xml file
#########################################################################################


#########################################################################################
# w means write 
#########################################################################################
log = open( outputFile , "w")

allitems = root.findall(objectRequestedSingle)

for data in allitems:
	
	id =  data.find('./id').text
	objectName = data.find('./name').text
	print('--------------------------------------------------------------------------')
	print ('Running for ID:' + id + '\tName:' + objectName + '\tFile is:' + outputFile)
	print ('ID:' + id + '\tScript:' + objectName , file = log)

EOF
}



#########################################################################################
# END OF SECTION IN PYTHON
#########################################################################################



#########################################################################################
# parseFolderOfXmlPy
#########################################################################################


function parseFolderOfXmlPy () {
# v1.3
local xmlFilesFolder="$1"
outputFile1="$2"
outputFile2="$3"
outputFile3="$4"


highlightSeparationLine2
echo "Running function:parseFolderOfXmlPy"


if [ ! -z $debugMode ]
then
highlightSeparationLine
echo "DEBUG"
separationLine
echo "xmlFilesFolder is set as: $xmlFilesFolder"
echo "outputFile1 is set as: $outputFile3"
echo "outputFile2 is set as: $outputFile3"
echo "outputFile3 is set as: $outputFile3"
fi
#########################################################################################
# RUNNING IN PYTHON
#########################################################################################

python3 - << EOF

from __future__ import print_function

import xml.etree.ElementTree as ET
import os


#########################################################################################
# parse this xml file
#########################################################################################
#########################################################################################
# 
outputFile1 = '$outputFile1'
outputFile2 = '$outputFile2'
outputFile3 = '$outputFile3'

allXmlFiles = '$xmlFilesFolder'

#########################################################################################
# w means write 
#########################################################################################
log = open( outputFile1 , "w")
log2 = open( outputFile2 , "w")
log3 = open( outputFile3 , "w")

for myXML in os.listdir(allXmlFiles):
#  if statement to filter out files that are not xml files
	if myXML.endswith(".xml"):
		
		fullXMLPath = allXmlFiles + "/" + myXML
		
		print('--------------------------------------------------------------------------')
		print("CURRENT XML BEING PROCESSED IS:" + myXML )
		print('--------------------------------------------------------------------------')

		tree = ET.parse( fullXMLPath )
		root = tree.getroot()
		
		scriptinfo = root.findall('scripts/script')
		policyName = root.find('general/name').text
		policyID = root.findtext('general/id')

# 		print(policyID)
		print('****************************************************************************************************' , file = log )
		print('Policy Name is:' + policyName , file = log ) 
		if scriptinfo:
			for items in scriptinfo:
				scriptName = items.find('./name').text
				Scriptid = items.find('./id').text
				print('--------------------------------------------------------------------------')
				print("Printing to policy file")
				print ('ID:' + Scriptid + '\tScript:' + scriptName , file = log)
				print("Printing to assigned scripts file")
				print('Script ID:' + Scriptid + '\t\tName is:' + scriptName , file = log2)

		else:
				print('Policy has no scripts:' + policyName , file = log ) 
				print('Policy has no scripts:' + policyName + policyID, file = log3 ) 
# 				print('Policy has no scripts:' + policyName , file = log3 ) 

	else:
		print(myXML + 'IS NOT AN XML')
		
	print('--------------------------------------------------------------------------')

EOF
}

#########################################################################################
# parseFolderOfTextFiles
#########################################################################################

function parseFolderOfTextFiles {
# This script will parse a folder of text files
# Analyse the individual policies and extract references to scripts included in them
# A summary of all policy files goes to: "$outputFolder"/allFiles.txt
# Individual files are created for each policy with the scripts included

allPolicyTextFiles=(`ls "$outputFolder"/ | grep .txt`)
allItemUsageSummaryFile="$1"


highlightSeparationLine2
echo "Running function:parseFolderOfTextFiles"


if [ ! -z $debugMode ]
then
highlightSeparationLine
echo "DEBUG"
separationLine
echo "allItemUsageSummaryFile is now:$allItemUsageSummaryFile"

echo '#######################################'
echo "---------------------------------------"
echo "Processing Policy Text Files"
fi

# echo "ALL POLICIES ARE: ${allPolicyTextFiles[@]}" | tee -a "$outputFolder"/allFiles.txt

for currentPolicyTextFile in ${allPolicyTextFiles[@]}
do
echo "---------------------------------------"
echo "CURRENT POLICY TEXT FILE IS:$currentPolicyTextFile"

	allItems=(`cat "$outputFolder"/$currentPolicyTextFile`)
	echo "---------------------------------------"
	nameOfPolicy=${allItems[0]}
	echo "NAME OF POLICY IS FIRST ITEM IN LIST:$nameOfPolicy "
	echo "---------------------------------------"
	currentSh=$(cat "$outputFolder/$currentPolicyTextFile" | grep -E '.sh')

	if [ ! -z "$currentSh" ]
	then
	echo '***********************************************'
	echo "currentSh is: $currentSh - found in policy:$nameOfPolicy - id:$currentPolicyTextFile" >> "$allItemUsageSummaryFile"
	else
	echo "---------------------------------------"
	echo "NO SCRIPT FOUND in policy:$nameOfPolicy"
	fi

checkFolderExists "$outputFilesProcessed"


separationLine 
echo "WRITING TO NEW TEXT FILE"
separationLine 
# echo "NAME OF POLICY IS:$nameOfPolicy " > "$outputFilesProcessed"/scripts_${currentPolicyTextFile}
echo "$currentSh" >> "$outputFilesProcessed"/${nameOfPolicy}_${currentPolicyTextFile_scriptsUsed}
separationLine 
# echo "WRITING TO SUMMARY FOLDER TO CALCULATE TOTAL DEPLOYMENT OF SCRIPTS"
# echo "$currentDmgPkg" >> "$1"
separationLine 
done

}

#########################################################################################
# proceedIfVariableIsNotEmpty
#########################################################################################

function proceedIfVariableIsNotEmpty() {
var_name="$1"
actual_var_name="$!var_name"

if [ ! -z "$1" ]
then
separationLine 
echo "$actual_var_name CONTAINS A VALUE - PROCEEDING WITH SCRIPT"
touch "$var_name"
else
separationLine 
echo "VARIABLE $actual_var_name DOES NOT EXIST - ABORTING"
separationLine 
exit 0
fi
}

#########################################################################################
# processTextFileDownloadPolicy
#########################################################################################

function processTextFileDownloadPolicy {
IFS=$'\n'

xmlFilesFolderLocal="$1"
# This script will process the text file containing all the policy ids
# This will download individual policy xml files for each policy

highlightSeparationLine2
echo "Running function:processTextFileDownloadPolicy"


if [ ! -z $debugMode ]
then
highlightSeparationLine
echo "DEBUG"
separationLine
echo "allItemUsageSummaryFile is now:$allItemUsageSummaryFile"
highlightSeparationLine
highlightSeparationLine
echo "xmlFilesFolderLocal is now:$xmlFilesFolderLocal"
highlightSeparationLine
highlightSeparationLine
separationLine 
echo "DOWNLOADING ---------------------- REQUESTING POLICY IN XML FORMAT"
separationLine 
echo "FILE WILL BE DOWNLOADED TO CURRENT DIRECTORY"
separationLine 
fi

policyIds=(`cat $allPoliciesTextFile | awk '{ print $1 }' | awk -F : '{ print $NF }'`)

# proceedIfVariableIsNotEmpty "$policyIds"

if [ -z "$policyIds" ]
then
separationLine 
echo "VARIABLE $policyIds DOES NOT EXIST - ABORTING"
separationLine 
exit 0
fi

separationLine 

for currentPolicy in "${policyIds[@]}"
do

printf "CURRENT POLICY IS:$currentPolicy\tDOWNLOADING\n"
curl -v -k -u $jssUser:$jssPass $jssURL/JSSResource/policies/id/${currentPolicy} > "$xmlFilesFolderLocal"/${currentPolicy}.xml
#########################################################################################
# DEBUG
#########################################################################################

	if [ ! -z $debugMode ]
	then
	highlightSeparationLine
	echo "DEBUG - request is:"
	echo "curl -v -k -u $jssUser:$jssPass $jssURL/JSSResource/policies/id/${currentPolicy} > $xmlFilesFolderLocal/${currentPolicy}.xml"
	fi
separationLine 
echo "FILE HAS BEEN DOWNLOADED"
done
}

#########################################################################################
# processFinalProcessFile
#########################################################################################

function processFinalProcessFile () {

#########################################################################################
# This script will process the final all_scripts_assigned text file and consolidate the total installs for individual scripts
#########################################################################################

allScriptsAssignedFile="$1"
objectRequested="$2"

highlightSeparationLine2
echo "Running function:processFinalProcessFile"


if [ ! -z $debugMode ]
then
highlightSeparationLine
echo "DEBUG"
separationLine
# echo "allItemUsageSummaryFile is now:$allItemUsageSummaryFile"

separationLine 
fi

separationLine | tee -a $final_summary_file
echo "SUMMARY OF $objectRequested INSTANCES ACROSS ALL POLICIES FROM FILE:" | tee -a $final_summary_file
echo ""
echo "$allScriptsAssignedFile" | tee -a $final_summary_file
separationLine | tee -a $final_summary_file
grep -v "^$" "$allScriptsAssignedFile" | \
sort | uniq -c | \
sort -r | tee -a $final_summary_file
}

#########################################################################################
# removeBrackets
#########################################################################################

function removeBrackets () {
outputTextFile="$1"
holdingFile=holdingFile.txt
separationLine
echo "Removing brackets from file:$1"
cat "$outputTextFile" | sed "y/\//\n/" | sed -e 's/\<name>//'  | sed -e 's/name>//'  | sed -e 's/<//' > "$holdingFile"
cat "$holdingFile" > "$outputTextFile"
separationLine
# echo "Final file is:"
# cat "$outputTextFile"
rm $holdingFile
}


#########################################################################################
# separationLine
#########################################################################################

function separationLine {
echo "--------------------------------------------------------------------------" 
}

function highlightSeparationLine {
echo "###########################################################################"
}

function highlightSeparationLine2 {
echo '***************************************************************************'
}
 
#########################################################################################
# tidyXML
#########################################################################################

function tidyXML () {
xmlFilesSourceFolder="$1"
objectRequested="$2"
TargetFolder="$3"

#########################################################################################
# The first argument is the folder of files being targeted
# The second arg is the file
# The third arg is the target folder 
#########################################################################################
separationLine
highlightSeparationLine

if [ ! -z $debugMode ]
then
highlightSeparationLine
echo "DEBUG"
separationLine
echo "xmlFilesSourceFolder is:$xmlFilesSourceFolder"
separationLine
echo "objectRequested is now:$objectRequested"
separationLine
echo "TargetFolder is now:$TargetFolder"
fi

#########################################################################################
# Tidying the format of the downloaded xml
#########################################################################################
# xmllint --format $xmlFilesSourceFolder/$objectRequested/$objectRequested.xml --output $TargetFolder/${objectRequested}.xml
xmllint --format "${xmlFilesSourceFolder}/${objectRequested}.xml" --output $TargetFolder/${objectRequested}.xml

separationLine 
echo "Copying downloaded XML file from:"
separationLine
echo "$xmlFilesSourceFolder/$objectRequested.xml" 
separationLine
echo "to:"
separationLine
echo "$TargetFolder/"
# cp -v "$objectRequestedTargetFolder/${objectRequested}.xml" "$xmlFilesFolder/"

# cat $xmlFilesSourceFolder/${objectRequested}.xml
}


function tidyXMLMultiple () {
local xmlFilesFolder="$1"
xmlFilesProcessedFolder="$2"
xmlDownloadFiles=`ls $xmlFilesFolder`
for eachFile in $xmlDownloadFiles
do
# remove file extension
eachFileProcessed="${eachFile%.*}"
echo "File is:$eachFile"
echo "File is now:$eachFileProcessed"
tidyXML $xmlFilesFolder $eachFileProcessed $xmlFilesProcessedFolder
done

} 

#########################################################################################

#########################################################################################
# xpath
#########################################################################################
# Adjust xpath depending upon version of OS
#########################################################################################

xpath() {
	# the xpath tool changes in Big Sur 
	if [[ $(sw_vers -buildVersion) > "20A" ]]; then
		/usr/bin/xpath -e "$@"
	else
# 	 Old version
		/usr/bin/xpath "$@"	
	fi
}

 



#########################################################################################
# SCRIPT PROGRESS
#########################################################################################
# open ./
#########################################################################################
# Clean up old files
#########################################################################################
separationLine
echo "Starting script at:$dateTime....................."
echo "Clear old output files:$outputFolder"
# rm -Rf "$outputFolder"/*
# 
# echo "Backup Output Folder"
# mv "$outputFolder" ./"${outputFolder}_backup_$dateTime"

echo "Backup cacheFolder Folder"
# mv "$cacheFolder" ./"${cacheFolder}_backup_$dateTime"
#########################################################################################
# Check these folders exist and make if not
#########################################################################################
# 

checkFordebugMode
# 
checkFolderExists "$cacheFolder"
checkFolderExists "$xmlFilesMainFolder"
checkFolderExists "$xmlFilesFolder"
checkFolderExists "$xmlFilesProcessedFolder"
checkFolderExists "$finalFolder"
checkFolderExists "$outputFolder"
checkFolderExists "$outputFilesProcessed"
checkFolderExists "$allScriptTextFilesFolder" 
checkFolderExists "$requestedObjectsFolder" 
checkFolderExists "$requestedObjectsProcessed" 

separationLine 
checkFileExists "$allScriptsFile"
checkFileExists "$allScriptsSummary"
checkFileExists "$allPoliciesSummaryFile"
checkFileExists "$allScriptsAssignedFile"
checkFileExists "$unassignedScriptsFile"
checkFileExists "$allItemUsageSummaryFile"
checkFileExists "$policiesWithoutScriptsFile"


#########################################################################################
# Download an XML file containing all the requested objects from the JSS - stage 1
#########################################################################################
downloadAllChosenObject policies $requestedObjectsFolder
downloadAllChosenObject scripts $requestedObjectsFolder

#########################################################################################
# Tidying the format of the downloaded xml
#########################################################################################
# 
# The first argument is the folder of files being targeted
# The second arg is the file
# The third arg is the target folder 
#########################################################################################
# 

tidyXML $requestedObjectsFolder/policies policies $requestedObjectsProcessed
tidyXML $requestedObjectsFolder/scripts scripts $requestedObjectsProcessed

#########################################################################################
# Extract search criteria - 1 & 2
#########################################################################################
# Running in Python --
# Interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria. In this case, this is policies and scripts records and ids
#########################################################################################
# 
extractSearchCriteriaGeneric scripts script $requestedObjectsProcessed $allScriptsFile
extractSearchCriteriaGeneric policies policy $requestedObjectsProcessed $allPoliciesTextFile

#########################################################################################
# Process text file - and download individual policy records - 3
#########################################################################################

#########################################################################################
# Process the policy ids text files and DOWNLOAD each individual policy as an XML file
#########################################################################################
# 
processTextFileDownloadPolicy "$xmlFilesFolder"

#########################################################################################
# Parse a folder of xml individual policy files - 4
#########################################################################################
# it will then output the script name into a text file with the ID of the individual policy
# in the folder OUTPUT_FILES
#########################################################################################
# Tidy the individual xml files
# The first argument is the folder of files being targeted
# The second arg is the file
# The third arg is the target folder 
#########################################################################################

tidyXMLMultiple $xmlFilesFolder $xmlFilesProcessedFolder

parseFolderOfXmlPy "$xmlFilesProcessedFolder" "$allPoliciesSummaryFile" "$allScriptsAssignedFile" "$policiesWithoutScriptsFile"
parseFolderOfXmlPy "$xmlFilesFolder" "$allPoliciesSummaryFile" "$allScriptsAssignedFile" "$policiesWithoutScriptsFile"

# open $outputFolder

#########################################################################################
# Parse a folder of text files - 5
#########################################################################################
# Analyse the individual policy files and extract references to scripts included in them
#########################################################################################

parseFolderOfTextFiles "$outputFilesProcessed"/all_scripts_assigned.txt

#########################################################################################
# Final Summary file - 6
#########################################################################################
# # This script will process the final all_scripts_assigned text file and 
# consolidate the total use of scripts 
#########################################################################################

processFinalProcessFile "$allScriptsAssignedFile" "scripts"

#########################################################################################
# Check for packages not assigned
#########################################################################################

echo "allScriptsFile is set as:$allScriptsFile"
echo "finalFolder is set as:$finalFolder"

checkForMatchInLists "$allScriptsFile" "$allScriptsAssignedFile" "$unassignedScriptsFile" "$confirmedAssignedScriptsFile"

#########################################################################################
open $cacheFolder

echo "Ending script at:$dateTime....................."


open "$outputFilesProcessed/"



