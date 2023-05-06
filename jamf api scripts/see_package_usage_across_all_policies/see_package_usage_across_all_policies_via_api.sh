#!/bin/sh

#########################################################################################
# NOTES
#########################################################################################
# Amos Deane 2019
# This is combined version of multiple scripts created in 2017
# The purpose of the overall script is to be able to check the usage of packages across all policies on the JSS
# and to determine which are used the most/least
# The method for doing this requires multiple stages for parsing the data.
#########################################################################################
# Below is a summary:
#########################################################################################
# The script downloads a list of all policy ids
# It then parses list of these and downloads their xml files from the JSS
# The xml files are then parsed for their name and packages 
# A final list is then output in a text file
# 
#########################################################################################
# Updated Jul 2022 - v.1 - updated xpath
# v1.2 - improved formatting
# v1.3 - improved efficiency
# v1.4 - added package detail
# v1.5 - added search
# v1.6 - tidied up
# v1.7 - search working
# v1.8 - tidied up
# v1.9 - 28 Feb 2023 - updated
#########################################################################################
# Variables
#########################################################################################
# These are examples and need to be configured
#########################################################################################
# Hard coded values - needs to be configured
# Adjust address url and port to that of your jss
jssURL=https://myJss.myDomain.co.uk:8443/
jssUser=myExampleApiUser
jssPass=myExamplePW
#########################################################################################
# Using temp files to hold credentials for the jss. 
# These should be stored in a secure location!
#########################################################################################
# Example - needs to be configured
#########################################################################################
jssUser=$(cat /Volumes/SECURE/Configs/myuser.txt)
jssPass=$(cat /Volumes/SECURE/Configs/myuserinfo.txt)
jssURL=$(cat /Volumes/SECURE/Configs/myserv.txt)
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

cacheFolder=./CACHE
xmlFilesFolder=./CACHE/XML_FILES
outputFilesProcessed=./CACHE/PROCESSED
outputFolder=./CACHE/OUTPUT_FILES
allPolicyTextFilesFolder=./CACHE/FINAL
allPackageTextFilesFolder=./CACHE/FINAL
finalFolder=./CACHE/FINAL
final_summary_file=./CACHE/FINAL/final_summary_file.txt
allPoliciesSummary=./CACHE/FINAL/allPoliciesSummary.txt
unassignedPackages=./CACHE/FINAL/unassignedPackages.txt
allPackagesAssigned="$outputFilesProcessed/all_packages_assigned.txt"
allPackages=$allPackageTextFilesFolder/all_packages.txt
confirmedAssignedPackages="$outputFilesProcessed/all_packages_assigned_confirmed.txt"
all_policies="$allPolicyTextFilesFolder/all_policies.txt"

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
# separationLine
#########################################################################################

function separationLine {
echo "--------------------------------------------------------------------------" 
}
 
#########################################################################################
# checkFolderExists
#########################################################################################

function checkFolderExists () {
if [ ! -d $1 ]
then
separationLine 
echo "$1 DOES NOT EXIST - MAKING"
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
echo "$1 DOES NOT EXIST - MAKING"
touch "$1"
else
separationLine
echo "$1 ALREADY EXISTS - PROCEEDING"
fi
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

# #########################################################################################
# # downloadAllChosenObject
# #########################################################################################
# 
# function downloadAllChosenObject2 {
# # This script will download an XML file containing all the requested objects from the JSS - script 1
# separationLine 
# echo "Downloading XML file containing for requested object:$objectRequested from the JSS"
# # /usr/bin/curl -k -u ${jssUser}:${jssPass} ${jssURL}/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml
# curl -k -u $jssUser:$jssPass "$jssURL"/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}2.xml
# 
# #########################################################################################
# # DEBUG
# #########################################################################################
# echo "DEBUG ****************************************************************************"
# echo "/usr/bin/curl --request Get --user ${jssUser}:${jssPass} ${jssURL}/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml"
# }
# 
#########################################################################################
# downloadAllChosenObject
#########################################################################################

function downloadAllChosenObject () {
# This script will download an XML file containing all the requested objects from the JSS - script 1
objectRequested=$1
objectRequestedFolder=./CACHE/REQUESTED_OBJECTS/$objectRequested
checkFolderExists "$objectRequestedFolder"

separationLine 
echo "Downloading XML file containing for requested object:$objectRequested from the JSS"
curl -k -u $jssUser:$jssPass "$jssURL"/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml

#########################################################################################
# DEBUG
#########################################################################################
echo "DEBUG ****************************************************************************"
echo "/usr/bin/curl --request Get --user ${jssUser}:${jssPass} ${jssURL}/JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml"
}

#########################################################################################
# tidyXML
#########################################################################################

function tidyXML () {
objectRequested=$1
objectRequestedFolder=./CACHE/REQUESTED_OBJECTS/$objectRequested
# Tidying the format of the downloaded xml
xmllint --format $xmlFilesFolder/${objectRequested}.xml --output $objectRequestedFolder/${objectRequested}.xml
separationLine 
echo "Copying downloaded XML file from:$objectRequestedFolder/${objectRequested}.xml to:$xmlFilesFolder/"
cp -v "$objectRequestedFolder/${objectRequested}.xml" "$xmlFilesFolder/"
}

#########################################################################################
# extractSearchCriteria
#########################################################################################

#########################################################################################
# This script will interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria. In this case, this is policy records and ids
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
outputFile = '$allPolicyTextFilesFolder/all_policies.txt'

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

function extractSearchCriteria2 () {
objectRequested=$1

#########################################################################################
# RUNNING IN PYTHON
#########################################################################################

python3 - << EOF

from __future__ import print_function

import xml.etree.ElementTree as ET

tree = ET.parse('$xmlFilesFolder/${objectRequested}.xml')
# tree = ET.parse('$packageFile')

root = tree.getroot()

# print("Printing" + "$xmlFilesFolder/${objectRequested}.xml")

#########################################################################################
# parse this xml file
#########################################################################################
# TEXT OUTPUT FILE -
# outputFile = './CACHE/ALL_PACKAGE_TEXT/all_packages.txt'
# outputFile = '$allPackageTextFilesFolder/$all_packages'
outputFile = '$allPackages'

# w means write 
log = open( outputFile , "w")

packageID = root.findall('packages/package/id')

allpackages = root.findall('packages/package')

packageName = root.find('package/name').text

packageinfo = root.findall('package')

for data in packageinfo:
	
	ids =  data.find('./id').text
	packageNames = data.find('./name').text
# 	print ('ID:' + ids + '\tpackage:' + packageNames , file = log)
	print (packageNames , file = log)


EOF
}


#########################################################################################
# END OF SECTION IN PYTHON
#########################################################################################



#########################################################################################
# processTextFileDownloadPolicy
#########################################################################################

function processTextFileDownloadPolicy {
IFS=$'\n'

# This script will process the text file containing all the policy ids
# This will download individual policy xml files for each policy
separationLine 
echo "DOWNLOADING ---------------------- REQUESTING POLICY IN XML FORMAT"
separationLine 
echo "FILE WILL BE DOWNLOADED TO CURRENT DIRECTORY"
separationLine 

policyIds=(`cat $allPolicyTextFilesFolder/all_policies.txt | awk '{ print $1 }' | awk -F : '{ print $NF }'`)

# proceedIfVariableIsNotEmpty "$policyIds"

if [ -z "$policyIds" ]
then
separationLine 
echo "VARIABLE $!policyIds DOES NOT EXIST - ABORTING"
separationLine 
exit 0
fi

separationLine 
for currentPolicy in "${policyIds[@]}"
do

printf "CURRENT POLICY IS:$currentPolicy\tDOWNLOADING\n"
curl -v -k -u $jssUser:$jssPass $jssURL/JSSResource/policies/id/${currentPolicy} > "$xmlFilesFolder"/${currentPolicy}.xml

#########################################################################################
# DEBUG
#########################################################################################

echo "curl -v -k -u $jssUser:$jssPass $jssURL/JSSResource/policies/id/${currentPolicy} > "$xmlFilesFolder"/${currentPolicy}.xml
"
separationLine 
echo "FILE HAS BEEN DOWNLOADED"
done
}

#########################################################################################
# parseFolderOfXML
#########################################################################################

function parseFolderOfXML {

searchItem=name
searchItem2=package
allXmlFiles=(`ls "$xmlFilesFolder"/ | grep xml`)
namedItems=XmlFiles

#########################################################################################
# this script will parse a folder of xml individual policy files
# it will then output the searched details into a text file named with the id of the individual policy
# in the folder OUTPUT_FILES
#########################################################################################

# open "$outputFolder"


separationLine 
echo "PROCESSING XML FILES"
separationLine 
echo "MAIN OUTPUT - SEARCH ITEM IS:$searchItem"
separationLine 
echo "CONVERTING XML FILES TO TEXT FILE"
separationLine 
echo "CREATING:$outputFolder/holdingFile.txt"

# proceedIfVariableIsNotEmpty "$outputFolder"


if [ -z "$outputFolder" ]
then
separationLine 
echo "VARIABLE $!outputFolder DOES NOT EXIST - ABORTING"
separationLine 
exit 0
fi

	touch "$outputFolder"/holdingFile.txt

IFS=$'\n'

		for currentXmlFile in "${allXmlFiles[@]}"
		do
		separationLine 
		echo "CURRENT XML FILE IS:$currentXmlFile"
		separationLine 
		echo "MAKING TEXT FILE FOR:$currentXmlFile"
		# REMOVE FILE EXTENSION
		shortenedCurrentXML=${currentXmlFile%.*}
		outputTextFile="$outputFolder"/${shortenedCurrentXML}.txt
		holdingFile="$outputFolder/holdingFile.txt"
		separationLine 
		echo "REMOVING FILE EXTENSION - NEW NAME IS:$shortenedCurrentXML"
		separationLine 
		echo "PARSING XML FILE - SEARCHING FOR OCCURENCE OF:$searchItem"
		
		separationLine 
		echo "OUTPUTTING POLICY NAME INTO TEMP FILE"
		xpath '/policy/general/name' "$xmlFilesFolder"/"$currentXmlFile" | tee -a $outputTextFile $allPoliciesSummary
		separationLine 
		echo "OUTPUTTING PACKAGE NAME INTO TEMP FILE"
		xpath '/policy/package_configuration/packages/package/name' "$xmlFilesFolder"/"$currentXmlFile" | tee -a $outputTextFile $allPoliciesSummary

		separationLine 
# 		echo "Removing brackets from file:$$outputTextFile"
# 		cat "$outputTextFile" | sed "y/\//\n/" | sed -e 's/\<name>//'  | sed -e 's/name>//'  | sed -e 's/<//' > "$holdingFile"
# 		cat "$holdingFile" > "$outputTextFile"
# 	rm "$holdingFile"
	
	removeBrackets "$outputTextFile"
	removeBrackets $allPoliciesSummary
	
		done

separationLine 
echo "CLEARING HOLDING FILE: $outputFolder/holdingFile.txt"
separationLine 

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
echo "Final file is:"
cat "$outputTextFile"
rm $holdingFile
}

#########################################################################################
# parseFolderOfTextFiles
#########################################################################################

function parseFolderOfTextFiles {
# This script will parse a folder of text files
# Analyse the individual policies and extract references to packages and dmg included in them

allTextFiles=(`ls "$outputFolder"/ | grep .txt`)

echo "---------------------------------------"
echo "ALL POLICIES ARE: ${allTextFiles[@]}" | tee -a "$outputFolder"/allFiles.txt
echo "---------------------------------------"

for currentTextFile in ${allTextFiles[@]}
do
echo "CURRENT TEXT FILE IS:$currentTextFile"

	allItems=(`cat "$outputFolder"/$currentTextFile`)
	echo "---------------------------------------"
	nameOfPolicy=${allItems[0]}
	echo "NAME OF POLICY IS FIRST ITEM IN LIST:$nameOfPolicy "
	echo "---------------------------------------"
	currentDmgPkg=$(cat "$outputFolder/$currentTextFile" | grep -E 'pkg|dmg')

	if [ ! -z "$currentDmgPkg" ]
	then
	echo "***********************************************"
	echo "currentDmgPkg is: $currentDmgPkg"
	fi

checkFolderExists "$outputFilesProcessed"

# 		if [ ! -d "$outputFilesProcessed" ]
# 		then
# 		echo "---------------------------------------"
# 		echo "MAKING PROCESSED FOLDER"
# 		mkdir "$outputFilesProcessed"
# 		else
# 		echo "---------------------------------------"
# 		echo "PROCESSED FOLDER ALREADY EXISTS"
# 		fi

separationLine 
echo "WRITING TO NEW TEXT FILE"
separationLine 
# echo "NAME OF POLICY IS:$nameOfPolicy " > "$outputFilesProcessed"/packages_${currentTextFile}
# currentDmgPkg=$(cat "$outputFile"/$currentTextFile | grep -E 'pkg|dmg')
echo "$currentDmgPkg" >> "$outputFilesProcessed"/${nameOfPolicy}_${currentTextFile}
separationLine 
echo "WRITING TO SUMMARY FOLDER TO CALCULATE TOTAL DEPLOYMENT OF PACKAGES"
echo "$currentDmgPkg" >> "$outputFilesProcessed"/all_packages_assigned.txt
separationLine 

done

}

#########################################################################################
# processFinalProcessFile
#########################################################################################

function processFinalProcessFile {

# This script will process the final all_packages_assigned text file and consolidate the total installs for individual packages

separationLine | tee -a $final_summary_file
echo "SUMMARY OF PACKAGE INSTANCES ACROSS ALL POLICIES FROM FILE:" | tee -a $final_summary_file
echo ""
echo "$allPackagesAssigned" | tee -a $final_summary_file
separationLine | tee -a $final_summary_file
grep -v "^$" "$allPackagesAssigned" | \
sort | uniq -c | \
sort -r | tee -a $final_summary_file

}

###########################################################################################
# checkForMatchInLists
###########################################################################################


function checkForMatchInLists () {

touch $3
touch $4

listOne=(`cat $1`)
listTwo=(`cat $2`)
missingList=($3)
foundList=($4)

separationLine 

echo "Confirming:listOne = $1"
echo "Confirming:listTwo = $2"
echo "Confirming:missingList = $3"
echo "Confirming:foundList = $4"

	separationLine 
	echo "Check for items in one array but not the other"

for eachItem in ${listOne[@]}; do
	
	echo "Checking item:$eachItem"
	separationLine 
	echo "Reset Match to false to allow to check for match for the next item"
	Match="False"
	
	for eachItem2 in ${listTwo[@]}; do
	
		if [ "$Match" = "False" ]
		then
		    # If the elements don't match, loop through until we find a match or get to the end of the volatile users array
	    	if [ "$eachItem" != "$eachItem2" ]
	    	then
		    	
		    		separationLine 
					echo "$eachItem doesn't match $eachItem2 - continue"
					echo ""
		    else
	    		
	    			separationLine 
					echo "$eachItem matches $eachItem2 - write to found list and reset"
					echo "$eachItem" >> $foundList
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
			echo "No match found - write $eachItem to missing list"
			echo "$eachItem" >> $missingList
		fi
done

}

#########################################################################################
# SCRIPT PROGRESS
#########################################################################################

# open ./

# Check these folders exist and make if not
checkFolderExists "$cacheFolder"
checkFolderExists "$xmlFilesFolder"
checkFolderExists "$allPolicyTextFilesFolder"
checkFolderExists "$allPackageTextFilesFolder"
checkFolderExists "$outputFolder"
checkFolderExists "$outputFilesProcessed"
checkFolderExists "$finalFolder"

separationLine 
checkFileExists $all_policies
separationLine 
checkFileExists $allPackages
checkFileExists $allPoliciesSummary
#########################################################################################
# Download an XML file containing all the requested objects from the JSS - stage 1
#########################################################################################

downloadAllChosenObject policies
downloadAllChosenObject packages


#########################################################################################
# Tidying the format of the downloaded xml
#########################################################################################

tidyXML policies
tidyXML packages

#########################################################################################
# Extract search criteria - 2
#########################################################################################
# Running in Python --
# Interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria. In this case, this is policy records and ids
#########################################################################################

extractSearchCriteria policies
extractSearchCriteria2 packages

#########################################################################################
# Process text file - and download individual policy records - 3
#########################################################################################

#########################################################################################
# Process the policy ids text filea and DOWNLOAD each individual policy as an XML file
#########################################################################################

processTextFileDownloadPolicy 

#########################################################################################
# Parse a folder of xml individual policy files - 4
#########################################################################################
# it will then output the searched details into a text file with the name of the individual policy
# in the folder OUTPUT_FILES
#########################################################################################

parseFolderOfXML

#########################################################################################
# Parse a folder of text files - 5
#########################################################################################
# Analyse the individual policies and extract references to packages and dmg included in them
#########################################################################################

parseFolderOfTextFiles

#########################################################################################
# Final Summary file - 6
#########################################################################################
# # This script will process the final all_packages_assigned text file and consolidate the total installs for individual packages
#########################################################################################

processFinalProcessFile

#########################################################################################
# Check for packages not assigned
#########################################################################################

checkForMatchInLists $allPackages $allPackagesAssigned $unassignedPackages $confirmedAssignedPackages 

echo "Opening folder containing results"
open $cacheFolder

# open "$outputFilesProcessed/"

