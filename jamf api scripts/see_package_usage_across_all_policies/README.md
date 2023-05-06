The purpose of this script is to be able to check the usage of packages across all policies on the JSS
and to determine which are used the most/least. The method for doing this queries the JSS via the web api,
downloads the data as XML, and then processes the data parsing it and converting it into a text format.

Below is a summary of the process:
The script downloads a list of all policy ids
It then parses list of these and downloads their xml files from the JSS
The xml files are then parsed for their name and packages
A final list is then output in a text file, summarising the packages number of occurrences in the jss
