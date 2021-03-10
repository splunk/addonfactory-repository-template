addonfactory-repository-template
===============================

This repository is used to automate the creation and updates to common files for all github.com/splunk/splunk-add-for-* projects

To rollout PR's in the repos mentioned in csv file we need to approve the sync run from the CI.

sync.sh:  
--------
Main script which will create branches, push the changes and create PR's for those changes in the repositories.

repositories_master.csv: 
--------------------------
    
This file contains repository information on which updates will be made via sync.sh  

Information like reponame, destination branch while creating PR etc. (default main).

If a new addon is introduced and we want this Commmon template to pushlish changes to that repository too the addon-repo info should be updated in this csv file.

If we want to make changes to selected repos via non-master branch a new file named repositories_<branch-name>.csv should be created with the list of repo's , Updating repositories_master.csv will only work for master branch

     
enforce: 
-------
As the name suggests the files/changes present here will be enforced to the repositories as part of a PR.
i.e. Updating License information in all the required.

seed: 
-----
The changes/files that are required to be updated only once and not everytime should be kept in seed. 
i.e package, tests, baseline files etc.

If a new file *abc.txt* is added into seed and rolled out to all the TA's, *abc.txt* will be created in the repo if the file does not already exists otherwise no changes will be made in *abc.txt*.

conditional
-----------
if we want to update files based on some conditions those files are kept here.
i.e For addons with tests/ui directory update the pytest-ci.ini file otherwise ignore
