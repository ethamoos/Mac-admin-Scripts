####################################################################################
This is script to remove and re-add an account from encryption - this can be used to fix an account that is not syncing its password.
####################################################################################

# IMPORTANT! 

a) This can not re-add the user that is currently logged in, therefore it should be run 
when logged in with a separate account than that to be re-added

b) This must be run from an account that is enabled for filevault

c) This is a work in progress script with no guarantees of its success.
Please test it carefully on a test machine in your environment before using it

 
d) ALWAYS ensure that you have access to a valid filevault enabled account before making 
any modifications on any other filevault enabled accounts, to avoid locking 
yourself out of the machine!
