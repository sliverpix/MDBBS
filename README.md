# MDBBS - MongoDB Backup and Store


## Description

* __Filename:__    	mdbbs_logrotate.bat
* __Created:__      	11-02-2018
* __Modified:__   	03-20-2019
* __Author:__         James Griffith
* __Version:__        2.0


The purpose of this batch file is to rotate the log of the MongoDB instance. Mongo does not do this automatically. This script will open a mongo shell, use adminDB and runCommand to start the internal LogRotate. Regardless if a logrotate is issued, the script will also clean up old log files. This script should be set to a scheduled task to be most effective.

## History
