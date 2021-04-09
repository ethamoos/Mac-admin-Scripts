  This is a script to make sure that all the components of Adobe CC have installed correctly. 
  
  This will do the following:
  
  Checks components: (e.g. that files are physically there?
  Checks size of the overall install - if it finds applications missing it will trigger a re-install via jamf pro
  Checks for crash logs, to ascertain if they are crashing on launch -  if so, triggers a re-install for that module.
  (this needs to be configured and individual install policies need to be present) 
  
  The script works via the presence of flags, so it can be configured to keep trying at a set interval until it detects all components from Adobe CC present on the device, at which point the flag will be removed and the script will cease to trigger.
  
  Known issues:
  The calculation of the size of the fully installed suite is fairly basic and limited in the scope of what is checked. In practise, I have found that it works reasonably well as if an install fails it usually ommits most of the install files, however it could potentially be unreliable and I am looking at creating a function/some functions to do more accurate install checks.
