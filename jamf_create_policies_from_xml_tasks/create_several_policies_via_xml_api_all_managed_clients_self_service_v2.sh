#!/bin/bash
#
# This is a script to create multiple jamf policies from a provided list and upload them 
# to the jss via the jamf Api
# The policy will be created with the name specified in the list
# This will also be used as a custom trigger for the policy
# You are able to specify particular standard scripts to add to each policy 
# For example: if the policy is an install policy that uses a generic download script  
# this can be added to each policy
# 
# 2021 Amos Deane
# Versions
# v1 - initial version
# v2 - added cat command to confirm text file

IFS=$'\n'
currentUser=$USER
dateTime=$(date "+%d-%m_%Y_%H_%M")

#######################################################################################
# CONFIGURATION STARTS HERE
#######################################################################################

jssAddress="addressOfJss"
serverPort=8443
apiUser="apiUserHere"
apiPass="passwordHere"

#######################################################################################
# For new policy use: 0
#######################################################################################
policyID=0
# The policy list file is required - this contains the names of the new policies
policyListFile="./policy_list.txt"
policyList=(`cat ./policy_list.txt`)

#######################################################################################
# Category
#######################################################################################

category="NameOfCategory
categoryID=XX

#######################################################################################
# Scope
#######################################################################################
# This sets the scope of the policy based on either a smart or static group

groupID=XX
groupName="NameOfGroup"

#######################################################################################
# Scripts
#######################################################################################
# Identify script/s to add to the policy

scriptID=XX
scriptName="nameOfScript"
script2ID=XX
script2Name="nameOfScript"

#######################################################################################
# Set various parameters - defaults provided

output_file_location=./output_files
selfServiceStatus=true
doRecon=false
logFile=./logs/"$dateTime"_log.txt

downloadInstallURL=
downloadInstallParam5=
downloadInstallParam6=
# Add more paramters as required

#######################################################################################
# CONFIGURATION ENDS HERE
#######################################################################################

########################################################################################	
# FUNCTIONS
########################################################################################	

########################################################################################	
# checkForLastCommandSuccess ###########################################################
########################################################################################	

trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG

function checkForLastCommandSuccess {	
	# 	Modified 10 Aug 2020
	#	Check if last command succeeded
	if [ $? != 0 ]; then
		# IF PREVIOUS COMMAND ERRORED THEN PRINT THIS MESSAGE
		echo '------------------------------------------------------------------------------------'
		echo "PREVIOUS COMMAND FAILED:$previous_command"
	else
		# ELSE PRINT THIS MESSAGE
		echo '------------------------------------------------------------------------------------'
		echo -e "PREVIOUS COMMAND: \n$previous_command \nCOMMAND COMPLETED ------------------------------------------------------------------"
	fi
}

########################################################################################	
# outputFile
########################################################################################	

function outputFile() {
output_file=$1/$2.xml
echo "First arg is: output_file_location:$1"
echo "Second arg is:eachPolicyName:$2"
echo "Output file is:$output_file"
policyName="$2"
cat > $output_file << CASPER-SYNC-LAUNCHD
<?xml version="1.0" encoding="utf-8"?>
<policy>
	<general>
		<id>$policyID</id>
		<name>$policyName</name>
		<enabled>true</enabled>
		<trigger>EVENT</trigger>
		<trigger_checkin>false</trigger_checkin>
		<trigger_enrollment_complete>false</trigger_enrollment_complete>
		<trigger_login>false</trigger_login>
		<trigger_logout>false</trigger_logout>
		<trigger_network_state_changed>false</trigger_network_state_changed>
		<trigger_startup>false</trigger_startup>
		<trigger_other>$customTrigger</trigger_other>
		<frequency>Ongoing</frequency>
		<retry_event>none</retry_event>
		<retry_attempts>-1</retry_attempts>
		<notify_on_each_failed_retry>false</notify_on_each_failed_retry>
		<location_user_only>false</location_user_only>
		<target_drive>/</target_drive>
		<offline>false</offline>
		<category>
			<id>$categoryID</id>
			<name>$category</name>
		</category>
		<date_time_limitations>
			<activation_date/>
			<activation_date_epoch>0</activation_date_epoch>
			<activation_date_utc/>
			<expiration_date/>
			<expiration_date_epoch>0</expiration_date_epoch>
			<expiration_date_utc/>
			<no_execute_on/>
			<no_execute_start/>
			<no_execute_end/>
		</date_time_limitations>
		<network_limitations>
			<minimum_network_connection>No Minimum</minimum_network_connection>
			<any_ip_address>true</any_ip_address>
			<network_segments/>
		</network_limitations>
		<override_default_settings>
			<target_drive>default</target_drive>
			<distribution_point/>
			<force_afp_smb>false</force_afp_smb>
			<sus>default</sus>
			<netboot_server>current</netboot_server>
		</override_default_settings>
		<network_requirements>Any</network_requirements>
		<site>
			<id>-1</id>
			<name>None</name>
		</site>
	</general>
	<scope>
		<all_computers>false</all_computers>
		<computers/>
		<computer_groups>
			<computer_group>
				<id>$groupID</id>
				<name>$groupName</name>
			</computer_group>
		</computer_groups>
		<buildings/>
		<departments>
		</departments>
		<limit_to_users>
			<user_groups/>
		</limit_to_users>
		<limitations>
			<users/>
			<user_groups/>
			<network_segments/>
			<ibeacons/>
		</limitations>
		<exclusions>
			<computers/>
			<computer_groups/>
			<buildings/>
			<departments/>
			<users/>
			<user_groups/>
			<network_segments/>
			<ibeacons/>
		</exclusions>
	</scope>
	<self_service>
		<use_for_self_service>true</use_for_self_service>
		<self_service_display_name>$policyName</self_service_display_name>
		<install_button_text>Install</install_button_text>
		<reinstall_button_text>Reinstall</reinstall_button_text>
		<self_service_description>This will install $policyName</self_service_description>
		<force_users_to_view_description>true</force_users_to_view_description>
		<self_service_icon/>
		<feature_on_main_page>false</feature_on_main_page>
		<self_service_categories>
			<category>
				<id>$categoryID</id>
				<name>$category</name>
				<display_in>$selfServiceStatus</display_in>
				<feature_in>false</feature_in>
			</category>
		</self_service_categories>
		<notification>false</notification>
		<notification>Self Service</notification>
		<notification_subject/>
		<notification_message/>
	</self_service>
	<package_configuration>
		<packages>
			<size>0</size>
		</packages>
	</package_configuration>
	<scripts>
		<size>1</size>
		<script>
			<id>$scriptID</id>
			<name>$scriptName</name>
			<priority>After</priority>
			<parameter4>$downloadInstallURL</parameter4>
			<parameter5>$downloadInstallParam5</parameter5>
			<parameter6>$downloadInstallParam6</parameter6>
			<parameter7/>
			<parameter8/>
			<parameter9/>
			<parameter10/>
			<parameter11/>
		</script>
			<script>
			<id>$script2ID</id>
			<name>$script2Name</name>
			<priority>After</priority>
			<parameter4/>
			<parameter5/>
			<parameter6/>
			<parameter7/>
			<parameter8/>
			<parameter9/>
			<parameter10/>
			<parameter11/>
		</script>
	</scripts>
	<printers>
		<size>0</size>
		<leave_existing_default/>
	</printers>
	<dock_items>
		<size>0</size>
	</dock_items>
	<account_maintenance>
		<accounts>
			<size>0</size>
		</accounts>
		<directory_bindings>
			<size>0</size>
		</directory_bindings>
		<management_account>
			<action>doNotChange</action>
		</management_account>
		<open_firmware_efi_password>
			<of_mode>none</of_mode>
			<of_password_sha256 since="9.23">e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855</of_password_sha256>
		</open_firmware_efi_password>
	</account_maintenance>
	<reboot>
		<message>This computer will restart in 5 minutes. Please save anything you are working on and log out by choosing Log Out from the bottom of the Apple menu.</message>
		<startup_disk>Current Startup Disk</startup_disk>
		<specify_startup/>
		<no_user_logged_in>Do not restart</no_user_logged_in>
		<user_logged_in>Do not restart</user_logged_in>
		<minutes_until_reboot>5</minutes_until_reboot>
		<start_reboot_timer_immediately>false</start_reboot_timer_immediately>
		<file_vault_2_reboot>false</file_vault_2_reboot>
	</reboot>
	<maintenance>
		<recon>$doRecon</recon>
		<reset_name>false</reset_name>
		<install_all_cached_packages>false</install_all_cached_packages>
		<heal>false</heal>
		<prebindings>false</prebindings>
		<permissions>false</permissions>
		<byhost>false</byhost>
		<system_cache>false</system_cache>
		<user_cache>false</user_cache>
		<verify>false</verify>
	</maintenance>
	<files_processes>
		<search_by_path/>
		<delete_file>false</delete_file>
		<locate_file/>
		<update_locate_database>false</update_locate_database>
		<spotlight_search/>
		<search_for_process/>
		<kill_process>false</kill_process>
		<run_command/>
	</files_processes>
	<user_interaction>
		<message_start/>
		<allow_users_to_defer>false</allow_users_to_defer>
		<allow_deferral_until_utc/>
		<allow_deferral_minutes>0</allow_deferral_minutes>
		<message_finish/>
	</user_interaction>
	<disk_encryption>
		<action>none</action>
	</disk_encryption>
</policy>
CASPER-SYNC-LAUNCHD
}

############################################################################################
# For new policy use: 0
############################################################################################

policyID=0

#######################################################################################
# SCRIPT PROGRESS
#######################################################################################

echo "Move previous files to old folder"
mv $output_file_location/*.xml $output_file_location/OLD/

echo "Policy list is:${policyList[@]}"
echo "Script started" | tee -a "$logFile"

for eachPolicy in "${policyList[@]}";
do
customTriggerUnfiltered="install"$eachPolicy

customTrigger="$(echo -e "${customTriggerUnfiltered}" | tr -d '[:space:]')"

echo "Item is:$eachPolicy" | tee -a "$logFile"
echo "customTrigger is:$customTrigger" | tee -a "$logFile"
echo "Create policy:$eachPolicy.xml"
eachPolicyNoSpace="$(echo -e "${eachPolicy}" | tr -d '[:space:]')"
outputFile $output_file_location $eachPolicyNoSpace
newFile=$output_file_location/$eachPolicyNoSpace.xml

########################################################################################	
# check XML for formatting errors
########################################################################################	
echo "--------------------------------------------------------------------------------"
echo "CHECKING new XML FILE:$newFile"
echo "--------------------------------------------------------------------------------"
xmllint --format $newFile
echo "--------------------------------------------------------------------------------"
echo "curl -skfu $apiUser:$apiPass https://$jssAddress:$serverPort/JSSResource/policies/id/$policyID -T $newFile -X POST;"
echo "--------------------------------------------------------------------------------"
echo "UPLOADING FILE:$newFile" | tee -a "$logFile"
echo "--------------------------------------------------------------------------------"
curl -skfu $apiUser:$apiPass "https://$jssAddress:$serverPort/JSSResource/policies/id/$policyID" -T "$newFile" -X POST;
checkForLastCommandSuccess | tee -a "$logFile"
echo "DONE........................................."
done

echo "Backing up policy list file"
mv "$policyListFile" ./backups/"$dateTime"_policyList.txt
echo "Create new policy list file"
touch "$policyListFile"
echo "Move policy XML to OLD folder"
mv $output_file_location/$eachPolicyNoSpace.xml $output_file_location/OLD/
open https://$jssAddress:$serverPort/policies.html



cat "$policyListFile"
echo "IF THERE IS NO ACTIVITY CHECK NOTHING IS COMMENTED OUT - OR THAT THE policy_list.txt IS NOT BLANK!"

