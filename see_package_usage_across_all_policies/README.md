The purpose of this script is to be able to check the usage of packages across all policies on the JSS
and to determine which are used the most/least. The method for doing this is, admittedly somewhat "Heath Robinson" and requires multiple stages for parsing the data.

Below is a summary of the process:
The script downloads a list of all policy ids
It then parses list of these and downloads their xml files from the JSS
The xml files are then parsed for their name and packages
A final list is then output in a text file, summarising the packages number of occurrences in the jss
