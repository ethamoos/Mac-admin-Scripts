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
# 
# Updated Jul 2022 - v.1
#########################################################################################
# Variables
#########################################################################################
# These are examples and need to be configured
#########################################################################################
# Hard coded values - needs to be configured
# Adjust address url and port to that of your jss
jssHost=https://myJss.myDomain.co.uk:8443/
jssUser=
jssPass=
#########################################################################################
# Using temp files
#########################################################################################
# Example - needs to be configured
#########################################################################################
# jssUser=$(cat /Users/$USER/.myuser.txt)
# jssPass=$(cat /Users/$USER/.userinfo.txt)
# jssHost=(cat ~/.myserv.txt)
#########################################################################################
currentUser=$USER
#########################################################################################
# Objects
#########################################################################################
# This is set to search for policies 
objectRequested=policies
#########################################################################################
# EXAMPLE OBJECTS
# objectRequested=departments
# objectRequested=computers
#########################################################################################
# Configured locations
#########################################################################################
# By default this creates these files in the folder where the script is being run - this can
# be re-configured if desired

objectRequestedFolder=./REQUESTED_OBJECTS/$objectRequested
xmlFilesFolder=./XML_FILES
outputFilesProcessed=./OUTPUT_FILES/PROCESSED
outputFolder=./OUTPUT_FILES
finalProcessFile="$outputFilesProcessed/ALL_PACKAGES_SUMMARY.txt"

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
# FUNCTIONS
#########################################################################################

function checkFolderExists () {
if [ ! -d $1 ]
then
echo "----------------------------------------------------------------"
echo "$1 DOES NOT EXIST - MAKING"
mkdir -p $1
else
echo "----------------------------------------------------------------"
echo "$1 ALREADY EXISTS - PROCEEDING"
fi
}

#########################################################################################
# downloadAllChosenObject


function downloadAllChosenObject {
# This script will download an XML file containing all the requested objects from the JSS - script 1
echo "----------------------------------------------------------------"
echo "Downloading XML file containing for requested object:$objectRequested from the JSS"
/usr/bin/curl --request Get --user ${jssUser}:${jssPass} ${jssHost}JSSResource/$objectRequested >> $objectRequestedFolder/${objectRequested}.xml
}

#########################################################################################
# tidyXML

function tidyXML {
# Tidying the format of the downloaded xml
sudo xmllint --format $xmlFilesFolder/${objectRequested}.xml --output $objectRequestedFolder/${objectRequested}.xml
echo "----------------------------------------------------------------"
echo "Copying downloaded XML file from:$objectRequestedFolder/${objectRequested}.xml to:$xmlFilesFolder/"
cp -v "$objectRequestedFolder/${objectRequested}.xml" "$xmlFilesFolder/"
}


#########################################################################################
# extractSearchCriteria
#########################################################################################

# This script will interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria. In this case, this is policy records and ids

function extractSearchCriteria {

#########################################################################################
# RUNNING IN PYTHON
#########################################################################################

python - << EOF

from __future__ import print_function

import xml.etree.ElementTree as ET
tree = ET.parse('$xmlFilesFolder/CasperPolicies.xml')
root = tree.getroot()

#########################################################################################
# parse this xml file
#########################################################################################
# TEXT OUTPUT FILE -
outputFile = './TEXT_FILES/all_policy_info.txt'

# w means write 
log = open( outputFile , "w")

policyID = root.findall('policies/policy/id')

allPolicies = root.findall('policies/policy')

policyName = root.find('policy/name').text

policyinfo = root.findall('policy')


for data in policyinfo:
	
	ids =  data.find('./id').text
	policyNames = data.find('./name').text
	print ('ID:' + ids + '\tPolicy:' + policyNames + '\tPackage:\t' , file = log)

EOF
}
#########################################################################################
# END OF SECTION IN PYTHON
#########################################################################################



#########################################################################################
# processTextFile
#########################################################################################

function processTextFile {
IFS=$'\n'

# This script will process the text file containing all the policy ids
# This will download individual policy xml files for each policy
echo "------------------------------------------------------------------"
echo "REQUESTING POLICY IN XML FORMAT"
echo "------------------------------------------------------------------"
echo "FILE WILL BE DOWNLOADED TO CURRENT DIRECTORY"
echo "------------------------------------------------------------------"

policyIds=(`cat ./TEXT_FILES/all_policy_info.txt | awk '{ print $1 }'`)

echo "------------------------------------------------------------------"
for currentPolicy in "${policyIds[@]}"
do
printf "CURRENT POLICY IS:$currentPolicy\tDOWNLOADING\n"
curl -v -k -u $apiUser:$apiPass $jssURL/JSSResource/policies/id/${currentPolicy} > "$xmlFilesFolder"/${currentPolicy}.xml
echo "------------------------------------------------------------------"
echo "FILE HAS BEEN PROCESSED"
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

# this script will parse a folder of xml individual policy files
# it will then output the searched details into a text file with the name of the individual policy
# in the folder OUTPUT_FILES


echo "--------------------------------------------------------------"
echo "PROCESSING XML FILES"
echo "--------------------------------------------------------------"
echo "MAIN OUTPUT - SEARCH ITEM IS:$searchItem"
echo "--------------------------------------------------------------"
echo "CONVERTING XML FILES TO TEXT FILE"

echo "--------------------------------------------------------------"
echo "CREAING:$outputFolder/holdingFile.txt"

touch "$outputFolder"/holdingFile.txt
IFS=$'\n'
		for currentXmlFile in "${allXmlFiles[@]}"
		do
		echo "--------------------------------------------------------------"
		echo "CURRENT XML FILE IS:$currentXmlFile"
		echo "--------------------------------------------------------------"
		echo "MAKING TEXT FILE FOR:$currentXmlFile"
		# REMOVE FILE EXTENSION
		shortenedCurrentXML=${currentXmlFile%.*}
		echo "--------------------------------------------------------------"
		echo "REMOVING FILE EXTENSION - NEW NAME IS:$shortenedCurrentXML"
		echo "--------------------------------------------------------------"
		echo "PARSING XML FILE - SEARCHING FOR OCCURENCE OF:$searchItem"
		echo "--------------------------------------------------------------"
		echo "OUTPUTTING DEPARTMENT POLICY NAME INTO FILE"
		echo "--------------------------------------------------------------"
		xpath "$xmlFilesFolder"/"$currentXmlFile" '/policy/general/name' >> "$outputFolder"/holdingFile.txt
		xpath "$xmlFilesFolder"/"$currentXmlFile" '/policy/package_configuration/packages/package/name' >> "$outputFolder"/holdingFile.txt
		cat "$outputFolder"/holdingFile.txt | sed "y/\//\n/" | sed -e 's/\<name>//'  | sed -e 's/name>//'  | sed -e 's/<//' > "$outputFolder"/${shortenedCurrentXML}.txt
		cat "$outputFolder"/holdingFile.txt | sed "y/\//\n/" | sed -e 's/\<name>//'  | sed -e 's/name>//'  | sed -e 's/<//' > "$outputFilesProcessed"/ALL_PACKAGES_SUMMARY.txt
		cat "$outputFolder"/holdingFile.txt | sed "y/\//\n/" | sed -e 's/\<name>//'  | sed -e 's/name>//'  | sed -e 's/<//' > "$finalProcessFile"
		
		
		done

echo "--------------------------------------------------------------"
echo "CLEARING HOLDING FILE: $outputFolder/holdingFile.txt"
echo "--------------------------------------------------------------"

rm "$outputFolder"/holdingFile.txt


}

#########################################################################################
# parseFolderOfTextFiles
#########################################################################################

function parseFolderOfTextFiles {
# This script will parse a folder of text files
# Analyse the individual policies and extract references to packages and dmg included in them

allTextFiles=(`ls "$outputFolder"/ | grep .txt`)

echo "---------------------------------------"
echo "ALL DEPARTMENTS ARE: ${allTextFiles[@]}"
echo "---------------------------------------"

for currentTextFile in ${allTextFiles[@]}
do
echo "CURRENT TEXT FILE IS:$currentTextFile"

allItems=(`cat "$outputFolder"/$currentTextFile`)
echo "---------------------------------------"
echo "NAME OF DEPARTMENT IS: ${allItems[0]} "
echo "---------------------------------------"
cat "$outputFolder"/$currentTextFile | grep -E 'pkg|dmg' 



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

echo "---------------------------------------"
echo "WRITING TO NEW TEXT FILE"
echo "---------------------------------------"
echo "NAME OF DEPARTMENT IS: ${allItems[0]} " > "$outputFilesProcessed"/packages_${currentTextFile}
cat "$outputFile"/$currentTextFile | grep -E 'pkg|dmg'  >> "$outputFilesProcessed"/${allItems[0]}_${currentTextFile}
echo "---------------------------------------"
echo "WRITING TO SUMMARY FOLDER TO CALCULATE TOTAL DEPLOYMENT OF PACKAGES"
cat "$outputFile"/$currentTextFile | grep -E 'pkg|dmg' >> "$outputFilesProcessed"/ALL_PACKAGES_SUMMARY.txt
echo "---------------------------------------"

done

}

#########################################################################################
# processFinalProcessFile
#########################################################################################

function processFinalProcessFile {

# This script will process the final ALL_PACKAGES_SUMMARY text file and consolidate the total installs for individual packages

echo "------------------------------------------------------------------------"
echo "SUMMARY OF PACKAGE INSTANCES ACROSS ALL POLICIES FROM:$finalProcessFile"
echo "------------------------------------------------------------------------"
grep -v "^$" "$finalProcessFile" | \
sort | uniq -c | \
sort -r


}



#########################################################################################
# SCRIPT PROGRESS
#########################################################################################

# Check these folders exist and make if not
checkFolderExists "$objectRequestedFolder"
checkFolderExists "$xmlFilesFolder"
checkFolderExists ./TEXT_FILES
checkFolderExists "$outputFolder"

# Download an XML file containing all the requested objects from the JSS
downloadAllChosenObject 

# Tidying the format of the downloaded xml
tidyXML

# Running in Python --
# Interrogate the xml file (downloaded from the jss) and extract 
# the requested search criteria. In this case, this is policy records and ids
extractSearchCriteria

# Process the text file containing all the policy ids
# Note:This will DOWNLOAD individual policy xml files for each policy via the jamf API

# processTextFile 

# Parse a folder of xml individual policy files
# it will then output the searched details into a text file with the name of the individual policy
# in the folder OUTPUT_FILES

# parseFolderOfXML

# Parse a folder of text files
# Analyse the individual policies and extract references to packages and dmg included in them

# parseFolderOfTextFiles
# 
# 
# # This script will process the final ALL_PACKAGES_SUMMARY text file and consolidate the total installs for individual packages
# processFinalProcessFile


# open ./